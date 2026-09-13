#!/bin/bash
# slug.sh — canonical plan-filename generator for backlog-grooming.
# Usage: ./slug.sh "<bead-id> <title>"   OR   echo "<bead-id> <title>" | ./slug.sh
#   Prints the canonical plan filename:
#     plans/<bead-id>-<slug>.md
#
# Deterministic implementation of the slug rules. Every caller
# (backlog-grooming -> build.md bead lookup -> log-result archive) must derive
# the SAME name, so this is the single source of truth. Keying by bead ID
# (not a sequence number) means two beads with identical titles never collide
# and the filename is recoverable from the ledger alone.
#
# Accepts input in any of these shapes:
#   rq-abc123 Create Player entity with movement and collision
#   "rq-abc123: Create Player entity with movement and collision"
#   bare title (no id) — falls back to slug-only name (legacy/manual use)
# Exit codes: 0 = printed a filename; 1 = could not derive a slug.
set -euo pipefail

line="${1:-$(cat)}"

# Normalize "id: title" / "id - title" to "id title"
line="$(printf '%s' "$line" | sed -E 's/^([A-Za-z0-9][A-Za-z0-9-]*):[[:space:]]+/\1 /')"

# Extract bead id (first token matching xx-xxxx hex-ish pattern)
bead_id=""
if printf '%s' "$line" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*-[a-z0-9]+ '; then
    bead_id="$(printf '%s' "$line" | awk '{print $1}')"
    title="$(printf '%s' "$line" | cut -d' ' -f2-)"
else
    title="$line"
fi

# slugify title: drop [tag]/[...] and (..) tags, lowercase, non-alnum -> '-',
# collapse runs, trim leading/trailing hyphens
slug="$(printf '%s' "$title" \
    | sed -E 's/\[[^]]*\]//g; s/\([^)]*\)//g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

if [ -z "$slug" ]; then
    echo "❌ FAIL: could not derive a slug from: $*" >&2
    exit 1
fi

printf 'plans/%s-%s.md\n' "$bead_id" "$slug"
