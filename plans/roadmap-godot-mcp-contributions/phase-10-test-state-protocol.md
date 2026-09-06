# Phase 10 — Issue: Game-Object Test-State Protocol (`get_test_state` convention)

Kind: issue-first discussion, likely convention/doc + minor bridge support ·
Status: exploratory — new concept discovered 2026-09-05

## Importance to us: MEDIUM (architectural leverage, not urgent pain)

- **Why:** every game the swarm builds must expose agent-verifiable state
  for QA. Today each game-build session invents this ad hoc: the trace shows
  per-game `get_test_state()` dictionaries hand-designed per node (Ball,
  GameCoordinator, VisualPolish each grew bespoke fields like `speed`,
  `game_over`, `color_tier`, `vertical_fraction`), plus ad-hoc harness
  autoloads (`TestPlayer`) with per-game scenario schemas. It works — the
  agent population converged on it independently — but it's reinvented
  every session and inconsistently shaped (numbers vs vectors vs enums).
- **Impact area:** every downstream phase consumes it: Phase 3's
  `step_until(path, property, op, value)` needs uniform property access;
  Phase 4's degenerate detection cross-checks game-stated state vs pixels;
  Phase 5's QA suite grammar keys off it. A *convention* here multiplies
  everything above it.
- **What it is NOT:** a test framework (Phase 5 stays harness-side); a
  mandatory protocol (games opt in). It's a **discovered emergent pattern
  from our own traces** — the strongest possible evidence for proposing a
  convention.

## What the trace shows (the discovery)

The GLM-run agents spontaneously converged on this pattern without being
told:

- game scripts expose `get_test_state() -> Dictionary` with plain-typed
  scalar/vector fields, recomputed on demand (not latched)
- TestPlayer autoload translates declarative scenario JSON into a bot +
  invariant checker reading those states per physics tick
- probes (run_script) read the same fields for mechanic verification

This IS the missing "concept" the whole ecosystem papers over: a
**standardized observable-state surface for agent-facing games** — the
Godot-agent equivalent of a Page Object / accessibility tree. Enhanced's
property-snapshot determinism and satelliteoflove's digests are the same
idea, implicit.

## Proposal (two tiers)

1. **Convention tier (issue text, docs only):** a documented recipe —
   "expose `get_test_state()` returning flat primitives; document it in
   your game's README for agent consumption". Survives even if nothing
   upstream adopts it.
2. **Support tier (small, only if maintainer bites):** `run_script` sugar
   for batch-reading test state across a node list in one call
   (`get_test_states([paths])` → single dictionary), since the trace shows
   agents hand-writing 3-4 node fetches per probe. Watch the tool-count
   budget — could be an option on an existing read tool instead.

## Maintainer-fit notes

- Risk of "not a playtesting replacement" scope collision is low IF framed
  as a *convention for game authors*, not testing infrastructure
- The maintainer's docs (`docs/tool-authoring.md`, README recipes)
  are the natural home for a convention page — docs-only contribution is
  the cheapest possible ask
- Our evidence (agents converged on this unprompted across 17 subagent
  sessions) is genuinely novel input for the issue discussion

## Verification

- Skill-side first: codify the convention in `skills/playtest` reference
  docs + `setup-project`'s test_player.gd template, measure across next
  benchmark run whether probe-script authoring gets shorter (token cost
  per probe is measurable in the session DB)
- Only propose upstream once we have that second-run evidence
