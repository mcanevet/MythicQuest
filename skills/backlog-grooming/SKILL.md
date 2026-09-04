---
name: backlog-grooming
description: Select next unchecked task from GAME_STATE.md and create persistent plan in plans/<number>-<slug>.md with link in GAME_STATE.md. Use when starting a new task iteration.
---

## What I do

Creates persistent plan for the next unchecked task by:
1. Reading `GAME_STATE.md` to find first `[ ]` task
2. Extracting task number and creating slug from description
3. Marking it as `[in progress]` in `GAME_STATE.md` with link to plan file
4. Writing detailed implementation plan to `plans/<number>-<slug>.md`
5. Specifying Definition of Done criteria

## Execution

### Step 1: Find Next Task

Read `GAME_STATE.md` and locate the next task to plan. If the caller tells you a specific `Task N: <title>` to own (as it does for parallel runs that pre-claim tasks with `[in progress]`), target that exact line. Otherwise, find the **first unchecked task** (format: `- [ ] Task N: description [tag]`).

Use `grep("^- \\[ \\]", "GAME_STATE.md")` to find the first unchecked task, or `grep("^- \\[in progress\\] .*Task N", "GAME_STATE.md")` when targeting a claimed task.

### Step 2: Create Plan File

No directory pre-creation needed — `write()` auto-creates parent directories.

Derive the plan filename deterministically — do not hand-roll the slug. Feed the task line to [scripts/slug.sh](scripts/slug.sh) **one task per bash call**:

```bash
./.opencode/skills/backlog-grooming/scripts/slug.sh "- [ ] Task 3: Create Player entity with movement and collision [core]"
# -> plans/03-create-player-entity-with-movement-and-collision.md
```

> **One invocation per call, no compounds.** Batching two `slug.sh` calls with `;` or `&&` in one bash invocation gets denied by the granular bash allowlist (observed 09-04: compound commands don't match `*scripts/*.sh*` even though each part does; the agent burned 2 denials before splitting them). Run the script separately per task.

Read the [full plan template](reference/plan-template.md) once, then write the plan to `plans/<num>-<slug>.md` using it. Skeleton:

### Step 3: Update GAME_STATE.md

Change the task status and add link to plan file:

**Before:**
```markdown
- [ ] Task 3: Create Player entity with movement and collision [core]
```

**After:**
```markdown
- [in progress] Task 3: Create Player entity with movement and collision [core] (see: plans/03-create-player-entity-with-movement-and-collision.md)
```

```markdown
# Task <N>: <Task Title>

## Task Type
## Goal
## Files to Create
## Definition of Done ✅
## Visual Verification Needed ⚠️
## Implementation Hints
## Dependencies
## Notes
```

## Critical Rules

1. **Select the targeted task when specified, else first unchecked** — In sequential runs, don't skip ahead (first unchecked, maintain order). When the caller names a specific `Task N` (parallel pre-claiming), target that exact line — it's already `[in progress]` with a link, so repurpose its plan file rather than re-claiming.
2. **Update both files** — GAME_STATE.md AND create plan file in `plans/`
3. **Specific file paths** — Never vague like "create script", say `scripts/x.gd`
4. **DoD checklist concrete** — Each item must be verifiable pass/fail
5. **No scope creep** — Stick to single task, not multiple features
6. **Execute without questions** — Invention already done in genesis
7. **No post-write re-reads** — After writing GAME_STATE.md and the plan file, do NOT re-read them to verify. Trust the write succeeded. Re-reading wastes tool calls.
8. **Read only what you need** — Read files only if their content will directly inform the plan: existing scripts for interface design, project.godot for viewport dimensions. Skip README, unrelated scenes, CONVENTIONS.md, and any file you won't reference in the plan file.
9. **No repeated directory scans** — To discover existing project files, use one glob call (e.g. `glob("**/*.gd")`). Do not call glob on the same directory multiple times with different patterns.

## Examples

**Example 1: Player entity task**

Input (from GAME_STATE.md):
```
- [ ] Task 1: Create Player entity with movement and collision [core]
```

Output (plan file excerpt):
```
## Files to Create
### `scenes/entities/player.tscn`
- Root: CharacterBody2D named "Player"
- Children: Sprite2D, CollisionShape2D (RectangleShape2D 32x48)

### `scripts/player.gd`
extends CharacterBody2D
@export var speed = 400
func _physics_process(delta):
    var input_dir = Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    )
    velocity = input_dir * speed
    move_and_slide()
```

**Example 2: Score UI task**

Input (from GAME_STATE.md):
```
- [ ] Task 2: Add score display with increment on goal [core]
```

Output (plan file excerpt):
```
## Files to Create
### `scenes/ui/score_display.tscn`
- Root: Control named "ScoreUI"
- Children: Label named "ScoreLabel" (text: "0", anchor: top-center)

### `scripts/score_ui.gd`
extends Control
var score = 0
func update_score(new_score):
    score = new_score
    $ScoreLabel.text = str(score)
```

---
*Planning skill. Translates backlog item into actionable implementation plan.*
