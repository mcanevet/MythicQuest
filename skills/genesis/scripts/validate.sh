#!/bin/bash
# Genesis validation — operates on cwd (project root)
# Usage: ./scripts/validate.sh
# Exit codes: 0 = pass, 1 = fail
set -e

errors=0

echo "=== Genesis Validation ==="

# Check 1: GAME_STATE.md exists with required sections
if [ ! -f "GAME_STATE.md" ]; then
    echo "❌ FAIL: GAME_STATE.md missing" >&2
    errors=$((errors+1))
else
    sections_ok=true
    grep -q "^## Vision" GAME_STATE.md || { echo "❌ FAIL: GAME_STATE.md missing '## Vision'" >&2; sections_ok=false; errors=$((errors+1)); }
    grep -q "^## Core Mechanics" GAME_STATE.md || { echo "❌ FAIL: GAME_STATE.md missing '## Core Mechanics'" >&2; sections_ok=false; errors=$((errors+1)); }
    grep -q "^## Task Backlog" GAME_STATE.md || { echo "❌ FAIL: GAME_STATE.md missing '## Task Backlog'" >&2; sections_ok=false; errors=$((errors+1)); }
    
    if $sections_ok; then
        task_count=$(grep -c '^- \[' GAME_STATE.md || true)
        echo "✓ OK: GAME_STATE.md (sections present, $task_count tasks)"
    fi
fi

# Check 2: README.md exists
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