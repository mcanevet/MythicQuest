---
name: tracker
description: Create, update, comment on, or query tracker issues and milestones via the Beads (bd) CLI. Use when grooming the backlog, reporting a bug (Rachel), filing critique or vision feedback (Pootie/Ian), updating issue status or assigning work (Poppy), or anytime a skill needs the tracker. Applies per-role tracker permission rules.
---

## What I do

The Beads implementation of the tracker plugin contract
([../README.md](../README.md)). There is **no adapter script** — agents call
the `bd` CLI directly from bash. This skill defines the sanctioned bd
invocations per contract operation, and the role-permission rules that constrain which ones you may run.

## Execution steps

### Step 0: One-time setup (per project — owned by setup-project)

Init is owned by the **setup-project** skill (executed by poppy or solo) —
it runs these commands as part of platform bootstrap, BEFORE genesis seeds
the queue. Creative/QA agents (ian, rachel, pootie) never run them; if they
find the tracker uninitialized they report
`⛔ BLOCKED: tracker not initialized — run setup-project first`.

The `bd` binary is provided by mise (repo root `mise.toml` pins
`aqua:gastownhall/beads`) — run through `mise exec -- bd ...` or after
`mise install`. If the bd database (`.beads/`) does not exist yet:

```bash
bd init --prefix dd
bd config set types.custom "vision,critique,material,animation,audio,refactor,core"
```

Custom types registration prints a warning; it works — verify with
`bd types`.

### Step 1: Check the permission table

Deny-first: an operation not listed for your role is forbidden. Enforcement
is mixed — each row below says whether it is machine-enforced by the bash
allowlist or a **norm** you must apply yourself:

| Operation | ian | poppy | rachel | pootie | phil | Enforcement |
|---|---|---|---|---|---|---|
| create_milestone | ✓ | — | — | — | — | allowlist (`bd create -t milestone`) |
| create_issue | any | any | `bug` only | `critique` only | `material` only | allowlist (`-t` patterns) |
| update_issue_status | — | ✓ | — | — | — | allowlist (`bd update`) |
| close_issue | own only | assigned-to-self only | — | — | — | **norm** + allowlist (`bd close`) |
| assign_issue | ✓ | — | — | — | — | allowlist (`bd assign`) |
| add_label | ✓ | ✓ | — | — | — | allowlist (`bd tag`) |
| add_comment | any | any | any | own only | any (own filings) | allowlist (`bd comment`); "own only" is a **norm** |
| list_issues | ✓ | ✓ | ✓ | ✓ | ✓ | allowlist (`bd list`) |

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
| init | `bd init --prefix dd` + `bd config set types.custom ...` |
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
- **Close is a two-command sequence** (comment then close) so the
  resolution survives as an append-only record; never close without the
  comment.

### Step 3: Logical-field → bd-JSON mapping

The contract's issue fields map onto bd as follows (this mapping is what
makes other backends a data export, not a redesign):

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

0. **Run bd from the project root** — the tracker database is project-local
   (`.beads/` under the cwd). A `bd` command issued from any other workdir
   silently reads or writes the WRONG project's tracker (observed 09-11: a
   genesis session ran `bd list` from the harness repo root). Always confirm
   cwd is the game project before any bd call.

1. **Permission table is deny-first** — never run a bd command outside
   your role's rows; norm-enforced rows additionally require the scope
   check in Step 1.
2. **Comments are append-only** — never edit or delete an existing comment.
3. **Ids are opaque hashes** — copy them verbatim from bd output; never
   guess, abbreviate, or reuse a seen prefix in new contexts.
4. **One bash invocation per bd call** — no compounds (`;`, `&&`); the
   granular bash allowlist denies compound commands even when each part is
   allowlisted.
5. **Never touch `.beads/` with file edits** — all mutations go through
   `bd` (read-only inspection via `bd list`/`bd show` is fine).
7. **Report bd failures verbatim** — a non-zero bd exit is a structured
   failure (`⛔ BLOCKED: bd <cmd> failed: <stderr>`), not a workaround
   situation; do not retry the identical call.

## Examples

**Genesis seeds the queue (after writing the GAME_STATE.md charter):**

```bash
bd create --silent "Zone 1 Playable!" -t milestone -d "first zone" --due 2026-09-12 --actor ian
bd create --silent "Create Player entity with movement" -t core -d "..." -l reporter:ian --actor ian
```

**Rachel files a bug found in playtest:**

```bash
bd create --silent "Pearl counter desyncs after rapid collection" -t bug -d "Counter showed 14 after collecting 12 pearls in zone 3..." -l reporter:rachel -l qa-verified --actor rachel
```

**Poppy closes an issue assigned to her:**

```bash
bd show dd-xyz123                 # verify assignee == poppy (norm)
bd comment dd-xyz123 "[poppy] CLOSED: fixed via pearl dedup"
bd close dd-xyz123
```

**Pootie files a critique; must NOT comment on rachel's bug (norm):**

```bash
bd create --silent "Upgrade screen buries reroll" -t critique -d "..." -l reporter:pootie --actor pootie
bd show dd-abc456                 # reporter:pootie label → own filing → commenting allowed
```

---
*Tracker backend skill (Beads). Interface contract: [../README.md](../README.md).*
