#!/bin/bash
# simplify-ignore.sh - Read (PreToolUse)、Edit|Write (PostToolUse)、Stop 用フック
#
# PreToolUse Read   → ファイルをバックアップし、ブロックを BLOCK_<hash> でインプレース置換する
# PostToolUse Edit  → プレースホルダーを展開し、ファイルが隠れたままになるよう再フィルタする
# PostToolUse Write → プレースホルダーを展開し、ファイルが隠れたままになるよう再フィルタする
# Stop              → バックアップから実ファイル内容を復元する
#
# セッション中、ディスク上のファイルには常にプレースホルダーがある。
# 実内容（モデルの変更を適用したもの）はバックアップにある。
#
# 依存関係: jq、shasum または sha1sum（自動検出）

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "エラー: jq がありません" >&2; exit 1
fi

CACHE="${CLAUDE_PROJECT_DIR:-.}/.claude/.simplify-ignore-cache"
if [ -t 0 ]; then INPUT="{}"; else INPUT=$(cat); fi

# フック入力をパースする。明示的にエラーを捕捉し、壊れた JSON で set -e が
# 無言終了しないようにして、有用な診断を出す。
parse_error=""
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || {
  parse_error="フック入力から .tool_name をパースできませんでした"
  TOOL_NAME=""
}
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || {
  parse_error="フック入力から .tool_input.file_path をパースできませんでした"
  FILE_PATH=""
}
if [ -n "$parse_error" ]; then
  printf '警告: %s (input: %.120s)\n' "$parse_error" "$INPUT" >&2
fi

hash_cmd() {
  if command -v shasum >/dev/null 2>&1; then shasum
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  else printf '%s\n' "エラー: shasum または sha1sum がありません" >&2; exit 1; fi
}
file_id() { printf '%s' "$1" | hash_cmd | cut -c1-16; }
block_hash() { printf '%s' "$1" | hash_cmd | cut -c1-8; }
# glob メタ文字をエスケープし、${var/pattern/repl} が pattern をリテラルとして扱うようにする。
# Bash 3.2（macOS）では、引用しても PE パターン内の globbing は抑止されないため必要。
escape_glob() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\*/\\*}"
  s="${s//\?/\\?}"
  s="${s//\[/\\[}"
  printf '%s' "$s"
}

# ── filter_file: simplify-ignore ブロックを BLOCK_<hash> プレースホルダーへ置換 ─
# $1（source）を読み、フィルタ済み版を $2（dest）へ書き、ブロックをキャッシュへ保存する。
# ブロックが見つかれば 0、なければ 1 を返す。
filter_file() {
  local src="$1" dest="$2" fid="$3"
  : > "$dest"
  rm -f "$CACHE/${fid}".block.* "$CACHE/${fid}".reason.* "$CACHE/${fid}".prefix.* "$CACHE/${fid}".suffix.*

  local count=0 in_block=0 buf="" reason="" prefix="" suffix=""

  while IFS= read -r line || [ -n "$line" ]; do
    # 開始マーカーを確認する（fork なし。bash case を使う）
    if [ $in_block -eq 0 ]; then
      case "$line" in *simplify-ignore-start*)
        in_block=1
        buf="$line"
        # 言語に合った構文を保つため、コメントの prefix/suffix を抽出する
        prefix="${line%%simplify-ignore-start*}"
        suffix=""
        case "$line" in *'*/'*) suffix=" */" ;; *'-->'*) suffix=" -->" ;; esac
        reason=$(printf '%s' "$line" | sed -n 's/.*simplify-ignore-start:[[:space:]]*//p' \
          | sed 's/[[:space:]]*\*\/.*$//' | sed 's/[[:space:]]*-->.*$//' | sed 's/[[:space:]]*$//')
        # 単一行ブロック（start + end が同じ行）を処理する
        case "$line" in *simplify-ignore-end*)
          in_block=0
          # 単一行ブロックをすぐ書き、次行へ進む。
          # 下の end-marker チェックが再度発火するのを避ける。
          local h; h=$(block_hash "$buf")
          count=$((count + 1))
          printf '%s' "$buf" > "$CACHE/${fid}.block.${h}"
          [ -n "$reason" ] && printf '%s' "$reason" > "$CACHE/${fid}.reason.${h}"
          printf '%s' "$prefix" > "$CACHE/${fid}.prefix.${h}"
          printf '%s' "$suffix" > "$CACHE/${fid}.suffix.${h}"
          if [ -n "$reason" ]; then
            printf '%s\n' "${prefix}BLOCK_${h}: ${reason}${suffix}" >> "$dest"
          else
            printf '%s\n' "${prefix}BLOCK_${h}${suffix}" >> "$dest"
          fi
          buf=""; reason=""; prefix=""; suffix=""
          continue
          ;; *)
          continue
          ;;
        esac
      ;; esac
    fi
    # ブロック内容を蓄積する
    if [ $in_block -eq 1 ]; then
      buf="${buf}
${line}"
    fi
    # 終了マーカーを確認する
    case "$line" in *simplify-ignore-end*)
      if [ $in_block -eq 1 ]; then
        local h; h=$(block_hash "$buf")
        count=$((count + 1))
        printf '%s' "$buf" > "$CACHE/${fid}.block.${h}"
        [ -n "$reason" ] && printf '%s' "$reason" > "$CACHE/${fid}.reason.${h}"
        printf '%s' "$prefix" > "$CACHE/${fid}.prefix.${h}"
        printf '%s' "$suffix" > "$CACHE/${fid}.suffix.${h}"
        if [ -n "$reason" ]; then
          printf '%s\n' "${prefix}BLOCK_${h}: ${reason}${suffix}" >> "$dest"
        else
          printf '%s\n' "${prefix}BLOCK_${h}${suffix}" >> "$dest"
        fi
        in_block=0; buf=""; reason=""; prefix=""; suffix=""
        continue
      fi
      ;;
    esac
    [ $in_block -eq 0 ] && printf '%s\n' "$line" >> "$dest"
  done < "$src"

  # 閉じられていないブロック → そのまま出力する
  if [ $in_block -eq 1 ] && [ -n "$buf" ]; then
    printf '警告: %s に閉じられていない simplify-ignore-start があります（ブロックは隠されません）\n' "$src" >&2
    printf '%s\n' "$buf" >> "$dest"
  fi

  # source の末尾改行状態を保つ
  if [ -s "$dest" ] && [ -s "$src" ] && [ -n "$(tail -c 1 "$src")" ]; then
    perl -pe 'chomp if eof' "$dest" > "${dest}.nnl" && \
      cat "${dest}.nnl" > "$dest" && rm -f "${dest}.nnl"
  fi

  [ $count -gt 0 ] && return 0 || return 1
}

# ── Stop: すべてのファイルをバックアップから復元する ───────────────────────
if [ -z "$TOOL_NAME" ]; then
  [ -d "$CACHE" ] || exit 0
  for bak in "$CACHE"/*.bak; do
    [ -f "$bak" ] || continue
    fid="${bak##*/}"; fid="${fid%.bak}"
    pathfile="$CACHE/${fid}.path"
    [ -f "$pathfile" ] || { rm -f "$bak"; continue; }
    orig=$(cat "$pathfile")
    if [ -f "$orig" ]; then
      cat "$bak" > "$orig"
      rm -f "$bak" "$pathfile" "$CACHE/${fid}".block.* "$CACHE/${fid}".reason.* "$CACHE/${fid}".prefix.* "$CACHE/${fid}".suffix.*
      rmdir "$CACHE/${fid}.lock" 2>/dev/null
    else
      # ファイルが移動または削除された。バックアップは破棄せず .recovered として保存する
      mkdir -p "$(dirname "${orig}.recovered")"
      mv "$bak" "${orig}.recovered"
      rm -f "$pathfile" "$CACHE/${fid}".block.* "$CACHE/${fid}".reason.* "$CACHE/${fid}".prefix.* "$CACHE/${fid}".suffix.*
      rmdir "$CACHE/${fid}.lock" 2>/dev/null
      printf '警告: %s は移動または削除されました。元の内容を %s.recovered へ復旧しました\n' "$orig" "$orig" >&2
    fi
  done
  # orphan lock を掃除する（作成後、バックアップ前にクラッシュしたもの）
  for lockdir in "$CACHE"/*.lock; do
    [ -d "$lockdir" ] || continue
    rmdir "$lockdir" 2>/dev/null
  done
  exit 0
fi

[ -z "$FILE_PATH" ] && exit 0

# ── PreToolUse Read: インプレースでフィルタする ─────────────────────────────
if [ "$TOOL_NAME" = "Read" ]; then
  [ -f "$FILE_PATH" ] || exit 0
  case "$(basename "$FILE_PATH")" in simplify-ignore*|SIMPLIFY-IGNORE*) exit 0 ;; esac

  mkdir -p "$CACHE"
  ID=$(file_id "$FILE_PATH")

  # バックアップが存在するなら、ファイルはすでにフィルタ済みなのでスキップ
  [ -f "$CACHE/${ID}.bak" ] && exit 0

  grep -q 'simplify-ignore-start' -- "$FILE_PATH" || exit 0

  # アトミックロック: 別セッションと競合すると mkdir は失敗する
  if ! mkdir "$CACHE/${ID}.lock" 2>/dev/null; then
    # ロックが存在する。stale（60 秒超、バックアップなし = クラッシュ残り）の場合だけ回収する
    if [ ! -f "$CACHE/${ID}.bak" ] && \
       [ -n "$(find "$CACHE/${ID}.lock" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
      rmdir "$CACHE/${ID}.lock" 2>/dev/null || true
      mkdir "$CACHE/${ID}.lock" 2>/dev/null || exit 0
    else
      exit 0
    fi
  fi

  # 元ファイルをバックアップする（末尾改行状態を保つ）
  cp -p "$FILE_PATH" "$CACHE/${ID}.bak" 2>/dev/null || cp "$FILE_PATH" "$CACHE/${ID}.bak"
  printf '%s' "$FILE_PATH" > "$CACHE/${ID}.path"

  # インプレースでフィルタする（cat > は inode とパーミッションを保つ）
  FILTERED="$CACHE/${ID}.$$.tmp"
  rm -f "$FILTERED"
  if filter_file "$FILE_PATH" "$FILTERED" "$ID"; then
    cat "$FILTERED" > "$FILE_PATH"
    rm -f "$FILTERED"
  else
    rm -f "$FILTERED" "$CACHE/${ID}.bak" "$CACHE/${ID}.path"
    rmdir "$CACHE/${ID}.lock" 2>/dev/null
  fi
  exit 0
fi

# ── PostToolUse Edit|Write: 展開してから再フィルタする ───────────────────────
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  ID=$(file_id "$FILE_PATH")
  [ -f "$CACHE/${ID}.bak" ] || exit 0
  ls "$CACHE/${ID}".block.* >/dev/null 2>&1 || exit 0

  # プレースホルダーを展開し、モデルが周囲に追加したインラインコードを保つ
  EXPANDED="$CACHE/${ID}.$$.expanded"
  rm -f "$EXPANDED"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *BLOCK_*)
      # この行のすべてのプレースホルダーを展開する（1 行複数に対応）
      for bf in "$CACHE/${ID}".block.*; do
        [ -f "$bf" ] || continue
        h="${bf##*.}"
        case "$line" in *"BLOCK_${h}"*)
          # 正確なプレースホルダーパターンを再構築する
          bp=""; bs=""; br=""
          [ -f "$CACHE/${ID}.prefix.${h}" ] && bp=$(cat "$CACHE/${ID}.prefix.${h}")
          [ -f "$CACHE/${ID}.suffix.${h}" ] && bs=$(cat "$CACHE/${ID}.suffix.${h}")
          [ -f "$CACHE/${ID}.reason.${h}" ] && br=$(cat "$CACHE/${ID}.reason.${h}")
          if [ -n "$br" ]; then
            placeholder="${bp}BLOCK_${h}: ${br}${bs}"
          else
            placeholder="${bp}BLOCK_${h}${bs}"
          fi
          block_content=$(cat "$bf"; printf x); block_content="${block_content%x}"
          # パターン内の glob メタ文字（* ? [ \）をエスケープする
          esc_placeholder=$(escape_glob "$placeholder")
          # Bash ネイティブ置換（// = 全置換）で、周辺コードを保ったままプレースホルダーを置換する
          line="${line//$esc_placeholder/$block_content}"
          # フォールバック: モデルが理由テキストを変えた場合、理由なしで試す。
          # BLOCK_hash がまだ存在し、かつ元ブロック内容に含まれていない場合だけ発火する。
          case "$block_content" in *"BLOCK_${h}"*) ;; *)
            case "$line" in *"BLOCK_${h}"*)
              printf '警告: placeholder BLOCK_%s はモデルに変更されたため、あいまい一致を使います\n' "$h" >&2
              esc_fuzzy=$(escape_glob "${bp}BLOCK_${h}${bs}")
              line="${line//$esc_fuzzy/$block_content}"
              # 最後の手段: ハッシュトークンだけで一致させる
              case "$line" in *"BLOCK_${h}"*)
                line="${line//BLOCK_${h}/$block_content}"
              ;; esac
            ;; esac
          ;; esac
        ;; esac
      done
    ;; esac
    printf '%s\n' "$line" >> "$EXPANDED"
  done < "$FILE_PATH"
  # 末尾改行状態を保つ
  if [ -s "$EXPANDED" ] && [ -s "$FILE_PATH" ] && [ -n "$(tail -c 1 "$FILE_PATH")" ]; then
    perl -pe 'chomp if eof' "$EXPANDED" > "${EXPANDED}.nnl" && \
      cat "${EXPANDED}.nnl" > "$EXPANDED" && rm -f "${EXPANDED}.nnl"
  fi
  # モデルが保護ブロック全体を削除した場合は警告する
  for bf in "$CACHE/${ID}".block.*; do
    [ -f "$bf" ] || continue
    bh="${bf##*.}"
    # 展開後、ブロックは元コード（simplify-ignore-start）として現れる。
    # 展開済みコードもプレースホルダーも EXPANDED にない場合は削除された。
    if ! grep -qF "BLOCK_${bh}" "$EXPANDED" 2>/dev/null; then
      # ブロックの先頭行を取得し、元に展開されたか確認する
      first_line=$(head -1 "$bf")
      if ! grep -qF "$first_line" "$EXPANDED" 2>/dev/null; then
        printf '警告: 保護ブロック BLOCK_%s はモデルに削除されました\n' "$bh" >&2
      fi
    fi
  done
  # inode とパーミッションを保つ
  cat "$EXPANDED" > "$FILE_PATH"
  rm -f "$EXPANDED"

  # 展開済み版を新しいバックアップとして保存する（これがモデル変更を含む「実」ファイル）
  cp "$FILE_PATH" "$CACHE/${ID}.bak"

  # ディスク上のファイルがプレースホルダー付きのままになるよう、インプレースで再フィルタする
  FILTERED="$CACHE/${ID}.$$.tmp"
  rm -f "$FILTERED"
  if filter_file "$FILE_PATH" "$FILTERED" "$ID"; then
    cat "$FILTERED" > "$FILE_PATH"
    rm -f "$FILTERED"
  fi

  exit 0
fi
