# Bead Conventions (MythicQuest ledger)

The task queue is the **beads ledger** — a flat set of task beads, no epics.
Every queue entry follows these conventions so loop tooling can operate
mechanically. The old markdown task-line grammar is retired; this doc is the
beads-era equivalent (kept as the canonical field mapping).

## Fields

| Field | Values | Notes |
|-------|--------|-------|
| `type` | `task` \| `bug` \| `feature` \| `chore` | genesis tasks are `task`; loop-fed findings use their nature type |
| `status` | `open` \| `in_progress` \| `blocked` \| `closed` | `closed` beads are history, never reopened |
| `title` | imperative sentence | subject + verb + artifact ("Create Player entity with movement") |
| labels | `core` \| `optional` \| `future` \| `loop-<origin>` | who fed the queue: genesis (core/optional/future), QA loop (`loop-bug`), vision loop (`loop-vision`), consumer loop (`loop-critique`), dev-loop self-check (`loop-polish`) |
| `priority` | P0-P4 | playable-loop tasks P0, rest P1, future P2; loop-fed bugs P0/P1 |
| metadata `attempts` | 1..3 | retry counter; 3 exhausts the circuit breaker (bumped via `bd_ledger.sh bump_attempts`) |
| metadata `plan` | `plans/<bead-id>-<slug>.md` | written by backlog-grooming; `.completed.md` suffix after log-result |
| `discovered-from` dep | parent bead id | provenance for findings filed by QA/vision/consumer loops |
| `blocks`/`waits-for` deps | bead ids | dependency gating: a blocked bead never appears in `bd ready` |

## Operator flags (filesystem, not ledger)

Declared as a file at the game-project root before the run starts:

```
SKIP_CONSUMER_LOOP   # (file exists = flag on)
```

Skips the consumer loop (benchmark comparability). MUST be recorded in the
completion report when active.

## Append rules (loop feeders)

Beads added mid-run by a gate or finding use `bd_ledger.sh file_finding`
(QA/vision/consumer origins — wires `discovered-from` provenance + loop label
automatically) or `bd create` + `bd dep add` (decomposition, ordering):

```
bd_ledger.sh file_finding <parent> bug "Fix ball tunneling through paddle at high speed" "<repro>"
bd_ledger.sh file_finding <parent> vision "Realign title screen with arcade-on-chrome vision" "<finding>"
bd create "Increase juice on score events" -t chore -l loop-critique -p 2 --deps "discovered-from:<bead>"
```

No prose status notes in the ledger — use `bd note`/`bd comment` on the bead.

## Access rule

All ledger access in game-build sessions goes through `bd_ledger.sh`
(genesis/scripts/, symlinked into every skill that needs it). Agents do not
call `bd` directly — the helper is the sanctioned path, and per-agent verb
profiles (see AGENTS.md `bd-verb-surface`) gate what each role can do.
