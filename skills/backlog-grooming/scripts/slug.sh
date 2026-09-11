#!/bin/bash
# slug.sh — canonical plan-filename generator for backlog-grooming.
# Usage: ./slug.sh "<tracker issue id>" "<task title>"
#   Prints the canonical plan filename: plans/<id>-<slug>.md
#
# Deterministic implementation of the rules that used to be prose ("lowercase the
# description, replace spaces with hyphens, strip special chars"). Every caller
# (backlog-grooming -> log-result archive) must derive the SAME name, so this is
# the single source of truth.
#
# The issue id is opaque and tracker-defined (bd hash, GitHub #42, Jira PROJ-123)
# — it is embedded verbatim, never parsed or reformatted.
# Exit codes: 0 = printed a filename; 1 = could not derive a slug.
set -euo pipefail

id="${1:?usage: slug.sh <issue-id> <title>}"
title="${2:-${3:-}}"

# slugify title: drop [tag]/[...] and (..) qualifiers, lowercase,
# non-alnum -> '-', collapse runs, trim leading/trailing hyphens
slug="$(printf '%s' "$title" \
    | sed -E 's/\[[^]]*\]//g; s/\([^)]*\)//g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"

if [ -z "$slug" ]; then
    echo "❌ FAIL: could not derive a slug from title: $title" >&2
    exit 1
fi

printf 'plans/%s-%s.md\n' "$id" "$slug"
