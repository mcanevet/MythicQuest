# Phase 3 — Issue-First: Deterministic Playtest Module (`game_time`)

Kind: issue-first (design), then PR · Status: not started · **The friction
point of the roadmap — read maintainer-fit notes before doing anything**

## Importance to us: CRITICAL (highest-value item)

- **Why:** deterministic replay is the foundation for trustworthy automated
  QA: flaky, timing-dependent assertions are a top source of false results
  in our benchmark scoring. Freeze/step/seed turns "the bot moved" into
  "the bot is at (x,y) every time", which is what invariant pass-rate
  comparisons across models and sessions actually require.
- **Impact area:** every playtest and every benchmark measurement — the
  difference between anecdotal and reproducible evidence.
- **Cost:** large (framework-sized contribution, quarters-scale timeline,
  real risk of deferral). Highest value AND highest effort/risk in the
  roadmap — hence issue-first and the run_script fallback, which caps the
  downside at zero.

## Sequencing gate

Phases 1–2 must land (or be clearly accepted in review) first. The
maintainer's trust is earned per-PR; this is the only framework-sized ask.
Realistic timeline: quarters, not days.

## Proposed surface

Few consolidated tools (NOT micro-tools — his rules):

- `freeze` / `unfreeze` — `tree.paused`, bridge keeps responding
  (`PROCESS_MODE_ALWAYS` precedent)
- `step` N frames — coroutine-advanced
- `step_until` — declarative conditions `[{path, property, op, value}]`
  (AND-ed), bounded by `max_frames` / wall budget — **no expression
  evaluation, RCE-safe**
- `set_seed` — global randi/randf

## Framing (decisive)

Present as *verification infrastructure for agents* — echoing his own thesis
("the agent closes the loop on its own changes"). NEVER as a playtesting
replacement: his README explicitly disclaims that scope.

Lead with the RCE-safe declarative-condition design — it dovetails with his
`run_script` security-gate philosophy (his own `gdscript-scanner` fights
`Expression`-class injection; our design avoids arbitrary evaluation
entirely).

## Design details

- Never use `randi()` internally so seed locking holds (incl. port
  randomization via crypto, not randi — enhanced's detail)
- Honest limits to disclose in the issue (mirrors his honest-limitations
  culture in security.md): seed covers global randi/randf only (game
  `RandomNumberGenerator` instances unaffected); physics-tick vs
  process-tick semantics
- TDD e2e: same seed + same input timeline → same asserted state, twice
- Frame-timed input sequences (à la enhanced's `at_frame` timelines) can ride
  on top of `step` + existing `simulate_input` — mention as follow-up, not
  part of the initial ask

## Fallback

If deferred/rejected: keep determinism as a harness-side `run_script`
composite in MythicQuest `skills/playtest` (soft-fork branch for our dist,
as already practiced). No migration pressure.

## Techniques to mine

- enhanced: freeze/step/step_until mechanics; crypto port randomization
- satelliteoflove: frozen-clock stepping model (docs suffice to port concept)
