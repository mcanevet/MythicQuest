#!/usr/bin/env bash
# watch_root.sh — root-session stall watchdog (complements watch_session.sh).
#
# Problem (observed 09-04, ling run): the root build session emitted a truncated
# mega-step (finish:length at ~123k context) and then sat brain-dead for 7.1
# hours with the opencode PROCESS ALIVE. Subagent-span monitors saw nothing —
# no children were running. The stall cost an overnight of wall clock.
#
# Usage:
#   ./watch_root.sh <root_session_id> [interval_s] [stall_threshold_s]
#
# Alerts when BOTH:
#   1. the root session's last part is older than the threshold, AND
#   2. the root's process tree shows no fresh child-session activity either
#      (i.e. it isn't just "thinking while a subagent works").
# Caveat per AGENTS.md: host sleep looks identical — check process uptime and
# kern.waketime before intervening; a live-but-spinning root shows this state,
# a sleeping host shows it too. The script prints both diagnostics on alert.
#
# Exit codes: 0 = running clean when interrupted, 1 = bad args, 2 = not found.

set -euo pipefail

DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
ROOT_ID="${1:?usage: watch_root.sh <root_session_id> [interval_s] [stall_threshold_s]}"
INTERVAL="${2:-30}"
THRESHOLD="${3:-300}"

if ! sqlite3 "$DB" "SELECT 1 FROM session WHERE id='$ROOT_ID';" | grep -q 1; then
  echo "ERROR: session $ROOT_ID not found in $DB" >&2
  exit 2
fi

last_alert=0
while true; do
  row=$(sqlite3 "$DB" \
    "SELECT COUNT(*) || '|' || COALESCE(MAX(time_created),0) FROM part WHERE session_id='$ROOT_ID';")
  last_ms=${row##*|}
  now_s=$(date +%s)
  age=$(( now_s - last_ms / 1000 ))

  # any child session updated recently? (root may be awaiting a task() result)
  child_fresh=$(sqlite3 "$DB" \
    "SELECT COUNT(*) FROM session c WHERE c.parent_id='$ROOT_ID' AND c.time_updated > $(( (now_s - THRESHOLD) * 1000 ));")

  printf "[%s] root_last_part_age=%ds fresh_children=%d" "$(date '+%H:%M:%S')" "$age" "$child_fresh"

  if [ "$age" -gt "$THRESHOLD" ] && [ "$child_fresh" -eq 0 ]; then
    printf "  🚨 ROOT STALL: no root parts for %ds and no child activity — check finish:length truncation (brain-death) vs host sleep\n" "$age"
    if [ "$last_alert" -eq 0 ]; then
      pid="$(pgrep -x opencode | head -1)"
      printf "      diagnostics: opencode pid: %s; uptime: %s; kern.waketime: %s\n" \
        "${pid:-none (process gone)}" \
        "$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ' || echo '?')" \
        "$(sysctl -n kern.waketime 2>/dev/null | head -1 || echo '?')"
    fi
    last_alert=1
  else
    printf "\n"
    last_alert=0
  fi
  sleep "$INTERVAL"
done
