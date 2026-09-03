#!/bin/bash
# Archive a plan file: move plans/<num>-<slug>.md -> plans/<num>-<slug>.completed.md
# Called by log-result so the move never transits the LLM context (token-free, deterministic).
# Usage: archive_plan.sh <plan-file-path>   (relative to project root; absolute also accepted)
# Exit codes: 0 = archived (or already archived), 1 = failure
set -euo pipefail

f="${1:-}"
if [ -z "$f" ]; then
    echo "usage: archive_plan.sh <plan-file-path>" >&2
    exit 1
fi

# Normalize: strip leading ./ and trailing whitespace
f="${f#./}"

if [ ! -f "$f" ]; then
    # Edge cases per SKILL.md: missing plan file (skip silently), or already archived
    case "$f" in
        *.completed.md)
            if [ -f "${f%.completed.md}.md" ]; then
                echo "❌ FAIL: '$f' archived but original '${f%.completed.md}.md' still exists" >&2
                exit 1
            fi
            echo "OK: '$f' already archived"
            exit 0
            ;;
        *)
            # Check for a tombstone-only original (pre-migration state)
            if [ -f "$f.completed.md" ]; then
                echo "OK: '$f.completed.md' already archived (original missing — pre-existing state)"
                exit 0
            fi
            echo "ℹ️  INFO: plan file '$f' does not exist — skipping (per SKILL.md edge case)" >&2
            exit 0
            ;;
    esac
fi

if [[ "$f" == *.md ]]; then
    dest="${f%.md}.completed.md"
else
    dest="$f.completed.md"
fi
mv "$f" "$dest"

# Confirm the archive landed and the original is gone
if [ -f "$dest" ] && [ ! -f "$f" ]; then
    echo "OK: archived '$f' -> '$dest'"
    exit 0
else
    echo "❌ FAIL: archive of '$f' incomplete (dest exists: $([ -f "$dest" ] && echo yes || echo no); original gone: $([ ! -f "$f" ] && echo yes || echo no))" >&2
    exit 1
fi
