---
name: genesis
description: Initialize the beads ledger with game vision, mechanics, and 10-20 flat task beads (plus a README.md skeleton). Use when starting a new game project to define what gets built.
---

## What I do

Creates the project's tracking state — a **beads ledger** (not markdown) — plus the player-facing README:

### 1. Beads ledger (development backlog)
Contains:
1. **Game title** — Memorable name (not "My Game")
2. **Vision statement** — One sentence capturing emotional core
3. **Core mechanics** — 3-7 gameplay systems listed
4. **Art style** — Visual direction (pixel/vector/minimalist)
5. **Task Backlog** — 10-20 concrete tasks as **flat beads** (no epic), in priority order

Vision/mechanics/art-style live in a `VISION.md` file (small, stable, read often);
tasks live as beads in the ledger (mutated constantly, queried — never re-read wholesale).

### 2. `README.md` (player-facing manual)
Contains:
1. **Game title and one-liner** — What is this game?
2. **Controls section** — Empty skeleton, filled by log-result as features are built
3. **Rules section** — Empty skeleton
4. **Scoring section** — Empty skeleton
5. **Game Flow section** — Empty skeleton
6. **Difficulty section** — Empty skeleton
7. **Art Style section** — Empty skeleton

**README.md is always player-facing.** No task numbers, no WIP markers, no ledger references. It grows incrementally: each log-result fills in the relevant section. At any point it reflects only what's actually built and working.

## Execution

### Step 1: Invent Game Concept

1. Invent game concept with memorable title
2. Write vision statement (emotional core, not just description)
3. List 3-7 core mechanics serving the vision
4. Define art style direction
5. Create 10-20 flat tasks prioritized by dependency
   - First 7 tasks should create playable loop
   - Mix of `core`, `optional`, `future` labels
6. **Create README.md skeleton** with empty sections (filled by log-result later)

### Step 2: Initialize the ledger

Run the ledger helper (single sanctioned entrypoint — agents never call `bd` directly):

```bash
./.opencode/skills/genesis/scripts/bd_ledger.sh init
```

Exit 0 required. If it fails, report `⛔ BLOCKED: bd unavailable — <error>` — do not improvise markdown fallbacks.

### Step 3: Write VISION.md

Use the **write** tool to create `VISION.md`:

```markdown
# [Game Title]

## Vision
[One sentence capturing emotional core]

## Core Mechanics
- [Mechanism 1]
- [Mechania 2]
- [etc]

## Art Style
[Visual direction]
```

### Step 4: Create task beads

Create each backlog task as a bead, one `bd create` per task, via the helper script
`skills/backlog-grooming/scripts/bd_ledger.sh` `create_task` subcommand — or directly:

```bash
bd create "Create Player entity with movement and collision" \
  -t task -l core -p 1 \
  -d "Concrete description of what done looks like" \
  --silent
```

Conventions (load-bearing):
- **Flat backlog only** — NO epics, no `--parent`
- **Title** = imperative, concrete ("Create Player entity with movement and collision"), NOT a vague description
- **Labels**: `core`, `optional`, or `future`
- **Priority**: P0 for the first 7 (playable loop), P1 for the rest, P2 for future
- **Dependencies**: if task B needs task A's output, create A first and pass `--deps blocks:<id-of-A>`... (careful: `--deps` syntax is `'blocks:<id>'` meaning "this blocks that" or "that blocks this"? see `bd dep add --help` — use `bd dep add <blocked-id> <blocking-id>` to wire "B blocked-by A")

**Ordering note:** bd sorts `ready` by priority, then creation order. Create beads in dependency order; wire explicit `blocks` edges only when priority alone won't enforce the sequence.

### How to create README.md

Also create `README.md` with the game title and empty section skeletons. Use the **write** tool. Copy [reference/readme-skeleton.md](reference/readme-skeleton.md) verbatim, substituting the game title and one-line description.

**Important:** The README is NOT a development document. It is a player-facing manual. Sections use `*Filled in as...*` placeholders because at genesis time, nothing exists yet. These placeholders are replaced with polished content during log-result steps.

## Success Criteria ✅

After running this skill, run validation (mandatory):

```bash
./.opencode/skills/genesis/scripts/validate.sh
```

Run from the project root. Exit code must be 0 before declaring success. If it fails, fix the missing state and re-run until it passes.

**Validation checks (deterministic, no interpretation):**
- ✅ `.beads/` ledger exists and opens (`bd list` exits 0)
- ✅ ≥ 10 open task-type beads exist, all with a `core|optional|future` label
- ✅ VISION.md exists with required sections (Vision, Core Mechanics)
- ✅ README.md exists with section skeletons at project root

## Critical Rules

1. **Flat backlog only** — NO epics, direct task beads
2. **Concrete tasks** — Each must be independently implementable
3. **Dependency order** — First tasks should enable later ones
4. **Playable loop first** — First 7 tasks create basic gameplay
5. **Execute without questions** — Invention happens autonomously
6. **Real names** — Not placeholders like "Player", use specific names if appropriate

---
*First creative step. Defines everything that follows.*
