#!/bin/bash
# sdd-cache-post.sh - WebFetch 用 PostToolUse フック。
#
# WebFetch 後、レスポンス本文を .claude/sdd-cache/<sha>.json に保存する。
# 現在の ETag / Last-Modified は HEAD リクエストで取得し、次回 fetch 時に
# pre フックが再検証できるようにする。
#
# URL をキーにする。呼び出し元のプロンプトはキーの一部ではなくメタデータとして
# 保存されるため、将来のキャッシュヒット時に、どの問いがキャッシュ読み取りを
# 生んだかを示せる。ETag または Last-Modified のないエントリはキャッシュしない。
#
# 依存関係: jq、curl、shasum（または sha256sum）。

set -euo pipefail

command -v jq   >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0
command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || exit 0

if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# デバッグログ: SDD_CACHE_DEBUG=1 が設定されているか、
# .claude/sdd-cache/.debug sentinel ファイルがある場合に有効。
# `touch` / `rm` で切り替える。
dbg() {
  local dir="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
  [ "${SDD_CACHE_DEBUG:-0}" = "1" ] || [ -f "$dir/.debug" ] || return 0
  mkdir -p "$dir"
  printf '%s [post] %s\n' "$(date -u +%FT%TZ)" "$*" >> "$dir/.debug.log"
}
dbg "起動, input=$(printf '%s' "$INPUT" | head -c 400)"

URL=$(printf '%s'    "$INPUT" | jq -r '.tool_input.url    // empty' 2>/dev/null || true)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
if [ -z "$URL" ]; then dbg "tool_input に url がないため終了"; exit 0; fi
dbg "url=$URL prompt=$(printf '%s' "$PROMPT" | head -c 80)"

# WebFetch tool_response の形（2026-04 時点の Claude Code）は、bytes、code、
# codeText、durationMs、result、url を持つオブジェクトで、内容は .result にある。
# 形が変わった場合に備え、他のキー（.output / .text / .content / .body）は
# 防御的フォールバックとして残す。どれにも一致しなければ jq は空を返す。
# 文字列分岐は古い連携やカスタム連携を扱う。
TOOL_RESPONSE_TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_response | type' 2>/dev/null || echo "unknown")
dbg "tool_response type=$TOOL_RESPONSE_TYPE keys=$(printf '%s' "$INPUT" | jq -r 'try (.tool_response | keys | join(",")) catch "n/a"' 2>/dev/null)"

CONTENT=$(printf '%s' "$INPUT" | jq -r '
  if (.tool_response | type) == "object" then
    (.tool_response.result
     // .tool_response.output
     // .tool_response.text
     // .tool_response.content
     // .tool_response.body
     // empty)
  elif (.tool_response | type) == "string" then
    .tool_response
  else
    empty
  end
' 2>/dev/null || true)

if [ -z "$CONTENT" ]; then
  dbg "tool_response から content を抽出できないため終了（形状不明）"
  exit 0
fi
dbg "抽出した content bytes=${#CONTENT}"

# pre フックと一致させる: sha256(URL) の先頭 32 hex 文字。
hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
mkdir -p "$CACHE_DIR"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

# オリジンからバリデータを取得する。エージェントが実際にやり取りした URL と
# 一致するようリダイレクトをたどる。リダイレクトチェーン上のレスポンスブロック間の
# 空区切りを awk の段落モードが認識できるよう、CR を除去する。
HEAD_OUT=$(curl -sI -L --max-time 5 "$URL" 2>/dev/null | tr -d '\r' || true)

# 中間の 301/302 hop からバリデータを拾わないよう、最終レスポンスの
# ヘッダー（最後の段落）だけを使う。
FINAL_HEADERS=$(printf '%s' "$HEAD_OUT" | awk '
  BEGIN { RS = ""; last = "" }
  { last = $0 }
  END { print last }
')

extract_header() {
  local name="$1"
  printf '%s' "$FINAL_HEADERS" | awk -v h="$name" '
    BEGIN { FS = ":" }
    tolower($1) == tolower(h) {
      sub(/^[^:]*:[ \t]*/, "")
      sub(/[ \t]+$/, "")
      print
      exit
    }
  '
}

ETAG=$(extract_header "ETag")
LAST_MOD=$(extract_header "Last-Modified")
dbg "HEAD etag=$ETAG last_modified=$LAST_MOD"

if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "オリジンからバリデータがないため、古いエントリを削除して終了"
  rm -f "$CACHE_FILE"
  exit 0
fi

NOW=$(date +%s)

TMP="${CACHE_FILE}.$$.tmp"
if jq -n \
  --arg url           "$URL" \
  --arg prompt        "$PROMPT" \
  --arg etag          "$ETAG" \
  --arg last_modified "$LAST_MOD" \
  --arg content       "$CONTENT" \
  --argjson fetched_at "$NOW" \
  '{url: $url, prompt: $prompt, etag: $etag, last_modified: $last_modified, content: $content, fetched_at: $fetched_at}' \
  > "$TMP"
then
  mv "$TMP" "$CACHE_FILE"
  dbg "キャッシュファイルを書き込み: $CACHE_FILE"
else
  rm -f "$TMP"
  dbg "jq が失敗したため一時ファイルを削除"
fi

exit 0
