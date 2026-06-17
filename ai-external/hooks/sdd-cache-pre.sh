#!/bin/bash
# sdd-cache-pre.sh - WebFetch 用 PreToolUse フック。
#
# URL をキーにした HTTP リソースキャッシュ。新鮮性は HTTP バリデータで
# オリジンへ委譲する。304 Not Modified だけをキャッシュ提供の根拠にする。
# ヒット時は終了コード 2 で終了し、キャッシュ本文を stderr に書くことで、
# Claude Code が WebFetch 結果の代わりにエージェントへ渡せるようにする。
# それ以外では 0 で終了する。
#
# TTL はない。バリデータが変更を捕捉できないなら、他にも捕捉できるものはない。
# ETag または Last-Modified のないエントリは、再検証できないためキャッシュしない。
#
# キャッシュ本文はプロンプト依存である（WebFetch がモデルで後処理する）。
# そのためキーは URL のみにし、ヒット時メッセージで元プロンプトを示すことで、
# 次のエージェントが過去の読み取りをまだ適用できるか判断できるようにする。
#
# 依存関係: jq、curl、shasum（または sha256sum）。

set -euo pipefail

# graceful degradation: 依存関係が欠けている場合は fetch を通す。
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
  printf '%s [pre]  %s\n' "$(date -u +%FT%TZ)" "$*" >> "$dir/.debug.log"
}
dbg "起動"

URL=$(printf '%s' "$INPUT" | jq -r '.tool_input.url // empty' 2>/dev/null || true)
if [ -z "$URL" ]; then dbg "tool_input に url がないため終了"; exit 0; fi
dbg "url=$URL"

# キャッシュキーは sha256(URL) を 128 ビットへ切り詰めたもの。
hash_key() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | cut -c1-32
  else
    printf '%s' "$1" | sha256sum | cut -c1-32
  fi
}

CACHE_DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/sdd-cache"
CACHE_FILE="$CACHE_DIR/$(hash_key "$URL").json"

if [ ! -f "$CACHE_FILE" ]; then dbg "$CACHE_FILE にキャッシュファイルがないため終了"; exit 0; fi
dbg "キャッシュファイルあり: $CACHE_FILE"

FETCHED_AT=$(jq -r '.fetched_at // 0' "$CACHE_FILE" 2>/dev/null || echo 0)
ORIGINAL_PROMPT=$(jq -r '.prompt // empty' "$CACHE_FILE" 2>/dev/null || true)
ETAG=$(jq -r '.etag // empty' "$CACHE_FILE" 2>/dev/null || true)
LAST_MOD=$(jq -r '.last_modified // empty' "$CACHE_FILE" 2>/dev/null || true)

# バリデータがなければ新鮮性を検証できないため、キャッシュから返さない。
if [ -z "$ETAG" ] && [ -z "$LAST_MOD" ]; then
  dbg "キャッシュエントリに etag/last-modified がなく再検証できないためバイパス"
  exit 0
fi

HEADERS=()
[ -n "$ETAG" ]     && HEADERS+=(-H "If-None-Match: $ETAG")
[ -n "$LAST_MOD" ] && HEADERS+=(-H "If-Modified-Since: $LAST_MOD")

STATUS=$(curl -sI -o /dev/null -w "%{http_code}" \
  --max-time 5 -L \
  "${HEADERS[@]}" \
  "$URL" 2>/dev/null || echo "000")
dbg "再検証 HEAD status=$STATUS"

if [ "$STATUS" != "304" ]; then
  dbg "304 ではないため WebFetch を続行"
  exit 0
fi

# サーバーが内容不変を確認したため、キャッシュコピーをエージェントへ返す。
CONTENT=$(jq -r '.content // empty' "$CACHE_FILE" 2>/dev/null || true)
if [ -z "$CONTENT" ]; then dbg "キャッシュファイルの content フィールドが空のためバイパス"; exit 0; fi
dbg "キャッシュヒット。${#CONTENT} バイトのキャッシュ内容で WebFetch をブロック"

VERIFIED_AT_ISO=$(date -u -r "$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || date -u -d "@$FETCHED_AT" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
              || echo "unknown")

# $CONTENT がシェルに解釈されないよう printf でペイロードを出力する。
# ドキュメントにはコード例中のバッククォート、$vars、バックスラッシュが含まれる。
# クォートなし heredoc ではコマンド置換として扱われてしまう。
{
  printf '[sdd-cache] %s のキャッシュヒット\n\n' "$URL"
  printf 'HTTP 304 で再検証済み。%s 以降は未変更です。\n' "$VERIFIED_AT_ISO"
  printf '以下のキャッシュ内容を、WebFetch が今返した内容として使用してください。\n\n'
  if [ -n "$ORIGINAL_PROMPT" ]; then
    printf '元の WebFetch プロンプト: "%s"。観点が異なる場合は、\n' "$ORIGINAL_PROMPT"
    printf 'この読み取りがまだ目的を満たすか判断してください。\n\n'
  fi
  printf -- '----- キャッシュ済みコンテンツ開始 -----\n'
  printf '%s\n' "$CONTENT"
  printf -- '----- キャッシュ済みコンテンツ終了 -----\n'
} >&2
exit 2
