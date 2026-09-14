# BrickFall — lumo-max — Instancing Stress + Lease Stack (Run 16)

**Date:** 2026-09-13/14
**Model:** proton-lumo/lumo-max (build agent)
**Prompt:** `benchmarks/prompts/brickfall.md` (instancing coverage variant)
**Sandbox:** `test/` at harness `ba214b8f`
**Stack under test:** direct bd (v1.3.0-rc.2 with leases/heartbeat/reclaim), game-four-loops formula, trimmed build.md

## Objective Triad

| Axis | Result |
|------|--------|
| **1. Outcome** | ✅ SHIPPED — BrickFall breakout, QA gauntlet 0 violations, vision ALIGNED, consumer RECOMMEND_SHIP (2.5 B-holes), manually re-verified live (grid renders, serve → paddle → brick → score works) |
| **2. Speed** | ~7h wall clock (larger backlog + 3 rework cycles + 3 respawn recoveries); no stalls, no human intervention |
| **3. Token efficiency** | 31 beads total; batching held throughout; report-return convention held (40+ reports kept out of root context) |

## Coverage Goals — Achieved

1. **Repeated-node instancing** ✅ — 12×5 brick grid via `brick_grid.gd` scene instancing (preload flagged by security scanner, benign); 21 bricks destroyed via real collisions in QA
2. **Adaptive milestone cadence** ✅ — 18-bead backlog fired milestone smoke at task 7 (≥7 cross-refs → every-3 would be aggressive; agent chose 7 and tracked an interim violation to closure), vision checkpoint at half cadence: ALIGNED
3. **Lease stack (bd v1.3.0-rc.2)** ✅ — no dead-worker lockups; `bd reclaim` incorporated at Step 0

## Behaviors Validated

- **Hallucinated-path permission rejection auto-recovered**: a poppy session attempted access to a garbage external directory (`PhyunchickengheMythiidoiu/...`); auto-reject fired and the retry delegation succeeded on first respawn
- **Silent subagent death recovered**: "Mid-investigation death, no fix landed. Respawning with the leading hypothesis" — the completion-run respawn protocol from build.md worked as written (3 total recoveries)
- **Three consumer rework cycles, correctly classified**: cycles 1–2 were feature/juice rework; cycle 3 (win→restart race under rapid clicks) was treated as *bug-fix work, not taste divergence* — the taste-divergence escalation did NOT fire because the final critique was RECOMMEND_SHIP. Cap discipline intact
- **Idempotent restart fix**: change_scene_to_file + one-shot flag + button-disable — engineering quality held under rework pressure
- **Incremental QA re-runs**: round 4 re-verified only the win-restart path + regression scenario rather than a full sweep (token economy rule held)

## Incidents / Observations

- One transient tool crash mid-run (ball-physics batch) — retry delegation recovered; no manual intervention
- The rework-cycle accounting exceeded the nominal cap of 2 but the formula's intent (escalate on *taste* divergence) was honored: cycle 3 was bug-class, and the run shipped

## Conclusion

Run 16 closes both flagged coverage gaps (instancing, larger-backlog cadence) and gives the bd v1.3.0-rc.2 lease stack its first full-run validation. The direct-bd + formula architecture has now shipped two consecutive benchmarks (Run 15 pong, Run 16 brickfall) with zero human interventions.
