# Phase 7 — PR: Rich `run_script` Compile-Error Diagnostics

Kind: bugfix-class PR (behavior improvement on existing tool) · Status: not
started · Discovered: 2026-09-05 GLM-run trace analysis · Sibling of Phase 1

## Importance to us: CRITICAL (top empirical finding of the trace read)

- **Why:** the single largest non-latency error class in the traced run: 12
  run_script compile failures, each returning only "Script compilation
  failed (error 43). Check syntax." — no line, no message, no column. The
  agent had literally zero diagnostic surface: it retried two scripts
  VERBATIM (couldn't know what to change), made 23 get_debug_output calls
  chasing details that were never captured, and burned long reasoning chains
  hypothesizing causes (lambdas? captured vars? CONNECT_ONE_SHOT?).
- **Impact area:** every run_script call in every session — the eval hatch
  is our architectural insurance (survey deciding factor #4), and right now
  it fails *opaque*. An agent that can't fix a broken script in 1-2 tries
  burns the whole task's retry budget.
- **Cost:** small. The compiler emits errors with line/column/message to
  stderr; we're failing to parse/surface them.

## Approach

- On script-compile failure in `evaluateScript()`, capture the Godot
  compiler's stderr (message, line, column — Godot prints
  `SCRIPT ERROR: ... at line N`) and return it in the tool error payload
- Same parser as Phase 1's `validate` line-numbers — shared code, single PR
  family
- If stderr capture is impractical in that code path, fall back to Godot's
  `GDScript` reload + `get_doc...`/diag APIs in a probe SceneTree — but
  stderr parse is the lean route and proven by tugcantopaloglu's
  validate_script
- Regression fixtures: the 12 verbatim failing scripts from the GLM run
  (session ses_f8f465002ffe65u9J4zOb66PaT; keep copies harness-side)

## Maintainer-fit notes

- Aligns with his README thesis: the server exists so "an agent [can] check
  work" — an unactionable compile error defeats the loop. Strong story.
- No new tool; behavior improvement inside `run_script`'s existing error
  contract (`SCRIPT ERROR` + solutions list gets a real cause)
- tool-authoring.md compliance: update the `run_script` error-path docs in
  `docs/tools.md`

## Relation to Phase 1

Phase 1 fixes `validate`; this fixes the same diagnostic gap on
`run_script`. Can be one combined PR (shared stderr-parse helper, two call
sites) or sequenced — decide at implementation; combined is cleaner and
one review cycle.
