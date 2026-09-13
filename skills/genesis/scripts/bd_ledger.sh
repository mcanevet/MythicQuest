#!/bin/bash
# bd_ledger.sh — canonical beads-ledger helper for MythicQuest skills.
# SINGLE SANCTIONED ENTRYPOINT for all bd interactions in game-build sessions.
# Skills call this script; agents never invoke `bd` directly. This is the
# sanctioned-path rule (lint: sanctioned-paths-only) applied to the ledger:
# one script, deterministic subcommands, validated in the 09-13 spike.
#
# Usage: bd_ledger.sh <subcommand> [args...]
#   init                              — bd init --stealth (+ claim.pools config)
#   ready                             — JSON: claimable beads (labels + deps applied)
#   claim  <id>                       — atomic claim (fails loudly if taken)
#   close   <id> <reason>             — close with reason; sets metadata attempts if given
#   complete_check                    — exit 0 iff no open tasks remain (any status)
#   attempts <id>                     — print current attempt count from metadata
#   bump_attempts <id>                 — increment retry counter, print new value
#   create_task <title> <description> <label> <priority> [dep-ids...]
#                                     : create a flat task bead - genesis backlog;
#                                       dep-ids are beads this task WAITS FOR - created earlier
#  file_finding <parent-id> <type> <title> <description>
#                                     — create bug/vision/critique/polish bead with
#                                       discovered-from provenance (P0/P1 by type)
#   plan_link <id> <plan-file>        — set metadata plan=<plan-file> on the bead
#   show    <id> [--field <name>]     — full bead JSON or single field value
#   backup                            — bd backup snapshot into .beads/backups/
#   gate_create <blocked-id> <name> <reason>
#                                     — create a human gate blocking <blocked-id>
#   gate_close <gate-id> <reason>     — resolve a gate (releases the blocked bead)
#   gate_list                         — open gates (JSON)
#   release_entry                     — create release bead + qa/vision/consumer
#                                       gate chain; prints RID G1 G2 G3 (space-sep)
#
# Exit codes: 0 = success; 1 = failure (message on stderr). Never silently
# degrades — the caller reports ⛔ BLOCKED on non-zero.
set -euo pipefail

LEDGER_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cmd="${1:-}"
shift || true

die() { echo "❌ bd_ledger: $*" >&2; exit 1; }

need_bd() {
  command -v bd >/dev/null 2>&1 || die "bd binary not found on PATH — install beads (brew install beads) and retry; do not improvise"
}

# _mk_gate <blocked-id> <reason> — create a human gate; prints gate id
_mk_gate() {
  bd gate create --blocks "$1" --type human --reason "$2" --json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
print(d.get('id', ''))"
}

case "$cmd" in
  init)
    need_bd
    bd init --quiet --stealth >/dev/null 2>&1 || true  # idempotent: re-init over existing is fine
    # Claim pools for the swarm arm: parallel poppies claim from a shared pool
    # so spawned workers partition tasks without racing.
    bd config set claim.pools.poppy-pool "MythicQuest swarm implementer pool" --file .beads/config.yaml >/dev/null 2>&1 || true
    echo "✓ ledger initialized (.beads/, stealth mode, poppy-pool configured)"
    ;;
  ready)
    need_bd
    # Only actionable task/bug beads, excluding gates (issue_type gate),
    # excluding human-escalation beads — they are for the operator, not agents.
    bd ready --json 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
beads = [b for b in data if b.get("issue_type") not in ("gate",)]
print(json.dumps(beads))'
    ;;
  claim)
    need_bd
    [ $# -ge 1 ] || die "claim requires <id>"
    # Atomic: bd rejects a racing claimant. On failure exit non-zero with stderr.
    bd update "$1" --claim --json >/dev/null || die "claim failed for $1 (already claimed by another agent?) — re-run ready and pick another"
    echo "✓ claimed $1"
    ;;
  close)
    need_bd
    [ $# -ge 2 ] || die "close requires <id> <reason>"
    bd close "$1" --reason "$2" --json >/dev/null || die "close failed for $1"
    echo "✓ closed $1"
    ;;
  complete_check)
    need_bd
    # Game complete when no WORK beads remain open — release beads (label
    # "release", orchestrator-owned Phase-3 artifacts) are excluded so a
    # re-entered Phase 3 isn't wedged by its own gate chain. Status
    # open|in_progress counts.
    count=$(bd list --json --status open,in_progress 2>/dev/null | python3 -c '
import json, sys
beads = [b for b in json.load(sys.stdin) if "release" not in (b.get("labels") or [])]
print(len(beads))')
    if [ "$count" -eq 0 ]; then
      echo "✓ no open beads remain — game complete"
      exit 0
    else
      echo "ℹ️  $count open bead(s) remain"
      exit 1
    fi
    ;;
  attempts)
    need_bd
    [ $# -ge 1 ] || die "attempts requires <id>"
    bd show "$1" --json 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
md = d.get('metadata') or {}
print(md.get('attempts', 0) if isinstance(md, dict) else 0)"
    ;;
  bump_attempts)
    need_bd
    [ $# -ge 1 ] || die "bump_attempts requires <id>"
    cur=$(bd show "$1" --json 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
md = d.get('metadata') or {}
print(md.get('attempts', 0) if isinstance(md, dict) else 0)")
    next=$((cur + 1))
    bd update "$1" --set-metadata "attempts=${next}" >/dev/null 2>&1 || bd update "$1" --metadata "{\"attempts\": ${next}}" >/dev/null 2>&1 || die "could not set attempts metadata on $1"
    echo "$next"
    ;;
  create_task)
    need_bd
    [ $# -ge 4 ] || die "create_task requires <title> <description> <label> <priority> [dep-ids...]"
    title="$1"; desc="$2"; label="$3"; prio="$4"; shift 4
    deps=""
    if [ $# -gt 0 ]; then
      deps=$(printf '%s,' "$@" | sed 's/,$//')
    fi
    if [ -n "$deps" ]; then
      id=$(bd create "$title" -t task -l "$label" -p "$prio" -d "$desc" --deps "$deps" --silent 2>/dev/null) \
        || die "bd create failed for task: $title"
    else
      id=$(bd create "$title" -t task -l "$label" -p "$prio" -d "$desc" --silent 2>/dev/null) \
        || die "bd create failed for task: $title"
    fi
    echo "$id"
    ;;
  file_finding)
    # QA/vision/consumer findings become beads with provenance, not reports-only prose
    need_bd
    [ $# -ge 4 ] || die "file_finding requires <parent-id> <type> <title> <description>"
    parent="$1"; ftype="$2"; title="$3"; desc="$4"
    case "$ftype" in
      bug) prio=0 ;;
      vision) prio=1 ;;
      critique) prio=1 ;;
      polish) prio=2 ;;
      *) die "unknown finding type: $ftype (expected bug|vision|critique|polish)" ;;
    esac
    id=$(bd create "$title" -t "$ftype" -p "$prio" -l "loop-$ftype" \
      -d "$desc" --deps "discovered-from:$parent" --silent 2>/dev/null) \
      || die "bd create failed for finding"
    echo "$id"
    ;;
  plan_link)
    need_bd
    [ $# -ge 2 ] || die "plan_link requires <id> <plan-file>"
    bd update "$1" --set-metadata "plan=$2" >/dev/null 2>&1 || die "could not set plan metadata on $1"
    ;;
  show)
    need_bd
    [ $# -ge 1 ] || die "show requires <id>"
    if [ "${1:-}" = "--field" ] || [ "${2:-}" = "--field" ]; then
      # show <id> --field <name>
      id="$1"; fld="${3:-}"
      bd show "$id" --json 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
if isinstance(d, list): d = d[0] if d else {}
print(d.get('$fld', ''))"
    else
      bd show "$1" --json
    fi
    ;;
  gate_list)
    need_bd
    bd gate list --json 2>/dev/null || echo "[]"
    ;;
  release_entry)
    need_bd
    rid=$(bd create "Release: ship the game" -t task -l release -p 0 --silent 2>/dev/null) \
      || die "could not create release bead"
    g1=$(_mk_gate "$rid" "Functional QA: 0 violations required")
    g2=$(_mk_gate "$rid" "Vision: aligned verdict required")
    g3=$(_mk_gate "$rid" "Consumer critique + creative disposition")
    [ -n "$g1" ] && [ -n "$g2" ] && [ -n "$g3" ] || die "gate chain creation failed for $rid"
    echo "$rid $g1 $g2 $g3"
    ;;
  gate_create)
    need_bd
    [ $# -ge 3 ] || die "gate_create requires <blocked-id> <name> <reason>"
    gid=$(_mk_gate "$1" "$3")
    [ -n "$gid" ] || die "gate create returned no id for $1"
    echo "$gid"
    ;;
  gate_close)
    need_bd
    [ $# -ge 2 ] || die "gate_close requires <gate-id> <reason>"
    bd gate resolve "$1" 2>/dev/null || bd close "$1" --reason "$2" || die "gate resolve failed for $1"
    echo "✓ resolved gate $1"
    ;;
  backup)
    need_bd
    mkdir -p .beads/backups
    bd export --all -o ".beads/backups/ledger-$(date +%Y%m%d-%H%M%S).jsonl" >/dev/null || die "backup export failed"
    echo "✓ ledger backup exported"
    ;;
  *)
    die "unknown subcommand: $cmd (init|ready|claim|close|complete_check|attempts|bump_attempts|file_finding|plan_link|show|gate_list|gate_create|gate_close|release_entry|backup)"
    ;;
esac
