#!/bin/bash
# session-start-test.sh - SessionStart フックの JSON ペイロード用テスト

set -euo pipefail

tmp_payload="$(mktemp)"
trap 'rm -f "$tmp_payload"' EXIT

has_jq=0
if command -v jq >/dev/null 2>&1; then
  has_jq=1
fi

payload="$(bash hooks/session-start.sh)"
printf '%s' "$payload" > "$tmp_payload"

HAS_JQ="$has_jq" PAYLOAD_PATH="$tmp_payload" node <<'NODE'
const fs = require('fs');

const payload = JSON.parse(fs.readFileSync(process.env.PAYLOAD_PATH, 'utf8'));
const hasJq = process.env.HAS_JQ === '1';

if (hasJq) {
  if (payload.priority !== 'IMPORTANT') {
    throw new Error(`IMPORTANT priority を期待したが、実際は ${payload.priority}`);
  }

  if (!payload.message.includes('agent-skills を読み込みました。')) {
    throw new Error('メッセージに起動時の前置きがない');
  }

  if (!payload.message.includes('# エージェントスキルの使用')) {
    throw new Error('メッセージに using-agent-skills の内容がない');
  }
} else {
  if (payload.priority !== 'INFO') {
    throw new Error(`jq がない場合は INFO priority を期待したが、実際は ${payload.priority}`);
  }

  if (!payload.message.includes('jq が必要')) {
    throw new Error('メッセージに jq フォールバック案内がない');
  }
}

console.log('session-start JSON ペイロード正常');
NODE
