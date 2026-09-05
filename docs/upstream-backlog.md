# Upstream Contribution Backlog

Local memory of improvements we owe to external dependencies (godot-mcp-runtime,
opencode, providers). Workarounds live in skills/agents with upstream-status
citations; this file is the master list so they get retired when fixes ship.
Do not commit fixes that would only apply to `test/` sandboxes.

## godot-mcp-runtime

### FileAccess elicitation gate is lexically evadable
- **Observed:** 09-04 Run 5 (qwen). The MCP runtime's file-write elicitation
  gate string-matches source text; `var fa := FileAccess; fa.open(...)`
  (indirection through a local variable) bypasses it entirely. Also
  inconsistent per-primitive: `ConfigFile.save()` slips through while
  `FileAccess.open` is gated, and `OS.execute` was blocked.
- **Proposed upstream fix:** gate at the effect layer, not the source layer —
  either a semantic check on the call target or (better) a path-allowlist
  enforced by a debugger hook / fs sandbox rather than script-text inspection.
- **Status:** not filed. Motivation partly removed by granting pootie
  `write: reports/**` (commit 55a3fe5), but the gate weakness stands.
- **Retire:** once upstream gates semantically, note it in
  skills/playtest/SKILL.md report-persistence gotcha.

### MCP client transport timeout is not configurable
- **Observed:** 09-04 Run 5 (qwen, session nfd7fn). The tool-level `timeout`
  parameter on `run_script` does not raise the client transport cap (~60s) —
  passing a larger value still yields `MCP error -32001`. Probed deliberately;
  dead end confirmed.
- **Proposed upstream fix:** plumb the tool `timeout` through to the transport,
  or expose a transport-level timeout config.
- **Status:** not filed. Workaround: segmented-script recipe (mcp-patterns.md,
  commit 55a3fe5).
- **Retire:** if a release makes `timeout` effective, replace the
  segmentation gotcha's recovery with the `timeout` parameter.

## opencode

### Provider prompt-caching metadata absent for some model tiers
- **Observed:** qwen run: `tokens.cacheRead` was null/absent on every message
  while ling-flash reported cache reads — token accounting differs per
  provider tier, complicating benchmark comparisons.
- **Status:** observation only; possibly provider-side, not opencode.

## Providers

### Watchdog for verbose-generation brain-death
- **Observed:** ling-flash Run 4 — a single ~32k-token step hit `finish:
  length` at high context, then zero activity for 7.1h with the process alive.
  opencode has no built-in watchdog for this; the harness mitigated via
  step-caps.
- **Proposed upstream fix:** inactivity alert / step timeout that surfaces a
  human-checkable state instead of idling.
- **Status:** not filed; mitigation shipped in-repo.

## Filed/resolved upstream (reference trail)

- Relative-`projectPath` bug (09-01): reproduced → patched on fork with TDD
  regression test → released in godot-mcp-runtime v3.2.3 → `opencode.jsonc`
  repointed to the published package. The model workflow per AGENTS.md.
