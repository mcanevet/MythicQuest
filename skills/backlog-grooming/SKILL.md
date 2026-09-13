---
name: backlog-grooming
description: Select next ready bead from the beads ledger and atomically claim it for work. Use when starting a new task iteration.
---

## What I do

Claims the next ready bead:
1. Listing claimable beads (`ready`)
2. Atomically claiming the target (racing claimants fail loudly — no pre-claiming dance needed)
3. Reading the bead's description and acceptance criteria as the task brief (no plan file — the bead IS the plan)

## Execution

### Step 1: Find Next Ready Bead

Run the ledger helper (single sanctioned entrypoint — agents never call `bd` directly):

```bash
./.opencode/skills/backlog-grooming/scripts/bd_ledger.sh ready
```

Returns JSON of claimable beads — ledger constraints (labels, deps) already applied by bd.

Selection rule:
- If the caller names a specific bead ID or title to own (parallel runs), target exactly that bead.
- Otherwise select the **first ready bead ordered by (priority, creation order)** — do not skip ahead. Sequential discipline preserved: earliest-created among same priority wins.

If `ready` returns an empty array, there is nothing claimable — report that to the caller (may mean: all remaining beads are blocked, or the game is complete).

### Step 2: Claim It (atomic — do this FIRST)

```bash
./.opencode/skills/backlog-grooming/scripts/bd_ledger.sh claim <bead-id>
```

- Exit 0 = you own it (idempotent if already yours).
- Non-zero = someone else has it. Re-run `ready`, pick the next unclaimed bead, claim again. Report `⛔ BLOCKED: no claimable bead after conflict` if none remain — never work an unclaimed bead.

Claiming before planning is what makes parallel delegation safe — the racing-claimant rejection replaces the old pre-claiming protocol entirely. Parallel sessions do NOT need the orchestrator to pre-claim tasks anymore.

### Step 3: Read the Bead Brief

Extract the task specification directly from the bead — its title, description, and acceptance criteria:

```bash
./.opencode/skills/backlog-grooming/scripts/bd_ledger.sh show <bead-id>
```

If description fields are thin, supplement by reading VISION.md sections referenced in the bead's labels — do not invent scope beyond what the bead + vision specify.

## Critical Rules

1. **Claim before working** — never work an unclaimed bead. Atomic claim is the only concurrency control.
2. **Claim the targeted bead when specified, else first ready by (priority, creation)** — In sequential runs, don't skip ahead.
3. **Bead IS the plan** — no plan file is written; the bead's description + acceptance criteria + VISION.md are the full task brief. Implementation detail decisions happen in the implementing agent's context, guided by the bead.
4. **No scope creep** — Stick to single bead, not multiple features.
5. **Execute without questions** — Invention already done in genesis.
6. **Read only what you need** — Read files only if their content will directly inform the work: existing scripts for interface design, project.godot for viewport dimensions. Skip README, unrelated scenes, and any file you won't reference.
7. **No repeated directory scans** — one glob call to discover project files; do not glob the same directory multiple times.

## Examples

**Example: Player entity bead**

Input (from `ready` JSON):
```json
{"id": "rq-abc123", "title": "Create Player entity with movement and collision", "priority": 0, "labels": ["core"]}
```

Output: claimed `rq-abc123`; the bead's description and acceptance criteria are passed verbatim to the implementing agent as the complete task brief.

---
*Planning skill. Translates a backlog bead claim into a task handoff.*
