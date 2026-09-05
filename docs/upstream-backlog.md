# Upstream Contribution Backlog

Local memory of improvements we owe to external dependencies (godot-mcp-runtime,
opencode, providers). Workarounds live in skills/agents with upstream-status
citations; this file is the master list so they get retired when fixes ship.
Do not commit fixes that would only apply to `test/` sandboxes.

## godot-mcp-runtime

### Value coercer silently drops Resource-typed properties (next fix target)
- **Observed:** MythicQuest runs — `set_node_properties` /
  `add_node(properties=...)` coerces Vector/Color dicts but has no
  dict→Resource mapping, so `{"shape": {"type": "RectangleShape2D", ...}}`
  fails to coerce and the property is dropped **while the tool reports
  success**. Forced poppy's `edit: "**/*.tscn": allow` exception and the
  procedural "safe only when no run/playtest is active" rule (AGENTS.md).
- **Two defects:** (1) no Resource coercion path; (2) worse — coercion
  failure is silent success instead of an error.
- **Plan:** first PR = error contract only (unsupported values return an
  explicit "cannot set property X of type Y via this tool" error — small,
  uncontroversial); second PR = Resource support (`{"type": "<Class>",
  ...}` → sub_resource serialization in scene edits, ClassDB.instantiate at
  runtime).
- **Status:** not filed.
- **Retire:** error contract retires the "verify the write landed on disk"
  footgun; full Resource support retires poppy's .tscn-edit exception.

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
- **Root cause found (09-05):** the cap is the MCP client's per-request
  timeout (SDK `DEFAULT_REQUEST_TIMEOUT_MSEC = 60000`), not the tool handler.
  The spec-sanctioned reset path is server-emitted `notifications/progress`
  on the request's progress token, honored by clients that set
  `resetTimeoutOnProgress` (opencode does — `packages/opencode/src/mcp/catalog.ts`).
- **Status: PATCHED — fork branch `fix/progress-heartbeat-long-tools`
  (squashed commit 205923c), PR-ready.** Server heartbeats every 20s for the
  lifetime of every tools/call when the client attached a progress token;
  non-opting clients see zero change. Full `npm run verify` green incl. 4
  integration tests. Pending: push to fork, open PR, pin release.
- **Retire:** once released upstream, repoint `opencode.jsonc` at the release,
  then delete the segmented-script recipe (mcp-patterns.md, commit 55a3fe5)
  and its gotcha — long sims can run as single awaited scripts.

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
- Progress heartbeats for long tool calls (09-05, `fix/progress-heartbeat-long-tools`):
  server-side `notifications/progress` every 20s so `resetTimeoutOnProgress`
  clients (opencode) don't kill run_script sims at the SDK's 60s default.
  Patched on integration branch `combined/mythicquest-integration` (@1479a2f)
  with 172-line integration test; NOT yet released upstream —
  `opencode.jsonc` TEMPORARILY points at the local branch checkout. Revert to
  the published package when released.
- Type-validation on property assignments (09-05,
  `fix/property-set-type-validation`): dict→Resource assignments to
  `set_node_properties`/`add_node` now error explicitly instead of silently
  dropping while reporting success. Retires the "reports success but the write
  never landed" half of the coercer-gap gotcha (see poppy's `.tscn` edit
  rationale in AGENTS.md — the edit path itself remains necessary for Resource
  values; this fix only makes the failure loud). Patched on
  `combined/mythicquest-integration` (@1479a2f) with real-headless-Godot
  integration tests; NOT yet released upstream — same TEMPORARY local pin.
