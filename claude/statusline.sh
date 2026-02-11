#!/bin/bash
#
# Claude Code ステータスライン表示スクリプト
#
# Claude Code のステータスバーに以下の情報を一行で表示する:
#   ⚡ S:14% ~21:59 📅 W:4% ~2/17 | 🤖 Opus 4.6 | 💰 $0.23 | 📝 ctx:45%
#
#   ⚡ S:14% ~21:59  ... プラン使用率（5時間ウィンドウ）とリセット時刻(JST)
#   📅 W:4% ~2/17    ... プラン使用率（7日間ウィンドウ）とリセット日(JST)
#   🤖 Opus 4.6      ... 現在のモデル名（stdin から取得）
#   💰 $0.23         ... セッションコスト（stdin から取得）
#   📝 ctx:45%       ... コンテキストウィンドウ使用率（stdin から取得）
#
# 使用方法:
#   ~/.claude/settings.json に以下を設定:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
#
# 依存ツール: jq, curl, security (macOS標準)
#
# 注意: プラン使用率の取得に使用する /api/oauth/usage は非公式エンドポイントのため、
#       将来変更される可能性があります。API 取得に失敗した場合はセッション情報のみ表示します。
#

set -o pipefail

# キャッシュ設定
# ステータスラインは高頻度で呼び出されるため、API レート制限を避けるために
# レスポンスをファイルにキャッシュし、TTL 以内なら API を呼ばずに再利用する
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_TTL=300 # 5分

# --- セッション情報の取得（stdin） ---
# Claude Code が JSON で渡すモデル名・コスト・コンテキスト使用率を読み取る
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi

model=""
cost=""
ctx=""
if [ -n "$INPUT" ]; then
  model=$(echo "$INPUT" | jq -r '.model.display_name // empty' 2>/dev/null)
  cost=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
  ctx=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
fi

# セッション情報を「|」区切りでフォーマット
session_parts=""
if [ -n "$model" ]; then
  session_parts="🤖 $model"
fi
if [ -n "$cost" ]; then
  formatted_cost=$(printf '💰 $%.2f' "$cost")
  if [ -n "$session_parts" ]; then
    session_parts="$session_parts | $formatted_cost"
  else
    session_parts="$formatted_cost"
  fi
fi
if [ -n "$ctx" ]; then
  formatted_ctx=$(printf '📝 ctx:%s%%' "$ctx")
  if [ -n "$session_parts" ]; then
    session_parts="$session_parts | $formatted_ctx"
  else
    session_parts="$formatted_ctx"
  fi
fi

# --- キャッシュの鮮度チェック ---
# ファイルの更新時刻から経過秒数を計算し、TTL 以内ならキャッシュを使う
use_cache=false
if [ -f "$CACHE_FILE" ]; then
  now=$(date +%s)
  file_mod=$(stat -f %m "$CACHE_FILE" 2>/dev/null)
  if [ -n "$file_mod" ]; then
    age=$(( now - file_mod ))
    if [ "$age" -lt "$CACHE_TTL" ]; then
      use_cache=true
    fi
  fi
fi

# --- プラン使用率の取得（API） ---
usage_data=""
if [ "$use_cache" = true ]; then
  # キャッシュが有効ならファイルから読み込む
  usage_data=$(cat "$CACHE_FILE" 2>/dev/null)
else
  # macOS Keychain から Claude Code の OAuth トークンを取得
  cred_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  if [ -n "$cred_json" ]; then
    access_token=$(echo "$cred_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    if [ -n "$access_token" ]; then
      # 非公式エンドポイントからプラン使用率を取得（beta ヘッダー必須）
      usage_data=$(curl -s --max-time 5 \
        -H "Authorization: Bearer $access_token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
      if [ -n "$usage_data" ] && echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1; then
        # 正常レスポンスをキャッシュに保存
        echo "$usage_data" > "$CACHE_FILE"
      else
        # API 失敗時は期限切れのキャッシュでもフォールバックとして使う
        if [ -f "$CACHE_FILE" ]; then
          usage_data=$(cat "$CACHE_FILE" 2>/dev/null)
        else
          usage_data=""
        fi
      fi
    fi
  fi
fi

# --- プラン使用率のフォーマット ---
plan_parts=""
if [ -n "$usage_data" ]; then
  five_hour=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  seven_day=$(echo "$usage_data" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
  five_hour_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
  seven_day_reset=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

  if [ -n "$five_hour" ] && [ -n "$seven_day" ]; then
    # 使用率を整数に丸める
    s_int=$(printf '%.0f' "$five_hour" 2>/dev/null || echo "$five_hour")
    w_int=$(printf '%.0f' "$seven_day" 2>/dev/null || echo "$seven_day")

    # リセット時刻を JST に変換（API は UTC で返すため UTC→Asia/Tokyo）
    s_reset=""
    if [ -n "$five_hour_reset" ]; then
      epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${five_hour_reset%%.*}" +%s 2>/dev/null)
      [ -n "$epoch" ] && s_reset="~$(TZ=Asia/Tokyo date -j -r "$epoch" "+%-H:%M" 2>/dev/null)"
    fi

    # 週間リセット日を JST に変換
    w_reset=""
    if [ -n "$seven_day_reset" ]; then
      epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${seven_day_reset%%.*}" +%s 2>/dev/null)
      [ -n "$epoch" ] && w_reset="~$(TZ=Asia/Tokyo date -j -r "$epoch" "+%-m/%-d" 2>/dev/null)"
    fi

    plan_parts="⚡ S:${s_int}%${s_reset:+ $s_reset} 📅 W:${w_int}%${w_reset:+ $w_reset}"
  fi
fi

# --- 最終出力 ---
# プラン使用率とセッション情報を「|」で結合して出力
# どちらかが取得できなかった場合は、取得できた方のみ表示する
output=""
if [ -n "$plan_parts" ] && [ -n "$session_parts" ]; then
  output="$plan_parts | $session_parts"
elif [ -n "$plan_parts" ]; then
  output="$plan_parts"
elif [ -n "$session_parts" ]; then
  output="$session_parts"
fi

if [ -n "$output" ]; then
  echo "$output"
fi
