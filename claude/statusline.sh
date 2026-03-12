#!/bin/bash
#
# Claude Code ステータスライン表示スクリプト（3行リッチ表示）
#
# 表示例:
#   🤖 Opus 4.6 │ 📊 0% │ ✏️ +42/-1 │ 🔀 main
#   ⏱ 5h  ▰▱▱▱▱▱▱▱▱▱  13%  Resets 4pm (Asia/Tokyo)
#   📅 7d  ▰▰▰▰▰▱▱▱▱▱  55%  Resets 3/6 (Asia/Tokyo)
#
# 1行目: セッション情報
#   🤖 モデル名        ... stdin .model.display_name
#   📊 コンテキスト使用率 ... stdin .context_window.used_percentage（色分け付き）
#   ✏️ 行追加/削除数     ... stdin .cost.total_lines_added / .cost.total_lines_removed
#   🔀 gitブランチ名    ... git branch --show-current（5秒キャッシュ）
#
# 2行目: 5時間レートリミット（プログレスバー + リセット時刻 JST）
# 3行目: 7日間レートリミット（プログレスバー + リセット日 JST）
#   データソース: /api/oauth/usage（5分キャッシュ）
#   色分け: 0-49% 緑 / 50-79% 黄 / 80-100% 赤
#
# 使用方法:
#   ~/.claude/settings.json に以下を設定:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
#
# 依存ツール: jq, curl, security (macOS標準)
#

set -o pipefail

# --- キャッシュ設定 ---
USAGE_CACHE_FILE="/tmp/claude-usage-cache.json"
USAGE_CACHE_TTL=300 # 5分
GIT_BRANCH_CACHE_FILE="/tmp/claude-git-branch-cache"
GIT_BRANCH_CACHE_TTL=5 # 5秒

# --- ANSIカラー定義 ---
COLOR_GREEN='\033[38;2;151;201;195m'
COLOR_YELLOW='\033[38;2;229;192;123m'
COLOR_RED='\033[38;2;224;108;117m'
COLOR_GRAY='\033[38;2;74;88;92m'
COLOR_RESET='\033[0m'

# --- 使用率に応じた色を返す ---
color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then
    echo "$COLOR_RED"
  elif [ "$pct" -ge 50 ]; then
    echo "$COLOR_YELLOW"
  else
    echo "$COLOR_GREEN"
  fi
}

# --- プログレスバーを生成 ---
progress_bar() {
  local pct=$1
  local filled=$(( (pct + 5) / 10 ))
  [ "$filled" -gt 10 ] && filled=10
  [ "$filled" -lt 0 ] && filled=0
  local empty=$(( 10 - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="▰"; done
  for ((i=0; i<empty; i++)); do bar+="▱"; done
  echo "$bar"
}

# --- stdin JSON パース ---
parse_stdin() {
  INPUT=""
  if [ ! -t 0 ]; then
    INPUT=$(cat)
  fi

  model=""
  ctx=""
  lines_added=""
  lines_removed=""
  if [ -n "$INPUT" ]; then
    model=$(echo "$INPUT" | jq -r '.model.display_name // empty' 2>/dev/null)
    ctx=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
    lines_added=$(echo "$INPUT" | jq -r '.cost.total_lines_added // empty' 2>/dev/null)
    lines_removed=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // empty' 2>/dev/null)
  fi

  # null/空の場合のデフォルト
  [ -z "$lines_added" ] && lines_added=0
  [ -z "$lines_removed" ] && lines_removed=0
}

# --- gitブランチ取得（キャッシュ付き） ---
get_git_branch() {
  local branch=""

  # キャッシュチェック
  if [ -f "$GIT_BRANCH_CACHE_FILE" ]; then
    local now file_mod age
    now=$(date +%s)
    file_mod=$(stat -f %m "$GIT_BRANCH_CACHE_FILE" 2>/dev/null)
    if [ -n "$file_mod" ]; then
      age=$(( now - file_mod ))
      if [ "$age" -lt "$GIT_BRANCH_CACHE_TTL" ]; then
        branch=$(cat "$GIT_BRANCH_CACHE_FILE" 2>/dev/null)
        echo "$branch"
        return
      fi
    fi
  fi

  # git から取得
  branch=$(git branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    echo "$branch" > "$GIT_BRANCH_CACHE_FILE"
  fi
  echo "$branch"
}

# --- API使用率取得（既存キャッシュ機構を維持） ---
fetch_usage_data() {
  local use_cache=false
  if [ -f "$USAGE_CACHE_FILE" ]; then
    local now file_mod age
    now=$(date +%s)
    file_mod=$(stat -f %m "$USAGE_CACHE_FILE" 2>/dev/null)
    if [ -n "$file_mod" ]; then
      age=$(( now - file_mod ))
      if [ "$age" -lt "$USAGE_CACHE_TTL" ]; then
        use_cache=true
      fi
    fi
  fi

  usage_data=""
  if [ "$use_cache" = true ]; then
    usage_data=$(cat "$USAGE_CACHE_FILE" 2>/dev/null)
  else
    local cred_json access_token
    cred_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$cred_json" ]; then
      access_token=$(echo "$cred_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
      if [ -n "$access_token" ]; then
        usage_data=$(curl -s --max-time 5 \
          -H "Authorization: Bearer $access_token" \
          -H "anthropic-beta: oauth-2025-04-20" \
          -H "Content-Type: application/json" \
          "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$usage_data" ] && echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1; then
          echo "$usage_data" > "$USAGE_CACHE_FILE"
        else
          if [ -f "$USAGE_CACHE_FILE" ]; then
            usage_data=$(cat "$USAGE_CACHE_FILE" 2>/dev/null)
          else
            usage_data=""
          fi
        fi
      fi
    fi
  fi
}

# --- 1行目フォーマット ---
format_line1() {
  local sep="${COLOR_GRAY}│${COLOR_RESET}"
  local parts=()

  if [ -n "$model" ]; then
    parts+=("🤖 $model")
  fi

  if [ -n "$ctx" ]; then
    local ctx_int
    ctx_int=$(printf '%.0f' "$ctx" 2>/dev/null || echo "$ctx")
    local ctx_color
    ctx_color=$(color_for_pct "$ctx_int")
    parts+=("📊 ${ctx_color}${ctx_int}%${COLOR_RESET}")
  fi

  parts+=("✏️ +${lines_added}/-${lines_removed}")

  local branch
  branch=$(get_git_branch)
  if [ -n "$branch" ]; then
    parts+=("🔀 $branch")
  fi

  # パーツを │ で結合
  local result=""
  for ((i=0; i<${#parts[@]}; i++)); do
    if [ $i -gt 0 ]; then
      result+=" ${sep} "
    fi
    result+="${parts[$i]}"
  done
  echo -e "$result"
}

# --- レートリミット行フォーマット（2行目・3行目共通） ---
format_rate_line() {
  local icon=$1
  local label=$2
  local pct=$3
  local reset_text=$4

  local color
  color=$(color_for_pct "$pct")
  local bar
  bar=$(progress_bar "$pct")

  echo -e "${icon} ${label}  ${color}${bar}  ${pct}%${COLOR_RESET}  Resets ${reset_text} (Asia/Tokyo)"
}

# --- メイン処理 ---
main() {
  parse_stdin
  fetch_usage_data

  # 1行目: セッション情報
  format_line1

  # 2行目・3行目: レートリミット情報
  if [ -n "$usage_data" ]; then
    local five_hour seven_day five_hour_reset seven_day_reset
    five_hour=$(echo "$usage_data" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    seven_day=$(echo "$usage_data" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    five_hour_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
    seven_day_reset=$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

    if [ -n "$five_hour" ] && [ -n "$five_hour_reset" ]; then
      local s_int s_reset_text epoch
      s_int=$(printf '%.0f' "$five_hour" 2>/dev/null || echo "$five_hour")
      epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${five_hour_reset%%.*}" +%s 2>/dev/null)
      if [ -n "$epoch" ]; then
        s_reset_text=$(TZ=Asia/Tokyo LANG=en_US.UTF-8 date -j -r "$epoch" "+%-I%p" 2>/dev/null | sed 's/AM/am/;s/PM/pm/')
        format_rate_line "⏱" "5h" "$s_int" "$s_reset_text"
      fi
    fi

    if [ -n "$seven_day" ] && [ -n "$seven_day_reset" ]; then
      local w_int w_reset_text epoch
      w_int=$(printf '%.0f' "$seven_day" 2>/dev/null || echo "$seven_day")
      epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${seven_day_reset%%.*}" +%s 2>/dev/null)
      if [ -n "$epoch" ]; then
        w_reset_text=$(TZ=Asia/Tokyo date -j -r "$epoch" "+%-m/%-d" 2>/dev/null)
        format_rate_line "📅" "7d" "$w_int" "$w_reset_text"
      fi
    fi
  fi
}

main
