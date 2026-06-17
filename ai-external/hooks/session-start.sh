#!/bin/bash
# agent-skills セッション開始フック
# 新しいセッションごとに using-agent-skills メタスキルを注入する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")/skills"
META_SKILL="$SKILLS_DIR/using-agent-skills/SKILL.md"

if ! command -v jq >/dev/null 2>&1; then
  echo '{"priority": "INFO", "message": "agent-skills: session-start フックには jq が必要ですが、PATH 上で見つかりませんでした。メタスキル注入を有効にするには jq をインストールしてください（例: `brew install jq` または `apt-get install jq`）。各スキルは個別には引き続き利用できます。"}'
  exit 0
fi

if [ -f "$META_SKILL" ]; then
  CONTENT=$(cat "$META_SKILL")
  # jq を使い、適切にエスケープした有効な JSON を構築する
  jq -cn \
    --arg message "agent-skills を読み込みました。スキル発見フローチャートを使い、タスクに合うスキルを見つけてください。

$CONTENT" \
    '{priority: "IMPORTANT", message: $message}'
else
  echo '{"priority": "INFO", "message": "agent-skills: using-agent-skills メタスキルが見つかりません。各スキルは個別には利用できる可能性があります。"}'
fi
