---
name: log-result
description: Close the tracker issue for the completed task and archive the plan file. Use after task implementation is verified. Updates README.md with player-facing content and runs mandatory validation.
---

## What I do

Documents completed work: close the tracker issue, update README, archive plan file, run mandatory validation.

## Definition of Done (all three, no exceptions)

A task is only fully logged when **ALL** of these are true:

1. Plan file renamed to `.completed.md` (Step 2)
2. Tracker issue for the task is `closed` (Step 3)
3. Validation script exits 0 (Step 4)

Archiving the plan but leaving the issue `in_progress` is a HALF-DONE
failure — verify both after writing (Step 3.5 requires listing both as
confirmed).

## Execution

### Step 0: Read Plan File (if exists)

Find the active plan: `glob("plans/*.md")` excluding `.completed.md` — there
is one active plan for the task being logged. (Parallel sessions: your
caller gave you the issue id; the plan is `plans/<id>-*.md`.)

If its "Visual Verification Needed" checklist has any checked box, the implementation MUST have produced a `Scene:`/`Entity:`/`Issues:`/`Verdict:`/`Next:` analysis block.

- **If present:** include in the task result detail.
- **If absent:** do NOT close. Return error: `"BLOCKED: Task <id> requires visual verification but no analysis was provided. Re-run implementation."`

### Step 1: Update README.md

Always update for player-visible changes (controls, scoring, rules, game flow). Skip for pure scaffolding. Write polished present-tense content. No issue ids or backlog references.

### Step 2: Archive Plan File

Run the archive script (moves `plans/<id>-<slug>.md` → `plans/<id>-<slug>.completed.md` deterministically — the plan content never transits your context, so no read/write token cost and no truncation risk):

```bash
./.opencode/skills/log-result/scripts/archive_plan.sh <plan-file-path>
```

Exit 0 = archived (also covers the "already archived" and "plan file doesn't exist" edge cases — the script reports which and you may proceed). Non-zero = genuine failure; fix the cause and retry once, then report `BLOCKED`.

Never archive by reading the plan and re-writing it yourself — that path loses content on large plans and wastes tokens. Never call `mv` directly.

### Step 3: Close the tracker issue

Via the **tracker** skill — poppy-pattern close (two commands, comment then
close):

```bash
bd comment <id> "[poppy] CLOSED: <one-line resolution>"
bd close <id>
```

(If you are not the assignee, the caller (build) delegates the close to the
assignee or ian — see the tracker permission table. Report the issue id
back to the caller either way.)

### Step 3.5: Verify Both Writes (mandatory)

Before validating, confirm BOTH Step 2 and Step 3 landed:

- `plans/<id>-<slug>.completed.md` exists
- `bd show <id>` reports `"status": "closed"`

If either is missing, fix it before proceeding. Returning after only one is
the most common failure of this skill.

### Step 4: Validate (mandatory)

Run validation script:

```bash
./.opencode/skills/log-result/scripts/validate.sh <ISSUE_ID>
```

Exit code must be 0 before declaring success.

### Step 5: Return summary to caller

Your `<task_result>` must contain:

- [x] ISSUE_ID closed in tracker (**confirmed by bd show**)
- [x] Plan file archived to `.completed.md` (**confirmed to exist**)
- [x] Validation script exit code (0 = success)
- [x] List of files created/modified
- [x] Any gotchas encountered

Example:
```
✅ Task logged successfully.

**Changes:**
- Tracker: issue dd-x3k2q closed (resolution: "fixed via dedup")
- Plan file: archived to .completed.md
- Validation: PASS (exit 0)

**Files:**
- scenes/entities/entity.tscn (created)
- scripts/entity.gd (created)
```

### Step 6: Check Completion

`bd list -s open` — if empty, game is complete — trigger final playtest.

---

## Critical Rules

1. Done = plan archived **AND** tracker issue `closed` **AND** validation exit 0 — all three
2. Update all tracking artifacts
3. README is player-facing only
4. Visual evidence gate is the one hard stop
5. No post-write re-reads (except the Step 3.5 verification — that one is mandatory)
6. **MANDATORY:** Validation script must run and exit 0

---
*Documentation skill.*
