---
name: genesis
description: Create GAME_STATE.md with game vision, mechanics, and 10-20 flat tasks (plus a README.md skeleton). Use when starting a new game project to define what gets built.
---

## What I do

Creates two files:

### 1. `GAME_STATE.md` (development backlog)
Contains:
1. **Game title** — Memorable name (not "My Game")
2. **Vision statement** — One sentence capturing emotional core
3. **Core mechanics** — 3-7 gameplay systems listed
4. **Art style** — Visual direction (pixel/vector/minimalist)
5. **Task Backlog** — 10-20 concrete tasks in priority order (flat list, no epics)

### 2. `README.md` (player-facing manual)
Contains:
1. **Game title and one-liner** — What is this game?
2. **Controls section** — Empty skeleton, filled by log-result as features are built
3. **Rules section** — Empty skeleton
4. **Scoring section** — Empty skeleton
5. **Game Flow section** — Empty skeleton
6. **Difficulty section** — Empty skeleton
7. **Art Style section** — Empty skeleton

**README.md is always player-facing.** No task numbers, no WIP markers, no backlog references. It grows incrementally: each log-result fills in the relevant section. At any point it reflects only what's actually built and working.

## Execution

### Step 0: Check for lessons (optional, cheap)

`glob("LESSONS.jsonl")`. If it exists in the project root (a human/harness distribution step may place a copy of the harness's accumulated cross-project lessons here), `read()` it and keep in mind any entries whose `tags` are relevant to genre/mechanics you're about to invent (e.g. a lesson tagged `collision` if you're about to design a physics-heavy game). This is a lightweight keyword scan, not mandatory research — if the file doesn't exist, skip this step entirely and proceed normally. **Note:** nothing in this repo generates this file — it's an optional external input from a harness-build session's cross-project analysis (see `AGENTS.md`), not a bug if absent.

### Step 1: Invent Game Concept

1. Invent game concept with memorable title
2. Write vision statement (emotional core, not just description)
3. List 3-7 core mechanics serving the vision
4. Define art style direction
5. Create 10-20 flat tasks prioritized by dependency
   - First 7 tasks should create playable loop
   - Mix of [core], [optional], [future] tags
6. Mark all as `[ ]` (unchecked)
7. **Create README.md skeleton** with empty sections (filled by log-result later)

### How to create GAME_STATE.md

Use the **write** tool to create/update `GAME_STATE.md`. Format:

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

## Task Backlog
- [ ] Task 1: [description] [core]
- [ ] Task 2: [description] [core]
- ... (10-20 total)
```

**Format is load-bearing (do not deviate):** every backlog line MUST start `- [ ] Task N: description`. Downstream tooling matches this literally — backlog-grooming parses it to claim tasks and log-result's validator greps `Task N:` to confirm completion. A bare `- [ ] description` list breaks the validator and sends implementing agents into a failed-validation spiral.

Create the file from scratch using the **write** tool, providing the complete content in one go.

### How to create README.md

After GAME_STATE.md is created, also create `README.md` with the game title and empty section skeletons. Use the **write** tool. Copy [reference/readme-skeleton.md](reference/readme-skeleton.md) verbatim, substituting the game title and one-line description.

**Important:** The README is NOT a development document. It is a player-facing manual. Sections use `*Filled in as...*` placeholders because at genesis time, nothing exists yet. These placeholders are replaced with polished content during log-result steps.

## Success Criteria ✅

After running this skill, run validation (mandatory):

```bash
./.opencode/skills/genesis/scripts/validate.sh
```

Run from the project root. Exit code must be 0 before declaring success. If it fails, fix the missing files and re-run until it passes.

**Validation checks (deterministic, no interpretation):**
- ✅ README.md exists with section skeletons
- ✅ `GAME_STATE.md` exists with required sections (Vision, Core Mechanics, Task Backlog)
- ✅ `README.md` exists at project root

## Critical Rules

1. **Flat backlog only** — NO epics, direct task list
2. **Concrete tasks** — Each must be independently implementable
3. **Dependency order** — First tasks should enable later ones
4. **Playable loop first** — Tasks 1-7 create basic gameplay
5. **Execute without questions** — Invention happens autonomously
6. **Real names** — Not placeholders like "Player", use specific names if appropriate

---
*First creative step. Defines everything that follows.*
