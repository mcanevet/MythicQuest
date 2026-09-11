---
name: genesis
description: Create GAME_STATE.md charter (game vision, mechanics, art style), seed the tracker queue with 10-20 tasks via the tracker skill, and create a README.md skeleton. Use when starting a new game project to define what gets built.
---

## What I do

Creates the project's founding artifacts:

1. **`GAME_STATE.md`** — the charter: game title, vision, core mechanics,
   art style. Read-only after this skill; it contains **no task lines**
   (the task queue lives in the tracker).
2. **Tracker queue** — 10-20 concrete tasks seeded into the tracker
   (milestone + issues) via the tracker skill.
3. **`README.md`** — player-facing manual skeleton.

## Execution

### Step 1: Invent Game Concept

1. Invent game concept with memorable title
2. Write vision statement (emotional core, not just description)
3. List 3-7 core mechanics serving the vision
4. Define art style direction
5. Draft 10-20 flat tasks prioritized by dependency
   - First 7 tasks should create playable loop
   - Mix of types: `core` (must-have), `polish`/`vision` (optional/future)
6. Create README.md skeleton with empty sections (filled by log-result later)

### Step 2: Write the GAME_STATE.md charter

Use the **write** tool, complete content in one go:

```markdown
# [Game Title]

## Vision
[One sentence capturing emotional core]

## Core Mechanics
- [Mechanism 1]
- [Mechanism 2]
- [etc]

## Art Style
[Visual direction]
```

The charter never changes after this step — later phases read it for
vision alignment; all task state lives in the tracker.

### Step 3: Seed the tracker

Invoke the **tracker** skill (`skill({ name: "tracker" })`) for every tracker
operation below. One issue per create — no batching:

**Prerequisite (fail loudly, never bootstrap):** the tracker must already be
initialized (`setup-project` owns init — platform bootstrapping is
implementation work, not creative). If the tracker is missing or empty of
configuration (Beads: no `.beads/`), report
`⛔ BLOCKED: tracker not initialized — run setup-project first` and stop.
Do not run init commands yourself.

1. Create one milestone for the playable-loop arc, e.g.
   `create_milestone "Playable Loop" --description "<from concept>"`.
2. `create_issue` for each drafted task, in dependency order:
   `-t core|polish|vision`, `-l reporter:ian --actor ian`, `--parent <milestone-id>` for
   playable-loop tasks.
   **The `-d "<description>"` is the implementation plan** — there are no
   plan files; the description IS what poppy implements from and what
   log-result validates against. Follow the structure in
   [reference/plan-template.md](reference/plan-template.md)
   (Task Type / Goal / Files to Create / Definition of Done /
   Visual Verification Needed / Implementation Hints / Dependencies) —
   compressed to the essentials per task, not copied wholesale: pin exact
   file paths, concrete pass/fail DoD items (5-7), and named input actions.
   A thin one-liner description blocks the implementer (they must fail
   loudly rather than invent requirements).
3. Record the milestone id and issue ids from command output — the caller
   cites them in delegation prompts (`bd show <id>` retrieves the plan).

### Step 4: Create README.md

Copy [reference/readme-skeleton.md](reference/readme-skeleton.md) verbatim,
substituting the game title and one-line description (write tool).

**Important:** The README is NOT a development document. It is a
player-facing manual. Sections use `*Filled in as...*` placeholders because
at genesis time, nothing exists yet.

## Success Criteria ✅

After running this skill, run validation (mandatory):

```bash
./.opencode/skills/genesis/scripts/validate.sh
```

Run from the project root. Exit code must be 0 before declaring success.
If it fails, fix the missing files/state and re-run until it passes.

**Validation checks (deterministic, no interpretation):**
- ✅ `GAME_STATE.md` exists with required sections (Vision, Core Mechanics)
- ✅ Tracker has ≥10 issues, all `open` status, each with a `reporter:` label
- ✅ `README.md` exists at project root

## Critical Rules

1. **Charter has no task lines** — GAME_STATE.md ends at Art Style; the
   queue lives in the tracker. A `- [ ]` line in GAME_STATE.md breaks the
   division of state and confuses readers expecting the old scheme.
2. **Flat backlog only** — NO epics, direct task list in the tracker
3. **Concrete tasks** — Each must be independently implementable
4. **Dependency order** — First tasks should enable later ones
5. **Playable loop first** — First 7 issues create basic gameplay
6. **Execute without questions** — Invention happens autonomously
7. **Real names** — Not placeholders like "Player", use specific names if appropriate

---
*First creative step. Defines everything that follows.*
