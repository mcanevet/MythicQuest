# Run 3: RallyWall E2E — BLOCKED, below supported model floor (2026-09-03 18:32 → 22:18 UTC)

**Harness revision**: `8a50f0f` at run start; three fixes landed **mid-run** from live diagnostics (`0439325`, `7b702f2`, `07188ec` — see Outcomes).
**Prompt**: `benchmarks/prompts/rallywall.md` (verbatim).
**Model**: nemotron-3.5-lightning (free tier) — the experiment variable. Prior runs used frontier-max-class.
**Host hygiene**: `caffeinate -dimsu` active for the entire run; zero host-sleep gaps (confirmed via subagent span continuity — the 09-02 overnight stalls did not recur).

## Executive Summary

**Status: BLOCKED at Task 2 of 16, after ~1h45m and 6 poppy delegations for a single task.** The run consumed its retry budget informally (no `attempt:` markers ever written), discovered a shipped harness bug (non-parsing `test_player.gd`), patched the consumer copy incorrectly (silently disabling invariant coverage), and finished in a blocked/stalled state without completing even the paddle task.

**Verdict: nemotron-3.5-lightning is below the harness's supported model floor.** Recorded as the lower-bound calibration point. The run nonetheless delivered high diagnostic value: three harness defects found and fixed live, each traceable to specific reasoning-log evidence.

## Raw Metrics

### Time

| Session | Agent | Span (local) | Parts | Role |
|---|---|---|---|---|
| root | build | 20:32:03 → 22:18:34 | 117 | orchestration, retries |
| genesis | ian | 20:32:56 → 20:36:17 (3.4 min) | 40 | GAME_STATE + 16-task backlog |
| poppy 1 | poppy | 20:36:32 → 20:43:18 (6.8 min) | 87 | Task 1: project setup — **complete** |
| poppy 2 | poppy | 20:44:10 → 20:46:52 (2.7 min) | 70 | Task 1 log-result validation |
| poppy 3 | poppy | 21:00:36 → 21:24:34 (24 min) | 131 | Task 2: paddle — **timed out** mid-implementation |
| poppy 4 | poppy | 21:37:57 → 21:46:14 (8.3 min) | 13 | Task 2 retry: backlog-grooming only — **timed out** |
| poppy 5 | poppy | 21:48:51 → 21:54:19 (5.5 min) | 108 | Task 2: paddle.gd written, scene validated OK |
| poppy 6 | poppy | 21:56:48 → 22:14:36 (18 min) | 165 | Task 2 playtest: debugged shipped `test_player.gd` parse bug, hit stale-bytecode confusion loop, stopped engine, then silent |

Note 13-min root stall 21:24→21:37 between poppy 3's timeout and the retry (model-side step latency on free tier; step-starts observed spaced 2+ min during throttle windows, vs 5–10 s normally).

### Tokens (assistant-message aggregation, full tree, 291 messages)

| Agent | Sessions | Input | Cache-read | Output |
|---|---|---|---|---|
| build (root) | 1 | 302k | 231k | 3.3k |
| ian | 1 | 43k | 91k | 1.5k |
| poppy | 6 | 887k | 3.37M | 18.9k |
| **Total** | **8** | **1.23M** | **3.70M** | **23.6k** |

For 1/16 tasks. Compare Run 2 (frontier-max-class): **9.43M input / 113k output for 14/14 tasks**. Extrapolating linearly (~19x multiplier on both): ≈ 23M input / 450k output — an underestimate, since task difficulty grows and retry churn compounds. The 5-session Task-2 arc alone mirrored Run 2's *worst* task.

### Reliability

| Metric | Run 2 (frontier-max-class) | Run 3 (nemotron) |
|---|---|---|
| Tasks completed | 14/14 + QA | 1/16, Task 2 unfinished |
| Subagent timeouts | 0 fatal | 3 (poppy 3, 4, and silent death of 6) |
| Retries with attempt-markers written | n/a (few retries) | 0 of ~4 — circuit breaker blind |
| Harness bugs exposed | 0 new | **3 new** (all fixed live) |
| Format drift (spec violations) | 0 | 2 (backlog format, retry-marker omission) |

## Failure Anatomy (reasoning-log evidence)

1. **Timeout cascade on Task 2.** Poppy 3 built `paddle.tscn` (131 parts of valid work) then hit the subagent wall with no result reaching root. Root's improvised ladder (full chain → split grooming-only → fresh implement) is good instinct but wrote no `(attempt: N)` markers — the 3-retry circuit breaker never engaged.
2. **Repeated greenfield rebuilds.** Each retry rebuilt paddle work from scratch; poppy 3's validated `paddle.tscn` was inherited only by coincidence of filename, not by design. No mechanism surfaces prior-attempt artifacts in retry briefs.
3. **Shipped-bug discovery tax.** Poppy 6's playtest exposed that `skills/setup-project/scripts/test_player.gd` did not parse (duplicate `var pos` across if/elif sibling scopes, latent since `206e32a`). The model diagnosed it correctly from raw debug output — credit where due — then produced a *compounded* fix: nesting the 3D elif and the child-recursion loop inside the 2D NaN-check branch, silently disabling NaN/Inf invariant coverage for all non-root nodes.
4. **Stale-bytecode confusion loop.** After its edit, the running engine kept serving cached script errors at phantom line numbers; poppy spent 5+ steps on "is there another duplicate I missed" before correctly hypothesizing cache staleness and executing the sanctioned stop/restart. Nothing in the skills warned that script edits under a live engine require a restart.
5. **Format drift.** Ian's genesis emitted a bare backlog without `Task N:` prefixes, breaking log-result's validator (fail-on-complete despite correct work) and sending poppy 2 into a bash-denied probing spiral before working around by declaration.

## Outcomes (fixes landed mid-run, all lint-clean)

| Commit | Fix |
|---|---|
| `0439325` | `validate.sh` tolerates format drift (matches numbered variants; WARN fallback on "≥1 [x], 0 in-progress"); genesis documents backlog format as load-bearing |
| `7b702f2` | Canonical `test_player.gd` parse fix (rename 3D-branch vars, preserve sibling structure + function-level recursion); verified `--check-only` |
| `07188ec` | `lint_skills.sh` check 10: headless GDScript parse of all `skills/*/scripts/*.gd`, gated on SCRIPT ERROR output (godot exit codes lie — returns 0 on parse failure) |
| (uncommitted at run start, later amended) | build.md retry ladder: attempt-markers mandatory on timeout retries; mandatory reuse of prior-attempt artifacts in retry briefs |

## Analysis

- **Per-session boot cost is down** (~123k input median vs ~550k in Run 2) — the 8a50f0f token-economy work (slim skills, report pointers, short briefs) is measurably effective. But cache-read dominates 3:1 and step-count roughly doubled: cheaper tokens, more of them, and wall-clock per task exploded.
- **The model's failure profile:** correct protocol adherence, competent tool use, genuinely good raw-error diagnosis — but cannot sustain multi-step chains (131 parts for a task frontier-max-class finished in ~40), violates format specs under ambiguity, and recovers from self-inflicted compounding fixes badly.
- **Where the harness held up:** permission boundaries contained probing without damage; root never recursed into doing work itself; the sanctioned-path doctrine survived — no shadow infrastructure was created even under timeout pressure.
- **Where the harness needs no change:** timeout-splitting and resume mechanisms tuned for this model would be optimizing below the floor. The floor is now documented; the harness targets mid-tier and up.

## Recommendation

Treat Run 3 as the calibrated lower bound. Next benchmark: frontier-max-class on the post-fix harness (regression check for `0439325`/`7b702f2`/`07188ec`), and ideally a mid-tier model to map the middle of the curve. `test/` to be reset to committed files before either run.

---

*Report generated 2026-09-03 from opencode SQLite session DB (`ses_f97752d24ffemQRnkFAzamdXrm` + 7 children) and reasoning-trace analysis.*
