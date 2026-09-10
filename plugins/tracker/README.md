# Tracker Plugin Interface

Multi-agent coordination layer that will eventually replace the flat
`GAME_STATE.md` task queue. A tracker backend stores **milestones** and
**issues** with GitHub-Projects-compatible semantics (fields map 1:1 to
GitHub Issues), so migrating to a real `github-projects` backend later is a
data export, not a redesign.

Current backend: **Beads (`bd`)** — [beads/adapter.md](beads/adapter.md).
Prerequisite: bd provided via mise (`aqua:gastownhall/beads`, pinned in the
project root `mise.toml`).
bd gives us a durable JSONL store, dependency graph, comments, and
milestone type out of the box; ids are opaque `prefix-hash` strings.
(The retired YAML/plainfile backend is recoverable from git history if a
zero-dependency fallback is ever needed.)

## Layout (per consuming game project — Beads backend)

```
.beads/                        # bd database (JSONL), sibling of GAME_STATE.md
```

bd owns storage and concurrency internally; run `bd export` after writes to
keep the JSONL current. Concurrency is bd's problem now (the retired
file-per-issue + id-counter locking scheme is gone with the plainfile
backend).

## Operations (the contract)

Every backend implements exactly these eight operations. Signature
compatibility is the contract — a backend may store data however it likes,
but must accept these inputs and produce equivalent observable effects:

| Operation | Signature | Notes |
|---|---|---|
| create_milestone | `(title, description, target_date) → id` | id = slug |
| create_issue | `(title, body, type, labels, milestone, assignee, reporter) → id` | appends compat line to GAME_STATE.md during transition |
| update_issue_status | `(id, status)` | status ∈ `open \| in_progress \| blocked \| closed` |
| assign_issue | `(id, assignee)` | |
| add_label | `(id, label)` | label must exist in label registry |
| add_comment | `(id, author, body)` | append-only — comments are never edited |
| list_issues | `(filter {status, assignee, label, milestone})` | read-only |
| close_issue | `(id, resolution)` | resolution recorded as a closing comment (comment-then-close) |
| link_issue | `(id, relation, target_id)` | relation ∈ `blocks \| blocked_by \| relates_to`; bidirectional (bd deps) |

## Issue schema

Issue fields map 1:1 onto GitHub Issues fields; the logical-field → bd-JSON
mapping table lives in [beads/adapter.md](beads/adapter.md) (Step 4).

Issue types: `bug`, `vision`, `critique`, `material`, `animation`, `audio`,
`refactor`, `core` — extended as new agents join the swarm.

Statuses: `open | in_progress | blocked | closed` (superset of GitHub's
open/closed — `in_progress` and `blocked` are derived-view states; all four
are bd-native in 1.2.2).

## Permission model

Backend operations are gated by **role**, not by path. There is no adapter
script — enforcement is split between bash allowlists (machine-checked
bd subcommand patterns per agent) and documented norms for conditional
scopes (authoritative copy in `beads/adapter.md`):

| Operation | ian | poppy | rachel | pootie |
|---|---|---|---|---|
| create_milestone | ✓ | — | — | — |
| create_issue (any type) | ✓ | ✓ | — | — |
| create_issue (type-restricted) | — | — | `bug` only | `critique` only |
| update_issue_status | — | ✓ | — | — |
| close_issue | own only | assigned-to-self only | — | — |
| assign_issue | ✓ | — | — | — |
| add_label | ✓ | ✓ | — | — |
| add_comment | any | any | any | own only |
| list_issues | ✓ | ✓ | ✓ | ✓ |

(The adapter skill — `beads/adapter.md` — owns the authoritative copy of
this table, including per-row enforcement mode and rationale.)

## Backward compatibility (transition period)

Until `backlog-grooming` and `log-result` read the tracker directly
(follow-up work, not yet scheduled), whoever creates an issue ALSO appends
an equivalent line to `GAME_STATE.md` in the current tag format
(`- [ ] Issue <id>: <title> [<type>]`), so the existing skills keep working
unmodified while the tracker is validated in parallel.

## Authoring a new backend

1. Implement the nine operations above with identical observable semantics
   (documented as bd-equivalent command mappings in `beads/adapter.md`;
   other backends document their own command tables).
2. Split enforcement into what your medium can machine-check vs norms, and
   mark each permission row accordingly — same split or stricter.
3. Preserve the compat-layer behavior if the transition is not finished.
