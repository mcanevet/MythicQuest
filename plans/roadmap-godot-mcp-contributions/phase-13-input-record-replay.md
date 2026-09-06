# Phase 13 — Input Recording & Frame-Anchored Replay (Phase 3 completion)

Kind: follow-on to Phase 3 (same design issue or immediate successor PR) ·
Status: not started · GATE: Phase 3 must land or be accepted in principle
first · Discovered: RallyWall trace (input synthesis pain + pootie's
decisive keyboard play)

## Importance to us: MEDIUM-HIGH (not standalone — the multiplier on Phase 3)

- **Why (trace evidence):**
  1. Agents hand-construct input timelines via `simulate_input` +
     `bash sleep` (324s of sleeps in this run alone), with wall-clock
     anchoring that background throttling (Phase 9) makes unreliable
  2. The single most convincing QA act of the run was pootie *playing the
     game by keyboard* — caught the bug nothing else caught. Recorded,
     replayable input makes that reproducible-by-assertion instead of
     luck-of-the-moment
  3. Phase 3's determinism is incomplete without it: same seed + same
     INPUT TIMELINE → same state. Replay determinism is what turns
     "seeded RNG" into "reproducible run" — this phase IS the input half
     of the Phase 3 promise
- **Cost:** medium; must land after/with Phase 3.

## Proposal

- `record_inputs` / `replay_inputs(id)` (or recording implicit in a
  `simulate_input` with `record: true` → returns recording id): capture
  an input sequence with **frame anchors**, not wall-clock timestamps
  (frame-anchoring is what makes replay survive background throttling —
  wall-clock replay would desync under Phase 9's throttle)
- `replay_inputs(id, {step_deterministic?: bool})`: at minimum re-issue
  sequence at frame anchors; with Phase 3's `step` primitives, tick-by-tick
  deterministic replay (advance one frame, apply that frame's inputs)
- Persist recordings harness-side (`.mcp/input_recordings/`) so a failing
  run's exact interaction can be re-run in a fix-verification pass —
  "the exact play that broke it" as a regression asset
- Frame-anchored storage gives Phase 5's QA suites their golden-agent
  acceptance runs (beremaran's design reference, made concrete)

## Maintainer-fit notes

- Fold INTO the Phase 3 design issue as its natural completion — do NOT
  pitch as a separate parallel surface (tool-budget rules); the framing
  is: "determinism is unusable for verification without deterministic
  replay of the input timeline"
- Actually reduces tool count pressure: recording rides existing
  `simulate_input`, replay may be a mode of `replay_inputs` (one new tool
  total, or a param if he prefers)
- Precedent-language: every browser automation stack (Playwright et al) —
  the README's own stated analogy — treats input replay as table stakes

## Verification

- TDD e2e (needs Phase 3): record chaos-bot run → set seed → replay →
  identical asserted states
- Without Phase 3: wall-clock replay still must survive background
  throttling (frame-anchored), regression-test with Phase 9's throttle
  repro
