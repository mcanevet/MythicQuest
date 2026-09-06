# Phase 5 — Harness-Side Only: QA Suites (MythicQuest, not upstream)

Kind: MythicQuest repo work · Status: not started · Unconstrained by upstream

## Importance to us: MEDIUM-HIGH (and zero political cost)

- **Why:** our declarative QA/invariant system is what turns playtest
  output into comparable scores across benchmark runs. Keeping it
  harness-side preserves flexibility to iterate without upstream
  negotiation — confirmed correct by the audit: the maintainer would not
  accept an opinionated test framework into his lean core, and his README
  explicitly disclaims playtesting scope.
- **Impact area:** the core measurement instrument of the whole harness.
- **Cost:** ongoing evolution, not one-shot; biggest lever once Phases 3–4
  primitives exist.

## Actions

- Declarative QA suites stay in the skill layer (`skills/playtest`)
- `test_player.gd` evolves to ride the new `game_time` primitives once
  Phase 3 merges (until then, run_script composite)
- Bookmark `beremaran/godot-agent-loop` as design reference for the
  QA/evidence layer (schemas, correlated diagnostics, golden-agent
  acceptance runs)
