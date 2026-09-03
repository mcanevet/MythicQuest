# Run 2: RallyWall E2E — PASS (2026-09-02 22:30 → 2026-09-03 07:40)

**Harness revision**: `3384007` (all three 09-02 bug fixes applied) + `godot-mcp-runtime@3.2.3` (published release, relative-path fix included).
**Prompt**: `benchmarks/prompts/rallywall.md` (verbatim).
**Model**: user-selected (same experiment variable as baseline).

## Executive Summary

**Status: SHIPPED — 14/14 tasks, 0 blocked, 0 QA bugs.** The full pipeline ran end-to-end: genesis → 15 poppy delegations → vision QA → consumer critique → completion report. All three harness bugs exposed by the 09-02 baseline were exercised and confirmed fixed. Pootie's verdict: SHIP IT; playtest gauntlet 0 violations; 5% speed-up verified to floating-point exactness (1081.0427 == 520 × 1.05¹⁵).

## Raw Metrics

### Time

| Metric | Value | Notes |
|---|---|---|
| Root wall clock | 22:30:43 → 07:40:12 = **549 min (9.2 h)** | Includes **5.8 h host sleep** (poppy9 stalled overnight 23:25→03:05→05:13 in two gaps of 219/127 min) |
| Estimated active wall clock | **~5.2 h** | Sum of subagent spans: 437 min + root transitions |
| Subagent count | **17 poppy + 2 ian + 1 pootie** | 15 poppy task-spans (Task 9 = continuation after one cancelled session), 1 poppy re-delegation |
| Per-task poppy median | **5.8 min** | Range 3.0–9.4 min; Tasks 1–8 each in one shot, no retries |
| Task 9 (lose screen + restart) | 351 min nominal / ~46 min active | Longest task: included restart-flow race diagnosis + host-sleep gaps |
| Ian genesis | 42 s | |
| Final QA (Task 14) | 9.4 min | Fresh full gauntlet, separate poppy |
| Vision + critique | 5.4 min | Ran after (not parallel with) Task 14 |

### Tokens (assistant-message aggregation, full tree)

| Session | Input | Output | Reasoning | Notes |
|---|---|---|---|---|
| poppy9 (Task 9 + restart debug) | 832k | 6.3k | 1.0k | Highest — includes overnight race debugging |
| poppy17 (Task 14 QA) | 760k | 15.1k | 0.6k | Heaviest output — full gauntlet |
| ian vision QA | 684k | 4.8k | — | |
| Typical implementation task | 400–650k in / 4–10k out | | | |
| **Total (19 sessions, 785 messages)** | **9.43M input** | **113k output** | **5.6k reasoning** | Cache read 16.5M; cost $0 (local/free provider) |

**vs. target (<3M tokens): MISSED at 9.4M input** — but each poppy delegation pays ~500k context-in for skill/plan loading; output is lean (113k). The <3M target assumed fewer, larger delegations. See Analysis.

### Reliability

| Metric | Baseline (09-02) | This run |
|---|---|---|
| Tasks completed | 1 of 14, then stall | **14/14 + final QA** |
| QA result | never reached | **PASS, 0 violations, 0 bugs** |
| Permission-ask hangs | 1 fatal (>2h) | **0** |
| Silent subagent deaths | — | **0** |
| Blocked escalations | — | **0** |
| Task-level retries | — | 1 (Task 9 re-delegation after root-cancelled session, not an error loop) |
| Tool errors (self-recovered) | — | 1 (`simulate_input` malformed action), self-corrected same step |

## Bug-Fix Verification (the point of this run)

1. **Permission-ask stall (Bug 1)** — poppy hit the expected `mv`/`rm`/`cp` denials **5+ times** across sessions; every occurrence followed the sanctioned path: report leftover / use `write` / escalate. Zero hangs. Root also correctly detected one genuinely cancelled poppy and re-delegated with adjusted instructions ("the plan already exists").
2. **`.tscn` sub_resource coercer (Bug 2)** — direct-edit path used ~6 times (collision shapes, screen layouts). Zero coercer silent-success incidents; on-disk verification confirmed each edit.
3. **Silent stall detection (Bug 3)** — root detected the Task 9 cancellation and re-delegated with correct context. Note: the 5.8 h poppy9 gap was **host sleep, not stall** (wake bursts resumed healthy work; failure-modes caveat held).

## Issues Observed (new, minor)

- **Restart-flow test race (game-side, diagnosed correctly):** a chaos-bot Space keystroke within one frame of scene reload dropped the ball through the paddle. Poppy diagnosed it as a test-harness race, not a game bug, and verified the fix numerically. Playtest skill could warn about inputs fired within one frame of scene reload.
- **Plan-file leftovers:** original non-`.completed.md` plan stubs persist because bash `mv`/`rm` is denied. Harmless (validators accept), but noisy — a `write`-based archive path in backlog-grooming would eliminate the leftovers entirely.
- **Trace language drift:** poppy9 emitted Chinese in several traces (model quirk; work remained correct and self-consistent).
- **Pursuit-bot silent no-op warning** (from COMPLETION_REPORT): nearly produced a false vision report — recommendation logged for playtest skill.

## Analysis

- **The harness changes were decisive.** The identical prompt that stalled at Task 2 on 09-02 shipped 14 tasks here. The three fixes (permission-terminal rule, direct `.tscn` path, stall detection) addressed the only failure encountered.
- **Token economics:** ~9.4M input / 113k output across 17 poppy delegations ≈ 550k input per task, dominated by skill + AGENTS.md context reload per delegation. A <3M-token run would require either larger task batching (3–4 tasks per poppy) or slimmer per-delegation context. Recommend tracking "tokens per task" as the primary efficiency metric going forward.
- **Host sleep is the enemy of benchmark wall-clock** — 5.8 of 9.2 h was sleep. The 45-min active-work target would have been met at ~5.2 h... no: active time was ~5.2 h, well over the 45-min aspiration. The <45 min target assumed far less per-task overhead; real per-task cost is ~6 min active + delegation overhead. Revise target to <4 h active for a 14-task build, or batch tasks.

## Verdict

**Baseline established: the harness ships a complete arcade game end-to-end with zero human intervention.** Fix-verification: 3/3. New baseline to beat: 9.4M tokens / ~5.2 h active / 19 subagent spans.
