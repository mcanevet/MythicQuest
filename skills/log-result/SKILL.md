---
name: log-result
description: Close the tracker issue for the completed task, with the resolution comment carrying the report. Use after task implementation is verified. Updates README.md with player-facing content and runs mandatory validation.
---

## What I do

Documents completed work: comment the resolution on the tracker issue,
close it, update README, run mandatory validation. There is no plan file
to archive — the tracker is the single durable task artifact (description
carried the plan, comments carry the result).

## Definition of Done (all three, no exceptions)

A task is only fully logged when **ALL** of these are true:

1. Resolution comment posted on the issue (Step 2)
2. Tracker issue for the task is `closed` (Step 2)
3. Validation script exits 0 (Step 3)

Commenting but leaving the issue `in_progress` is a HALF-DONE failure —
verify both after writing (Step 2.5 requires confirming both).

## Execution

### Step 0: Recall the plan from the issue

Retrieve the issue (`bd show <id> --json`) — its description is the plan
you are logging against. If the description's "Visual Verification Needed"
checklist has any checked box, the implementation MUST have produced a
`Scene:`/`Entity:`/`Issues:`/`Verdict:`/`Next:` analysis block.

- **If present:** include it in the resolution comment.
- **If absent:** do NOT close. Return error: `"BLOCKED: Task <id> requires visual verification but no analysis was provided. Re-run implementation."`

### Step 1: Update README.md

Always update for player-visible changes (controls, scoring, rules, game flow). Skip for pure scaffolding. Write polished present-tense content. No issue ids or backlog references.

### Step 2: Comment the resolution, then close

Via the **tracker** skill — the standard close (two commands, comment then
close):

```bash
bd comment <id> "[<agent>] CLOSED: <one-line resolution>

<files created/modified, validation evidence (exit code, invariant
results), gotchas encountered>"
bd close <id>
```

The comment is the permanent result record — closed issues keep their
description (the plan) and comments (the report) queryable in the tracker
forever. Keep it complete but tight; do not paste logs wholesale.

(If you are not the assignee, the caller delegates the close to the
assignee or the tracker owner — see the tracker permission table. Report the
issue id back to the caller either way.)

### Step 2.5: Verify Both Writes (mandatory)

Before validating, confirm BOTH parts of Step 2 landed:

- `bd show <id>` reports the resolution comment
- `bd show <id>` reports `"status": "closed"`

If either is missing, fix it before proceeding. Returning after only one is
the most common failure of this skill.

### Step 3: Validate (mandatory)

Run validation script:

```bash
./.opencode/skills/log-result/scripts/validate.sh <ISSUE_ID>
```

Exit code must be 0 before declaring success.

### Step 4: Return summary to caller

Your `<task_result>` must contain:

- [x] ISSUE_ID closed in tracker, resolution commented (**confirmed by bd show**)
- [x] Validation script exit code (0 = success)
- [x] List of files created/modified
- [x] Any gotchas encountered

Example:
```
✅ Task logged successfully.

**Changes:**
- Tracker: issue dd-x3k2q closed (resolution: "fixed via dedup")
- Validation: PASS (exit 0)

**Files:**
- scenes/entities/entity.tscn (created)
- scripts/entity.gd (created)
```

### Step 5: Check Completion

`bd list -s open` — if empty, game is complete — trigger final playtest.

---

## Critical Rules

1. Done = resolution comment posted **AND** tracker issue `closed` **AND** validation exit 0 — all three
2. Update all tracking artifacts
3. README is player-facing only
4. Visual evidence gate is the one hard stop
5. No post-write re-reads (except the Step 2.5 verification — that one is mandatory)
6. **MANDATORY:** Validation script must run and exit 0

---
*Documentation skill.*
