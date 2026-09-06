# Phase 1 — PR: Autoload-Aware `validate` with Line Numbers

Kind: bugfix PR · Status: not started · Depends: none (Phase 0 not required)

## Importance to us: HIGH

- **Why:** error-43 class failures directly burned the GLM benchmark run —
  agents hit misleading autoload-reference compile errors, waste retry
  budget, and sometimes ship around them (worse). Accurate line numbers
  also speed up every future agent debugging cycle across all runs.
- **Impact area:** reduces retries and false-negative validations in every
  game-build session; direct invariant-pass-rate improvement.
- **Cost:** small (scoped bugfix, prior art known) — best impact/effort
  ratio in the roadmap.

## Problem

Error-43 compile failures from the GLM benchmark run: scripts referencing
autoload singletons fail validation / produce noisy "Identifier not found"
errors, because validation compiles without autoload registration context.

## 2026-09-05 GLM-run trace evidence ( strengthens + widens this PR )

SQLite trace of the whole session tree (3504 parts, 17 subagents):

- **12 run_script compile failures**, every one returning only
  *"Script compilation failed (error 43). Check syntax"* — no line number,
  no parser message, nothing. The agent:
  - blindly retried 2 identical failing scripts verbatim (zero information
    to fix with)
  - made **23 `get_debug_output` calls** hunting for compile details that
    were never captured
  - burned reasoning tokens guessing (suspected lambdas, captured vars,
    `CONNECT_ONE_SHOT` — unconfirmable)
- Failing scripts were substantively reasonable (test harness probes with
  signal lambdas, typed local arrays) — this is not an agent-quality problem,
  it's missing diagnostic surface.

The failing-script corpus from this run is a ready-made regression suite —
keep the 12 scripts verbatim (plus autoshim of the referenced autoload) as
fixture inputs.

## Approach

- Compile through a `SceneTree` at `_initialize()` (post-autoload
  registration), AND capture the actual parser error (message + line +
  column) from Godot stderr for BOTH failure classes:
  - unknown-identifier due to missing autoload (error today: misleading)
  - genuine syntax/semantic errors (error today: "check syntax" with no
    location)
- Extend the existing `validate` tool's error output with `line` numbers
  (parsed from Godot stderr)
- TDD: regression test — an autoload-referencing script validates clean; a
  genuinely broken script reports accurate line numbers

## Maintainer-fit notes (from audit)

- Bug-fix-class PR — the maintainer's sweet spot (~1-day turnaround)
- Extends the existing `validate` tool; no new tool surface
- He has no Mac: verify stderr line-number parsing locally on macOS before
  submitting, and state that verification in the PR body
- Follow `docs/tool-authoring.md` pre-merge checklist (this is a
  behavior change on an existing tool: update `docs/tools.md` entry)

## Verification

- `npm run verify` + new regression tests
- Local macOS run of the GLM-run failure cases (error-43 class) against the
  patched build
