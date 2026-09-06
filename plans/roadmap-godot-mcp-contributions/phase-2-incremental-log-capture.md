# Phase 2 — Issue + PR: Sequence-Numbered Incremental Log/Error Capture

Kind: issue-first, then PR · Status: not started · Prefer after Phase 1 lands

## Importance to us: MEDIUM-HIGH

- **Why:** debug-harness stall detection is our only real-time defense
  against silent subagent deaths in 12h unattended runs. Today it rescans
  full logs and can miss the "quietly spinning" pattern; delta polling makes
  stalls cheaper to detect and distinguishes "silent failure" from "quietly
  working".
- **Impact area:** harness observability only (agents don't use it directly);
  improves intervention latency, not game quality.
- **Cost:** small-medium (ring buffer + cursor param), single-file scope.

## Goal

Let a supervising agent poll for *new* runtime errors/logs since last check,
instead of rescanning the full captured output.

## Design

- Ring buffer in `mcp_bridge.gd`: entries `{seq_id, type, message}` for
  runtime errors/logs, surfaced alongside `get_debug_output` semantics
- `since` cursor parameter for incremental polling
- Prior art to cite in the issue: godot-mcp-enhanced's `since_seq`
  ring-buffer (200-entry, 4 error types)

## Benefit (ours)

MythicQuest debug-harness stall detection polls only new entries — cheaper,
and enables distinguishing "silent failure" from "quietly working".

## Maintainer-fit notes

- **Do NOT propose a new parallel tool** — the maintainer consolidates by
  outcome (`tool-authoring.md` §5); he would fold it into `get_debug_output`
  anyway. Propose it as an extension of `get_debug_output` semantics.
- Be prepared for him to restructure the approach himself mid-review
  (precedent: PR #13 port-baking refactor). Treat that as a win.
- Acknowledge attach-mode limitation openly (stdout/stderr only flow through
  MCP-spawned processes) — propose bridge-side capture as the parity story
  for attached games, which solves a documented README gap.

## Verification

- `npm run verify` + unit tests on cursor semantics (empty-poll, wrap-around,
  concurrent-frame ordering)
- Live: poll-loop during a benchmark playtest; confirm stall detector sees
  only deltas
