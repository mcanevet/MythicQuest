---
name: tracker-beads
description: Create, update, comment on, or query tracker issues and milestones via the Beads (bd) CLI. Use when reporting a bug (Rachel), filing critique or vision feedback (Pootie/Ian), updating issue status or assigning work (Poppy), or coordinating tasks through the tracker instead of GAME_STATE.md. Applies per-role tracker permission rules.
---

## What I do

Implements the tracker plugin's Beads backend. There is **no adapter
script** — agents call the `bd` CLI directly from bash. This skill defines
the sanctioned bd invocations per tracker operation, the role-permission
rules that constrain which ones you may run, and the transition-period
compatibility append to `GAME_STATE.md`.

Interface contract: [../README.md](../README.md) — the operation set and
permission table below are the Beads implementation of it.

## Execution steps

### Step 0: One-time setup (per project)

The `bd` binary is provided by mise (repo root `mise.toml` pins
`aqua:gastownhall/beads`) — run through `mise exec -- bd ...` or after
`mise install`. If `tracker/` (the bd database) does not exist yet:

```bash
bd init --prefix dd
bd config set types.custom "vision,critique,material,animation,audio,refactor,core"
```

Custom types registration prints a warning; it works — verify with
`bd types`. bd writes into `.beads/` (JSONL, git-persisted via `bd export`).
Run `bd export` after any write so the on-disk JSONL is current.

### Step 1: Check the permission table

Deny-first: an operation not listed for your role is forbidden. Enforcement
is mixed — each row below says whether it is machine-enforced by the bash
allowlist or a **norm** you must apply yourself:

| Operation | ian | poppy | rachel | pootie | Enforcement |
|---|---|---|---|---|---|
| create_milestone | ✓ | — | — | — | allowlist (`bd create -t milestone`) |
| create_issue | any | any | `bug` only | `critique` only | allowlist (`-t` patterns) |
| update_issue_status | — | ✓ | — | — | allowlist (`bd update`) |
| close_issue | own only | assigned-to-self only | — | — | **norm** + allowlist (`bd close`) |
| assign_issue | ✓ | — | — | — | allowlist (`bd assign`) |
| add_label | ✓ | ✓ | — | — | allowlist (`bd tag`) |
| add_comment | any | any | any | own only | allowlist (`bd comment`); "own only" is a **norm** |
| list_issues | ✓ | ✓ | ✓ | ✓ | allowlist (`bd list`) |

Norm rows are not machine-checked — you are trusted to comply. Before a
conditional close or a pootie comment, verify scope with `bd show <id>`
(check `assignee` for poppy-close; the `reporter:<agent>` label for
ian-close and pootie-comment). Violating a norm is a protocol breach even
though the command would succeed.

### Step 2: Run the bd command

Mapping from contract operations to bd (one bash invocation per call, no
compounds):

| Contract operation | bd command |
|---|---|
| create_issue | `bd create --silent "<title>" -t <type> -d "<body>" -l reporter:<agent> [-l labels] [-a assignee] [--parent <milestone-id>] --actor <agent>` |
| create_milestone | `bd create --silent "<title>" -t milestone -d "<description>" [--due YYYY-MM-DD] --actor ian` |
| update_issue_status | `bd update <id> -s open\|in_progress\|blocked\|closed` |
| assign_issue | `bd assign <id> <who>` |
| add_label | `bd tag <id> <label>` |
| add_comment | `bd comment <id> "[<agent>] <body>"` |
| close_issue | `bd comment <id> "[<agent>] CLOSED: <resolution>"` then `bd close <id>` |
| link_issue | `bd dep <id> --blocks <t>` (id blocks t) / `bd dep add <id> <t>` (id blocked by t) / `bd dep relate <a> <b>` |
| list_issues | `bd list --json [-s status] [-a assignee]` (filter label/milestone client-side) |

Notes:

- Always pass `--actor <agent>` on create and prefix comments with
  `[<agent>]` — bd has no caller identity of its own, so these are the
  reporter/author records. The `reporter:<agent>` label created at issue
  birth is what ian's and pootie's own-only norms key on.
- `bd create --silent` prints just the new id. Ids are `<prefix>-<hash>`
  (e.g. `dd-yan`) — opaque, quote them, never invent or truncate one.
- After any mutating command, run `bd export` (persistence).
- Close is a two-command sequence (comment then close) so the resolution
  survives as an append-only record; never close without the comment.

### Step 3: Compatibility layer (create_issue only)

After a successful create, append the equivalent line to `GAME_STATE.md`
yourself (there is no script to do it):

```
- [ ] Issue <id>: <title> [<type>]
```

Exactly one line per created issue, appended at the end of the backlog
section — no reordering, no duplicates. Removed once backlog-grooming and
log-result read the tracker directly.

### Step 4: Logical-field → bd-JSON mapping

The contract's issue fields map onto bd as follows (this mapping is what
makes a future `github-projects` backend a data export, not a redesign):

| Contract field | bd representation |
|---|---|
| id | opaque `<prefix>-<hash>` |
| title / body | `title` / `description` |
| type | `issue_type` (custom types registered via Step 0) |
| status | `status` |
| labels | `labels` (convention: `reporter:<agent>` recorded at creation) |
| milestone | parent-child edge (`--parent`) |
| assignee | `assignee` (via `bd assign`) |
| reporter | `reporter:<agent>` label (bd's `created_by`/`--actor` is a human identity, not a role) |
| blocks / blocked_by / relates_to | `bd dep <id> --blocks <t>` / `bd dep add <id> <t>` / `bd dep relate <a> <b>` |
| comments | append-only; author embedded in text (`[<agent>] <body>`) |

## Critical rules

1. **Permission table is deny-first** — never run a bd command outside
   your role's rows; norm-enforced rows additionally require the scope
   check in Step 1.
2. **Comments are append-only** — never edit or delete an existing comment.
3. **Ids are opaque hashes** — copy them verbatim from bd output; never
   guess, abbreviate, or reuse a seen prefix in new contexts.
4. **One bash invocation per bd call** — no compounds (`;`, `&&`); the
   granular bash allowlist denies compound commands even when each part is
   allowlisted.
5. **Never touch `.beads/` or exported JSONL with file edits** — all
   mutations go through `bd` (read-only `read`/`grep` for debugging is
   fine).
6. **Report bd failures verbatim** — a non-zero bd exit is a structured
   failure (`⛔ BLOCKED: bd <cmd> failed: <stderr>`), not a workaround
   situation; do not retry the identical call.

## Examples

**Rachel files a bug found in playtest:**

```bash
bd create --silent "Pearl counter desyncs after rapid collection" -t bug -d "Counter showed 14 after collecting 12 pearls in zone 3..." -l reporter:rachel -l qa-verified --actor rachel
# -> dd-xyz123 ; then append "- [ ] Issue dd-xyz123: Pearl counter desyncs after rapid collection [bug]" to GAME_STATE.md
bd export
```

**Poppy claims a bug (assigned by ian, then status):**

```bash
bd assign dd-xyz123 poppy          # run by ian
bd update dd-xyz123 -s in_progress
bd export
```

**Poppy closes an issue assigned to her:**

```bash
bd show dd-xyz123                  # verify assignee == poppy (norm)
bd comment dd-xyz123 "[poppy] CLOSED: fixed via pearl dedup"
bd close dd-xyz123
bd export
```

**Pootie files a critique; must NOT comment on rachel's bug (norm):**

```bash
bd create --silent "Upgrade screen buries reroll" -t critique -d "..." -l reporter:pootie --actor pootie
bd show dd-abc456                 # shows reporter:pootie label → own filing → commenting allowed
```

---
*Tracker backend skill. Interface contract: [../README.md](../README.md).*
