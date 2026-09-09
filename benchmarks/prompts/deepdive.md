# Scale/stress variant — DeepDive (3D systems-coupling profile)

All shipped runs so far are one-scene arcade games (~15-20 tasks, one
system cluster), and only one 3D run (run 13, OrbField — 8 mechanics,
~20 tasks, minimal coupling). The swarm has never exercised: interacting
systems, multi-phase task graphs with state carried between phases,
persistence (save/load), or a vision complex enough that consumer
critique could plausibly warrant REVISE_VISION rather than ORDER_REWORK
(new pipeline path from commit f6a30fe, never yet triggered live). This
run roughly doubles task count (~35-45) and effective build time
(~4-5h) versus the primary prompt, in 3D. This is a **stress
benchmark**: the point is to find where the swarm's discipline (task
continuity, invariant coverage, token economy at root, disposition
loop) bends under scale — on top of the 3D foundations validated in
run 13 — not to ship a pretty game.

Untested surfaces entering this run (as of 2026-09-09):
- Save files (JSON/file I/O for meta-progression) — no skill covers
  persistence patterns; poppy's permission set (no bash, .gd edits
  allowed) should permit `FileAccess` usage, but no gotchas exist
- Multi-system invariants — QA scenarios so far cover one mechanic
  cluster; upgrade/economy interactions multiply invariant count
- 3D at scale — run 13 covered a single-arena 3D game; procedural
  multi-zone 3D layout, 3D spawners, and 3D UI overlays (shop screens)
  remain untested surfaces
- Root token economy at 2x tasks — report-compounding guidance exists
  (build.md) but has never been load-bearing
- REVISE_VISION disposition — ian's new authority (f6a30fe) is
  untested; a dominant-strategy game is the designed trigger

## The Prompt

```
Build a 3D roguelite mini-game called "DeepDive":

a submarine descends through procedurally arranged 3D depth zones
(enemies/hazards vary by zone, drifting in full 3D space around the
player). The player steers the sub with arrow keys (pitch/yaw-lite:
forward/back plus lateral strafe within the descending column) and
shoots forward torpedoes with Space. Destroyed enemies drop glowing
pearls that drift upward and can be collected by proximity. Between
zones, the player chooses ONE of three random upgrades (fire rate,
damage, speed, shield, magnet). Dying resets the run but banks half
the pearls as persistent meta-currency; the dive can then be restarted
with meta-purchases (extra life, starting upgrade) bought from a
simple shop screen. Win = reaching the trench floor at depth zone 10.
Lose = hull depleted. Meta-progress (banked pearls, owned purchases)
persists across game restarts via a save file. Controls: arrows +
Space, U/I for menu navigation. The game is complete when: the full
dive loop works (zones, upgrades, death, banking, shop, re-dive) in a
live engine run, save/load round-trips correctly across a full process
restart, the QA gauntlet passes, and the win/lose/shop screens display
correctly.
```

## Why this shape

- **Four coupled systems** — combat (torpedo damage/shield), economy
  (pearl drops/prices), progression (upgrades per zone), persistence
  (banking + shop + save file). A change to any one ripples: upgrade
  prices touch economy, magnet touches drop drift physics, shield
  touches combat invariants. Coupling is the stress target.
- **3D procedural zone layout** — enemies drift in 3D space within a
  descending water column; enough repetition-with-variation that poppy
  must build a 3D spawner/volume-population system rather than
  hand-place entities, arrivable via seeded random placement in a
  cylindrical/column volume (no navmesh, no terrain gen). Run 13's
  validated 3D patterns (RigidBody3D/CharacterBody3D, Area3D triggers,
  camera follow, emissive materials) are the building blocks.
- **Persistence is a genuinely new surface** — save/load across a
  *process restart* forces Rachel to verify durability outside a
  single engine session, a probe shape TestPlayer has not been used
  for (stop_project/run_project cycles are the natural tool; whether
  agents discover that path is itself a finding).
- **Dominant-strategy bait** — if one upgrade trivializes the dive
  (likely: shield stacking), pootie's RECOMMEND_REWORK lands in
  ian's lap with a real REVISE_VISION-shaped option (change upgrade
  balancing vision vs. patch values). Designed trigger for the
  disposition loop.
- **Genre-agnostic discipline preserved** — this file may describe
  genre-flavor, but no skill or agent file gains game-specific
  content; all genre knowledge stays in this prompt (per AGENTS.md).

## Expected findings (predictions to grade the run against)

1. **Task-graph scale:** does poppy's per-session task continuity
   hold at 40 tasks, or do we see drift/rework from stale task
   state? Prior runs at 16-20 tasks showed none; predict degradation
   starts appearing if task list exceeds ~30 incomplete at once —
   the build agent may need chunked phases.
2. **Persistence probe shape:** how does Rachel verify
   save-across-restart? Predict: initial attempts via in-session
   run_script only (insufficient — proves file write, not
   durability), requiring a second QA pass after someone realizes
   the process-restart requirement; a skill gap worth codifying
   afterward.
3. **Invariant explosion:** coupled systems mean N×M interaction
   invariants, and 3D volumes make bounds derivation harder (column
   extents vs arena plane). Predict: Rachel's scenario JSON grows
   3-4x, and at least one interaction (magnet × pearl drift, shield
   × enemy contact in 3D space) ships unverified in the first QA
   pass and only gets caught on the QA re-run after critique.
4. **Token economy:** predict root-session input tokens exceed 12M
   (vs ~10.7M run 12 at half the tasks, 8.9M run 13) unless
   report-discipline holds; if it exceeds ~15M, the token-economy
   guidance in build.md needs teeth (harder verdict-only returns).
5. **REVISE_VISION trigger:** predict pootie finds a dominant
   strategy (≥1 upgrade combo trivializing depth 10) in round 1;
   disposition is genuinely ambiguous (balance patch vs vision
   revision) — the interesting outcome is WHAT ian does, not
   whether the loop routes correctly (that part is mechanical).
6. **Save-file formats:** predict poppy hand-rolls JSON via
   FileAccess with no reference pattern; risk area is atomic-write
   discipline (partial-file corruption on kill) — cosmetic for the
   benchmark, upstream-skill material if observed.
7. **Phase 3 gate cascade:** 3 gate systems × 2 potential rework
   cycles at this scale — predict ≥1 full-gate re-run (Rachel+Ian+
   Pootie+Ian again), making wall-clock dominated by gate
   repetition rather than building; if gate re-runs exceed 40% of
   productive time, consider gate-delta modes (re-verify only what
   changed) as a follow-up skill rule.
8. **3D-under-scale regressions:** run 13's 3D patterns held at 20
   tasks/single arena; predict at least one new 3D-shaped failure
   at this scale — most likely candidates: camera control in a
   descending column (3D occlusion in critique screenshots),
   collision-shape complexity in dense enemy volumes, or zone-boundary
   seams (entities crossing zones). Not blockers — each is a skill
   update or gotcha, per the run-13 process.

Record actual outcomes in the run's benchmark result; convert
exposed gaps into skill updates or BLOCKED reports per the
sanctioned-paths rule — do NOT patch gaps by hand-editing scenes
mid-run to "help" agents.
