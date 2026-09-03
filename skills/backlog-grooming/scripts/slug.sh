#!/bin/bash
# slug.sh — canonical plan-filename generator for backlog-grooming.
# Usage: ./slug.sh "<task line>"   OR   echo "<task line>" | ./slug.sh
#   Prints the canonical plan filename: plans/NN-<slug>.md  (NN = zero-padded task number)
#
# Deterministic implementation of the rules that used to be prose ("lowercase the
# description, replace spaces with hyphens, strip special chars"). Every caller
# (backlog-grooming -> build.md plan link -> log-result archive) must derive the
# SAME name, so this is the single source of truth.
#
# Accepts task lines in any of these shapes:
#   - [ ] Task 3: Create Player entity with movement and collision [core]
#   - [in progress] Task #3: Description (see: plans/03-...md)
# Exit codes: 0 = printed a filename; 1 = could not derive a slug.
set -euo pipefail

line="${1:-$(cat)}"

# strip status marker: "- [ ] " / "- [in progress] " / "- [x] "  (literal, not a class)
case "$line" in
    "- [in progress] "*|"- [x] "*|"- [ ] "*)
        line="${line#*- \[*\] }" ;;
esac

# strip a "(see: plans/...)" link if present
line="$(printf '%s' "$line" | sed -E 's/\(see: plans\/[^)]*\)[[:space:]]*$//')"

# extract task number + description ("Task N: desc" or "Task #N: desc")
if printf '%s' "$line" | grep -qE '^Task #?[0-9]+:'; then
    num="$(printf '%s' "$line" | sed -E 's/^Task #?([0-9]+):.*/\1/')"
    desc="$(printf '%s' "$line" | sed -E 's/^Task #?[0-9]+:\s*//')"
else
    num="1"
    desc="$line"
fi

# slugify description: drop [tag]/[...] and (..) tags, lowercase, non-alnum -> '-',
# collapse runs, trim leading/trailing hyphens
slug="$(printf '%s' "$desc" \
    | sed -E 's/\[[^]]*\]//g; s/\([^)]*\)//g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

if [ -z "$slug" ]; then
    echo "❌ FAIL: could not derive a slug from task line: $*" >&2
    exit 1
fi

numz="$(printf '%02d' "$num")"
printf 'plans/%s-%s.md\n' "$numz" "$slug"
