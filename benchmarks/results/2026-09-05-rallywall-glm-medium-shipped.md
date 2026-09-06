# Run 7: RallyWall E2E — SHIPPED (GLM 5.3 native-high reasoning: quality parity with qwen-medium at 3× wall clock) (2026-09-05 08:40 → 13:49)

**Harness revision**: `f8126b7` (run-6 harness + TEMPORARY godot-mcp-runtime pin to local `combined/mythicquest-integration` @1479a2f: progress heartbeats + property type-validation).
**Prompt**: `benchmarks/prompts/rallywall.md` (verbatim).
**Model**: GLM 5.3 (lumo-max), requested reasoning effort **medium** — 7th data point; cross-family comparison against run 6 (qwen 3.8 27B / medium).

**Correction (2026-09-06, discovered reading the Lumo backend config):** the Lumo scheduler folds requested "medium" onto GLM 5.3's native **high** tier (GLM has no medium; low|high|max only — glm53.rs). This run therefore measured **GLM at native high** against **qwen at native medium**, i.e. best-vs-stronger. The parity conclusion below survives with this framing: GLM matching qwen's quality while reasoning one tier hotter strengthens the "qwen is more token-efficient per reasoning level" reading, but the runs are NOT effort-matched as originally claimed.
**Host**: no host-sleep gaps; wall-clock clean.

## Executive Summary

**Status: SHIPPED — 16/16 tasks, zero human interventions, one critique cycle (REWORK on a real bug → fix → SHIP).** Functional QA PASS with zero invariant violations, vision QA HIGH, consumer critique caught a genuine defect (WinScreen labels at negative coordinates clipping the victory screen), fix verified to the pixel, re-check SHIP.

This was billed as a matched-effort comparison; in fact it is GLM-high vs qwen-medium. Result: **quality and token parity, latency 3× worse** (5h09m vs 1h43m at the same 12.5–12.6M input budget).

The pinned integration runtime (@1479a2f) held across the whole run: QA phases ran repeated long `run_script` simulations (60s+) with **zero MCP client timeouts** — the progress-heartbeat fix exercised under real 5-hour load.

## Raw Metrics

### Time (total 5h09m — vs 1h43m run 6)

| Segment | Span | Dur | Notes |
|---|---|---|---|
| Genesis (ian) | 08:40 → 08:41 | 1 min | 15 tasks, 3 phases |
| Setup + tasks 1–4 (poppy ×4) | 08:41 → 09:00 | 19 min | fast start |
| Tasks 5–7 (poppy ×3) | 09:00 → 10:10 | 70 min | pursuit-bot QA adaptation; milestone smoke test @ task 7 PASS |
| Tasks 8–11 (poppy ×3) | 10:10 → 11:13 | 63 min | |
| Tasks 10–12 (poppy ×2) | 10:53 → 12:00 | 67 min | milestone smoke test @ task 12 PASS (p99 18ms) |
| Tasks 12–15 (poppy ×6) | 12:00 → 13:22 | 82 min | incl. functional QA gauntlet (1.3M-token session) |
| Vision QA (poppy → ian-class work) | 13:11 → 13:22 | 11 min | HIGH — tension/earned-win/style verified |
| Critique 1 (pootie) | 13:26 → 13:35 | 9 min | **REWORK** — win-screen label clipping |
| Fix (poppy) | 13:36 → 13:42 | 6 min | center anchors; label verified at exact (480,270) |
| Critique 2 (pootie) | 13:43 → 13:48 | 6 min | SHIP |

### Sessions (23 subagents: 19 poppy, 1 ian, 3 pootie; root included below)

| Session | Agent | Role | Dur | Input |
|---|---|---|---|---|
| vSV8ic | ian | genesis | 1m | 56k |
| jGAW0S | poppy | setup | 2m | 163k |
| VWVmeZ…MBj2QT | poppy | tasks 1–6 + QA | 8–45m each | 272k–1057k |
| 09WJ0X | poppy | tasks 12-ish | 16m | 1,057k |
| kAR9F0 | poppy | task 13 QA | 31m | 627k |
| KLkxtX | poppy | functional QA gauntlet | 32m | **1,321k** |
| zkEtjr | poppy | QA/README | 19m | 590k |
| 5q39nV | pootie | critique 1 | 9m | 270k |
| xZaciy | poppy | win-screen fix | 6m | 518k |
| euBtMe | pootie | critique re-check | 6m | 130k |

### Tokens (whole run)

- **Input: 12.59M** — statistically identical to run 6's 12.48M despite 3× the wall clock (GLM steps are slower, not more numerous).
- **Output: 152k** (vs 191k run 6).

### Outcome axis

- **Invariant violations: 0** (functional QA gauntlet, all mechanics PASS; numeric ramp 1.05ⁿ exact).
- **Two milestone smoke tests** (tasks 7 and 12) — extra checkpoint discipline neither qwen run performed.
- **One real bug found and fixed**: win-screen labels at negative coordinates (TitleLabel −200,−40 etc.) → center anchors → `FinalScoreLabel` verified centered at exactly (480,270), all labels `fully_on_screen: true`.
- **Adaptive testing**: poppy noticed chaos-input runs yielded zero collision coverage (ball flew out open bottom pre-restart) and switched to a pursuit bot unprompted.
- **Honest hygiene note**: flagged an unused scratch file in `/private/tmp/opencode/` it couldn't remove under sandbox rules — accurate self-report, no evasion.

## Comparison Table (GLM native-high vs qwen native-medium)

| Metric | Run 6: qwen 3.8 27B (native medium) | Run 7: GLM 5.3 (native high) |
|---|---|---|
| Outcome | SHIP | SHIP |
| Tasks | 12 | 16 (finer decomposition) |
| Critique cycles | 1 (0 REWORK) | 2 (1 REWORK, real bug) |
| Gauntlet violations | 0 | 0 |
| Input tokens | 12.48M | 12.59M |
| Output tokens | 191k | 152k |
| Wall clock | **1h43m** | 5h09m |
| Retries/respawns | 2 silent-death respawns | 1 mid-stream death, resumed from plan file |
| Extra discipline | — | 2 milestone smoke tests |

**Cross-family conclusion (revised):** GLM 5.3 at native **high** delivered qwen-medium-grade quality (both zero-violation SHIPs) at identical token cost but ~3× the wall clock — i.e. GLM spent one more reasoning tier to merely match. A true effort-matched comparison would be GLM at native **low** (its weakest tier) vs qwen medium; untested. Token-per-outcome is the wrong cost lens for latency-sensitive benchmarking; GLM's finer task decomposition (16 vs 12) didn't add cost. Neither family dominated — GLM's critique caught a subtler bug (negative-coordinate labels) than run 6's single cosmetic flag, but also needed the extra cycle to find it.

## Series Table (updated)

| Run | Model / reasoning | Result | Cycles | Tokens | Wall |
|---|---|---|---|---|---|
| 1 (09-02) | frontier max tier | SHIPPED (nudges) | — | — | — |
| 3 (09-03) | nemotron (floor) | BLOCKED early | — | — | — |
| 4 (09-04) | ling flash | SHIPPED (nudges) | — | 1.85M | — |
| 5 (09-04) | qwen 27B / none | SHIPPED | 5 (4 REWORK) | 17.6M | 2h51m |
| 6 (09-05) | qwen 27B / medium | SHIPPED | 1 (0 REWORK) | 12.5M | 1h43m |
| **7 (09-05)** | **GLM 5.3 / req. medium → native high** | **SHIP** | **2 (1 REWORK)** | **12.6M** | **5h09m** |

## Incidents

1. **One delegation death (task 13), clean resume.** Poppy session died mid-stream; orchestrator respawned, poppy found the already-claimed plan file, resumed, and passed. No lost work. Total interruptions for the run: 1 (vs run 6's 2 respawns).
2. **Scratch-file hygiene flag** — run left `/private/tmp/opencode/qa_runner.gd` (outside the project) and honestly reported it couldn't remove it. No action needed; noted for sandbox cleanliness only.

## Infrastructure Note

First benchmark run on the TEMPORARY local pin (`opencode.jsonc` → `combined/mythicquest-integration` @1479a2f): progress heartbeats eliminated the long-tool-call timeout class entirely under 5h of sustained QA load, and the type-validation path saw no silent drops (every reported property write landed). No reason to revert until upstream releases; keep watching `docs/upstream-backlog.md` lifecycle entries.

## Next Steps

- The effort curve on qwen remains half-characterized (none → medium tested; high untested). If the goal is finding the effort ceiling, qwen/high is the cheap next run.
- GLM at high effort only if the goal becomes maximizing single-run quality regardless of latency — the 3× wall-clock penalty suggests diminishing returns for benchmark throughput.
