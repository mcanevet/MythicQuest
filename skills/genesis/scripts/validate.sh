#!/bin/bash
# Genesis validation — operates on cwd (project root)
# Usage: ./scripts/validate.sh
# Exit codes: 0 = pass, 1 = fail
set -e

errors=0

echo "=== Genesis Validation ==="

# Check 1: GAME_STATE.md exists with required charter sections (no task lines)
if [ ! -f "GAME_STATE.md" ]; then
    echo "❌ FAIL: GAME_STATE.md missing" >&2
    errors=$((errors+1))
else
    grep -q "^## Vision" GAME_STATE.md || { echo "❌ FAIL: GAME_STATE.md missing '## Vision'" >&2; errors=$((errors+1)); }
    grep -q "^## Core Mechanics" GAME_STATE.md || { echo "❌ FAIL: GAME_STATE.md missing '## Core Mechanics'" >&2; errors=$((errors+1)); }
    if grep -qE '^- \[ \]' GAME_STATE.md 2>/dev/null; then
        echo "❌ FAIL: GAME_STATE.md contains task lines ('- [ ]') — the queue belongs in the tracker, not the charter" >&2
        errors=$((errors+1))
    fi
    if [ "$errors" -eq 0 ]; then
        echo "✓ OK: GAME_STATE.md charter present (Vision, Core Mechanics, no task lines)"
    fi
fi

# Check 2: tracker seeded with >=10 open issues, all with reporter labels.
# Reads the backend directly (read-only bd — required on PATH, provided by mise).
if ! command -v bd >/dev/null 2>&1; then
    echo "❌ FAIL: bd not on PATH — run via mise (project mise.toml)" >&2
    errors=$((errors+1))
else
    issues=$(bd list --json 2>/dev/null || echo "[]")
    issue_count=$(printf '%s' "$issues" | grep -c '"id"' || true)
    open_count=$(printf '%s' "$issues" | grep -c '"status": *"open"' || true)
    reporter_count=$(printf '%s' "$issues" | grep -c '"reporter:' || true)
    if [ "$issue_count" -lt 10 ]; then
        echo "❌ FAIL: tracker has $issue_count issues (<10) — genesis must seed 10-20 tasks" >&2
        errors=$((errors+1))
    elif [ "$open_count" -ne "$issue_count" ]; then
        echo "❌ FAIL: $((issue_count - open_count)) issue(s) not in 'open' status right after genesis" >&2
        errors=$((errors+1))
    elif [ "$reporter_count" -ne "$issue_count" ]; then
        echo "❌ FAIL: $((issue_count - reporter_count)) issue(s) missing a 'reporter:' label" >&2
        errors=$((errors+1))
    else
        echo "✓ OK: tracker seeded ($issue_count open issues, all labeled)"
    fi
fi

# Check 3: README.md exists
if [ ! -f "README.md" ]; then
    echo "❌ FAIL: README.md missing" >&2
    errors=$((errors+1))
else
    echo "✓ OK: README.md exists"
fi

# Final result
if [ "$errors" -gt 0 ]; then
    echo ""
    echo "❌ Genesis validation FAILED ($errors errors)" >&2
    exit 1
else
    echo ""
    echo "✓ Genesis validation PASSED"
    exit 0
fi
