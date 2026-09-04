# MCP Tool Usage Patterns

## Tool Selection (Default Strategy)

Use **batch operations first**, individual tools for simple cases:

- **3+ nodes** → `godot-mcp-runtime:batch_scene_operations` (saves ~3s per operation)
- **1-2 nodes** → `godot-mcp-runtime:create_scene` + `godot-mcp-runtime:add_node`
- **Update properties** → `godot-mcp-runtime:set_node_properties` (primitives + Vector/Color dicts only — its coercer has no Resource path and reports success even when the typed assignment fails; see SKILL.md Step 5a; Resources/packed arrays need direct `.tscn` edit)
- **Attach script** → `godot-mcp-runtime:attach_script`
- **Check hierarchy** → `godot-mcp-runtime:get_scene_tree`
- **Wire signals** → `godot-mcp-runtime:connect_signal`
- **Verify connections** → `godot-mcp-runtime:get_node_signals`
- **Validate files** → `godot-mcp-runtime:validate` (before runtime)
- **Debug errors** → `godot-mcp-runtime:get_debug_output` (after runtime failures)

## Tool Boundaries (Pick the Right One)

| Pair | Which to use | Why |
|------|--------------|-----|
| `run_project` vs `attach_project` | `run_project`, **always** | Happy-path-only policy: never launch Godot yourself and never use `attach_project`. Manual-launch + attach looks equivalent but bypasses the sanctioned verification path (no captured debug output, unsanctioned infra, observed: a subagent built tmp launch/kill scripts and attached-mode tested Task 11 after 4 bridge timeouts instead of reporting BLOCKED). If `run_project` fails after the recovery procedure below, report BLOCKED — do not manufacture attachability |
| `get_debug_output` | requires a **spawned** session | In attached mode there is nothing captured — it returns empty. Do not call it to "check" an attached run |
| `validate` vs `run_script` | `validate` for static checks | `validate` parses files headlessly; `run_script` executes in the live process and requires an active runtime session |
| `save_scene` | only for `newPath` save-as or re-canonicalization | All mutations (`add_node`, `set_node_properties`, `delete_nodes`, …) auto-save — calling it in place is redundant |
| `get_node_signals` vs `get_scene_tree` | `get_node_signals` for wiring; `get_scene_tree` for hierarchy | Signals ops need the signal+method names; the tree gives structure only |
| `simulate_input` | `click_element` resolves by node path/name, **not visible text** | Discover valid elements via `get_ui_elements` first; wrong identifier silently no-ops |

## Path Conventions

| Context | Format | Example |
|---------|--------|---------|
| MCP `scenePath` param | Relative, no `res://` | `"scenes/main.tscn"` |
| MCP `projectPath` param | "." (CWD is project root) | `"."` |
| Inside `.tscn` ext_resource | Godot `res://` path | `"res://scripts/player.gd"` |
| Inside `.gd` preload() | Godot `res://` path | `preload("res://scenes/player.tscn")` |
| MCP `parentNodePath`/`nodePath` | Scene-root-relative: `root` for the root node, `root/<Child>` for descendants; bare child names (`"Entity1"`) and `root/<RootName>` also resolve | `"root/Player"` |

**Common mistake:** Root node cannot have `parent="."` — remove it or scene fails to parse.

## Batch Operations Template

```bash
# Pseudo-code showing batch pattern:
godot-mcp-runtime:batch_scene_operations(
  operations=[
    {operation: "add_node", nodeName: "Entity1", nodeType: "Area2D", properties: {...}},
    {operation: "add_node", nodeName: "CollisionShape2D", parentNodePath: "Entity1", nodeType: "CollisionShape2D"},
    {operation: "save"}
  ]
)
```

> ⚠️ **Gotcha — auto-save persists partially-failed batches:** even when some
> ops in the batch error (e.g. a dropped `operation` or `scenePath` key), the
> remaining ops run and the scene's accumulated mutations are auto-saved on
> process exit — a half-built scene can land on disk silently. Two defenses:
> 1. Pass `abortOnError: true` for multi-op scene builds so one malformed op
>    doesn't leave partial mutations to be auto-saved.
> 2. **Check every entry in `results[]`**, not just the last one — each op is
>    tagged with its own `success`/`error`. A batch "completes" even when ops
>    inside it failed.
>
> Also: every op object must carry its own `operation` and `scenePath` keys —
> omitting either produces `Unknown batch operation: ` /
> `scene_path required for add_node` errors that are easy to miss among
> sibling successes.

## MCP Health Check (mandatory before any engine work)

Before the first engine tool call in a session, call `godot-mcp-runtime:get_project_info()`.

- **It succeeds** → proceed normally.
- **The tool is absent from your toolset** (no `godot-mcp-runtime_*` tools available) → **STOP IMMEDIATELY.** Return `⛔ BLOCKED: engine tools missing from toolset. Only the human can fix this by restarting the entire opencode process; re-delegating or spawning a new subagent inherits the same dead toolset (subagents share the parent's MCP connections). Do not retry, do not re-delegate, do not build shell-based workarounds` (custom validators, headless drivers, screenshot scripts) — that masks a broken harness and silently degrades verification quality (observed: 11+ subagents ran for hours with no engine tools, building parallel test infra nobody sanctioned). The MCP server is a child of the primary opencode process; no agent action can restart it.
  - **Report the likely cause, not just the symptom** (two causes share this symptom):
    - *Server death* — opencode logged `MCP connection closed`, earlier sessions had the tools. Wording: `MCP server down`.
    - *Toolset-snapshot race* (observed 09-01) — this session started within ~seconds of opencode boot; the async MCP handshake (npx cold-start → connect → listTools) hadn't finished when the toolset was snapshotted. Server process is alive; LATER sessions have the tools. Wording: `likely toolset-snapshot race at opencode boot`. Same fix (restart), but this tells the human the server itself is fine and they should not debug the MCP server config.

## Error Recovery Pattern

> ℹ️ **Runtime phase and parallel subagents.** Within one opencode session all
> subagents share a single MCP server, which serializes `run_project` calls
> internally — concurrent runtime phases are safe (verified 09-01: two
> parallel `run_project` calls through one server both succeed). Other engine
> commands (`run_script`, `take_screenshot`, `simulate_input`, …) are **NOT
> queued** — if another command is in flight, the server rejects with
> "another command ('X') is in flight"; just re-issue after the current
> command completes (observed 09-01: `take_screenshot` rejected during a
> long `run_script`). The one real hazard is *two opencode sessions* running
> engine tools against the same project simultaneously (each session gets
> its own MCP server and both re-inject the bridge autoload): the server
> detects this and reports "Another MCP client likely re-injected
> concurrently" with the expected vs on-disk port. Treat that error as a
> coordination problem — let one session finish its runtime phase before the
> other starts. File writes (implementation) always run freely in parallel.

> ⚠️ **Long-bodied `run_script` → timeout + stuck "in flight" slot.** A
> `run_script` whose body waits in-engine (loops, timers, empirical tuning
> measurements) can exceed the MCP client timeout (~60s): the client reports
> `MCP error -32001: Request timed out`, but the script **keeps executing
> server-side and holds the single command slot**. Every retry is rejected
> with "another command ('run_script') is in flight", and `stop_project` +
> `run_project` cycles may NOT clear it if the long script's in-engine wait
> survives the restart path (observed 09-04: tuning probes wedged the slot
> across THREE bridge restarts, ~4 min of futile cycling, before a deliberate
> `sleep 60` — waiting out the server-side script lifetime — freed it).
> Sanctioned recovery: after the first `-32001` on `run_script`, do NOT
> hammer retries; issue `bash sleep <client-timeout>` once (60s), then retry.
> If the retry still hits "in flight", that is the `⛔ BLOCKED:` terminus.
> Prevention: keep probe scripts under the client timeout — poll state in
> short runs (return intermediate readings, re-invoke) instead of one
> long-waiting script body.

> ⚠️ **GDScript compile errors (error 43) in probe scripts.** A failing
> `run_script` costs a full engine round-trip (~10–30s). Before the FIRST
> `run_script` call, lint the probe script (`validate.sh` or headless
> `--check-only`). If the same script fails with error 43 twice: STOP
> iterating on edits — write the script to a file, lint it, confirm zero
> syntax errors, THEN re-run. Observed 09-01: two sessions burned 5+
> repeated run_script round-trips on successive syntax guesses.

**If `godot-mcp-runtime:run_project` fails (bridge timeout, "did not respond", "process exited"):**
1. Call `godot-mcp-runtime:get_debug_output()` immediately — read actual error
2. Kill lingering engine process: `bash("./.opencode/skills/create-scene-with-script/scripts/stop_engine.sh")` — the blessed stop script (kills only `godot --path …`, waits for port release). **NEVER run pkill yourself** (see warning below)
3. Fix specific issue in source files
4. Retry once. If same error → **STOP** and report to build agent: `⛔ BLOCKED: runtime phase failed after sanctioned recovery (debug → stop_engine → fix → retry). Do not self-launch Godot or use attach_project.`
   - **DO NOT invent workarounds**: manual launch scripts, `attach_project`, custom validation hooks, shell-based test runners, or "background mode" hacks. These look equivalent but bypass the sanctioned verification path (no captured debug output, unsanctioned infra, observed: Task 11 subagent built tmp launch/kill scripts and attached-mode tested after 4 bridge timeouts instead of reporting BLOCKED).

> ⚠️ **Critical — never invoke pkill directly:** `npx godot-mcp-runtime` (the
> MCP server) contains "godot" in its command line, so any pattern broader than
> the exact engine invocation kills it — permanently, since no auto-reconnect
> exists. Worse, permission-allow patterns are string-matched, not
> argv-parsed: the allow rule `pkill -f *godot --path*` matched an *unquoted*
> `pkill -f godot --path`, which the shell splits into argv
> `["pkill","-f","godot","--path"]` — pkill binds the pattern `godot`,
> ignores `--path`, and kills the MCP server (observed: killed a live run at
> the exact second of the kill). The only sanctioned engine stop is the
> `stop_engine.sh` script, which encodes the safe pattern internally.

**Common errors and fixes:**
- `Parse Error: Expected '['` → malformed `.tscn` (check brackets, headers)
- `Invalid scene: root node X cannot specify a parent` → remove `parent="."` from root
- `Property 'X' does not exist` → wrong node type for the property
- `Resource file not found` → ext_resource path incorrect
- `Script not found` → path mismatch between scene and actual file
- Resource-typed property (e.g. `shape`) reads back as `null` after a successful-looking `set_node_properties`/`add_node` → **not fixable via MCP**: the runtime's value coercer (`_coerce_property_value` in godot_operations.gd) only maps `{x,y,z}` → Vector and `{r,g,b}` → Color; any other dict is `set()` raw, the typed assignment fails, and the tool reports `success: true` regardless. Sanctioned path: direct `.tscn` edit embedding `[sub_resource]` blocks (see SKILL.md Step 5a). **Do not debug the MCP server source, do not probe alternate dict formats** — >2 failed attempts on the same Resource property = switch to the direct-edit path immediately (observed 09-02: paddle task burned ~8 min probing four serialization formats before stalling)

**Validation strategy:**
- Before `run_project`: Call `godot-mcp-runtime:validate()` on all .tscn/.gd files
- After failure: Call `godot-mcp-runtime:get_debug_output()` before any retry
- If no debug output: Call `godot-mcp-runtime:list_autoloads` to check for broken autoloads
