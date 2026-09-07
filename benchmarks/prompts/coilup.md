# Benchmark prompt — CoilUp (grid-movement profile)

Grid-based movement, tick-driven state, discrete-cell collision, and a
growing-segments body — a mechanic family untouched by RallyWall (continuous
physics) and BrickFall (instancing). Similar scale to the primary prompt
(~7 mechanics, no physics bodies, no instancing), so it doubles as a
regression benchmark for the run-9 harness fixes (windowed delta-rate,
warm-up reset) on a **timer/tick-driven** game instead of a physics one.

## The Prompt

```
Build a small grid-movement survival game called "CoilUp":
a player-controlled snake moves on a fixed grid in one of four
directions (up/down/left/right), advancing one cell per tick.
Eating a food pellet that spawns at a random empty cell grows
the snake by one segment and increases the score by 1. The game
ends immediately if the snake's head collides with a wall or
with its own body, showing the final score with a "play again"
key. The player wins by reaching a score of 10, showing a win
screen. Controls: arrow keys (all four directions, no reversing
into yourself). The game is complete when: all mechanics work
in a live engine run, the full QA gauntlet passes, and the
win/lose screens display correctly.
```

## Why this shape

- **Tick-driven, not physics-driven** — movement advances on a fixed tick
  (one cell per tick), so there is no physics engine dependency: collisions
  are discrete cell-equality checks, not `Area2D` overlaps. This exercises
  the `Timer`/`_process`-accumulation path and the invariant framework's
  delta-rate rules on a fundamentally different game loop than RallyWall
  (a direct test of the run-9 TestPlayer fixes on non-physics games).
- **Self-collision is the interesting check** — "no reversing into
  yourself" (a direction change to the opposite of the current heading must
  be ignored) and body self-collision are logic bugs the
  functional-QA bots can provoke deterministically with directional input
  sequences, unlike physics-edge flakiness.
- **Growth state** — the growing snake is mutable entity state that must
  survive across ticks (segment list handling), a good probe for
  state-exposure hooks in scenario configs (`get_score()`-style test hooks).
- **Random spawn** — food at a random empty cell covers seeded-RNG
  testability: the QA bot verifies "pellet never spawns on the snake",
  which needs controllable or observable randomness.
- **Same scale as the primary prompt** — ~7 mechanics (four-direction
  movement + no-reverse rule, tick advance, food eat + grow + score,
  wall/self collision → lose screen + play again, win at 10), one entity
  family, no instancing. Comparable token burn to RallyWall; differences in
  outcome across runs measure the harness, not the prompt.
- **Known coverage gaps:** no repeated-node instancing (use `brickfall.md`)
  and no continuous physics/collision-response (use `rallywall.md`). Snake
  segments *may* be drawn as instanced sprites by the builder, but the spec
  does not require it — instancing coverage should use the dedicated
  variant.
