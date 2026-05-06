#!/bin/bash
# jgy-cc-statusline

input=$(cat)
echo "$input" > /tmp/claude-statusline-last.json

# ─── Config ───
CONFIG_FILE="$HOME/.claude/jgy-cc-statusline.conf"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
: ${MESSAGE_URL:=}
: ${SCRIPT_URL:=}
: ${SHOW_INTERVAL:=1800}
: ${SHOW_DURATION:=30}
: ${SYNC_INTERVAL:=3600}

SCRIPT_PATH="$0"

# ─── Cache files ───
CACHE=/tmp/claude-statusline-rate-cache.json
PORTS_CACHE=/tmp/claude-statusline-ports.cache
MESSAGE_CACHE=/tmp/claude-statusline-message.txt
SYNC_META=/tmp/claude-statusline-sync-meta.json
SHOW_STATE=/tmp/claude-statusline-show-state.json

# 파일 부재 / 빈 파일 / invalid JSON 모두 {} 로 정상화
if ! jq -e . "$CACHE" >/dev/null 2>&1; then echo '{}' > "$CACHE"; fi

# ─── 백그라운드 동기화 (메시지 + statusline 스크립트 자체) ───
do_sync() {
  if [ -n "$MESSAGE_URL" ]; then
    tmp=/tmp/claude-statusline-message.tmp
    if curl -fsSL --max-time 10 "$MESSAGE_URL" -o "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      if ! cmp -s "$tmp" "$MESSAGE_CACHE" 2>/dev/null; then
        mv "$tmp" "$MESSAGE_CACHE"
      else
        rm -f "$tmp"
      fi
    else
      rm -f "$tmp"
    fi
  fi

  # 스크립트 자동 업데이트 (syntax 통과 + 첫 줄 shebang 일치 시에만 swap)
  if [ -n "$SCRIPT_URL" ] && [ -n "$SCRIPT_PATH" ]; then
    tmp=/tmp/claude-statusline-script.tmp
    if curl -fsSL --max-time 10 "$SCRIPT_URL" -o "$tmp" 2>/dev/null \
       && head -1 "$tmp" 2>/dev/null | grep -q '^#!/bin/bash' \
       && bash -n "$tmp" 2>/dev/null; then
      new_hash=$(shasum -a 256 "$tmp" 2>/dev/null | cut -d' ' -f1)
      old_hash=$(shasum -a 256 "$SCRIPT_PATH" 2>/dev/null | cut -d' ' -f1)
      if [ -n "$new_hash" ] && [ "$new_hash" != "$old_hash" ]; then
        cp -p "$SCRIPT_PATH" "$SCRIPT_PATH.bak" 2>/dev/null
        chmod +x "$tmp"
        mv "$tmp" "$SCRIPT_PATH"
      else
        rm -f "$tmp"
      fi
    else
      rm -f "$tmp"
    fi
  fi
}

now=$(date +%s)
last_sync=$(jq -r '.last_sync // 0' "$SYNC_META" 2>/dev/null || echo 0)
if [ $((now - last_sync)) -ge "$SYNC_INTERVAL" ]; then
  jq -n --argjson t "$now" '{last_sync: $t}' > "$SYNC_META"
  ( do_sync ) >/dev/null 2>&1 &
fi

# 첫 실행 케이스: 메시지 캐시가 아직 없으면 동기로 한 번만 fetch (3초 타임아웃)
if [ -n "$MESSAGE_URL" ] && [ ! -f "$MESSAGE_CACHE" ]; then
  curl -fsSL --max-time 3 "$MESSAGE_URL" -o "$MESSAGE_CACHE" 2>/dev/null
  [ -s "$MESSAGE_CACHE" ] || rm -f "$MESSAGE_CACHE"
fi

# ─── 메시지 노출 윈도우 (캐시에서 랜덤 한 줄) ───
show_msg=""
if [ -n "$MESSAGE_URL" ] && [ -f "$MESSAGE_CACHE" ] && [ -s "$MESSAGE_CACHE" ]; then
  last_shown=$(jq -r '.last_shown // 0' "$SHOW_STATE" 2>/dev/null || echo 0)
  since_show=$((now - last_shown))
  if [ "$since_show" -ge "$SHOW_INTERVAL" ]; then
    # 새 노출 윈도우 — 캐시에서 랜덤 한 줄 선택, SHOW_STATE 에 저장
    msgs=()
    while IFS= read -r line; do
      [ -n "$line" ] && msgs+=("$line")
    done < "$MESSAGE_CACHE"
    if [ "${#msgs[@]}" -gt 0 ]; then
      show_msg="${msgs[$((RANDOM % ${#msgs[@]}))]}"
      jq -n --argjson t "$now" --arg m "$show_msg" '{last_shown: $t, shown_msg: $m}' > "$SHOW_STATE"
    fi
  elif [ "$since_show" -lt "$SHOW_DURATION" ]; then
    # 윈도우 안 — 직전에 고른 메시지 그대로 유지
    show_msg=$(jq -r '.shown_msg // empty' "$SHOW_STATE" 2>/dev/null)
  fi
fi

j() { echo "$input" | jq -r "$1 // empty"; }

# ─── JSON 필드 ───
model_name=$(j '.model.display_name' | sed -E 's/ ?\(1M context\)//; s/ ?\(.*\)//')
effort=$(j '.effort.level')
cost_usd=$(j '.cost.total_cost_usd')
duration_ms=$(j '.cost.total_duration_ms')
lines_added=$(j '.cost.total_lines_added')
lines_removed=$(j '.cost.total_lines_removed')
total=$(j '.context_window.context_window_size')
used_pct=$(j '.context_window.used_percentage')
used_input=$(echo "$input" | jq -r '
  ((.context_window.current_usage.input_tokens // 0)
   + (.context_window.current_usage.cache_creation_input_tokens // 0)
   + (.context_window.current_usage.cache_read_input_tokens // 0))')
five_pct_raw=$(j '.rate_limits.five_hour.used_percentage')
five_reset=$(j '.rate_limits.five_hour.resets_at')
week_pct_raw=$(j '.rate_limits.seven_day.used_percentage')
week_reset=$(j '.rate_limits.seven_day.resets_at')
cwd=$(j '.cwd')

# ─── 색상 팔레트 ───
RESET=$'\033[0m'; DIM=$'\033[2m'; BOLD=$'\033[1m'
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'; WHITE=$'\033[0;37m'
B_CYAN=$'\033[1;36m'; B_YELLOW=$'\033[1;33m'; B_WHITE=$'\033[1;37m'

SEP=" ${DIM}│${RESET} "

usage_color() {
  if [ "$1" -ge 80 ] 2>/dev/null; then printf "%s" "$RED"
  elif [ "$1" -ge 50 ] 2>/dev/null; then printf "%s" "$YELLOW"
  else printf "%s" "$GREEN"; fi
}
remaining_color() {
  if [ "$1" -le 20 ] 2>/dev/null; then printf "%s" "$RED"
  elif [ "$1" -le 50 ] 2>/dev/null; then printf "%s" "$YELLOW"
  else printf "%s" "$GREEN"; fi
}

# ─── 포맷 (128k / 1M, 1h 27m, 1d 15h) ───
fmt_tokens() {
  echo "$1" | awk '{
    if ($1 >= 1000000) {
      v = $1 / 1000000
      if (v == int(v)) printf "%dM", v
      else printf "%.1fM", v
    } else if ($1 >= 1000) {
      printf "%dk", $1 / 1000
    } else {
      printf "%d", $1
    }
  }'
}

fmt_duration() {
  ms=$1
  [ -z "$ms" ] || [ "$ms" = "0" ] && return
  s=$(( ms / 1000 ))
  if [ "$s" -ge 3600 ]; then
    printf "%dh %dm" $((s / 3600)) $(( (s % 3600) / 60 ))
  elif [ "$s" -ge 60 ]; then
    printf "%dm" $((s / 60))
  else
    printf "%ds" "$s"
  fi
}

eta_until() {
  reset_val=$1
  [ -z "$reset_val" ] && return
  case "$reset_val" in
    *[!0-9]*) reset_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$(echo "$reset_val" | sed 's/\..*Z$/Z/')" +%s 2>/dev/null) ;;
    *) reset_ts=$reset_val ;;
  esac
  [ -z "$reset_ts" ] && return
  now_local=$(date +%s); diff=$(( reset_ts - now_local ))
  if [ "$diff" -le 0 ]; then echo "0m"
  elif [ "$diff" -ge 86400 ]; then echo "$(( diff / 86400 ))d $(( (diff % 86400) / 3600 ))h"
  elif [ "$diff" -ge 3600 ]; then echo "$(( diff / 3600 ))h $(( (diff % 3600) / 60 ))m"
  else echo "$(( diff / 60 ))m"; fi
}

# ─── Rate limit 단조증가 가드 ───
reconcile() {
  win=$1; new_pct=$2; new_reset=$3
  [ -z "$new_pct" ] && { echo ""; return; }
  cached_pct=$(jq -r --arg w "$win" '.[$w].pct // empty' "$CACHE")
  cached_reset=$(jq -r --arg w "$win" '.[$w].reset // empty' "$CACHE")
  use_pct=$new_pct
  if [ -n "$cached_pct" ] && [ -n "$cached_reset" ] && [ "$cached_reset" = "$new_reset" ]; then
    if [ "$(printf '%.0f' "$new_pct")" -lt "$(printf '%.0f' "$cached_pct")" ]; then
      use_pct=$cached_pct
    fi
  fi
  jq --arg w "$win" --arg p "$use_pct" --arg r "$new_reset" \
     '.[$w] = {pct: ($p | tonumber), reset: ($r | tonumber)}' "$CACHE" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
  echo "$use_pct"
}
five_pct=$(reconcile "five_hour" "$five_pct_raw" "$five_reset")
week_pct=$(reconcile "seven_day" "$week_pct_raw" "$week_reset")

# ─── 리스닝 포트 (10초 캐시) ───
ports_line=""
if command -v lsof >/dev/null 2>&1; then
  cache_age=999
  if [ -f "$PORTS_CACHE" ]; then
    cache_age=$(( $(date +%s) - $(stat -f %m "$PORTS_CACHE" 2>/dev/null || echo 0) ))
  fi
  if [ "$cache_age" -gt 10 ]; then
    lsof -iTCP -sTCP:LISTEN -P -n -a -u "$USER" 2>/dev/null | awk '
      NR>1 {
        port = $9; sub(/.*:/, "", port)
        cmd = tolower($1)
        # 개발 도구 화이트리스트만 (lsof 가 cmd 9자 truncate)
        if (cmd ~ /^(node|bun|deno|python|ruby|php|java|next|vite|webpack|postgres|redis|mongod|mysql|docker|nginx|caddy|apache|ngrok|cloudfla|supabase|tsx|ts-node|expo|metro|drizzle|trigger|rails|gunicorn|uvicorn|hypercorn|fastapi|flask)/ &&
            port+0 >= 1024 && port+0 <= 65535) {
          if (!seen[port "|" $1]++) print port "\t" $1
        }
      }' | sort -n -u > "$PORTS_CACHE.tmp" && mv "$PORTS_CACHE.tmp" "$PORTS_CACHE"
  fi
  if [ -s "$PORTS_CACHE" ]; then
    ports_parts=""
    count=0
    while IFS=$'\t' read -r p_port p_cmd; do
      [ -z "$p_port" ] && continue
      count=$((count+1))
      [ "$count" -gt 6 ] && break
      cmd_short=$(echo "$p_cmd" | cut -c1-8)
      [ -n "$ports_parts" ] && ports_parts="${ports_parts}  "
      link_start=$'\033]8;;http://localhost:'"${p_port}"$'\033\\'
      link_end=$'\033]8;;\033\\'
      ports_parts="${ports_parts}${link_start}${B_WHITE}${p_port}${RESET}${link_end}${DIM}·${cmd_short}${RESET}"
    done < "$PORTS_CACHE"
    ports_line="$ports_parts"
  fi
fi

# ─── Last commit ago / branch / PR URL ───
commit_ago=""
commit_url=""
branch=""
branch_url=""
pr_url=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  ago=$(git -C "$cwd" log -1 --format=%cr 2>/dev/null)
  if [ -n "$ago" ]; then
    commit_ago=$(echo "$ago" | sed -E '
      s/ minutes? ago/m/
      s/ minute ago/m/
      s/ hours? ago/h/
      s/ days? ago/d/
      s/ weeks? ago/w/
      s/ months? ago/mo/
      s/ years? ago/y/
      s/ ago$//
    ')
  fi
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  remote=$(git -C "$cwd" remote get-url origin 2>/dev/null)
  sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)
  if [ -n "$remote" ]; then
    web_url=""
    case "$remote" in
      git@*:*)
        host=$(echo "$remote" | sed -E 's/^git@([^:]+):.*/\1/')
        path=$(echo "$remote" | sed -E 's/^git@[^:]+:(.*)$/\1/; s/\.git$//')
        web_url="https://${host}/${path}"
        ;;
      ssh://*)
        web_url=$(echo "$remote" | sed -E 's#^ssh://git@#https://#; s#^ssh://#https://#; s/\.git$//')
        ;;
      https://*|http://*)
        web_url=$(echo "$remote" | sed 's/\.git$//')
        ;;
    esac
    if [ -n "$web_url" ]; then
      case "$web_url" in
        *github.com*)
          [ -n "$sha" ] && commit_url="${web_url}/commit/${sha}"
          [ -n "$branch" ] && branch_url="${web_url}/tree/${branch}"
          pr_url="${web_url}/pulls"
          ;;
        *gitlab*)
          [ -n "$sha" ] && commit_url="${web_url}/-/commit/${sha}"
          [ -n "$branch" ] && branch_url="${web_url}/-/tree/${branch}"
          pr_url="${web_url}/-/merge_requests"
          ;;
        *bitbucket.org*)
          [ -n "$sha" ] && commit_url="${web_url}/commits/${sha}"
          [ -n "$branch" ] && branch_url="${web_url}/branch/${branch}"
          pr_url="${web_url}/pull-requests"
          ;;
        *)
          [ -n "$sha" ] && commit_url="${web_url}"
          ;;
      esac
    fi
  fi
fi

# ════════ Line 1 ════════
line1=""

if [ -n "$model_name" ]; then
  l1="${BOLD}${model_name}${RESET}"
  if [ -n "$effort" ]; then
    l1="${l1} ${BOLD}${effort}${RESET}"
  fi
  line1="$l1"
fi

# Branch (35자 초과 시 …로 축약, URL 은 원본 유지)
if [ -n "$branch" ]; then
  [ -n "$line1" ] && line1="${line1}${SEP}"
  if [ ${#branch} -gt 35 ]; then
    branch_disp="${branch:0:34}…"
  else
    branch_disp="$branch"
  fi
  branch_text="${DIM}⎇${RESET} ${CYAN}${branch_disp}${RESET}"
  if [ -n "$branch_url" ]; then
    bl_start=$'\033]8;;'"${branch_url}"$'\033\\'
    bl_end=$'\033]8;;\033\\'
    line1="${line1}${bl_start}${branch_text}${bl_end}"
  else
    line1="${line1}${branch_text}"
  fi
fi

if [ -n "$pr_url" ]; then
  [ -n "$line1" ] && line1="${line1}${SEP}"
  pl_start=$'\033]8;;'"${pr_url}"$'\033\\'
  pl_end=$'\033]8;;\033\\'
  line1="${line1}${pl_start}${DIM}PR${RESET}${pl_end}"
fi

la=${lines_added:-0}; lr=${lines_removed:-0}
if [ "$la" != "0" ] || [ "$lr" != "0" ]; then
  [ -n "$line1" ] && line1="${line1}${SEP}"
  line1="${line1}${GREEN}+${la}${RESET}${DIM}/${RESET}${RED}-${lr}${RESET}"
fi

# ════════ Line 2 ════════
line2=""

if [ -n "$total" ] && [ "$total" != "0" ] && [ -n "$used_pct" ]; then
  pct_int=$(printf "%.0f" "$used_pct")
  col=$(usage_color "$pct_int")
  used_fmt=$(fmt_tokens "$used_input")
  total_fmt=$(fmt_tokens "$total")
  line2="${WHITE}CTX${RESET} ${col}${pct_int}%${RESET} ${DIM}(${used_fmt}/${total_fmt})${RESET}"
fi

if [ -n "$five_pct" ]; then
  five_used=$(printf "%.0f" "$five_pct"); five_rem=$(( 100 - five_used ))
  col=$(remaining_color "$five_rem")
  eta=$(eta_until "$five_reset")
  [ -n "$line2" ] && line2="${line2}${SEP}"
  if [ -n "$eta" ]; then
    line2="${line2}${WHITE}5h${RESET} ${col}${five_rem}%${RESET} ${DIM}(↻${eta})${RESET}"
  else
    line2="${line2}${WHITE}5h${RESET} ${col}${five_rem}%${RESET}"
  fi
fi

if [ -n "$week_pct" ]; then
  week_used=$(printf "%.0f" "$week_pct"); week_rem=$(( 100 - week_used ))
  col=$(remaining_color "$week_rem")
  eta=$(eta_until "$week_reset")
  [ -n "$line2" ] && line2="${line2}${SEP}"
  if [ -n "$eta" ]; then
    line2="${line2}${WHITE}7d${RESET} ${col}${week_rem}%${RESET} ${DIM}(↻${eta})${RESET}"
  else
    line2="${line2}${WHITE}7d${RESET} ${col}${week_rem}%${RESET}"
  fi
fi

now_time=$(date +%H:%M:%S)
[ -n "$line2" ] && line2="${line2}${SEP}"
line2="${line2}${B_WHITE}${now_time}${RESET}"

# ─── 출력 ───
[ -n "$show_msg" ] && printf "${DIM}💬 ${RESET}${B_WHITE}%s${RESET}\n" "$show_msg"
[ -n "$line1" ] && printf "%s\n" "$line1"
[ -n "$line2" ] && printf "%s" "$line2"
[ -n "$ports_line" ] && printf "\n%s" "$ports_line"
exit 0
