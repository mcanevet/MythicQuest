#!/bin/bash
# Log-result validation — operates on cwd (project root)
# Usage: ./validate.sh [ISSUE_ID]
#   ISSUE_ID: the tracker issue id of the task being logged (opaque, e.g. dd-yan).
# Exit codes: 0 = success, 1 = failure
# Reads the tracker backend directly (bd; provided by mise).
set -e

ISSUE_ID="${1:-}"
errors=0

echo "=== Log-Result Validation ==="

# Check 1: bd available
if ! command -v bd >/dev/null 2>&1; then
    echo "❌ FAIL: bd not on PATH — run via mise (project mise.toml)" >&2
    exit 1
fi

# Check 2: The logged issue must be closed; no OTHER issue may still be
# in_progress (batched delegations legitimately groom the next task before
# the current one validates — but the groomed issue is open-for-planning,
# and if it was set in_progress the NEXT log-result will cover it; here we
# only fail when the issue being logged is not closed, or — without an id —
# when any issue is in_progress).
open_json=$(bd list --json 2>/dev/null || echo "[]")
in_prog_count=$(printf '%s' "$open_json" | grep -c '"status": *"in_progress"' || true)

if [ -n "$ISSUE_ID" ]; then
    issue_json=$(bd show "$ISSUE_ID" --json 2>/dev/null || echo "[]")
    if [ "$issue_json" = "[]" ] || [ -z "$issue_json" ]; then
        echo "❌ FAIL: issue '$ISSUE_ID' not found in tracker" >&2
        errors=$((errors+1))
    elif printf '%s' "$issue_json" | grep -q '"status": *"closed"'; then
        if [ "$in_prog_count" -gt 0 ]; then
            echo "ℹ️  INFO: $in_prog_count other issue(s) in_progress (batched delegation) — not an '$ISSUE_ID' failure" >&2
        fi
        echo "✓ OK: issue '$ISSUE_ID' closed"
    else
        echo "❌ FAIL: issue '$ISSUE_ID' is not closed — log-result did not complete its tracker close" >&2
        errors=$((errors+1))
    fi
else
    if [ "$in_prog_count" -gt 0 ]; then
        echo "❌ FAIL: $in_prog_count issue(s) still in_progress — log-result did not complete the status update" >&2
        errors=$((errors+1))
    else
        echo "✓ OK: No issue left in_progress"
    fi
fi

# Check 3: If ISSUE_ID provided, its plan must be archived (.completed.md exists)
if [ -n "$ISSUE_ID" ]; then
    if ls plans/"$ISSUE_ID"-*.completed.md >/dev/null 2>&1; then
        echo "✓ OK: plan for '$ISSUE_ID' archived to .completed.md"
    else
        echo "❌ FAIL: no plans/$ISSUE_ID-*.completed.md — archive step did not run" >&2
        errors=$((errors+1))
    fi
fi

# Check 4: No orphaned active plan files for closed issues
# (An issue closed by log-result must not still have a live .md plan.)
closed_ids=$(printf '%s' "$open_json" >/dev/null 2>&1 && bd list --json --all 2>/dev/null \
    | python3 -c '
import json,sys
try:
    rows=json.load(sys.stdin)
except Exception:
    rows=[]
for r in rows:
    if isinstance(r,dict) and r.get("status")=="closed":
        print(r.get("id",""))
' 2>/dev/null || true)
for cid in $closed_ids; do
    if ls plans/"$cid"-*.md >/dev/null 2>&1 && ! ls plans/"$cid"-*.completed.md >/dev/null 2>&1; then
        echo "❌ FAIL: closed issue '$cid' still has an active (non-.completed) plan file" >&2
        errors=$((errors+1))
    fi
done
if [ -n "$closed_ids" ]; then
    echo "✓ OK: no orphaned active plans for closed issues"
fi

# Check 5: At least one archived (.completed.md) plan file must exist if plans/ was ever used
if [ -d "plans" ]; then
    completed_count=$(find plans -maxdepth 1 -name "*.completed.md" | wc -l | tr -d ' ')
    active_count=$(find plans -maxdepth 1 -name "*.md" ! -name "*.completed.md" | wc -l | tr -d ' ')
    if [ "$completed_count" -eq 0 ] && [ "$active_count" -gt 0 ]; then
        echo "❌ FAIL: plans/ has active plan file(s) but none archived to .completed.md — archive step did not run" >&2
        errors=$((errors+1))
    else
        echo "✓ OK: plan archiving state consistent ($completed_count archived, $active_count active)"
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
