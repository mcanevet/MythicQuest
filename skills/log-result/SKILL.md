---
name: log-result
description: Close the completed bead in the ledger and run mandatory validation. Use after task implementation is verified. Updates README.md with player-facing content.
---

## What I do

Documents completed work: close bead, update README, run mandatory validation.

## Definition of Done (all three, no exceptions)

A task is only fully logged when **ALL** of these are true:

1. Bead status is `closed` in the ledger (Step 2)
2. Validation script exits 0 (Step 3)
3. README.md updated (if applicable, Step 1)

Closing the bead without running validation is a HALF-DONE failure — verify both after writing.

## Execution

### Step 0: Verify Implementation Completeness

Check the bead's description for any "Visual Verification Needed" or acceptance criteria that require runtime verification. If the implementation should have produced a `Scene:`/`Entity:`/`Issues:`/`Verdict:`/`Next:` analysis block but didn't, do NOT close. Return error: `"BLOCKED: Bead <id> requires visual verification but no analysis was provided. Re-run implementation."`

### Step 1: Update README.md

Always update for player-visible changes (controls, scoring, rules, game flow). Skip for pure scaffolding. Write polished present-tense content. No bead IDs or ledger references.

### Step 2: Close the Bead

```bash
./.opencode/skills/log-result/scripts/bd close <bead-id> "<one-line completion reason>"
```

Exit 0 required. Closing releases dependents — beads blocked on this one become `ready` for the next grooming pass automatically (no manual status flipping).

If the implementation took retries, close still proceeds — the attempt count lives in bead metadata (`bd show <id> --json` → `metadata.attempts`), incremented by the caller on retry delegations.

### Step 2.5: Verify Close Landed (mandatory)

Before validating, confirm the close landed:

- `bd show <bead-id> --json` → `status` is `closed`

If missing, fix it before proceeding. Returning after only a partial close is the most common failure of this skill.

### Step 3: Validate (mandatory)

Run validation script:

```bash
./.opencode/skills/log-result/scripts/validate.sh <BEAD_ID>
```

Exit code must be 0 before declaring success.

### Step 3a: Ledger Backup

Snapshot the ledger after each closed task (cheap, one JSONL export — protects against ledger corruption losing multi-session history):

```bash
./.opencode/skills/log-result/scripts/bd update --set-metadata backed_up=true
```

Non-zero = report but do not fail the task — the close already landed; note it as a gotcha.

### Step 4: Return summary to caller

Your `<task_result>` must contain:

- [x] BEAD_ID closed in ledger (**confirmed by `bd show <id> --json`**)
- [x] Validation script exit code (0 = success)
- [x] List of files created/modified
- [x] Any gotchas encountered

Example:
```
✅ Bead logged successfully.

**Changes:**
- Ledger: beads-rq-9f2 marked closed (reason: Player moves with WASD, collision verified)
- Validation: PASS (exit 0)

**Files:**
- scenes/entities/entity.tscn (created)
- scripts/entity.gd (created)
```

### Step 5: Check Completion

```bash
./.opencode/skills/log-result/scripts/bd list --status open,in_progress
```

Exit 0 = no open beads remain — trigger final playtest. Exit 1 = beads remain.

---

## Critical Rules

1. Done = bead `closed` **AND** validation exit 0 — both
2. Update all tracking state (ledger + README)
3. README is player-facing only
4. Visual evidence gate is the one hard stop
5. No post-write re-reads (except the Step 2.5 verification — that one is mandatory)
6. **MANDATORY:** Validation script must run and exit 0
7. **bd goes through the helper script** — never call `bd` directly; on helper failure report `⛔ BLOCKED: ledger error — <msg>`, do not fall back to markdown

---
*Documentation skill.*
