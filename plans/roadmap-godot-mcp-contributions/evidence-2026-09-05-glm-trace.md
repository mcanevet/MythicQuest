# Trace Evidence: 2026-09-05 GLM Game-Build Run

Source: opencode SQLite DB, session tree under root
`ses_f8f465002ffe65u9J4zOb66PaT` (eager-planet, project test/), 3504 parts,
17 subagent sessions (1 ian, 16 poppy), tasks 8–13 of RallyWall game.
Whole-tree extraction: `/tmp/glue_raw.json` (regenerate with the
debug-harness recursive CTE if needed).

## Headline numbers

- Tokens (whole tree): ~9.0M input, ~107k output, ~103k reasoning
- Godot tool calls: 311 (9.7 min cumulative wall), plus 220 read / 113
  edit / 106 run_script / 84 bash / 53 skill invocations
- run_script: 94 ok / 12 error; median 0s, max 70.3s
- Agent `bash sleep` total: 324s (waiting for throttled sim time)
- Errors: 12 run_script (all compile "error 43"), 4 bash, 3 grep, 1 edit,
  1 task (Task 13 delegation died mid-work — resumed cleanly by protocol)

## Findings → roadmap phases

| Finding | Evidence | Phase |
|---|---|---|
| run_script compile errors are opaque (no line/message) | 12 errors, all "Check syntax"; 2 verbatim blind retries; 23 get_debug_output calls chasing nothing | Phase 7 (Phase 1 sibling) |
| Timed-out scripts keep spinning in-engine; suspected serialization behind zombie loops | successive scripts hung after a timed-out infinite-loop script; agent hypothesized "slots stuck" | Phase 8 |
| Background (off-screen) mode frame-throttling on macOS | sim ≤0.133s/wall-s; 15s scenario → minutes; QA report showed p99 21ms alongside 55,297ms / 67,296ms frame-time violations (incoherent); ~6.8ms/frame foreground on same machine | Phase 9 |
| Frame-time warm-up pollution | violations clustered in first ~100 frames after resume spikes; agent re-ran scenarios twice chasing phantom violations | Phase 9 |
| Emergent `get_test_state()` protocol | agents converged unprompted across 16 poppy sessions: per-node flat-dict state + TestPlayer scenario runner | Phase 10 |
| MCP suicide / tool vanish | none this run | — |
| Silent subagent death | 1 (task 13 delegation aborted) — recovered by error-recovery protocol | — |

## Run final state (13:49 UTC) — COMPLETE

**RallyWall shipped**: 16/16 tasks (15 + 1 post-critique fix), 5.2h wall,
23 subagent sessions (18 poppy, 1 ian vision, 2 pootie critiques, +observer).
Full QA gauntlet passed; pootie consumer critique caught a real win-screen
off-screen-layout bug that every invariant-based check missed → fix task →
SHIP verdict on recheck (played via keyboard-driven replay, "the honest way").

### Late-run stats (Tasks 14–16, after previous read)

- ~707 new parts across 6 sessions; 5 run_project sessions each ending in
  clean stop_project + remove_autoload (teardown discipline held all run)
- 19 take_screenshot calls concentrated in the vision/critique tasks —
  vision playtest leans entirely on screenshot evidence, no helper besides
  take_screenshot + get_ui_elements (1 use)
- 4 run_script errors: 2 runtime (fine, full messages), 1 elicitation
  block (`dump_tree.call` flagged — worked around), 1 error-43 compile
  (still opaque; final tally 13 for the run)

### Final upstream-relevant tallies (whole run)

- run_script compile-opaque errors: **13** (Phases 1/7 target)
- elicitation blocks on otherwise-legitimate scripts: **2**
  (`FileAccess.open`, `dump_tree.call`) — harness env must set
  `GODOT_MCP_DISABLE_ELICITATION` (Phase 6 action; note Tier-2 reflection
  flags like `dump_tree.call` are common in state-dumping probes, so this
  will fire regularly in vision playtests)
- Zero MCP suicides, zero tool-vanish, zero unrecovered subagent deaths
  (1 aborted delegation recovered by protocol) — runtime stability under
  our merged PRs #28-#30-era dist was excellent
- Vision/critique agent (pootie) had **no file-write tool and shell denied**
  — report returned inline per protocol; worked, but an explicit
  "report-only agent" pattern might deserve a documented harness pattern

- **clever-falcon (Task 13, functional QA gauntlet): PASS** — 11 scenarios +
  3 scripted probes, zero outstanding violations. The emergent
  get_test_state/TestPlayer gauntlet (Phase 10) works end-to-end at scale.
- New error-class sample, runtime (not compile) errors **do** carry full
  messages ("Invalid access to property 'speed' on CharacterBody2D
  (ball.gd)", "Nonexistent 'bool'/'float' constructor" — the latter is
  agents writing C-style casts): confirms Phase 7's gap is specifically the
  *compile* path; runtime errors are already adequately surfaced.
- **Elicitation failure blocked a legitimate script**: run_script needing
  `FileAccess.open` failed with "requires user confirmation but the client
  does not support elicitation". In harness sandboxes every such call dies
  — `GODOT_MCP_DISABLE_ELICITATION` (fail-open) or `GODOT_MCP_STRICT`
  must be set in benchmark envs. Action: MythicQuest benchmark-prep /
  opencode.jsonc env config (Phase 6 item).
- 2 permission-denial tool errors (agent attempted a forbidden tool) —
  recovered by protocol; no upstream relevance.
- Scenario-completion polling is manual sleep-and-check everywhere —
  even absent upstream jobs (Phase 8), a skill-side `await`-one-script
  pattern (report polling inside a single run_script with raised timeout)
  was discovered mid-run and worked; codify it in playtest skill
- Two Background nodes existed in final scene tree (possible duplicate
  from tier-color work) — harmless but worth a harness-side scene audit
  check
- Harness-side (no upstream): the build root now sleeps between poppy
  delegations (`sleep 590` DB-poll loops from the harness observer session
  `brave-cabin`) — that's us, not the build agent
