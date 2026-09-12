---
name: backlog-grooming
description: Select next open task from the tracker, claim it in_progress, and prepare for implementation from the issue's own description. Use when starting a new task iteration.
---

## What I do

Claims the next task by:
1. Querying the tracker (`bd list`) to find the first `open` issue
2. Reading the issue's description — that description IS the implementation
   plan (seeded at issue creation; no separate plan file exists)
3. Marking the issue `in_progress` in the tracker

There are no plan files. The tracker is the single durable task artifact:
description carries the plan, comments carry the result. This is contract
v2 (see `plugins/tracker/README.md`): plans live in the tracker's native
description field, never in mirrored files.

## Execution

### Step 1: Find Next Task

Query the tracker via the **tracker** skill (your bd allowlist has the
read patterns): `bd list --json` gives all open issues in priority order.
If the caller tells you a specific issue id to own (as it does for
parallel runs that pre-claim tasks), target that exact issue. Otherwise,
take the **first `open` issue** in list order.

Fields you need: `id`, `title`, `issue_type`, `labels` (the `reporter:`
label tells you which loop filed it), and **`description`** — read it
via `bd show <id> --json` if the list view truncates it.

### Step 2: Read the Plan (from the issue)

The description is structured: Task Type, Goal, Files to Create,
Definition of Done, Visual Verification Needed, Implementation Hints,
Dependencies. Read it and hold it in context — do not restate it, do not
rewrite it, do not persist it anywhere.

If the description is thin (a one-liner with no DoD), that is a genesis
defect: report `⛔ BLOCKED: issue <id> has no implementation plan in its
description — ask build to have genesis enrich it` and stop. Do not invent
requirements on the caller's behalf.

### Step 3: Claim the issue in the tracker

Mark the issue in progress (tracker skill, the standard claim command):

```bash
bd update <id> -s in_progress
```

If the issue is already `in_progress`, another session claimed it — stop
and report; do not double-claim (caller handles assignment in parallel
runs, so this normally only happens on races).

## Critical Rules

1. **Select the targeted task when specified, else first open issue** — in sequential runs, don't skip ahead (first open, maintain list order). When the caller names a specific issue id (parallel pre-claiming), target that exact issue — it's already `in_progress`.
2. **The description is the plan** — never transcribe it into a file, never
   summarize it before acting; act from it directly.
3. **Specific file paths** — If the description is vague ("create script"), that's the blocker from Step 2, not license to improvise paths.
4. **No scope creep** — Stick to single task, not multiple features
5. **Execute without questions** — Invention already happened in genesis
6. **No repeated directory scans** — To discover existing project files, use one glob call (e.g. `glob("**/*.gd")`). Do not call glob on the same directory multiple times with different patterns.
7. **Read only what you need** — Read files only if their content will directly inform implementation: existing scripts for interface design, project.godot for viewport dimensions. Skip README, unrelated scenes, CONVENTIONS.md.

## Examples

**Example 1: Player entity task**

Input (from `bd show dd-x3k2q --json`):

```json
{"id": "dd-x3k2q", "title": "Create Player entity with movement and collision", "issue_type": "core", "status": "open", "labels": ["reporter:ian"], "description": "## Task Type\nscene+script\n## Goal\n...\n## Definition of Done\n- [ ] paddle responds to move_left/move_right\n..."}
```

Output: `bd update dd-x3k2q -s in_progress`, then implement per the
description's Files-to-Create and DoD sections. Nothing is written to
disk except the deliverables themselves.

---
*Claiming skill. Hands the caller an issue whose description is its plan.*
