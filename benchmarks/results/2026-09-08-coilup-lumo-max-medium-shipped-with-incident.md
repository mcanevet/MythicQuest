# Run 10: CoilUp E2E — SHIPPED WITH MAJOR INCIDENT (lumo-max / medium; first tick-driven genre; 5-hour bridge-wedge marathon dominates the time axis; three permission-system bugs found and fixed mid-series)

**Harness revision**: `2c67128` lineage (permission reorder + bare-pattern fixes applied *during* this run's three launch attempts). Sandbox `test/.opencode/opencode.jsonc` fork-pinned to the combined branch `feat/import-assets-plus-noise-masking` @ `d713a43` dist (import_assets + noise-masking; unpushed).
**Prompt**: `benchmarks/prompts/coilup.md` (verbatim) — first non-physics, tick-driven/grid profile in the series.
**Model**: lumo-max (proton-lumo), medium reasoning, uniform across root + all 14 subagents.
**Series context**: runs 1–9 were physics/paddle games (RallyWall profile). This run tests genre-agnosticism of the TestPlayer/chauntlet stack on a turn-tick grid game.

## Executive Summary

**Status: SHIPPED — 16/16 tasks, 0 blocked. Functional QA PASS (0 violations, 14 spec mechanics), vision QA HIGH, consumer critique SHIP.** But the Objective Triad takes a severe Speed hit: **7h05m wall clock, 70% of which was a single wedged subagent** (poppy tasks 6–7, `ses_f822ede7`), and the run required **three aborted launch attempts** before permissions worked.

Three distinct pre-game permission bugs were diagnosed and fixed live across the three attempts (the "three launches" story is itself a finding — see Permission Saga). Within the game build proper, throughput was excellent: ~10 min per 2-task batch, disciplined delegation, honest gotcha reporting, self-caught gameplay bugs (pellet-as-lethal-cell, win/lose screen overlap, deferred-shrink restart freeze).

The dominant incident: after a *successful* first scene-verify, the MCP bridge wedged — trivial `run_script` probes (`return {"ok": true}`) timed out while `get_debug_output` kept working (engine alive, logs clean) **across 18 stop/run engine cycles**. The subagent diagnosed it correctly within 7 minutes, then ignored its own bounded-work rule for 4.5 hours (70 run_script calls, 68 timeouts, ~3.5h of that literally waiting for timeouts to expire, including 17× 600s ladders). It self-recovered at 04:33 by finally honoring the max-3 rule. Root sat blocked on the `task()` the entire time — no visibility, no intervention. A later session (tasks 12–13) hit the same wedge class and escaped in ~6 minutes via TestPlayer-autoload removal + restart, proving the recovery knowledge existed but wasn't portable.

**Genre-agnosticism verdict: PASS.** The TestPlayer/scenario/chauntlet stack ran a tick-driven grid game with zero genre violations observed — bot input, invariant checking, and frame-time metrics all worked unmodified on non-physics mechanics.

## Raw Metrics

### Time (total 7h05m; root 23:15 → 06:20)

| Segment | Span | Dur | Notes |
|---|---|---|---|
| Genesis (ian) | 23:15 → 23:17 | ~1m | clean, both writes succeeded |
| Setup-project (poppy) | 23:17 → 23:19 | 3m | grep 64KB record noise ×2 |
| Tasks 2–3 (poppy) | 23:20 → 23:28 | 8m | one add_node missing projectPath |
| Tasks 4–5 (poppy) | 23:28 → 23:41 | 13m | 0 errors |
| **Tasks 6–7 (poppy)** | **23:41 → 04:38** | **4h58m** | **the marathon: 70 errors, bridge wedge** |
| Tasks 8–9 (poppy) | 04:38 → 04:53 | 14m | |
| Tasks 10–11 (poppy) | 04:53 → 04:59 | 6m | |
| Tasks 12–13 (poppy) | 04:59 → 05:31 | 32m | 13 errors: mini-wedge, escaped in minutes |
| Tasks 14–15 (poppy) | 05:31 → 05:37 | 6m | |
| Task 16 QA gauntlet (poppy) | 05:37 → 06:01 | 24m | PASS, 0 violations |
| Functional QA (poppy) | 06:01 → 06:10 | 10m | PASS, 0 violations |
| Vision QA (ian) | 06:10 → 06:16 | 5m | HIGH |
| Consumer critique (pootie) | 06:16 → 06:19 | 4m | SHIP |
| Root wrap-up → COMPLETION_REPORT | 06:19 → 06:20 | 1m | report written; critique write denied |

### Sessions (14 subagents + root; 11.94M input total, 94.9k output)

| Session | Agent | Parts | Errs | Input | Wall | Notes |
|---|---|---|---|---|---|---|
| f8245cb8 | ian | 18 | 0 | 0.05M | 1m | genesis |
| f8244d32 | poppy | 96 | 2 | 0.34M | 3m | setup |
| f8242221 | poppy | 281 | 1 | 0.78M | 9m | tasks 2–3 |
| f823a50d | poppy | 264 | 0 | 1.0M | 13m | tasks 4–5 |
| **f822ede7** | **poppy** | **621** | **70** | **5.6M** | **4h58m** | **tasks 6–7 marathon — 47% of run input** |
| f811e3dd | poppy | 347 | 1 | 0.50M | 14m | tasks 8–9 |
| f811163b | poppy | 164 | 0 | 0.25M | 6m | tasks 10–11 |
| f810b746 | poppy | 468 | 13 | 1.4M | 32m | tasks 12–13; mini-wedge, fast escape |
| f80edefc | poppy | 187 | 1 | 0.41M | 6m | tasks 14–15 |
| f80e8af3 | poppy | 234 | 1 | 0.74M | 24m | QA gauntlet |
| f80d2a71 | poppy | 114 | 2 | 0.19M | 10m | functional QA |
| f80c9ee9 | ian | 129 | 1 | 0.19M | 5m | vision QA |
| f80c5680 | pootie | 124 | 1 | 0.13M | 4m | critique |
| f824607b | root | 96 | 1 | 0.37M | 7h05m | orchestrator |

### Objective Triad

- **Outcome: SHIPPED.** All QA gates green; 4 gameplay bugs caught and fixed during build; honest residual-risk disclosure (task 7's directed self-collision test was skipped under the wedge but retired later in the QA gauntlet's directed U-shape scenario).
- **Speed: 7h05m — worst shipped run in the series** (run 9: 3h32m). Excluding the marathon segment: **~2h05m**, which would have been the fastest shipped run. The wedge, not the game, consumed the delta.
- **Tokens: 11.94M in — ~75% higher than run 9's 6.79M**, driven by the marathon session (5.6M, 47% of the run's input, all diagnostic spiraling with zero forward progress).

## The Permission Saga (three launch attempts before the game built)

Three consecutive, distinct opencode permission-semantics bugs — each diagnosed from live-session denial payloads and verified against opencode's source (`packages/opencode/src/permission/index.ts`, `packages/core/src/util/wildcard.ts`):

1. **Attempt 1 — ian's genesis writes denied.** Frontmatter granted `GAME_STATE.md`/`README.md` allows, but a misplaced catch-all... actually: the grant simply didn't exist yet (`7426bf2` fixed ian's allowlist). Root improvised the writes.
2. **Attempt 2 — same denial.** The fix WAS in the loaded ruleset (confirmed in the error payload) but `"*": deny` sat AFTER the allows, and opencode's `evaluate()` uses `findLast` — **last matching rule wins**. Our comment claimed "must come AFTER the allows" — we had the precedence inverted. Fixed by putting catch-all FIRST in all three agents (`c7b7954`).
3. **Attempt 3 — poppy's root-level writes denied** (`project.godot`, `icon.svg`, `.gitignore`). `Wildcard.match` compiles `**/x` to `^.*/x$`, which requires a parent directory — it never matches a root-level file. Fixed by adding bare patterns (`project.godot`, `*.svg`, …) alongside every `**/` grant (`2c67128`).

Attempt 4 (the shipped run) cleared all gates. Also removed en route: the dead `LESSONS.jsonl` mechanism (`56ca589`).

**Net: the harness's permission model assumed "ordered specific-over-default" semantics that are the opposite of opencode's actual findLast behavior, and path patterns that don't cover root-level files. Both now verified empirically against opencode source and fixed in all three agents.**

## Incident: the Bridge Wedge (ses_f822ede7)

**Signature:** `get_debug_output` succeeds (engine alive, clean logs, bridge listening) while every `run_script` times out — including `return {"ok": true}` probes — **persisting across 18 stop_project/run_project cycles.** The engine restarts do not recreate the transport.

**Timeline:** 23:44 first scene-verify PASS (15s chaos scenario, wall death confirmed empirically) → 23:46 first directed self-collision run_script times out → correct diagnosis by 23:53 ("transport wedged session-wide; the engine is running fine") → **then 4h35m of restart ladder anyway** (17× 600s timeouts, 14× 120s, 18 engine cycles) → 04:33 "This exceeds my bounded-work budget (max 3 per fix type; I'm far past it)" → clean shutdown, honest log-result with the risk disclosed.

**Root cause (still open):** unknown — upstream candidate. First run_script in a session works; subsequent ones hang even across engine restarts; a sibling session (tasks 12–13) hit the same class and escaped via TestPlayer-autoload removal. Smells like stale bridge/session state that stop/start does not reset (port mismatch or dead request channel in the MCP server process, not the engine).

**Failure-mode classification:** infrastructure, not game. The recovery-cost asymmetry is the harness finding: a rule that exists in prose ("max 3 attempts, then ⛔ BLOCKED") was violated 20× when each individual error message ("Is the game running?") suggested an actionable-looking next step. **Prose stopping conditions fail exactly when errors look recoverable but aren't.**

## What Worked (keep)

- **Genre-agnosticism** — full stack unmodified on tick-driven grid mechanics; TestPlayer bots, invariant merges (`tests/scenarios/*.json`), frame-time metrics all correct.
- Permission fixes held through the entire run: zero wrong denials after attempt 4; both post-fix denial-shaped events (bash deny, root critique write) were handled gracefully without improvisation.
- Bounded-work rule eventually worked — self-recovery, honest residual-risk disclosure, no fabricated results.
- Tasks 12–13 session escaped a same-class wedge in minutes (TestPlayer autoload removal + restart) — the recovery move exists in-repo now via trace; codifying it is a follow-up.
- Post-marathon cadence: 8 tasks + 3 QA gates in ~1h50m with 4 gameplay bugs caught and fixed — clean, disciplined, cheap.
- COMPLETION_REPORT quality: bug ledger + recommendations, all accurate per QA reports.

## Follow-Ups (this cycle)

1. **Skill hardening (highest leverage):** add the wedge signature ("get_debug_output OK + trivial run_script probe timeout across 2+ restarts") to `create-scene-with-script/reference/mcp-patterns.md` error recovery with an immediate-escalation mandate; add a cumulative timeout budget (cap restart cycles at 2–3) to the recovery ladder so the 600s×17 spiral is structurally impossible. (mcp-patterns.md:121-126 — extend the run_project recovery block; playtest SKILL.md:79 already has the one-retry-then-BLOCKED shape to mirror.)
2. **Mechanical bail:** the retry cap must move from prose to structure — cap total run_script timeout wait per verification.
3. **`validate.sh` task-ID padding:** accept `06`/`6` (agent burned reasoning on this).
4. **Root's consumer-critique write:** root lacks `reports/**` edit rights and dropped the artifact to inline text — preserve via delegation or grant `reports/consumer-*.md`.
5. **Upstream (godot-mcp-runtime):** (a) classify "bridge/transport wedged" distinctly from "game not running" — the current message actively misled a capable agent for hours; (b) root-cause the wedge (first-call-works, restarts-don't-clear pattern; suspect server-side request-channel state, not the engine).
6. **Upstream (opencode):** no subagent wall-clock cap/heartbeat — root was blind and blocked for 4h58m on one task(); also `edit * deny` silently governs `write` and the denial message doesn't name the tool.
7. **Failure-modes table:** add the bridge-wedge entry with the signature and the documented 6-minute escape (TestPlayer autoload removal).

*Triage note: items 5–6 are upstream contributions per the contribution rule (docs/upstream-backlog.md); item 1 is in-repo and cheapest to land.*
