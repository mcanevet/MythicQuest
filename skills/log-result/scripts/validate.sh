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

# Check 2: The logged issue must be closed with a resolution comment; no
# OTHER issue may still be in_progress (batched delegations legitimately
# groom the next task before the current one validates — but the groomed
# issue is open-for-claiming, and if it was set in_progress the NEXT
# log-result will cover it; here we only fail when the issue being logged
# is not closed, or — without an id — when any issue is in_progress).
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
        # Check 2b: the resolution comment must exist (comment-then-close)
        if bd show "$ISSUE_ID" 2>/dev/null | grep -qi "CLOSED:"; then
            echo "✓ OK: resolution comment present on '$ISSUE_ID'"
        else
            echo "❌ FAIL: issue '$ISSUE_ID' closed without a resolution comment (comment-then-close required)" >&2
            errors=$((errors+1))
        fi
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

# Check 3: No orphaned plan files — the tracker is the single durable task
# artifact; a plans/ directory with content means the old file-based plan
# path leaked into this run.
if [ -d "plans" ] && [ -n "$(find plans -maxdepth 1 -name '*.md' -print -quit)" ]; then
    echo "❌ FAIL: plans/ contains plan file(s) — plans live in the tracker issue description (contract v2), not on disk" >&2
    errors=$((errors+1))
elif [ -d "plans" ]; then
    echo "✓ OK: plans/ empty (plan-in-tracker respected)"
else
    echo "✓ OK: no plans/ directory (expected)"
fi

echo ""
if [ "$errors" -gt 0 ]; then
    echo "❌ Log-result validation FAILED ($errors errors)" >&2
    exit 1
else
    echo "✓ Log-result validation PASSED"
    exit 0
fi
