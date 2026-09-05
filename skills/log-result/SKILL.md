---
name: log-result
description: Mark task complete in GAME_STATE.md and archive plan file. Use after task implementation is verified. Updates README.md with player-facing content and runs mandatory validation.
---

## What I do

Documents completed work: mark task done, update README, archive plan file, run mandatory validation.

## Definition of Done (all three, no exceptions)

A task is only fully logged when **ALL** of these are true on disk:

1. Plan file renamed to `.completed.md` (Step 2)
2. GAME_STATE.md task line flipped `[in progress]` → `[x]` (Step 3)
3. Validation script exits 0 (Step 4)

Archiving the plan but leaving `[in progress]` is a HALF-DONE failure — verify
both files after writing (Step 5 requires listing both as confirmed).

## Execution

### Step 0: Read Plan File (if exists)

Check for active plan: read the plan file referenced in GAME_STATE.md's `[in progress]` line.

If its "Visual Verification Needed" checklist has any checked box, the implementation MUST have produced a `Scene:`/`Entity:`/`Issues:`/`Verdict:`/`Next:` analysis block.

- **If present:** include in the task result detail.
- **If absent:** do NOT mark `[x]`. Return error: `"BLOCKED: Task <N> requires visual verification but no analysis was provided. Re-run implementation."`

### Step 1: Update README.md

Always update for player-visible changes (controls, scoring, rules, game flow). Skip for pure scaffolding. Write polished present-tense content. No task numbers or backlog references.

### Step 2: Archive Plan File

Run the archive script (moves `plans/<num>-<slug>.md` → `plans/<num>-<slug>.completed.md` deterministically — the plan content never transits your context, so no read/write token cost and no truncation risk):

```bash
./.opencode/skills/log-result/scripts/archive_plan.sh <plan-file-path>
```

Exit 0 = archived (also covers the "already archived" and "plan file doesn't exist" edge cases — the script reports which and you may proceed). Non-zero = genuine failure; fix the cause and retry once, then report `BLOCKED`.

Never archive by reading the plan and re-writing it yourself — that path loses content on large plans and wastes tokens . Never call `mv` directly.

### Step 3: Update GAME_STATE.md

Find and replace `[in progress]` with `[x]` for the current task line. Keep the plan file link (now `.completed.md`).

### Step 3.5: Verify Both Writes (mandatory)

Before validating, confirm BOTH Step 2 and Step 3 landed:

- `plans/<num>-<slug>.completed.md` exists
- The task line in GAME_STATE.md shows `[x]` and no `[in progress]` remains

If either is missing, fix it before proceeding. Returning after only one is
the most common failure of this skill.

### Step 4: Validate (mandatory)

Run validation script:

```bash
./.opencode/skills/log-result/scripts/validate.sh <TASK_ID>
```

Exit code must be 0 before declaring success.

### Step 5: Return summary to caller

Your `<task_result>` must contain:

- [x] TASK_ID marked complete in GAME_STATE.md (**confirmed by re-read**)
- [x] Plan file archived to `.completed.md` (**confirmed to exist**)
- [x] Validation script exit code (0 = success)
- [x] List of files created/modified
- [x] Any gotchas encountered

Example:
```
✅ Task logged successfully.

**Changes:**
- GAME_STATE.md: Task #2 marked [x]
- Plan file: archived to .completed.md
- Validation: PASS (exit 0)

**Files:**
- scenes/entities/entity.tscn (created)
- scripts/entity.gd (created)
```

### Step 6: Check Completion

Count `^- \[ \]` lines in GAME_STATE.md. If zero, game is complete — trigger final playtest.

---

## Critical Rules

1. Done = plan archived **AND** GAME_STATE.md line `[x]` **AND** validation exit 0 — all three
2. Update all tracking files
3. README is player-facing only
4. Visual evidence gate is the one hard stop
5. No post-write re-reads (except the Step 3.5 verification — that one is mandatory)
6. **MANDATORY:** Validation script must run and exit 0

---
*Documentation skill.*
