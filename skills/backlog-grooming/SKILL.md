---
name: backlog-grooming
description: Select next open task from the tracker, mark it in_progress, and create persistent plan in plans/<id>-<slug>.md. Use when starting a new task iteration.
---

## What I do

Creates a persistent plan for the next task by:
1. Querying the tracker (`bd list`) to find the first `open` issue
2. Creating a slug from the issue title
3. Marking the issue `in_progress` in the tracker
4. Writing a detailed implementation plan to `plans/<id>-<slug>.md`
5. Specifying Definition of Done criteria

Plan association is by filename prefix (`plans/<id>-*`) — there is no
stored link anywhere; find a task's plan with `glob("plans/<id>-*.md")`.

## Execution

### Step 1: Find Next Task

Query the tracker via the **tracker** skill (your bd allowlist has the
read patterns): `bd list --json` gives all open issues in priority order.
If the caller tells you a specific issue id to own (as it does for
parallel runs that pre-claim tasks), target that exact issue. Otherwise,
take the **first `open` issue** in list order.

Fields you need: `id`, `title`, `issue_type`, `labels` (the `reporter:`
label tells you which loop filed it), and dependencies if shown.

### Step 2: Create Plan File

No directory pre-creation needed — `write()` auto-creates parent directories.

Derive the plan filename deterministically — do not hand-roll the slug. Feed
the issue id and title to [scripts/slug.sh](scripts/slug.sh) **one task per
bash call**:

```bash
./.opencode/skills/backlog-grooming/scripts/slug.sh "dd-x3k2q" "Create Player entity with movement and collision"
# -> plans/dd-x3k2q-create-player-entity-with-movement-and-collision.md
```

> **One invocation per call, no compounds.** Batching two `slug.sh` calls with `;` or `&&` in one bash invocation gets denied by the granular bash allowlist (compound commands don't match `*scripts/*.sh*` even though each part does). Run the script separately per task.

Read the [full plan template](reference/plan-template.md) once, then write the plan to the filename slug.sh printed, using it. Skeleton:

```markdown
# Task <id>: <Task Title>

## Task Type
## Goal
## Files to Create
## Definition of Done ✅
## Visual Verification Needed ⚠️
## Implementation Hints
## Dependencies
## Notes
```

### Step 3: Claim the issue in the tracker

Mark the issue in progress (tracker skill, poppy-pattern command):

```bash
bd update <id> -s in_progress
```

## Critical Rules

1. **Select the targeted task when specified, else first open issue** — in sequential runs, don't skip ahead (first open, maintain list order). When the caller names a specific issue id (parallel pre-claiming), target that exact issue — it's already `in_progress`, so repurpose its plan file rather than re-claiming.
2. **Update both** — claim in the tracker AND create the plan file
3. **Specific file paths** — Never vague like "create script", say `scripts/x.gd`
4. **DoD checklist concrete** — Each item must be verifiable pass/fail
5. **No scope creep** — Stick to single task, not multiple features
6. **Execute without questions** — Invention already happened in genesis
7. **No post-write re-reads** — After the tracker update and writing the plan file, do NOT re-read them to verify. Trust the write succeeded. Re-reading wastes tool calls.
8. **Read only what you need** — Read files only if their content will directly inform the plan: existing scripts for interface design, project.godot for viewport dimensions. Skip README, unrelated scenes, CONVENTIONS.md, and any file you won't reference in the plan file.
9. **No repeated directory scans** — To discover existing project files, use one glob call (e.g. `glob("**/*.gd")`). Do not call glob on the same directory multiple times with different patterns.

## Examples

**Example 1: Player entity task**

Input (from `bd list --json`):

```json
{"id": "dd-x3k2q", "title": "Create Player entity with movement and collision", "issue_type": "core", "status": "open", "labels": ["reporter:ian"]}
```

Output: a plan file at
`plans/dd-x3k2q-create-player-entity-with-movement-and-collision.md`
whose Files-to-Create section pins the exact scene root, children, and
script shape — following the template's implementation plan sections (full
body templates live in [reference/plan-template.md](reference/plan-template.md);
do not duplicate its code here) — and `bd update dd-x3k2q -s in_progress`.

---
*Planning skill. Translates backlog item into actionable implementation plan.*
