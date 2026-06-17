#!/usr/bin/env bash
# scripts/link-ai-external.sh
#
# 目的
#   dotfiles/ai-external/ （addyosmani/agent-skills 由来の skill / command / agent 群）
#   を、Claude Code と Codex CLI の両方から使えるようにする。
#   ai-external/ を一次ソースとして、各エージェントの設定先にリンクまたはコピーで配る。
#
# 構成
#   dotfiles/
#   ├── ai-external/                  一次ソース（skills/ commands/ agents/）
#   ├── claude/{skills,commands,agents}/   Claude 用。ai-external/ への symlink
#   ├── codex-marketplace/            Codex の local marketplace
#   ├── codex-plugin-agent-skills/    Codex plugin 実体（skills/ は実コピー）
#   └── scripts/link-ai-external.sh   ← このスクリプト
#
# Claude と Codex で扱いを変える理由
#   Claude は ~/.claude/skills/ 配下の symlink を透過に辿るため、個別 symlink で済む。
#   Codex は plugin インストール時に symlink を辿らず空ディレクトリだけ cache へコピー
#   する挙動のため、symlink では skill が見えない。
#   → Codex 用 plugin の skills/ だけは rsync -L で実体コピーして同期する。
#
# やること
#   1. dotfiles/claude/{skills,commands,agents}/<name> → ai-external/ への symlink
#   2. ~/.claude/{commands,agents}/<name>             → dotfiles/claude/{commands,agents}/<name>
#      (~/.claude/skills は既にディレクトリ全体の symlink)
#   3. dotfiles/codex-plugin-agent-skills/skills/      ← ai-external/skills/ を rsync で同期
#   4. codex plugin remove → add で Codex 側 cache を再生成
#
# 使うタイミング
#   - ai-external/ を編集した、または upstream から pull した後
#   - 新マシンでの初期セットアップ時
#
# 前提（初回のみ手動）
#   Codex の local marketplace 登録は 1 度だけ実行しておく:
#     codex plugin marketplace add /Users/abe/src/private/dotfiles/codex-marketplace
#
# 冪等性
#   再実行は安全。既存 symlink は最新化し、既存の実ファイル/ディレクトリ（自前のもの）は
#   保護してスキップする。

set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
AI_EXT="$DOTFILES/ai-external"
CLAUDE_DOT="$DOTFILES/claude"
CLAUDE_HOME="$HOME/.claude"

link_one() {
  local src="$1"  # link target
  local dst="$2"  # link path to create

  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    echo "skip (real file/dir exists): $dst" >&2
    return 0
  fi
  ln -s "$src" "$dst"
  echo "linked: $dst -> $src"
}

mkdir -p "$CLAUDE_DOT/skills" "$CLAUDE_DOT/commands" "$CLAUDE_DOT/agents"
mkdir -p "$CLAUDE_HOME/commands" "$CLAUDE_HOME/agents"

echo "=== skills (dotfiles/claude/skills/) ==="
for d in "$AI_EXT/skills"/*/; do
  name=$(basename "$d")
  link_one "../../ai-external/skills/$name" "$CLAUDE_DOT/skills/$name"
done

echo
echo "=== commands (dotfiles/claude/commands/) ==="
for f in "$AI_EXT/commands"/*.toml; do
  name=$(basename "$f")
  link_one "../../ai-external/commands/$name" "$CLAUDE_DOT/commands/$name"
done

echo
echo "=== commands (~/.claude/commands/) ==="
for f in "$AI_EXT/commands"/*.toml; do
  name=$(basename "$f")
  link_one "$CLAUDE_DOT/commands/$name" "$CLAUDE_HOME/commands/$name"
done

echo
echo "=== agents (dotfiles/claude/agents/) ==="
for f in "$AI_EXT/agents"/*.md; do
  name=$(basename "$f")
  link_one "../../ai-external/agents/$name" "$CLAUDE_DOT/agents/$name"
done

echo
echo "=== agents (~/.claude/agents/) ==="
for f in "$AI_EXT/agents"/*.md; do
  name=$(basename "$f")
  link_one "$CLAUDE_DOT/agents/$name" "$CLAUDE_HOME/agents/$name"
done

echo
echo "=== codex plugin skills (dotfiles/codex-plugin-agent-skills/skills/, real copy) ==="
# Codex の plugin インストールは symlink を辿らないため、Claude 側と異なり実体コピーで持つ。
# ai-external/ が一次ソース、codex-plugin-agent-skills/skills/ はそのスナップショット。
CODEX_PLUGIN="$DOTFILES/codex-plugin-agent-skills"
# 既存の symlink 群を一掃してから rsync で同期（symlink 残骸を残さない）
if [[ -L "$CODEX_PLUGIN/skills" ]]; then
  rm "$CODEX_PLUGIN/skills"
fi
mkdir -p "$CODEX_PLUGIN/skills"
find "$CODEX_PLUGIN/skills" -mindepth 1 -maxdepth 1 -type l -delete 2>/dev/null || true
rsync -aL --delete "$AI_EXT/skills/" "$CODEX_PLUGIN/skills/"
echo "synced: $CODEX_PLUGIN/skills/ ($(find "$CODEX_PLUGIN/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') skills)"

echo
echo "=== codex plugin reinstall (refresh cache) ==="
# Codex の plugin cache は marketplace add/install 時点のスナップショットなので、
# ai-external を更新したら remove → add で cache を作り直す。
if command -v codex >/dev/null 2>&1; then
  codex plugin remove agent-skills@abe-personal >/dev/null 2>&1 || true
  if codex plugin add agent-skills@abe-personal; then
    echo "codex plugin reinstalled"
  else
    echo "codex plugin add failed (marketplace not registered yet?)" >&2
    echo "  run: codex plugin marketplace add $DOTFILES/codex-marketplace" >&2
  fi
else
  echo "codex CLI not found, skipping plugin reinstall"
fi

echo
echo "done"
