# Testing and Validation Patterns

## Test Harness Schema

Full configuration schema for `start_test(scenario)`. All config is genre-agnostic — no game-specific data is required by any bot type or invariant rule.

### Bot Types

#### chaos
Random input fuzzing. Works for any game with InputMap actions.

```json
{
  "type": "chaos",
  "seed": 42,
  "input_rate_hz": 10
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `seed` | int | 42 | RNG seed for reproducibility |
| `input_rate_hz` | int | 10 | Inputs per second |

#### pursuit
Moves toward a target node by pressing directional input actions. Auto-discovers action names by convention (`move_up`, `up`, `ui_up`, etc.) or uses explicit `actions` override.

```json
{
  "type": "pursuit",
  "agent_path": "/root/Game/Player",
  "target_path": "/root/Game/Enemy",
  "deadzone": 10.0,
  "actions": {
    "up": "walk_forward",
    "down": "walk_back",
    "left": "strafe_left",
    "right": "strafe_right"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `agent_path` | string | "" | Absolute node path to the actor |
| `target_path` | string | "" | Absolute node path to the target |
| `deadzone` | float | 10.0 | Minimum distance before issuing input |
| `actions` | object | (convention) | Optional override mapping `up`/`down`/`left`/`right` to InputMap action names. Falls back to convention discovery when omitted. |

#### replay
Plays back recorded inputs for regression testing. Runs on the physics tick for deterministic replay.

```json
{
  "type": "replay",
  "inputs": [
    {"frame": 1, "action": "move_right", "pressed": true},
    {"frame": 10, "action": "move_right", "pressed": false},
    {"frame": 15, "action": "jump", "pressed": true}
  ]
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `inputs` | array | [] | Array of `{frame, action, pressed}` entries, frame is physics-tick index |

#### nav_agent
Wraps Godot's built-in NavigationAgent2D/3D to path toward a goal node. Delegates all pathfinding to the engine — equally valid for platformers, top-down games, or 3D levels.

```json
{
  "type": "nav_agent",
  "actor": "/root/Game/Player",
  "goal": "/root/Game/Goal",
  "actions": {
    "up": "jump",
    "left": "move_left",
    "right": "move_right"
  },
  "deadzone": 10.0
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `actor` | string | "" | Absolute node path to the actor (must have a NavigationAgent2D or NavigationAgent3D child) |
| `goal` | string | "" | Absolute node path or group tag for the goal |
| `actions` | object | (convention) | Same override as pursuit bot |
| `deadzone` | float | 10.0 | Minimum distance before issuing input |

**Error handling:** If no NavigationAgent2D/3D is found on or under the actor node, or the navigation goal can't be resolved, the scenario reports a `nav_agent_bot_config` violation and issues no input. The actor can also itself BE a NavigationAgent2D/3D.

**Gotcha (bots that issue no input are INVALID, not green):** a pursuit/nav_agent scenario with zero inputs in its report is a failed exercise, not a passing one. If `agent_path`/`target_path` don't resolve, or no movement actions match by convention or `actions` override, the bot now reports a violation named `pursuit_bot_config`/`nav_agent_bot_config` instead of silently standing still. Treat either as a scenario misconfiguration: fix the paths or the action mapping and re-run. Observed 09-03: a pursuit run with zero inputs nearly produced a false "vision achieved" report.

**Gotcha:** `nav_agent` needs a baked navigation mesh on the scene's NavigationRegion(s). Without one, `get_next_path_position()` returns the actor's current position, so dx/dy are ~0 and the bot issues **no input at all — silently**. If a nav_agent scenario passes with zero inputs, check `input_count` in the report and verify the scene has a baked navmesh.

---

### Invariant Rules

All invariants are checked every physics tick (not render tick) for deterministic reproducibility.

#### Built-in Rules

| Rule | Parameters | Description |
|------|------------|-------------|
| `no_fatal_errors` | none | Process-level crash detection — verified externally by the playtest skill (`get_debug_output`), not an in-harness check. Fatal errors crash the engine before `_physics_process` can run |
| `nodes_finite` | none | All Node2D/Node3D positions are finite (non-NaN, non-Inf) |
| `no_nan_or_inf` | none | Alias of `nodes_finite` (kept for backward compatibility) |
| `nodes_in_bounds` | `min_x`, `max_x`, `min_y`, `max_y`, `min_z` (opt), `max_z` (opt), `targets` (opt) | **Gameplay-node** positions within configured bounds: physics bodies (PhysicsBody2D/3D) and positioned visuals (Sprite2D/Sprite3D/TextureRect/ColorRect). Structural nodes at origin (scene roots, anchored backgrounds/UI) are exempt by design — flagging them floods reports with false positives (observed 09-04: `/root/root` + a Collision child using offset coords fired 899x/run and masked the real signal). `targets` overrides the default set with explicit node paths or `group:<name>` strings. Z-axis is optional and only checked for Node3D — 2D nodes ignore it. **For a 3D game, always set `min_z`/`max_z` explicitly** — omitting them leaves Z un-checked, so a Node3D drifting along Z would pass |
| `no_null_refs` | none | Scene tree root is valid |
| `frame_time_p99_below` | `value` (ms threshold, default 33.3) | 99th-percentile frame time stays below threshold. The harness warms up first: engine startup spikes (shader compile, resource streaming) register as 25,000-40,000ms "frames" — not game performance (observed 09-04: p99 = 40324ms on a healthy 16ms run). Timing samples only count after 3 consecutive settled (<100ms) ticks |
| `fps_floor` | `value` (min fps, default 30) | Average FPS over last 60 ticks stays above floor. Reports only after sustained violations (>10 consecutive violations) to avoid noise |

#### Custom (Declarative) Rules

Custom invariants use the same declarative `path + check + value` style as built-ins. They are checked every physics tick by the harness — no external polling required. **Use `"rule": "custom"` with a `"check"` operator** (`below`, `above`, `equals`).

Supported path forms:

| Path form | Meaning | Example |
|-----------|---------|---------|
| `_meta.<field>` | Harness metric, read live each tick (`frame_ms_p99`, `input_count`, `fps_floor_violations`) | `"_meta.frame_ms_p99"` |
| `/root/<NodePath>:<state_key>` | Read a game entity's exposed state — uses the node's `get_test_state()` dictionary when present, otherwise `get(<state_key>)` | `"/root/Game/Player:health"` |

```json
{
  "name": "frame_budget",
  "rule": "custom",
  "path": "_meta.frame_ms_p99",
  "check": "below",
  "value": 33.3
}
```

```json
{
  "name": "player_health_positive",
  "rule": "custom",
  "path": "/root/Game/Player:health",
  "check": "above",
  "value": 0
}
```

Note: `frame_ms_p99` is recomputed live during the run for invariant checks (the report's `metrics.frame_ms_p99` is also computed at report time). `below`/`above` only apply to numeric values; use `equals` for non-numeric state.

##### Rate-of-change checking (`max_delta_per_sec`)

Numeric custom invariants can also declare a `max_delta_per_sec` — the tracked value's rate of change (units per second, absolute) must stay below it. Checked every physics tick against the previous tick's sampled value. Use this whenever a counter is supposed to accrue gradually; a per-tick handler bug makes such counters explode.

```json
{
  "name": "score_rate_sane",
  "rule": "custom",
  "path": "/root/Game/ScoreManager:score",
  "check": "above",
  "value": -1,
  "max_delta_per_sec": 5
}
```

**Observed failure this catches (09-03, RallyWall):** a paddle-hit handler re-fired every physics tick while contact persisted — a scripted perfect player racked up 15 points in 0.22s and "won" on the first catch. Point-in-time invariants (`equals`, `below`) cannot see this class of bug; only rate-of-change can. Add a `max_delta_per_sec` to every game-economy counter (score, currency, combo, ammo) sized to a plausible human ceiling.

---

### Metrics

The report includes these metrics collected every physics tick:

| Metric | Type | Description |
|--------|------|-------------|
| `start_frame` | int | Physics frame at test start |
| `end_frame` | int | Physics frame at test end |
| `input_count` | int | Total inputs issued |
| `crash_detected` | bool | Fatal error detected |
| `frame_times` | array | Rolling buffer of last 300 frame times in ms |
| `frame_ms_p99` | float | 99th-percentile frame time (computed at report time) |
| `fps_floor_violations` | int | Count of fps_floor threshold breaches |

---

### Full Scenario Example

```json
{
  "scenario_id": "stress_test",
  "duration_s": 15,
  "bot": {
    "type": "chaos",
    "seed": 42,
    "input_rate_hz": 10
  },
  "invariants": [
    {"name": "no_crash", "rule": "no_fatal_errors"},
    {"name": "no_physics_blowup", "rule": "nodes_finite"},
    {"name": "stay_in_play_area", "rule": "nodes_in_bounds", "min_x": 0, "max_x": 960, "min_y": 0, "max_y": 540},
    {"name": "fps_stable", "rule": "frame_time_p99_below", "value": 33.3},
    {"name": "min_30fps", "rule": "fps_floor", "value": 30}
  ]
}
```

---

## Determinism Guarantee

The harness runs on `_physics_process()`, not `_process()`. This ensures:

1. **Reproducible replay** — Same input log produces identical frame-by-frame results across runs regardless of render load.
2. **Meaningful invariant checks** — NaN/bounds/frame-time violations reflect simulation state, not render hitches.
3. **Consistent metrics** — Frame-time tracking measures physics-tick cost, comparable across different hardware.

## Test Hooks for Entities

All interactive entities should expose state:

```gdscript
extends CharacterBody2D

func _ready():
    add_to_group("test_exposed")

func get_test_state() -> Dictionary:
    return {
        "position": global_position,
        "velocity": velocity,
        "health": get("health")
    }
```

## Verification Strategies

### Fast Path (Invariants)
Run scenario with invariant checker via `run_script`:

```gdscript
start_test(scenario={...})
# ... wait for duration ...
var report = get_test_report()
# Check report.violations.is_empty()
```

### Visual Diagnosis (Screenshots)
Manual visual verification with visible window — for diagnosing reported violations only, never an alternative pass path.
