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
- **Status:** defect (2) FIXED — error contract landed upstream via PR #29
  (v3.2.4, plus follow-on type-compatibility validation in 9a140af/9d401c0).
  Defect (1), inline Resource construction: implemented and PUSHED to fork
  branch `feat/inline-resource-construction` (tip 4acfa4b, 2026-09-06; history
  scrubbed of project references) — typed-dict `{type: ClassName, ...props}` →
  ClassDB.instantiate → recursive validated inner-property assignment via
  `_prepare_property_value`; 6 integration tests + full suite green.
  **RELEASED in v3.2.5** (upstream PR #32 merged, commits 670c842/8baf79e).
  `opencode.jsonc` repointed to `godot-mcp-runtime@3.2.5` (2026-09-07);
  fork-branch pin retired. Retirement COMPLETE (2026-09-07): poppy's
  `.tscn` edit permission narrowed to `deny` — zero invocations across
  run 8 + capability released; the sanctioned-paths rules tightened to
  "no alternative paths, not even invented ones" (permission exceptions
  require observed evidence + expiry).
- **Lifecycle:** filed → implemented → pushed to fork → PR #32 (green) →
  **released v3.2.5 → configs repointed → workaround retired.**
- **Retire:** error contract retires the "verify the write landed on disk"
  footgun; full Resource support retires poppy's .tscn-edit exception.

### TestPlayer scenario wait is fire-and-forget; agents sleep-poll
- **Observed:** 09-06 RallyWall run (fork pin, qwen). `start_test` returns
  immediately, so poppy improvised `bash sleep 100` between `get_test_report()`
  polls — one Task-7 QA cycle ground through 34+ polls, ~2h wall-clock and 200+
  tool calls on a 15s scenario, compounded by macOS background-throttling (idle
  engine frames stretch to 10-12s, so the sim barely advances between calls).
- **Fix applied (in-harness):** TestPlayer gains `await_test_done(max_wait_s)`
  (blocking, awaited inside one `run_script`); playtest skill now mandates the
  single-awaited-call pattern and forbids sleep-polling; `bash "sleep *"`
  permission removed from poppy/ian/pootie. Deterministic rule per
  AGENTS.md: the awaited body lives in the autoload script, not instructions.
- **Upstream-worthy?** **Hold — evidence pending.** In-harness fix (skill
  mandate + `await_test_done` + permission removal) addresses the root cause;
  a first-class wait/blocking-scenario tool would NOT have prevented this
  incident (poll-across-calls is the failure shape, and a wait tool used in
  the same loop recreates it). Decision gate: rerun the same model/prompt on
  harness `86476b4`; only if a wait-shaped need still surfaces does tool work
  get justified. Findings from reading the runtime source (09-06):
  (a) an in-engine wait ALREADY exists — `simulate_input`'s `type: "wait"`
  action (`create_timer` + timeout auto-sizing + heartbeats) — but it's
  undiscoverable as a general wait, which is why agents reach for `bash sleep`;
  (b) `run_script`'s tool description doesn't advertise long-await usage.
  The only immediately justified upstream piece is **doc-only**: clarify
  `run_script`'s description (long-await allowed, heartbeats keep the client
  alive, poll inside the call). A general `wait` tool / `run_scenario`
  blocking tool stays deferred until a run demonstrates the need.
- **Retire:** in-harness fix is complete; upstream doc tweak is queued as a
  small PR candidate; tool work deferred pending rerun evidence.

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
- **RETIRED (09-06):** PR #30 merged and released in v3.2.4; configs
  repointed; segmented-script recipe and gotcha replaced in mcp-patterns.md
  with a "long bodies are safe" note — recipe deletion complete.

## opencode

### Provider prompt-caching metadata absent for some model tiers
- **Observed:** qwen run: `tokens.cacheRead` was null/absent on every message
  while ling-flash reported cache reads — token accounting differs per
  provider tier, complicating benchmark comparisons.
- **Status:** observation only; possibly provider-side, not opencode.

### Subagent `finish_reason: length` returns an empty task_result indistinguishable from a crash
- **Observed:** 09-07 run 9: functional-QA subagent's final step died at
  `finish_reason: "length"` (8190 reasoning tokens, output 2 — max-output hit
  mid-generation). `task()` returned `state="completed"` with a 98-byte empty
  `<task_result>`. The orchestrator cannot distinguish output-token exhaustion
  from a silent crash without digging into the session DB — it cost a
  diagnostic cycle (filesystem check) before the (correct) respawn.
- **Proposed upstream fix:** propagate the finish reason into the task result
  (e.g. `state="truncated"` or a `finish_reason` attribute on task results);
  at minimum, a `length` finish with an empty final text should not be
  reported as "completed".
- **Status:** not filed; harness workaround codified in agents/build.md
  (silent-death respawn protocol, run-9-validated).

### No subagent wall-clock cap or progress heartbeat
- **Observed:** 09-07 run 10 (CoilUp): root blocked on one `task()` for 4h58m
  while the child spun in a timeout ladder — zero visibility for the
  orchestrator, and a 7h run where 70% was one wedged subagent.
- **Proposed upstream fix:** per-task wall-clock budget (configurable) that
  interrupts with a truncation signal the subagent can see, or a
  progress-notification channel subagents can emit so an orchestrator can
  distinguish "slow but progressing" from "spinning".
- **Status:** not filed; harness workaround is the skill-level timeout budget
  (mcp-patterns.md transport-wedge rules).

### `edit * deny` also governs `write` (unnamed in denial payload)
- **Observed:** run 10: root's `write` of a critique report denied by an
  `edit`-scoped `*: deny`; error text says "a rule prevents this tool call"
  without naming WHICH tool's scope matched, and the doc distinction between
  `edit` (all file modifications, incl. write/patch) and the tool named
  `edit` is implicit. Cost: one lost artifact (recovered manually).
- **Proposed upstream fix:** permission denial messages should name the
  resolved permission key (`edit`) and the triggering pattern; ideally map
  write-tool denials to a "file write" category distinct from diff-edits.
- **Status:** not filed; harness-side documented in agents' permission
  comments + run-10 report (permission saga section).

## godot-mcp-runtime (next: transport wedge)

### run_script timeout conflates "game not running" with "engine unresponsive"
- **Observed:** 09-07 run 10 (CoilUp): after a successful scenario call,
  every subsequent `run_script` timed out — including trivial
  `return {"ok": true}` probes — while `get_debug_output` kept succeeding on
  the same process (engine alive, bridge listening, clean logs) across 18
  stop_project/run_project cycles. The canned error "Is the game running?"
  sent a capable agent into a 4h58m restart ladder (17× 600s waits).
- **Root cause (confirmed post-run):** host memory pressure — the OS
  suspended the engine process under RAM exhaustion; a suspended engine
  keeps its bridge socket bound and stdio readable but never services
  RPC — exactly the observed get_debug_output-works/run_script-hangs split.
  Engine restarts can't fix a starved host.
- **Proposed upstream fixes:**
  1. Diagnostic split: when a probe times out but the engine process is alive
     and the bridge port is bound, classify the error as
     "engine unresponsive (possibly suspended by the OS — check host
     resource pressure)" instead of "Is the game running?".
  2. Health pre-check: before attributing a timeout to the game, the server
     could check whether the engine process is in a suspended state
     (`ps` state T / macOS appnap) and report that.
- **Status:** not filed; agent-side bail-fast protocol deployed
  (create-scene-with-script/reference/mcp-patterns.md _Engine/transport
  unresponsive_, playtest SKILL.md gotcha, debug-harness failure-modes
  entry).

### Background-mode visual-verification cluster (repro before filing)
- **Observed:** run 12 + run 13 (2026-09-09, three independent sessions):
  (a) `simulate_input` `wait(ms)` actions appear not to advance the sim
  deterministically under background throttle — input + 600–1500ms waits,
  world unchanged between captures; (b) `take_screenshot` returned
  identical-content frames at differing timestamps (idle-frame aliasing vs
  stale render output — unresolved which); (c) one `run_script` inline
  source arrived with a structural brace error the authored source did not
  contain (single observation, could be one-off).
- **In-harness mitigation deployed (run 13, playtest skill):** programmatic
  text sampling as primary evidence channel; static-capture-series caveat;
  reformat-before-debugging on suspected mangling; whole-suite probes in
  one awaited script (engine ticks at full rate while the call is open).
  Mitigations hold regardless of upstream action — no urgency.
- **Repro plan (next dedicated session):** (1) wait semantics — scripted
  input + wait bursts, sample a motion-counter before/after in the same
  body, N trials with/without background; (2) transport corruption — send a
  known 80-line nested-dict `run_script` 20×, hash what the engine
  receives; (3) screenshot freshness — mutate a labeled UI value, capture
  immediately, diff bytes. Stall telemetry (TestPlayer) makes (1)
  measurable. File upstream only what reproduces; otherwise document as
  caveats.
- **Status:** not filed; hypotheses logged 2026-09-09 (run-13 record).


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
- Progress heartbeats for long tool calls (09-05, `fix/progress-heartbeat-long-tools`,
  PR #30): server-side `notifications/progress` every 20s so
  `resetTimeoutOnProgress` clients (opencode) don't kill run_script sims at
  the SDK's 60s default. **MERGED 2026-09-05 and released in v3.2.4.**
  Configs repointed to upstream main; fork-branch workaround retired.
- Type-validation on property assignments (09-05,
  `fix/property-set-type-validation`, PR #29): dict→Resource assignments to
  `set_node_properties`/`add_node` now error explicitly instead of silently
  dropping while reporting success. Retires the "reports success but the write
  never landed" half of the coercer-gap gotcha (see poppy's `.tscn` edit
  rationale in AGENTS.md — the edit path itself remains necessary for Resource
  values; this fix only makes the failure loud). **MERGED 2026-09-05 and
  released in v3.2.4.** Configs repointed; fork-branch workaround retired.
- Contribution roadmap going forward lives at
  `Erodenn/godot-mcp-runtime/plans/roadmap-godot-mcp-contributions/`
  (Phases 1–13, all evidence-grounded from the RallyWall/GLM run traces).

## godot-mcp-runtime

### stdout JSON masked by exit-time RID-leak noise
- **Observed:** 09-07 run 9 (task 8): a headless operation that exits before
  emitting its JSON payload leaves stdout = Godot's exit-time RID-leak
  warnings only. `parseStdoutAsJson` then reports "GDScript returned invalid
  JSON (Unexpected token 'E', "ERROR: 5 R"...)" — blaming the operation's
  JSON emission instead of the actual early-exit failure. Repro pinned in
  `fix/stdout-noise-masking` (tests/unit/stdout-noise-extraction.test.ts).
- **Proposed upstream fix:** in `executeSceneOp`'s `parseStdoutAsJson` branch,
  surface the non-JSON stdout content and/or stderr diagnostics instead of
  "invalid JSON"; ideally emit the payload on a marker-delimited channel.
- **Status:** FIXED UPSTREAM. Filed as PR #39 (2026-09-09,
  `fix/json-absent-stdout-diagnosis`): JSON-absent stdout classified as early
  exit (not "invalid JSON"), with file+line preserved from early-exit stderr
  (follow-up b6ea2b8). MERGED 2026-09-09; unreleased beyond v3.5.0 — tracked
  by the opencode.jsonc local-main pin. Lifecycle: filed → merged →
  awaiting release → retire pin on publish.

### stop_project success result re-dumps the full engine banner every call
- **Observed:** 09-09 run 14 (DeepDive, 23 sessions): 31 `stop_project` calls
  each returned the near-identical `{"message":"Godot project stopped",...}`
  payload including `finalOutput` — full engine version banner, Metal
  renderer init lines, and recycled autoload warnings — into agent context
  on every routine engine-cycle teardown (~23 KB across the run). The
  teardown is a periodic housekeeping call; its result carries no diagnostic
  value beyond exit code and (rarely) the output tail.
- **Proposed upstream fix:** truncate `finalOutput`/`finalErrors` in
  `stop_project` success results (e.g. last 3–5 lines, or only lines matching
  ERROR/SCRIPT ERROR), with a pointer to `get_debug_output` for the full log.
  Consumers needing full output already have that path.
- **Status:** FIXED UPSTREAM. Filed as PR #40 (2026-09-09,
  `fix/truncate-stop-project-banner`): success payload condensed to
  diagnostic lines (88063dc; maintainer follow-up 0bca2d4 restored the
  200-line cap with a narrower noise filter). MERGED 2026-09-10; unreleased
  beyond v3.5.0 — tracked by the opencode.jsonc local-main pin.

### Sub-property paths rejected (theme_override_font_sizes/font_size)
- **Observed:** 09-07 run 9 (task 8): add_node/set_node_properties with
  slash-path theme overrides failed; agent fell back to bare adds + separate
  styling (3 retries). Supporting `set_indexed`-style paths upstream would
  remove the workaround class. Needs a minimal repro before proposing.
- **Status:** observed only.

### quit(1) from _init in a SceneTree script yields exit code 0 (Godot 4.7.2)
- **Observed:** 09-07: negative scene-instancing test asserts durable
  contract (no success text + file unchanged) instead of exit code.
- **Status:** upstream Godot issue candidate, not filed.

### Environment.set("fog_mode", ...) resets fog_density to 1.0 (property-order data loss)
- **Observed:** 09-10 solo control run: persisted fog_density values
  (0.015/0.02) silently became 1.0 on disk; root-caused post-run.
  Godot engine quirk — setting `fog_mode` reinitializes its dependent
  fog parameters to defaults. `_construct_inline_resource`
  (godot_operations.gd) applies dict keys in insertion order, so
  `{"fog_density": 0.015, "fog_mode": 1}` loses the density while the
  tool reports success. Deterministic (3/3 repros, /tmp/opencode/attach_repro
  probe10/probe11.gd). Not fixed by pinning branches; repros on main.
- **Fix candidates:** apply enum/dependency-parent properties before
  independent ones (order-independent application), or a second
  application pass; alternatively validate + error on the ordering.
- **Status:** repro in hand, PR not yet opened. Highest-severity open
  find — silent data loss, success-reported.

### Possibly stale Environment sub_resource reuse across scene saves
- **Observed:** 09-10 during fog repro: a newly constructed Environment
  resource appeared to share a stale `Environment_sgp6g` sub_resource id
  when saved into a scene that already carried an Environment. Low
  confidence — needs a dedicated repro before filing.
- **Status:** investigation, not filed.

### No import step in headless resource loading (SVG/textures fail on fresh projects)
- **Observed:** 09-07 run 9 (task 3): `res://assets/paddle.svg` and even
  `icon.svg` failed to load in headless MCP operations on a fresh project —
  no `.godot/imported` exists until the first editor/import-mode run, and
  background `run_project` does not run the import step. The subagent spent
  ~6 min and 4 denied-bash probes before correctly falling back to vector
  shapes (game outcome unaffected).
- **Implemented upstream:** `import_assets` tool on branch
  `feat/import-assets-plus-noise-masking` (Erodenn/godot-mcp-runtime),
  TDD-covered (unit + GODOT_PATH-gated integration test reproducing the
  run-9 failure shape: LOAD_FAILED before, LOAD_OK after, idempotent).
  Pending upstream PR. Sandbox consumes the branch via a temporary
  node_modules pin.
- **Lifecycle:** patched → pending PR → release retires the temp pin
  (test/.opencode/opencode.jsonc revert condition).

## Open: batch_scene_operations uninformative error for missing 'operation' key
- **Observed:** 09-11 rallywall run (lumo-max, test/ sandbox, kind-island
  session): an operations[] item missing its `operation` key returned the
  bare error `Unknown batch operation: ` — empty name, no item index, no
  hint. The agent retried the same malformed batch twice before noticing
  the omission: 3 tool calls on an undiagnosable message.
- **Proposed upstream fix:** when `operation` is omitted/empty, name the
  item index (`operations[N]`) and infer the intended op from sibling keys
  (nodeName/nodeType → add_node, updates → set_node_properties,
  texturePath → load_sprite); check camelCase and snake_case spellings.
- **Status:** FIXED UPSTREAM. Filed as PR #42 (2026-09-11,
  `batch-operation-error-context`): index + inference hint, 3
  integration tests, suite 1235 green. Same agent-observable-ACI class as
  #39–#41. Lifecycle: filed → awaiting merge → release > v3.5.0 retires
  the opencode.jsonc local-main pin (shared revert condition).

## Resolved: godot-mcp-runtime v3.3.0 (2026-09-07)

All three fork-pinned contributions merged and released — PR #33 (error
diagnostics: compiler message + line in validate/run_script, bare-ERROR scene
parses), PR #34 (scene instancing via add_node nodeType), PR #35 (batch
promoted-params). Maintainer follow-ups landed alongside: path containment
for instanced scenes, shared promoted-key list, position3d param dropped.
Fork pin in test/.opencode retired; sandbox back on the published package.
