# Run 14: DeepDive E2E — SHIPPED (lumo-max / medium; first scale/systems-coupling + persistence stress run)

**Status: SHIPPED — 27/27 tasks (16 original + 5 vision-fix + 5 critique-rework + 1 post-vision pearl-cull fix), 0 blocked, 0 harness interventions.** Full pipeline including the disposition loop's first live traversal of every path: ian genesis → 21 dev/QA/milestone sessions → rachel functional QA **PASS, 0 violations** (incl. save/load across a full engine-process restart) → ian vision ALIGNED → pootie consumer critique **RECOMMEND_REWORK, 1.5/2 B-holes** (dead pearls, HUD off-screen, hollow loop) → poppy rework batch → rachel post-fix smoke **PASS** → pootie replay **RECOMMEND_SHIP, 1.9/2 B-holes** → **ian CONFIRM_SHIP**. Root `ses_f788b7cc7ffeSRdcYkgYCQvf3p` ("clever-planet"), 2026-09-09 18:35 → 09-10 01:30 UTC (~6h55m wall, ~2h50m of it host sleep — root resumed cleanly after an overnight gap). **49 sessions** (1 root + 28 poppy + 11 rachel + 7 ian + 2 pootie).

Prompt: `benchmarks/prompts/deepdive.md` (3D submarine roguelite, ~40 planned tasks collapsed to 16 by genesis; 4 coupled systems, save-across-restart, dominant-strategy bait).

## Prediction scorecard (the 8 pre-registered in deepdive.md)

1. **Task-graph scale (>30 tasks degrade continuity): RED (wrong, favorably).** Genesis consolidated the ~40-task prompt into 16 well-scoped tasks; worst-case simultaneous incomplete backlog stayed ≤ 3. No drift/rework from stale task state; one subagent death (task 10) auto-recovered by root without intervention. The "~30 task" worry never materialized because genesis is a compression step, not a pass-through — prediction modeled the wrong variable (prompt tasks, not backlog tasks).
2. **Persistence probe shape (in-session run_script first, second QA pass needed): RED (wrong, favorably).** Rachel verified save/load across a **full engine-process restart** (stop_project/run_project cycle) in the FIRST final-QA pass, organically discovering the pattern with no skill rule prompting it. The predicted skill gap (persistence probe pattern) didn't bite; candidate: still codify the restart-round-trip pattern as a playtest reference example (cheap, prevents regression on other models).
3. **Invariant explosion (scenario JSON 3–4x, ≥1 interaction unverified in QA pass 1): PARTIAL GREEN.** Scenario coverage did scale (magnet×pearl-drift, shield×contact, upgrade-interaction probes all present in final QA), and the first-critique rework was dominated by *integration* bugs (signal wiring, collision-mask mismatch) rather than unverified invariants. But none were interaction-invariants that QA missed — rachel's final pass found them. Grades GREEN on outcome, RED on mechanism (bugs escaped via build errors, not invariant gaps).
4. **Token economy (root > 12M input, or > 15M = guidance needs teeth): GREEN.** Root landed ~2.0M input+cache with verdict-only task returns held throughout — the report-economy discipline was load-bearing at 2x task count, exactly what the prediction said had never been tested. Tree total 32.1M input + 37.5M cache-read (largest subagent session 5.0M — a 10-edit implementation+probe marathon, see Finding 2).
5. **REVISE_VISION trigger (dominant strategy → ambiguous disposition): GREEN on detection, RED on disposition flavor.** The balance probes fired exactly as designed (poppy probed zone-scaled aggression, passive-dive-with-upgrade-load, re-hit cooldowns — unsupervised). Pootie's round-1 RECOMMEND_REWORK cited real dominant-strategy-adjacent issues (passive safety early, hollow loop). But ian resolved ambiguity toward **ORDER_REWORK/CONFIRM_SHIP with "post-launch tuning" notes** — no REVISE_VISION issued. The disposition authority worked; the REVISE_VISION path remains untested live. Need a stronger vision-vs-tuning conflict in a future prompt (e.g., a core fantasy the mechanics actively betray).
6. **Save-file formats (hand-rolled JSON via FileAccess, atomic-write risk): GREEN.** Hand-rolled JSON confirmed; one atomic-write-adjacent bug observed (a `maxi(int(...)` typo in save_manager.gd that poppy's `sed` attempt to fix was correctly denied — worked around with the edit tool). No corruption observed.
7. **Gate cascade ≥1 full re-run, watch 40% threshold: GREEN.** Exactly 1 full consumer rework cycle; gate re-runs (post-fix smoke + vision-qa-final + critique-replay) were delta-shaped, not full-gate. Wall-clock was dominated by building (28 dev sessions), not gate repetition.
8. **3D-under-scale regressions (camera occlusion / collision complexity / zone seams): GREEN-shaped but wrong class.** No camera/collision/seam 3D failures. The actual scale-shaped failures were all *systems-integration* bugs (see Finding 1) — the coupled-systems stress did bend, just not in the 3D dimension predicted.

Score: 4 GREEN / 2 PARTIAL / 2 RED-all-favorable. No prediction flagged a risk that materialized as harm; the run's real defects (integration bugs escaping to critique) were caught by the pipeline as built.

## Finding 1: the pipeline caught what mattered (outcome-axis evidence)

Five real bugs surfaced by QA/critique loops, all fixed, all would have shipped silently in a one-shot build: missing `Submarine.died/won` signal wiring (blocker — end screens never fired), HullSensor collision-mask mismatch silently disabling all contact damage, pearl-despawn sign inversion starving the economy, HUD anchored off-screen, pearls swept by the zone cull. Frame p99 18–22 ms throughout — performance budget held at scale in 3D.

## Finding 2: cost anatomy (efficiency-axis evidence; feeds the solo control run)

Tree totals: **32.1M input + 37.5M cache-read + 270K output; 49 sessions; ~1,584 tool calls.** Waste classes quantified from traces:
- **Skill-reload churn: 115 `skill()` injections ≈ 1.7 MB** — the same 5–6 SKILL.mds reloaded per session (playtest ×18, backlog-grooming ×15, create-scene-with-script ×14, log-result ×13). Biggest single lever for the solo arm's 15–30%-of-swarm prediction.
- **Stale-LSP noise: 174 tool results carried "LSP errors detected"** (across ~460 writes/edits) — nearly 40%; the root's literal final message before declaring completion was dismissing them. Fix committed mid-analysis (poppy context-economy rule, commit b8b93e3) — applies to run 15+, NOT this run.
- **Plan-template re-read: 28.7 KB re-read in every grooming session** — trim candidate.
- **stop_project banner echo: 72 calls ≈ 80 KB** — upstream backlog entry logged (commit b8b93e3).
- **91 tool errors across the tree** — all self-recovered except one subagent death (root respawned task 10 cleanly).
- **`render_report.py` permission denials (2)** — our config lag (bash allowlist matched only `.sh`), NOT agent misuse; fixed in commit c49849f. Recorded as an incident class: **skill ships new sanctioned artifact → permission glob must track script types** (lint-worthy pattern for future skill additions).

## Finding 3: no background-mode visual-verification incidents

Run 13's weakness cluster (stale captures, narration-fiction, idle-frame aliasing) did NOT recur: programmatic text sampling carried vision/critique evidence, screenshots were corroborative. The 2026-09-09 playtest-skill rules held under 2x scale. (Upstream repro experiments for the underlying wait-semantics questions remain parked in `docs/upstream-backlog.md`.)

## Objective Triad

1. **Outcome: PASS** — shipped, verified end-to-end incl. process-restart persistence; vision ALIGNED (escalating pressure: safe zone 1 → lethal zone 7 verified programmatically); consumer 1.9/2 after one honest rework cycle; zero harness interventions.
2. **Speed:** ~6h55m wall, ~4h05m effective (≈2h50m host sleep overnight — caffeinate was NOT running this session; the watcher correctly distinguished it, and the run self-resumed). Longest productive subagent session ~35m; no wedges, no timeout ladders.
3. **Tokens:** 32.1M input + 37.5M cache — ~2.6x run 12's total at ~2x task count, linear scaling, within prediction. Root economy discipline held. Waste classes above are the actionable deltas.

## Follow-ups harvested

- Solo control run (benchmarks/prompts/deepdive-solo-control.md) now unblocked — run at commit `aeee2be` (this run's starting commit) for harness-parity.
- Poppy context-economy rules (b8b93e3) and `.py` permission fix (c49849f) land for run 15+; grade their effect as a run-15 prediction if desired.
- Skill-sizing pass: plan-template trim + SKILL.md-to-reference rebalance, sized from the 1.7 MB churn number above.
- REVISE_VISION remains untested live — design the next stress prompt around a vision/mechanics betrayal, not a balance gradient.
