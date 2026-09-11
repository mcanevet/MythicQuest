# Task State Mapping (tracker)

The tracker is the task queue. This document maps the concepts the swarm
uses onto tracker fields so tooling (and future backend migrations to
GitHub Projects/Trello/Jira) can translate mechanically without
understanding prose.

## Where things live

| Concept | Location |
|---|---|
| Game charter (title, vision, mechanics, art style) | `GAME_STATE.md` — read-only after genesis, no task lines |
| Task queue | tracker issues (the backend store, e.g. bd) |
| Plan per task | the issue's `description` field — seeded at creation, never mirrored to files |
| Resolution / discussion | append-only comments on the issue |

## Field mapping

| Swarm concept | Tracker field | Values / notes |
|---|---|---|
| task id | `id` | opaque, backend-defined (bd `<prefix>-<hash>`, GitHub `#42`, Jira `PROJ-123`); never parsed or reformatted |
| title | `title` | imperative sentence ("Create Player entity with movement") |
| implementation plan | `description` | the structured plan body (Task Type / Goal / Files to Create / DoD / Visual Verification / Hints / Dependencies) — must be seeded at issue creation; a thin description is a genesis defect, not the implementer's problem |
| origin loop | `labels` (`reporter:<agent>`) plus issue `type` | genesis `core`, QA `bug`, vision `vision`, consumer `critique`, dev self-check `polish` |
| status | `status` | `open` \| `in_progress` \| `blocked` \| `closed` — grooming sets `in_progress`, log-result sets `closed` |
| retry counter | `attempt:N` label + comments | circuit breaker: ≥3 attempts on one issue ⇒ decompose or escalate (build agent tracks this) |
| dependencies | `blocks` / `blocked_by` relations | `bd dep` edges; the build agent reorders around them before delegating |
| assignment | `assignee` | set by ian; poppy closes only what is assigned to her (norm) |
| milestone | parent issue of type `milestone` | e.g. "Playable Loop" |

## Loop feeders

Tasks added mid-run by a gate are created as new tracker issues with the
feeding loop's `type` (`bug`, `vision`, `critique`, `polish`) — created by
whichever role has create rights for that type (rachel: `bug`, pootie:
`critique`, ian: any). No prose status notes anywhere; discussion goes in
issue comments.

## Migration mapping (backend swaps)

| Tracker field | GitHub Projects | Trello | Jira |
|---|---|---|---|
| status | item state (Todo/In Progress/Done) | list membership | status category |
| labels | labels | labels | labels/components |
| type | custom field or label | label | issue type |
| assignee | assignee | member | assignee |
| comments | comments | card comments | comments |
| blocks/blocked_by | blocked-by relation | (plugin) | issue links |

Every backend is documented with its own command mapping (current:
[adapter.md](../../plugins/tracker/beads/adapter.md)); the concepts above
are the stable vocabulary.
