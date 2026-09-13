---
name: backlog-grooming
description: Select next ready bead from the beads ledger, atomically claim it, and create persistent plan in plans/<bead-slug>.md with link in bead metadata. Use when starting a new task iteration.
---

## What I do

Creates persistent plan for the next ready bead by:
1. Listing claimable beads (`ready`)
2. Atomically claiming the target (racing claimants fail loudly — no pre-claiming dance needed)
3. Writing detailed implementation plan to `plans/<slug>.md`
4. Linking the plan to the bead via metadata
5. Specifying Definition of Done criteria

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

Before writing any plan, claim the bead:

```bash
./.opencode/skills/backlog-grooming/scripts/bd_ledger.sh claim <bead-id>
```

- Exit 0 = you own it (idempotent if already yours).
- Non-zero = someone else has it. Re-run `ready`, pick the next unclaimed bead, claim again. Report `⛔ BLOCKED: no claimable bead after conflict` if none remain — never work an unclaimed bead.

Claiming before planning is what makes parallel delegation safe — the racing-claimant rejection replaces the old pre-claiming (`[in progress]` flips) protocol entirely. Parallel sessions do NOT need the orchestrator to pre-claim tasks anymore.

### Step 3: Create Plan File

Derive the plan filename deterministically — feed the bead's **title** to [scripts/slug.sh](scripts/slug.sh) **one bead per bash call**:

```bash
./.opencode/skills/backlog-grooming/scripts/slug.sh "beads-spike2-abc Create Player entity with movement and collision"
# -> plans/beads-spike2-abc-create-player-entity-with-movement-and-collision.md
```

(Pass `<bead-id> <title>` — slug.sh produces `<prefix>-<slug>.md` keyed by bead ID, so two beads with identical titles never collide and log-result can recover the filename from the bead alone.)

> **One invocation per call, no compounds.** Batching two script calls with `;` or `&&` in one bash invocation gets denied by the granular bash allowlist. Run the script separately per bead.

Read the [full plan template](reference/plan-template.md) once, then write the plan to the derived path. Skeleton:

```markdown
# Bead <id>: <Title>

## Task Type
## Goal
## Files to Create
## Definition of Done ✅
## Visual Verification Needed ⚠️
## Implementation Hints
## Dependencies
## Notes
```

Fill **Definition of Done** with concrete pass/fail items. Include the bead's own acceptance criteria and description (read via `bd_ledger.sh show <id>` if the ready JSON's fields were insufficient).

### Step 4: Link Plan to Bead

```bash
./.opencode/skills/backlog-grooming/scripts/bd_ledger.sh plan_link <bead-id> plans/<slug>.md
```

Exit 0 required. The bead's metadata now points at the plan file — log-result and the build agent recover the path from the ledger, not from markdown state.

## Critical Rules

1. **Claim before planning** — never write a plan for an unclaimed bead. Atomic claim is the only concurrency control.
2. **Claim the targeted bead when specified, else first ready by (priority, creation)** — In sequential runs, don't skip ahead.
3. **Link the plan** — bead metadata `plan=` must point at the plan file
4. **Specific file paths** — Never vague like "create script", say `scripts/x.gd`
5. **DoD checklist concrete** — Each item must be verifiable pass/fail
6. **No scope creep** — Stick to single bead, not multiple features
7. **Execute without questions** — Invention already done in genesis
8. **No post-write re-reads** — After writing the plan file, do NOT re-read it to verify. Trust the write succeeded.
9. **Read only what you need** — Read files only if their content will directly inform the plan: existing scripts for interface design, project.godot for viewport dimensions. Skip README, VISION.md details, unrelated scenes, and any file you won't reference in the plan file.
10. **No repeated directory scans** — one glob call to discover project files; do not glob the same directory multiple times.

## Examples

**Example 1: Player entity bead**

Input (from `ready` JSON):
```json
{"id": "rq-abc123", "title": "Create Player entity with movement and collision", "priority": 0, "labels": ["core"]}
```

Output: claimed `rq-abc123`; plan file at
`plans/rq-abc123-create-player-entity-with-movement-and-collision.md`
whose Files-to-Create section pins the exact scene root, children, and script
shape — following the template's implementation plan sections (full body
templates live in [reference/plan-template.md](reference/plan-template.md);
do not duplicate its code here).

---
*Planning skill. Translates backlog bead into actionable implementation plan.*
