# Task <N>: <Task Title>

## Task Type
`scene+script:` Creating an entity with physics body and collision

## Goal
Create a player-controlled entity that moves in response to input and collides with other objects.

## Files to Create

### `scenes/entities/player.tscn`
- Root node: `CharacterBody2D` named "Player"
- Child nodes:
  - `Sprite2D` named "Sprite" - displays entity texture
  - `CollisionShape2D` named "Collision" - shape for physics

### `scripts/player.gd`
```gdscript
extends CharacterBody2D

@export var speed = 400

func _physics_process(delta):
    var input_dir = Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    )
    velocity = input_dir * speed
    move_and_slide()

# TESTABILITY HOOKS (required)
func _ready():
    add_to_group("test_exposed")

func get_test_state() -> Dictionary:
    return {
        "position": global_position,
        "velocity": velocity
    }
```

### `assets/player.svg` (placeholder)
Minimal shape SVG if no texture available.

### `tests/scenarios/player_movement.json` (test config)
```json
{
    "scenario_id": "player_movement_stress",
    "duration_s": 15,
    "bot": { "type": "chaos", "seed": 42, "input_rate_hz": 10 },
    "invariants": [
        { "name": "no_physics_blowup", "rule": "nodes_finite" },
        { "name": "fps_stable", "rule": "custom", "path": "_meta.frame_ms_p99", "check": "below", "value": 33.3 }
    ]
}
```

Invariant rule names must come from `./.opencode/skills/setup-project/reference/testing-patterns.md` — an unknown `rule` value is silently ignored (no-op invariant).

## Definition of Done ✅

**Focus on ESSENTIALS only (5-7 critical items):**

- [ ] Scene file created at specified path via MCP tools
- [ ] Script created at specified path with correct `extends`
- [ ] Compiles without syntax errors (validate in headless mode)
- [ ] Test hooks added (`test_exposed` group + `get_test_state()` method)
- [ ] Test scenario config created in `tests/scenarios/`
- [ ] Visual verification OR invariant-based verification:
  - *Invariant-based (primary)*: Run chaos scenario, check report shows zero violations
  - *Visual (only when the invariant harness can't judge the outcome — see "Visual Verification Needed")*: launch visible window, capture before/after screenshots, describe visual changes
- [ ] Movement/collision works as intended (for player/AI entities)
- [ ] Signal connections established (if applicable)

## Visual Verification Needed ⚠️

**Check if this task requires visual testing:**
- [x] Task involves interactive elements (buttons, menus, animations)
- [x] Task involves player input handling
- [x] Task involves visual state changes (UI updates, screen transitions)
- [ ] Task involves collision feedback or visual effects

**If checked above, note these verification expectations in the plan:**
1. Primary evidence is an invariant report from `playtest` scene-verify (zero violations required)
2. Add a screenshot-based manual check only when the invariant harness can't judge the outcome (UI layout, visual state changes, animation feel):
   - Run the scene and capture `take_screenshot({ responseMode: "preview" })` during or after a chaos scenario
   - Describe what the image shows (positions, colors, movement evidence)
3. Check `get_debug_output()` for runtime errors
4. Document pass/fail status with the evidence used

## Implementation Hints

1. **Scene structure**: Use CharacterBody2D for physics-based movement
2. **Collision**: Set collision layer/mask appropriately for the game's needs
3. **Positioning**: Place entity at appropriate starting position
4. **Validation**: Use `godot-mcp-runtime:validate(scenePath="scenes/entities/entity.tscn")` or `godot-mcp-runtime:run_project({ scene: "res://scenes/entities/entity.tscn", background: true })` + `godot-mcp-runtime:get_debug_output()`
5. **RigidBody2D critical config** (if entity uses RigidBody2D):
   - `contact_monitor = true` is REQUIRED for collision signals to fire (defaults to false!)
   - `max_contacts_reported` must be > 0 (e.g., 1-10)
   - Use `linear_velocity` for movement, NOT `velocity` (velocity is CharacterBody2D API)
   - Full pattern in `./.opencode/skills/create-scene-with-script/reference/physics-nodes.md`
6. **Node type correctness**:
   - StaticBody2D is for immovable geometry — if the entity moves, do NOT use StaticBody2D
   - CharacterBody2D is for player/AI controlled movement via move_and_slide()
   - RigidBody2D is for physics-simulated objects that bounce/fly naturally
7. **Testability**: Declare invariants using the engine-agnostic schema in `./.opencode/skills/setup-project/reference/testing-patterns.md` (bot types, invariant rules, metrics)
8. **Verification**:
   - *Primary*: Run chaos scenario with invariant checker, no screenshots needed unless violations
   - *Visual (only when the invariant harness can't judge the outcome — UI layout, visual state, animation feel)*: manual screenshot-based verification with visible window

## Dependencies

- Requires: Project infrastructure setup, input actions defined
- Blocks: Gameplay logic, collision interactions

## Notes

- Speed value will be tuned during playtesting
- Animation support can be added later