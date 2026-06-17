#!/bin/bash
# simplify-ignore-test.sh - simplify-ignore フック用テスト
#
# フックから関数定義を抽出し、filter_file を検証する。
# 実行: bash hooks/simplify-ignore-test.sh

set -euo pipefail

PASS=0 FAIL=0
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

export CACHE="$TMPDIR/cache"
mkdir -p "$CACHE"

# 必要な関数定義を抽出する
hash_cmd() {
  if command -v shasum >/dev/null 2>&1; then shasum
  elif command -v sha1sum >/dev/null 2>&1; then sha1sum
  else printf '%s\n' "エラー: shasum または sha1sum がありません" >&2; exit 1; fi
}
file_id() { printf '%s' "$1" | hash_cmd | cut -c1-16; }
block_hash() { printf '%s' "$1" | hash_cmd | cut -c1-8; }
escape_glob() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\*/\\*}"
  s="${s//\?/\\?}"
  s="${s//\[/\\[}"
  printf '%s' "$s"
}

# フックスクリプトから filter_file を抽出する（"filter_file()" から閉じ brace まで）
eval "$(sed -n '/^filter_file()/,/^}/p' hooks/simplify-ignore.sh)"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf '  成功: %s\n' "$label"
  else
    FAIL=$((FAIL + 1))
    printf '  失敗: %s\n' "$label" >&2
    printf '    期待値: %s\n' "$(printf '%s' "$expected" | cat -v)" >&2
    printf '    実際:   %s\n' "$(printf '%s' "$actual" | cat -v)" >&2
  fi
}

# ── テスト 1: 単一行ブロックはプレースホルダーを 1 つだけ生成する ─────────
printf 'テスト 1: 単一行ブロック（start+end が同じ行）\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/single-line.js"
DEST="$TMPDIR/single-line-filtered.js"
cat > "$SRC" <<'EOF'
const a = 1;
/* simplify-ignore-start */ const secret = 42; /* simplify-ignore-end */
const b = 2;
EOF

FID="test_single"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "プレースホルダー行がちょうど 1 つ" "1" "$placeholder_count"
assert_eq "ブロック前の行が保持される" "1" "$(grep -c 'const a = 1' "$DEST")"
assert_eq "ブロック後の行が保持される" "1" "$(grep -c 'const b = 2' "$DEST")"

block_files=$(ls "$CACHE/${FID}".block.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "キャッシュ内のブロックファイルが 1 つ" "1" "$block_files"

block_content=$(cat "$CACHE/${FID}".block.*)
assert_eq "ブロック内容が一致する" \
  "/* simplify-ignore-start */ const secret = 42; /* simplify-ignore-end */" \
  "$block_content"

# ── テスト 2: 複数行ブロック ─────────────────────────────────────────────
printf '\nテスト 2: 複数行ブロック\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/multi-line.js"
DEST="$TMPDIR/multi-line-filtered.js"
cat > "$SRC" <<'EOF'
const a = 1;
// simplify-ignore-start
const secret1 = 42;
const secret2 = 99;
// simplify-ignore-end
const b = 2;
EOF

FID="test_multi"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "複数行ブロックのプレースホルダーがちょうど 1 つ" "1" "$placeholder_count"

output_lines=$(wc -l < "$DEST" | tr -d ' ')
assert_eq "出力は 3 行（前 + プレースホルダー + 後）" "3" "$output_lines"

# ── テスト 3: 1 ファイル内の複数ブロック ────────────────────────────────
printf '\nテスト 3: 1 ファイル内の複数ブロック\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/multi-block.js"
DEST="$TMPDIR/multi-block-filtered.js"
cat > "$SRC" <<'EOF'
line1
// simplify-ignore-start
blockA
// simplify-ignore-end
line2
// simplify-ignore-start
blockB
// simplify-ignore-end
line3
EOF

FID="test_multiblock"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "2 ブロックに対して 2 つのプレースホルダー" "2" "$placeholder_count"

block_files=$(ls "$CACHE/${FID}".block.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "キャッシュ内のブロックファイルが 2 つ" "2" "$block_files"

# ── テスト 4: 理由文字列が保持される ───────────────────────────────────
printf '\nテスト 4: プレースホルダー内の理由文字列\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/reason.js"
DEST="$TMPDIR/reason-filtered.js"
cat > "$SRC" <<'EOF'
// simplify-ignore-start: perf-critical
hot_loop();
// simplify-ignore-end
EOF

FID="test_reason"
filter_file "$SRC" "$DEST" "$FID"

assert_eq "プレースホルダーに理由が含まれる" "1" "$(grep -c 'perf-critical' "$DEST")"

reason_files=$(ls "$CACHE/${FID}".reason.* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "理由ファイルが保存される" "1" "$reason_files"
assert_eq "理由内容" "perf-critical" "$(cat "$CACHE/${FID}".reason.*)"

# ── テスト 5: 末尾改行の保持 ───────────────────────────────────────────
printf '\nテスト 5: 末尾改行の保持\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/no-trailing-nl.js"
DEST="$TMPDIR/no-trailing-nl-filtered.js"
printf 'line1\n// simplify-ignore-start\nsecret\n// simplify-ignore-end' > "$SRC"

FID="test_trail"
filter_file "$SRC" "$DEST" "$FID"

# source に末尾改行がないため、dest にも末尾改行がないはず
src_has_nl=$(tail -c 1 "$SRC" | wc -l | tr -d ' ')
dest_has_nl=$(tail -c 1 "$DEST" | wc -l | tr -d ' ')
assert_eq "dest が source の末尾改行なしを保持する" "$src_has_nl" "$dest_has_nl"

# ── テスト 6: ブロックなし → 1 を返す ─────────────────────────────────
printf '\nテスト 6: ブロックなしなら 1 を返す\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/no-blocks.js"
DEST="$TMPDIR/no-blocks-filtered.js"
cat > "$SRC" <<'EOF'
const a = 1;
const b = 2;
EOF

FID="test_noblocks"
rc=0
filter_file "$SRC" "$DEST" "$FID" || rc=$?
assert_eq "ブロックがない場合は 1 を返す" "1" "$rc"

# ── テスト 7: 閉じていないブロックは警告を出し、そのまま出力する ───────
printf '\nテスト 7: 閉じていないブロック\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/unclosed.js"
DEST="$TMPDIR/unclosed-filtered.js"
cat > "$SRC" <<'EOF'
line1
// simplify-ignore-start
orphan code
EOF

FID="test_unclosed"
stderr_out=$(filter_file "$SRC" "$DEST" "$FID" 2>&1) || true
assert_eq "閉じていないブロックの警告が出る" "1" "$(printf '%s' "$stderr_out" | grep -c '閉じられていない')"
assert_eq "孤立したコードが出力される" "1" "$(grep -c 'orphan code' "$DEST")"

# ── テスト 8: 理由付き単一行ブロック ───────────────────────────────────
printf '\nテスト 8: 理由付き単一行ブロック\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/single-reason.js"
DEST="$TMPDIR/single-reason-filtered.js"
cat > "$SRC" <<'EOF'
before
/* simplify-ignore-start: hot-path */ x = compute(); /* simplify-ignore-end */
after
EOF

FID="test_single_reason"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "理由付き単一行ブロックのプレースホルダーがちょうど 1 つ" "1" "$placeholder_count"
assert_eq "プレースホルダーに理由がある" "1" "$(grep -c 'hot-path' "$DEST")"

# ── テスト 9: HTML コメント構文 ───────────────────────────────────────
printf '\nテスト 9: HTML コメント構文\n'
rm -f "$CACHE"/*

SRC="$TMPDIR/html.html"
DEST="$TMPDIR/html-filtered.html"
cat > "$SRC" <<'EOF'
<div>
<!-- simplify-ignore-start -->
<secret-component />
<!-- simplify-ignore-end -->
</div>
EOF

FID="test_html"
filter_file "$SRC" "$DEST" "$FID"

placeholder_count=$(grep -c 'BLOCK_' "$DEST")
assert_eq "HTML ブロックが置換される" "1" "$placeholder_count"
assert_eq "HTML suffix が保持される" "1" "$(grep -c '\-\->' "$DEST")"

# ── テスト 10: 壊れた JSON 入力は警告を生成する ───────────────────────
printf '\nテスト 10: 壊れた JSON 入力は警告を生成する\n'

warning_out=$(echo 'NOT_JSON{{{' | bash hooks/simplify-ignore.sh 2>&1) || true
assert_eq "不正 JSON で警告" "1" "$(printf '%s' "$warning_out" | grep -c '警告.*パースできませんでした')"

# ── 要約 ───────────────────────────────────────────────────────────────
printf '\n══════════════════════════════════════════\n'
printf '結果: %d 件成功, %d 件失敗\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
