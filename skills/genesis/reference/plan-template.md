# Task <N>: <Task Title>

## Task Type
`<task-kind>:` <one-phrase summary, e.g. scene+script, script-only, ui>

## Goal
Create the entity/mechanic described in the task title, driven by the input/state sources the game's design calls for.

## Files to Create

### Entity scene
- One scene file for the entity (root node type per the engine skill's
  node-selection guide), with display and collision child nodes as the
  engine's scene patterns dictate

### Entity script
Implements movement from the game's input actions with testability hooks
(`test_exposed` group membership + `get_test_state()` returning position
and velocity — see the engine skill's testing schema for the required
hook contract). Concrete scaffold: the engine plugin's worked example
(see **create-scene-with-script** skill, `skill({ name:
"create-scene-with-script" })`, and its reference docs).

### Placeholder asset
Minimal visual placeholder if no texture is available.

### Test config
One scenario config under `tests/scenarios/` exercising the entity with
a chaos bot and stability invariants. Invariant rule names must come from
the canonical testing schema in the setup-project skill's
`reference/testing-patterns.md` (engine plugin) — an unknown `rule`
value is silently ignored (no-op invariant).

## Definition of Done ✅

**Focus on ESSENTIALS only (5-7 critical items):**

- [ ] Scene file created at specified path via engine tools
- [ ] Script created at specified path, compiles without errors
- [ ] Test hooks added (`test_exposed` group + `get_test_state()`)
- [ ] Test scenario config created in `tests/scenarios/`
- [ ] Visual verification OR invariant-based verification:
  - *Invariant-based (primary)*: Run chaos scenario, check report shows zero violations
  - *Visual (only when the invariant harness can't judge the outcome — see "Visual Verification Needed")*: launch visible window, capture before/after screenshots, describe visual changes
- [ ] The task's core behavior works as intended (the mechanic named in the Goal)
- [ ] Signal connections established (if applicable)

## Visual Verification Needed ⚠️

**Check if this task requires visual testing:**
- [ ] Task involves interactive elements (buttons, menus, animations)
- [ ] Task involves player input handling
- [ ] Task involves visual state changes (UI updates, screen transitions)
- [ ] Task involves collision feedback or visual effects

**If checked above, note these verification expectations in the plan:**

## Verification

1. Primary evidence is an invariant report from `playtest` scene-verify (zero violations required)
2. Add a screenshot-based manual check only when the invariant harness can't judge the outcome (UI layout, visual state changes, animation feel)
3. Document pass/fail status with the evidence used

## Implementation Hints

1. **Node/body selection**: choose physics body types per the engine
   skill's node-selection guide (player-controlled vs physics-simulated
   vs static geometry are different types; the wrong choice breaks the
   mechanic or its performance)
2. **Collision**: set collision layer/mask appropriately for the game's needs
3. **Positioning**: place entity at appropriate starting position
4. **Validation**: validate the scene and script through the engine
   skill's validation path (headless check + runtime smoke)
5. **Testability**: declare invariants using the testing schema in the
   setup-project skill's `reference/testing-patterns.md` (engine plugin)

## Dependencies

- Requires: Project infrastructure setup, input actions defined
- Blocks: Gameplay logic, collision interactions

## Notes

- Speed value will be tuned during playtesting
- Animation support can be added later
