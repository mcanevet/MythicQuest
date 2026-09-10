# Solo Control Run: DeepDive (lumo-max / medium) — SHIPPED, single agent

**Date:** 2026-09-10, 20:36 → 22:27 CEST (~1h51m wall, one voluntary stop at 21:25 + one resume)
**Prompt:** `benchmarks/prompts/deepdive-solo-control.md` (same DeepDive 3D submarine roguelite spec as run 14's swarm arm)
**Agent:** `solo.md` (mode: primary; task: deny; no orchestrator, no subagents)
**Engine pin:** local godot-mcp-runtime checkout `repro/ext-resource-id-collision` @ `76a4196` (identical to swarm arm's pin — pre-dates PRs #38/#39/#40/#41; fairness caveat noted in the spec)
**Root session:** `ses_f73644eecffeGdbZ8LQCz0Fw32` — **1 session total, 0 subagents** (as designed)

## Status: SHIPPED — 20/20 tasks

All backlog tasks completed, runtime-verified, and archived (`.completed.md` slugs). QA battery executed in-arm: chaos gauntlet (60s, 898 inputs, 0 violations, frame p99 18ms), full-loop scenario probe (dive→death→bank→shop→re-dive→extra-life consume→zones 1→10→victory), save-across-full-process-restart round-trip, self-critique playthrough with real inputs. One real bug found and fixed during the gauntlet (mine-spike `look_at()` before tree entry).

## Head-to-head vs run 14 (swarm)

| Axis | Swarm (run 14) | Solo control | Ratio |
|---|---|---|---|
| Sessions | 49 | 1 | — |
| Tasks | 27 (16 orig + 11 QA-loop) | 20/20 first-pass | — |
| Wall-clock (active) | ~4h05m (6h55m − 2h50m sleep) | ~1h51m (+2m gap) | **~45%** |
| Input tokens | 32.1M | 16.5M | **51%** raw |
| Cache-read tokens | 37.5M | 10.0M | 27% |
| Input+cache (cache-adjusted) | 69.7M | 26.5M | **38%** |
| Output tokens | 270K | 51K | 19% |
| Tool errors | 91 | 26 (all self-recovered) | — |
| Engine cycles | 72 run/72 stop | 39 run/38 stop | — |
| Skill invocations | ~30 (115 reloads) | 6 (0 duplicate reloads) | — |

All five pre-registered predictions, graded:

1. **Solo tokens 15–30% of swarm — MISS (flew past: 38% cache-adjusted, 51% raw).** Under-predicted. Solo's single-context accumulation (no compaction, but 10M cache-read from one growing context) costs more than the 15–30% band assumed. Solo is cheaper, but far from proportional — context reuse across 20 tasks isn't free.
2. **Solo wall-clock 40–60% — GREEN.** 45% active-wall. No wedge, no orchestration overhead. The one stop-and-resume (below) cost only ~2 min.
3. **Outcome parity with ≥1 unverified coupled invariant — PARTIAL (favorable to solo).** Solo's gauntlet was genuinely strong: chaos probe at 15Hz with counter-rate invariants, exact banking math asserted, save-across-restart probed live (prediction-3's named gap — persistence probing — did NOT materialize; solo did it unprompted). Coupled-invariant coverage comparable to rachel's run-14 pass. What WAS weaker: visual verification (screenshots throttled in background mode, admitted as "probe-filled gaps") and corrupt-save tested only via code guard, not live elicitation. So: parity on the automated axis, thinner on the adversarial/exploratory axis.
4. **Dominant-strategy detection — CONFIRMED MISS, the headline result.** Solo never probed for a dominant strategy, never self-flagged one, and its honest-verdict section covers pacing but not exploitability. The swarm's balance probes (run 14, prediction 5) fired unsupervised and caught passive-dive safety issues. This is the single clearest justification for the multi-agent architecture: **critique diversity, not error-catching, is what the swarm buys.**
5. **≥1 unbounded retry loop — GREEN against the prediction (no loops occurred).** Worst single-pattern spike: 12 `run_script` errors across the whole run, each self-recovered in ≤2 attempts. The input-race debug loop (menu selection, ~8 rounds) was the closest approach to a wedge but terminated. No bail-fast rescue needed.

## The voluntary early exit (novel failure mode)

At 21:25 (task 9/20 complete, ~50 min in) the solo agent emitted a polished two-segment recap ("Tasks 8 and 9 complete and validated") and **ended its turn voluntarily** — `step-finish reason: stop`, no error, no stall. Process stayed alive 111 more minutes before the operator noticed and resumed it. Diagnosis: no orchestrator exists to re-prompt "11 tasks remain, continue"; the model chose a natural milestone to conclude. It resumed flawlessly when nudged and went on to finish 20/20. **This is a solo-mode-specific reliability hazard the swarm cannot exhibit** (the build orchestrator's stopping conditions forbid premature completion), and it means unattended solo runs need either a watchdog that re-prompts on voluntary-stop-with-open-backlog or a resumption contract. Cost of the event: 62 idle minutes; total damage contained.

## Efficiency detail (solo arm)

- **Compaction:** 2 events, negligible payload — the 10M cache-read is the price of one cumulative context, as predicted.
- **Skill hygiene:** 6 invocations, zero redundant reloads (the context-economy rule worked; swarm's 115 reloads ≈1.7MB had no analog).
- **stop_project banner echo:** 38 calls / 30 KB — proportionally identical to swarm (PR #40 upstream fix pending would trim ~75%).
- **LSP-noise on writes/edits:** 107 noise-bearing results vs swarm's 174 — lower absolute, similar per-write rate. Config-level (denied-lint-glob in opencode.jsonc), not agent-level.
- **Bash denials:** 10, all compound-command or non-allowlisted-binary shapes; every one self-recovered in the next round. The agent reverse-engineered the permission globs from denial text (see opportunities).
- **Named tool-gap surfaced honestly:** solo hit the missing `import_assets` tool in setup, correctly avoided improvising, pivoted to fully-procedural visuals (spec-sanctioned), and noted the pivot in its report. Zero BLOCKED escalations.

## Game-quality comparison (Outcome axis first)

Both arms SHIPPED a playable, verified DeepDive — but "verified" meant different things (see the operator spot-check above): the swarm's game survived human play and a consumer-critique rework cycle; the solo's passed its own probes yet a human immediately found a combat defect (jellyfish kills not landing) and a glaring visual defect (fog at density 1.0). Swarm's shipped with a rework cycle (dead pearls, HUD overflow, hollow loop found by pootie, fixed, re-verified); solo's shipped first-pass with a self-found-and-fixed `look_at` bug and candid self-critique ("steep early difficulty", "critique-lite only"). Neither arm detected the dominant-strategy bait as a vision-level issue (swarm caught adjacent issues but never issued REVISE_VISION; solo didn't engage). On the objective triad: **Outcome** — swarm clearly ahead; solo's probes gave false confidence where a player-facing critique pass would not have. **Speed** — solo 45% of swarm wall-clock. **Tokens** — solo 38% cache-adjusted / 51% raw. Solo wins speed+tokens decisively; the swarm's ~2.6× premium bought the outcome axis — the human-visible defects in the solo build are precisely what the critic loop exists to intercept.

## Improvement opportunities (in-repo)

1. **Voluntary-stop watchdog** for solo runs: the run sat idle 62 min post-completion-report before manual resume. A watcher heuristic ("step-finish reason=stop while GAME_STATE.md has unchecked tasks") enables auto-resume. Cheap, harness-side.
2. **Permission-rule preface for primary-mode agents:** solo burned 10 bash denials + explicit reasoning effort theorizing about allowlist semantics. One rule line in solo.md/poppy.md — "bash: only exact `bash ./.opencode/skills/<skill>/scripts/<name>.sh` single-command invocations; anything else is denied, don't theorize" — saves ~20 rounds/run.
3. **Playtest-skill-before-first-probe:** solo rediscovered key-event race handling from scratch (~8 rounds on menu input). A gotcha in playtest reference ("simulate_input events can race `_ready`; assert via run_script state probe after a frame wait") compresses this for any agent.
4. **(from mid-run) validate-after-logical-units** — already committed (`688aad3`); solo's 10 validate calls vs swarm's heavier pattern suggests modest effect.

## Upstream (godot-mcp-runtime)

1. **SHIPPED as PR #40** (stop_project banner condensing) — evidence doubled by this run (38 calls/30 KB).
2. **SHIPPED as PR #41** (live-session scene-edit guard) — direct product of this run's ghost-success mystery; mechanism-neutral rationale after source audit.
3. **PR #39 strengthened** with the intermittent second-occurrence comment from this run's trace.
4. **NEW, highest-severity find of the day: `Environment.set("fog_mode", …)` resets `fog_density` to 1.0** — Godot engine dependency-reset quirk; the inline-resource constructor applies dict keys in insertion order, so `{"fog_density": 0.015, ..., "fog_mode": 1}` loses the density silently. Deterministic, 3/3 repros, explains solo's persistent fog bug. Candidate fix: order-independent application (apply enum/dependency-parent properties first) or a documented constraint + validation error. Not yet filed.
5. **Attaching-to-existing-node silent-fail shape** (`Environment` sub_resource reuse observed during repro): when a scene already carries an Environment sub_resource, a newly constructed resource can share the stale sub_resource id on save. Lower confidence, needs a dedicated repro before filing.

## Post-shipment operator spot-check (2026-09-10, manual)

Operator played the shipped build by hand and found a gameplay-affecting defect the in-arm QA battery missed: **shooting a jellyfish (the zone-1 enemy) produced no visible effect — torpedoes do not kill jellyfish in normal play.** The solo arm's verification was probe-driven (state assertions, programmatic scenario probes, chaos bots asserting counters), and none of those probes exercised live "press fire → hit enemy → enemy dies" as a player experiences it; its "self-critique playthrough with real inputs" covered only navigation and death, not combat effectiveness. This is exactly the class of gap the swarm arm's consumer-critique loop (pootie) existed to catch — see also the input-race finding in the trace analysis. The fog_density=1.0 visual defect (fog heavy/thick instead of subtle — from the engine quirk documented in docs/upstream-backlog.md) is likewise visible to any human player but was invisible to counter/state-based probes and to background-throttled screenshots.

**Correction to the outcome-axis verdict below:** outcome is NOT at parity. The swarm shipped a game that survived human play; the solo shipped a game that passed its own instruments. Quality difference is real, demonstrated by the operator, and attributable to critique methodology (human-analog play vs state probes), not model capability.

The solo arm is viable and dramatically cheaper/faster — but the operator spot-check overturns the outcome-parity reading: its instrument-based QA shipped a game a human found broken on first contact (jellyfish combat dead, fog blinding). Its marginal risks are exactly where predicted — adversarial critique depth and voluntary-stop reliability — and the critique gap turned out to matter far more than the trace analysis alone suggested. The multi-agent architecture's demonstrable value is the critic loop, which the token budget prices at ~2.6× — and the operator evidence says that premium is buying real quality, not ceremony.
