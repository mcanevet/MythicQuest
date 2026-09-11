# Tracker Plugin Interface

Multi-agent coordination layer replacing the flat `GAME_STATE.md` task
queue. A tracker backend stores **milestones** and **issues** with
GitHub-Projects-compatible semantics (fields map 1:1 to GitHub Issues), so
migrating between backends (Beads → GitHub Projects → Trello → Jira) is a
data export, not a redesign.

Current backend: **Beads (`bd`)** — [beads/adapter.md](beads/adapter.md).
Prerequisite: bd provided via mise (`aqua:gastownhall/beads`, pinned in the
project root `mise.toml`).

All agents query the backend directly for reads (read-only command
patterns in each agent's bash allowlist) — there is no mirrored or
materialized view of the queue to keep in sync. The backend store is the
single source of truth.

## Division of state

| Artifact | Role |
|---|---|
| `GAME_STATE.md` | **Charter, read-only after genesis**: title, vision, core mechanics, art style. No task lines. |
| Tracker (backend store) | **The queue**: all issues/milestones — the sole source of task state. |
| `plans/<id>-<slug>.md` | Plan per task; `id` is the tracker's opaque issue id, verbatim. Plan association is by filename prefix — no stored link. |

## Backend mount & the stable skill name

Exactly one backend is mounted per project. Whichever is active, its adapter
skill is frontmattered **`name: tracker`** — skills and agents always invoke
`skill({ name: "tracker" })` and read this README's contract, never a
backend-specific name. Swapping backends = mounting a different plugin
directory; zero edits elsewhere.

## Operations (the contract)

Every backend implements exactly these operations. Signature
compatibility is the contract — a backend may store data however it likes,
but must accept these inputs and produce equivalent observable effects:

| Operation | Signature | Notes |
|---|---|---|
| init | `(prefix) → ok` | one-time project setup |
| create_milestone | `(title, description, target_date) → id` | |
| create_issue | `(title, body, type, labels, milestone, assignee, reporter) → id` | |
| update_issue_status | `(id, status)` | status ∈ `open \| in_progress \| blocked \| closed` |
| assign_issue | `(id, assignee)` | |
| add_label | `(id, label)` | |
| add_comment | `(id, author, body)` | append-only — comments are never edited |
| list_issues | `(filter {status, assignee, label, milestone})` | read-only |
| close_issue | `(id, resolution)` | resolution recorded as a closing comment (comment-then-close) |
| link_issue | `(id, relation, target_id)` | relation ∈ `blocks \| blocked_by \| relates_to`; bidirectional |

Issue fields map 1:1 onto GitHub Issues; the logical-field → backend
representation mapping table lives in each adapter (Beads:
[beads/adapter.md](beads/adapter.md) Step 4). Issue types: `bug`, `vision`,
`critique`, `material`, `animation`, `audio`, `refactor`, `core` (extended
as agents join). Statuses: `open | in_progress | blocked | closed`.

## Ids and plan files

Tracker issue ids are **opaque strings** owned by the backend (Beads
`<prefix>-<hash>`, GitHub `#42`, Jira `PROJ-123`). Skills never parse or
reformat them — they pass them verbatim and build plan filenames from them:
`plans/<id>-<slug>.md`. Finding a task's plan = `glob("plans/<id>-*.md")`.

## Permission model

Backend operations are gated by **role**, not by path. Enforcement is split
between bash allowlists (machine-checked command patterns per agent) and
documented norms for conditional scopes (authoritative copy in the mounted
backend's adapter — `beads/adapter.md`):

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

## Authoring a new backend

1. Implement the eleven operations above with identical observable
   semantics, documented as your tool's command mappings in your adapter.
2. Frontmatter your adapter skill `name: tracker` (stable name; see above).
3. Split enforcement into what your medium can machine-check vs norms, and
   mark each permission row accordingly — same split or stricter.
