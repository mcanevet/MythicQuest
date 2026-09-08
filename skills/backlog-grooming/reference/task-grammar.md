# Task-Line Grammar (GAME_STATE.md)

The task queue is a flat markdown checklist. Every mutating line follows one
grammar, so tooling (and a future importer to Jira/Trello/GitHub Projects)
can parse it mechanically without understanding prose.

## Grammar

```
- [<status>] Task <N>: <description> [<origin-tag>[:<detail>]] [(attempt: <K>)] [(see: plans/<NN>-<slug>.md)]
```

| Field | Values | Notes |
|-------|--------|-------|
| `<status>` | `[ ]` \| `[in progress]` \| `[x]` | `[x]` lines are history, never rewritten |
| `<N>` | integer, unique | Line order within the file is priority order; `N` never reused |
| `<description>` | imperative sentence | subject + verb + artifact ("Create Player entity with movement") |
| `<origin-tag>` | `core` \| `bug` \| `vision` \| `critique` \| `polish` | who fed the queue: genesis (core), QA loop (bug), vision loop (vision), consumer loop (critique), dev-loop self-check (polish) |
| `[<origin-tag>:<detail>]` | e.g. `bug:qa-func`, `vision:drift` | optional qualifier — which loop/gate produced it |
| `(attempt: <K>)` | 1..3 | retry counter; K=3 exhausts the circuit breaker |
| `(see: ...)` | plan-file path | written by backlog-grooming; `.completed.md` suffix after log-result |

## Operator flags (file scope, not task scope)

Declared anywhere in GAME_STATE.md before the run starts:

```
SKIP_CONSUMER_LOOP=true
```

Skips the consumer loop (benchmark comparability). MUST be recorded in
the completion report when active.

## Append rules (loop feeders)

Tasks added mid-run by a gate use **non-conflicting next N**, preserving
grammar exactly:

```
- [ ] Task 17: Fix ball tunneling through paddle at high speed [bug:qa-func] (see: plans/17-...)
- [ ] Task 18: Realign title screen with arcade-on-chrome vision [vision:drift]
- [ ] Task 19: Increase juice on score events [critique:consumer]
```

No prose-only lines in the backlog section — free-text status notes go above
the backlog heading.

## Migration mapping (when a PM tool replaces the files)

| Grammar field | GitHub Projects equivalent |
|---------------|---------------------------|
| `[ ]`/`[x]` status | item state (Todo/Done) |
| `Task N` | issue title prefix or custom ID field |
| `[origin-tag]` | label |
| `(attempt: K)` | comment history |
| `(see: plans/...)` | linked artifact / repo file link |
| priority (line order) | board rank |

Until migration, the flat file IS the tool — do not maintain parallel state.
