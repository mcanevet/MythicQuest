#!/bin/bash
# Log-result validation — operates on cwd (project root)
# Usage: ./validate.sh [TASK_ID]
# Exit codes: 0 = success, 1 = failure
set -e

TASK_ID="${1:-}"
errors=0

echo "=== Log-Result Validation ==="

# Check 1: GAME_STATE.md exists (hard requirement — log-result always operates on it)
if [ ! -f "GAME_STATE.md" ]; then
    echo "❌ FAIL: GAME_STATE.md missing" >&2
    exit 1
fi
echo "✓ OK: GAME_STATE.md exists"

# Check 2: No task should still be [in progress] after log-result ran.
# Scope: tasks OTHER than the one being logged (batched delegations
# legitimately groom the next task to [in progress] before validating the
# current one — observed 09-04: agent had to temporarily revert Task 2 to
# unchecked to validate Task 1, then restore it; pointless state churn that
# risks losing the plan-file link on restore). With TASK_ID given, only an
# in-progress line matching THAT task is a failure. Without TASK_ID, any
# in-progress line fails (unchanged global check).
if [ -n "$TASK_ID" ]; then
    if grep -E "^- \[in progress\] (Task (#)?${TASK_ID}:|#?${TASK_ID}[.:] )" GAME_STATE.md | grep -q .; then
        echo "❌ FAIL: Task ${TASK_ID} still [in progress] — log-result did not complete its status update" >&2
        errors=$((errors+1))
    else
        others=$(grep -c '\[in progress\]' GAME_STATE.md || true)
        if [ "$others" -gt 0 ]; then
            echo "ℹ️  INFO: $others other task(s) [in progress] (batched delegation) — not a Task ${TASK_ID} failure" >&2
        fi
        echo "✓ OK: Task '${TASK_ID}' not left [in progress]"
    fi
else
    if grep -q '\[in progress\]' GAME_STATE.md; then
        echo "❌ FAIL: GAME_STATE.md still has a task marked [in progress] — log-result did not complete the status update" >&2
        errors=$((errors+1))
    else
        echo "✓ OK: No task left [in progress]"
    fi
fi

# Check 3: If TASK_ID provided, that specific task line must be marked [x]
# Accepts both mandated formats — "Task N:" prefix (canonical, per genesis) and bare
# numbered lines ("- [x] 1." / "- [x] #1") — plus plain "- [x]" as fallback when only
# one task exists. Genesis requires "Task N:" but deviations have been observed (09-03);
# the validator must not fail a correctly-completed task over format drift.
if [ -n "$TASK_ID" ]; then
    task_line=$(grep -E "^- \[[ x]\] (Task (#)?${TASK_ID}:|#?${TASK_ID}[.:] )" GAME_STATE.md || true)
    if [ -z "$task_line" ]; then
        # Fall back to matching any completed line when the task can't be located by ID
        # (format drift beyond the above patterns). Only sound when exactly one [x] exists.
        done_count=$(grep -cE '^- \[x\]' GAME_STATE.md || true)
        inprog_count=$(grep -cE '^- \[in progress\]' GAME_STATE.md || true)
        open_count=$(grep -cE '^- \[ \]' GAME_STATE.md || true)
        if [ "$done_count" -ge 1 ] && [ "$inprog_count" -eq 0 ]; then
            echo "⚠️  WARN: no 'Task ${TASK_ID}:' line found in GAME_STATE.md (format drift?), but $done_count task(s) marked [x] and none [in progress] — treating as complete" >&2
        else
            echo "❌ FAIL: No task line found matching 'Task $TASK_ID:' in GAME_STATE.md and fallback inconclusive" >&2
            errors=$((errors+1))
        fi
    elif ! echo "$task_line" | grep -q '^- \[x\]'; then
        echo "❌ FAIL: Task '$TASK_ID' is not marked [x]: $task_line" >&2
        errors=$((errors+1))
    else
        echo "✓ OK: Task '$TASK_ID' marked [x]"
    fi
else
    echo "ℹ️  INFO: No TASK_ID provided, skipping task-specific status check" >&2
fi

# Check 4: At least one archived (.completed.md) plan file must exist if plans/ was ever used
# Tombstones (single-line "Archived to ..." redirects from the retired pre-script archive
# workaround) still count as archived — kept for backward compatibility with older sandboxes.
if [ -d "plans" ]; then
    completed_count=$(find plans -maxdepth 1 -name "*.completed.md" | wc -l | tr -d ' ')
    active_count=0
    tombstone_count=0
    while IFS= read -r f; do
        if [ "$(wc -l < "$f" | tr -d ' ')" -le 1 ] && grep -qi '^Archived to ' "$f"; then
            tombstone_count=$((tombstone_count+1))
        else
            active_count=$((active_count+1))
        fi
    done < <(find plans -maxdepth 1 -name "*.md" ! -name "*.completed.md")
    if [ "$completed_count" -eq 0 ] && [ "$active_count" -gt 0 ]; then
        echo "❌ FAIL: plans/ has active plan file(s) but none archived to .completed.md — archive step did not run" >&2
        errors=$((errors+1))
    else
        echo "✓ OK: plan archiving state consistent ($completed_count archived, $active_count active, $tombstone_count tombstoned)"
    fi
else
    echo "ℹ️  INFO: No plans/ directory yet (expected for very first task)" >&2
fi

echo ""
if [ "$errors" -gt 0 ]; then
    echo "❌ Log-result validation FAILED ($errors errors)" >&2
    exit 1
else
    echo "✓ Log-result validation PASSED"
    exit 0
fi