# Benchmark prompt — DeepShade (art-forward profile)

Cave-exploration theme chosen so materials are **visible and
judgment-load-bearing**: distinct surface identities (rock terrain,
glowing crystals, hazard pools, character) map 1:1 onto the
apply-material skill's surface-type table. Purpose: first live validation
of Phil's insertion into the dev loop (apply-material step, graceful
degradation, `material:` follow-up filing) AND contract v2
(tracker-native plans) — one run exercises both. No prior run of this
prompt exists, so it starts its own series and corrupts no baseline
(RallyWall/CoilUp runs used the no-Phil pipeline).

Scale matches the primary prompt (~7 mechanics, simple physics, no
instancing, no AI opponent) — the variables under test are the art step
and contract v2, not game complexity. Keep complexity flat so run
comparisons within this series measure the harness, not the prompt.

## The Prompt

```
Build a small single-player cave-exploration game called "DeepShade":
a player-controlled explorer walks through a cave (left/right
movement, jump), collects glowing crystals, and must reach the
exit door at the far right of the cave. Touching a hazard pool
(liquid at the cave floor's low points) resets the explorer to
the cave entrance and decrements a 3-light supply shown as
torch icons on the HUD. Reaching the exit with any lights left
shows a win screen; losing all 3 lights shows a game-over screen
with a "play again" key. Collecting a crystal increases the
score by 1 and brightens the cave's ambient glow slightly.
Controls: left/right arrows, up arrow to jump.

Visual identity (the art style is part of the charter, not
decoration): the cave is dark rock with visible texture, crystals
are emissive and clearly distinguishable from plain stone, the
hazard pool reads as dangerous liquid (emissive, animated or
pulsing), and the explorer is visually distinct from the
background. Default-engine gray boxes on any of these surfaces
are a visual failure even if mechanics pass.

The game is complete when: all mechanics work in a live engine
run, the full QA gauntlet passes, the win/lose screens display
correctly, AND every surface above reads as its intended
material in a rendered screenshot (no default materials left on
crystals, hazard pool, cave terrain, or the explorer).
```

## Why this shape

- **Surfaces map to apply-material's decision table** — cave terrain
  (environment → procedural rock texture), crystals (prop/energy →
  emissive), hazard pool (hazard → animated/pulsing emission), explorer
  (character → standard PBR). Each surface class in the skill gets
  exercised at least once; a flatter theme (abstract geometry) would
  leave most of the decision table untested.
- **Explicit visual-identity language in the prompt** — "default-engine
  gray boxes are a visual failure" flows verbatim into the charter via
  genesis (build.md forwards the user prompt verbatim), giving Ian's
  vision check a concrete art-style basis and giving Phil's step a
  hard success criterion. Without this, "art style" is vibes and the
  art step's outcome is unfalsifiable.
- **Completeness clause includes the material gate** — "AND every
  surface reads as its intended material" makes Phil's output part of
  the DoD rather than an optional polish, while graceful degradation
  still applies (a degraded surface ships with a `material:` follow-up;
  the completeness clause is satisfied by the follow-up being filed and
  tracked, not by blocking).
- **Mechanics stay RallyWall-simple** — movement, jump, collect,
  hazard reset, light countdown, win/lose. The physics is
  CharacterBody2D platforming (covered territory), so run variance
  measures the new art step and contract v2, not novel game logic.
- **Light supply gives QA a discrete counter invariant** (torch count
  decrements exactly on hazard contact) — same class of deterministic
  check as CoilUp's growth state, so the functional gauntlet keeps
  teeth without new harness paths.

## What this run validates (and what to compare)

| Axis | Under test | Comparison |
|---|---|---|
| Outcome | Material gate honored — surfaces read correctly in screenshots; mechanics pass; graceful degradation produces `material:` follow-ups, never blockers | Was contract v2 (genesis description-seeding, log-result) clean? |
| Speed | Phil's insertion cost: per-visual-task session boot amortized against catching visual defects before QA | vs. a hypothetical no-art run of the same prompt (optional control, `deepshade-solo` style) |
| Tokens | Root-session tokens incl. Phil sessions; skill template re-read behavior | First run of a new series — establish baseline, compare only within the series |

Post-run checklist (harness analysis): did the Phil session fire only on
visual tasks? Did any material failure block a task (should be zero)?
Were `material:` follow-ups filed via the tracker with reporter:phil? Did
Ian's vision check cite materials against the charter? Did contract v2's
tracker-native plans work end-to-end (genesis seeded rich descriptions,
log-result validated against them)?

## Known coverage gaps

- **No shader-by-shared-resource case** (one material reused across
  several nodes) — apply-material 2c prefers inline construction, so a
  single-node-per-material game won't exercise the shared path.
- **No CC0 fallback test** — the fallback is off by default by design;
  testing it requires a dedicated prompt variant with the flag enabled.
- **No repeat run yet** — one run validates the paths exist; series
  statistics (retries, degradation rates) need ≥3 runs.
