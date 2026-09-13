---
name: log-result
description: Close the completed bead in the ledger and archive plan file. Use after task implementation is verified. Updates README.md with player-facing content and runs mandatory validation.
---

## What I do

Documents completed work: close bead, update README, archive plan file, run mandatory validation.

## Definition of Done (all three, no exceptions)

A task is only fully logged when **ALL** of these are true:

1. Plan file renamed to `.completed.md` (Step 2)
2. Bead status is `closed` in the ledger (Step 3)
3. Validation script exits 0 (Step 4)

Archiving the plan but leaving the bead `in_progress` is a HALF-DONE failure — verify
both after writing (Step 3.5 requires listing both as confirmed).

## Execution

### Step 0: Read Plan File (if exists)

Recover the active plan from the ledger — the claimed bead's metadata carries the path:

```bash
./.opencode/skills/log-result/scripts/bd_ledger.sh show <bead-id> --field metadata
```

(or take the bead id + plan path directly from the caller's task result).

If the plan's "Visual Verification Needed" checklist has any checked box, the implementation MUST have produced a `Scene:`/`Entity:`/`Issues:`/`Verdict:`/`Next:` analysis block.

- **If present:** include in the task result detail.
- **If absent:** do NOT close. Return error: `"BLOCKED: Bead <id> requires visual verification but no analysis was provided. Re-run implementation."`

### Step 1: Update README.md

Always update for player-visible changes (controls, scoring, rules, game flow). Skip for pure scaffolding. Write polished present-tense content. No bead IDs or ledger references.

### Step 2: Archive Plan File

Run the archive script (moves `plans/<slug>.md` → `plans/<slug>.completed.md` deterministically — the plan content never transits your context, so no read/write token cost and no truncation risk):

```bash
./.opencode/skills/log-result/scripts/archive_plan.sh <plan-file-path>
```

Exit 0 = archived (also covers the "already archived" and "plan file doesn't exist" edge cases — the script reports which and you may proceed). Non-zero = genuine failure; fix the cause and retry once, then report `BLOCKED`.

Never archive by reading the plan and re-writing it yourself — that path loses content on large plans and wastes tokens. Never call `mv` directly.

### Step 3: Close the Bead

```bash
./.opencode/skills/log-result/scripts/bd_ledger.sh close <bead-id> "<one-line completion reason>"
```

Exit 0 required. Closing releases dependents — beads blocked on this one become `ready` for the next grooming pass automatically (no manual status flipping in markdown).

If the implementation took retries, close still proceeds — the attempt count lives in bead metadata (`bd_ledger.sh attempts`), incremented by the caller on retry delegations.

### Step 3.5: Verify Both Writes (mandatory)

Before validating, confirm BOTH Step 2 and Step 3 landed:

- `plans/<slug>.completed.md` exists
- `bd_ledger.sh show <bead-id> --field status` returns `closed`

If either is missing, fix it before proceeding. Returning after only one is
the most common failure of this skill.

### Step 4: Validate (mandatory)

Run validation script:

```bash
./.opencode/skills/log-result/scripts/validate.sh <BEAD_ID>
```

Exit code must be 0 before declaring success.

### Step 4a: Ledger Backup

Snapshot the ledger after each closed task (cheap, one JSONL export — protects against ledger corruption losing multi-session history):

```bash
./.opencode/skills/log-result/scripts/bd_ledger.sh backup
```

Non-zero = report but do not fail the task — the close already landed; note it as a gotcha.

### Step 5: Return summary to caller

Your `<task_result>` must contain:

- [x] BEAD_ID closed in ledger (**confirmed by show --field status**)
- [x] Plan file archived to `.completed.md` (**confirmed to exist**)
- [x] Validation script exit code (0 = success)
- [x] List of files created/modified
- [x] Any gotchas encountered

Example:
```
✅ Bead logged successfully.

**Changes:**
- Ledger: beads-rq-9f2 marked closed (reason: Player moves with WASD, collision verified)
- Plan file: archived to .completed.md
- Validation: PASS (exit 0)

**Files:**
- scenes/entities/entity.tscn (created)
- scripts/entity.gd (created)
```

### Step 6: Check Completion

```bash
./.opencode/skills/log-result/scripts/bd_ledger.sh complete_check
```

Exit 0 = no open beads remain — trigger final playtest. Exit 1 = beads remain.

---

## Critical Rules

1. Done = plan archived **AND** bead `closed` **AND** validation exit 0 — all three
2. Update all tracking state (ledger + README)
3. README is player-facing only
4. Visual evidence gate is the one hard stop
5. No post-write re-reads (except the Step 3.5 verification — that one is mandatory)
6. **MANDATORY:** Validation script must run and exit 0
7. **bd goes through the helper script** — never call `bd` directly; on helper failure report `⛔ BLOCKED: ledger error — <msg>`, do not fall back to markdown

---
*Documentation skill.*
