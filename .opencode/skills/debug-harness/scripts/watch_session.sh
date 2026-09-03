#!/usr/bin/env bash
# watch_session.sh — poll a session's part-table activity for stall detection.
#
# Usage:
#   ./watch_session.sh <session_id> [interval_seconds] [stall_threshold_seconds]
#
# Prints part-count/type breakdown every interval; warns when the session's
# latest part is older than the stall threshold AND no new parts appeared
# since the previous poll.
#
# Exit codes: 0 = clean poll loop (Ctrl-C to stop), 1 = bad args,
#             2 = session not found.

set -euo pipefail

DB="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
SESSION_ID="${1:?usage: watch_session.sh <session_id> [interval_seconds] [stall_threshold]}"
INTERVAL="${2:-10}"
THRESHOLD="${3:-60}"

if ! sqlite3 "$DB" "SELECT 1 FROM session WHERE id='$SESSION_ID';" | grep -q 1; then
  echo "ERROR: session $SESSION_ID not found in $DB" >&2
  exit 2
fi

prev_count=-1
while true; do
  row=$(sqlite3 "$DB" \
    "SELECT COUNT(*) || '|' || COALESCE(MAX(time_created),0) FROM part WHERE session_id='$SESSION_ID';")
  count=${row%%|*}
  last_ms=${row##*|}
  last_hm=$(date -r "$((last_ms / 1000))" "+%H:%M:%S" 2>/dev/null || echo "?")
  now_s=$(date +%s)
  age=$(( now_s - last_ms / 1000 ))

  printf "[%s] parts=%d last=%s age=%ds" "$(date '+%H:%M:%S')" "$count" "$last_hm" "$age"
  if [ "$age" -gt "$THRESHOLD" ]; then
    if [ "$count" = "$prev_count" ]; then
      printf "  ⚠️  no new activity for >%ss — possible stall (verify via reasoning traces; host sleep also looks like this)\n" "$THRESHOLD"
    else
      printf "  (idle but progressed)\n"
    fi
  else
    printf "\n"
  fi
  prev_count=$count
  sleep "$INTERVAL"
done
