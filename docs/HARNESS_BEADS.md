# Harness Beads Workflow (one-page reference)

For harness-build sessions (this repo's own ledger, `.beads/`). Game sandboxes get their own ledger via `benchmark-prep`; this page is about harness work only.

## Creating harness beads

```bash
# New harness work (link discoveries to their origin)
bd create "Short title" -t bug|feature|task|chore -p 0-4 \
  --description "Context: what was found, evidence, links to commits/runs" \
  [--deps discovered-from:<parent-id>] --json
```

Link harness findings to game-build outcomes by citing the benchmark report path (`benchmarks/results/...`) and the relevant commit SHAs in the description — beads IDs are not stable across sandboxes.

## Lifecycle

- **Claim:** `bd update <id> --claim --json` (start of work; prevents double-work across sessions)
- **Close:** `bd close <id> --reason "<what was done + where the evidence lives>"`
- **Defer:** `bd defer <id> --reason "<blocker + revisit condition>"` — mandatory pattern for upstream-dependent work (e.g. tool releases)
- **Ready:** `bd ready --json` before asking what to work on

## Conventions

1. **Every closed bead cites its evidence** — report path, commit SHA, or validation run in the close reason.
2. **Incidents become beads** — any run failure with a root cause and fix gets a bug bead (filed + closed same session once fixed; e.g. MythicQuest-o3x sandbox-contamination).
3. **Stale scopes get deferred, not force-fit** — if the world changed under a bead (deleted wrapper, unreleased version), defer with the reason and revisit condition.
4. **Failure patterns worth codifying** route into the lint registry (`.opencode/skills/lint/scripts/rules.yaml`) — the bead is the incident record; the registry is the enforcement.

## Two ledgers, one source of truth

- Harness ledger (`.beads/` at repo root): harness improvements only
- Sandbox ledgers (`test/.beads/` etc.): created by `prepare_test_dir.sh`, seeded with the `game-four-loops` formula, owned entirely by the game-build session

Never mix them: harness beads in a sandbox ledger (or vice versa) means the prep script was bypassed.
