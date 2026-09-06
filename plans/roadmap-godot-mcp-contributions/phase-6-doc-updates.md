# Phase 6 — Documentation Updates (MythicQuest)

Kind: MythicQuest repo work · Status: not started · Runs last (or as things land)

## Importance to us: LOW urgency, HIGH hygiene value

- **Why:** `docs/upstream-backlog.md` is how the harness remembers what
  workarounds exist and when to retire them. Stale entries cause exactly
  the "workaround whose upstream fix has shipped" tech debt the
  contribution rule warns about.
- **Impact area:** future harness-build sessions' decision quality.
- **Cost:** trivial — pure documentation.

## Actions

- Update MythicQuest `docs/upstream-backlog.md`: survey conclusion +
  rationale; link this roadmap (now living at
  godot-mcp-runtime/plans/roadmap-godot-mcp-contributions/); mark
  superseded items
- Mark the "elicitation opt-out config" backlog item RESOLVED-SUPERSEDED:
  v3.2.1 shipped `GODOT_MCP_DISABLE_ELICITATION` (fail-open) and
  `GODOT_MCP_STRICT=true` (fail-closed) for unattended runs — use STRICT in
  benchmark sandboxes
- **Concrete from 13:12 trace read:** the Task 13 session hit a live
  elicitation failure (`FileAccess.open` in a run_script → hard error
  because the harness client doesn't support elicitation). Make
  `GODOT_MCP_DISABLE_ELICITATION=1` (or STRICT mode policy) part of
  benchmark sandbox env config in `benchmark-prep` / test
  `opencode.jsonc` — verify and record it as a launch precondition
- **Run-final count:** 2 elicitation blocks for the run (second:
  `dump_tree.call` — Tier-2 reflection flag, common in state-dump probes,
  will recur in every vision playtest). Env preconfig is not optional.
  Note asymmetry: `DISABLE_ELICITATION` is fail-open (warn+proceed) which
  is what we want for probes; STRICT=true would hard-fail Tier-2 — prefer
  DISABLE for benchmark sandboxes
- Record the landscape survey as the future re-evaluation baseline
  (pointer to `survey-conclusion.md`)
- Run the MythicQuest `lint` skill before committing any `skills/` or
  `agents/` changes
- Delete `_original-monolith.md` once Phase 0 completes (provenance no
  longer needed)
