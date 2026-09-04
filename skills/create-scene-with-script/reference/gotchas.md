# Gotchas — Annotated Failure Catalog

> Every entry records an observed real-build failure. Read fully when a triggered gotcha
> blocks you, or when authoring "on hit" effects (re-fire gotcha). This file is
> failure-knowledge, not a to-do list — the SKILL.md checklist links here.

## Instanced node identification
Never identify instanced nodes by `.name` — only the first PackedScene instance keeps its root name. Use groups (`add_to_group("collectibles")`) or type checks instead.

## Unconnected emitted signals
A signal defined and emitted but never connected silently does nothing. Verify every emitted signal has a connection (see SKILL.md Step 5b).

## AudioStreamPlayer ordering
Call `play()` before `get_stream_playback()`, not after.

## Input action names
Use Input action names (`Input.is_action_pressed("move_left")`), never raw key codes.

## Test/QA infrastructure cleanup
Clean up test/QA infrastructure (e.g. `TestPlayer` autoload) before shipping.

## Continuous-contact re-fire (critical)
A collision handler that emits signals or mutates state fires *every physics tick the contact persists* — `move_and_collide` keeps reporting the same contact until the bodies actually separate. A positional "nudge out of penetration" alone often does NOT separate (the next `move_and_collide` still finds the collider).

Guard every "on hit" effect (score, damage, pickups, spawn-on-contact) with a re-fire condition:
- minimum time since last hit on this collider, or
- a separation check (`!move_and_collide` no longer hits the same collider), or
- a state flag cleared on separation

**Verification:** simulate a stationary perfect-contact situation (actor held on the collider for ≥1s) and confirm the effect fires once, not per-tick.

*Observed 09-03:* a paddle-hit score handler re-fired ~68×/sec during contact — a scripted perfect player won the game on one catch (score 0→15 in 0.22s). Caught only by human play; motivated the `max_delta_per_sec` invariant rule in `setup-project/reference/testing-patterns.md`.

## Integration is not optional
An entity that exists as a script/scene but is not added to its parent/main scene is dead code. Verify it in the running scene tree before declaring done (SKILL.md Step 4b).

## Discrete input events
(key press, click) belong in `_input`/`_unhandled_input` or a connected signal — polling `Input.is_key_pressed` in `_process` for a one-shot event (e.g. ESC pause) silently misses it. See [godot-best-practices.md](godot-best-practices.md) §7.

## Never save scene files during a live run
A live engine session serializes runtime node state (positions, velocities) into the scene file. Stop the project first; if entities were mutated during testing, reset them to default values before any save.

## Generated tooling scripts live in `tools/`
Generated asset/tooling scripts belong in the game project's `tools/` directory, never in `.opencode/skills/**` or `skills/**` — those paths are harness code (write-denied anyway). A task needing a throwaway generator (asset importer, SFX synthesizer, format converter) writes it to `tools/` inside the consumer project.

*Observed:* an SFX task wrote 7 helper scripts into a skill directory and burned ~5 minutes writing cleanup scripts to remove them.

## Script edits under a running engine serve stale bytecode
A running Godot process caches compiled script bytecode. Editing a `.gd` file while the engine runs means the live process keeps reporting the OLD errors at OLD line numbers — including parse errors already fixed. Symptom: you edit a file, the reported error still points at the pre-edit line contents or names an identifier you already renamed (observed 09-03: agent fixed a duplicate-var, re-validated, saw the identical error, and hunted a nonexistent second bug for 5+ steps). Fix: `stop_project()` → relaunch → re-register autoload → re-validate. If the reported error doesn't match current file contents, do not debug the file — restart the engine first.
