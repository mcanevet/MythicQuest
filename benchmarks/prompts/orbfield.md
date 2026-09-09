# Exploratory variant — OrbField (3D profile)

A deliberately simple 3D game exercising the dimension the harness has
never run: Node3D scene trees, 3D collision shapes, camera setup, 3D
bounds/metrics in the QA bot, and the skills' 2D-centric reference docs
under a workload they don't currently describe. This is an **exploratory
coverage probe**, not a regression benchmark: expect the run to expose
3D-shaped gaps in skills (decision tables, collision-setup patterns,
invariant bounds derivation from 3D viewports) — those gaps are the
point. Size it like the primary prompt (~6 mechanics) so failures
attribute to the 3D dimension, not task volume.

Known 2D-only surfaces entering this run (as of 2026-09-09):
- `create-scene-with-script/reference/physics-nodes.md` decision table
  lists only `*2D` node types
- TestPlayer itself handles Node3D (bounds, PhysicsBody3D, Sprite3D,
  NavigationAgent3D) — engine-side support is believed complete
- Lighting/material/Environment setup has no reference pattern

## The Prompt

```
Build a small 3D arcade game called "OrbField":
a player-controlled sphere rolls on a flat arena floor,
steered with the arrow keys (WASD optional). Glowing
pickup orbs are scattered across the arena; touching one
collects it and increments the score by 1, with a brief
collection effect. Rolling off the arena edge ends the
game with a lose screen showing the final score. Collecting
all 8 orbs shows a win screen. Controls: arrow keys.
The game is complete when: all mechanics work in a live
engine run, the full QA gauntlet passes, and the win/lose
screens display correctly.
```

## Why this shape

- **Minimal 3D, maximal surface** — one floor, one sphere, eight
  instanced orbs, two screens: the smallest 3D game that still forces
  a 3D camera, a lit Environment or emissive materials, 3D collision
  shapes (sphere/box), and 3D-falling-actor detection.
- **Same mechanic family as the primary** — input-driven movement,
  pickup collection, score, win/lose state, edge/fall lose condition —
  so the comparison against RallyWall runs isolates the 3D dimension
  cleanly (anything harder/slower there is 3D friction, not task mix).
- **Fall-off-the-edge = 3D-specific lose logic** — y-position bounds
  checking, not screen-bounds; exercises 3D invariant derivation
  (`nodes_in_bounds` with 3D min/max, already supported by TestPlayer).
- **Orbs are light instancing** — 8 repeated pickups via scene
  instantiation, piggybacking the PR #38 instanced-child persistence
  coverage in a new dimension.

## Expected findings (predictions to grade the run against)

1. Poppy consults a physics-nodes decision table with no 3D rows —
   does it map CharacterBody2D→CharacterBody3D analogically, or stall?
2. Camera3D placement/angle has no reference pattern — improvised or
   delegated to ian vision feedback?
3. 3D bounds for `nodes_in_bounds` derived ad hoc — off-by-arena-size?
4. Materials/lighting (emissive orbs) — improvised or skipped?
5. Consumer critique (pootie) driving a 3D game with simulate_input:
   does off-screen-perspective screenshot judging hold up in 3D?

Record actual outcomes in the run's benchmark result; convert exposed
gaps into skill updates or BLOCKED reports per the sanctioned-paths rule
— do NOT patch 3D gaps by hand-editing scenes mid-run to "help" agents.
