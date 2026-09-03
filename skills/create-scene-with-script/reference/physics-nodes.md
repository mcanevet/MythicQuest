# Physics Node Patterns

## Choosing the Right Node Type

Choose based on **what the entity DOES**, not game genre:

```
Entity Role                        → Recommended Node Type
──────────────────────────────────────────────────────────
Moves by player input              → CharacterBody2D  (jump, move, respond to input)
Moves by physics forces            → RigidBody2D      (bounce, fall, collide naturally)
Detects overlaps (no physics)      → Area2D           (trigger zones, pickups, hazards)
Immovable geometry                 → StaticBody2D     (walls, floors, platforms)
Animated decoration                → Sprite2D / AnimatedSprite2D (no physics)
Text/info display                  → Label / RichTextLabel
Interactive UI                     → Button / Control hierarchy
```

**Decision guide:**
- Player-controlled entities → **CharacterBody2D** (predictable, responsive)
- Physics-driven entities (bouncing, chain reactions) → **RigidBody2D** (natural, less controllable)
- Entities that BOTH respond to input AND physics → **CharacterBody2D** with manual force simulation

## Collision Shape Setup

**Critical:** MCP tools cannot persist Resources like `RectangleShape2D` — their value coercer has no Resource path, so dict-shaped resources are `set()` raw, fail the typed assignment, and the tool still reports success (the shape stays `<Object#null>` in memory too; verified in runtime source 09-02). *(Upstream lifecycle trail: SKILL.md Step 5a records the issue status and retirement condition — check there before relying on this workaround.)* Use sub_resources via **direct `.tscn` edit** (allowed; never while a run/playtest is active):

```ini
[gd_scene format=3]

[sub_resource type="RectangleShape2D" id="shape_1"]
size = Vector2(20, 100)

[sub_resource type="CapsuleShape2D" id="shape_2"]
radius = 7.5
height = 15

[node name="Entity1" type="Area2D" parent="."]
collision_layer = 1
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="Entity1"]
shape = SubResource("shape_1")
```

**Alternative (runtime only, not persisted):**
```gdscript
var col_shape = get_node("/root/Entity1/CollisionShape2D")
var shape = RectangleShape2D.new()
shape.size = Vector2(20, 100)
col_shape.shape = shape
```

After any `.tscn` edit, confirm the `shape = SubResource(...)` binding actually landed on disk (`read`/`grep` the file) — this write class has failed silently via MCP (Bug 2, observed 09-02).

**RigidBody2D critical config** (if used):
- `contact_monitor = true` is REQUIRED for collision signals to fire (defaults to false!)
- `max_contacts_reported` must be > 0 (e.g., 1-10)
- Use `linear_velocity` for movement, NOT `velocity` (velocity is CharacterBody2D API)

**Gotchas:**
- StaticBody2D is for immovable geometry — if entity moves, do NOT use StaticBody2D
- CharacterBody2D uses `move_and_slide()` for movement
- RigidBody2D uses `apply_force()`/`apply_impulse()` for physics

## Common Validation Errors

If validator fails on "missing shape property":
1. Check `[sub_resource]` blocks exist after `[gd_scene format=3]`
2. Verify `shape = SubResource("shape_X")` references correct ID
3. Run validator: `./.opencode/skills/create-scene-with-script/scripts/validate.sh scenes/main.tscn`
