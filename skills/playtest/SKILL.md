---
name: playtest
description: >-
  Run automated playtesting with scenario-based invariants for game development QA. Use after
  implementing features, during development checks, or for final quality assurance. Supports five
  modes: fast-verify (cheapest — mandatory per-task smoke check), scene-verify (quick dev checks after scene creation),
  functional (exhaustive mechanic verification), vision (creative alignment assessment), and critique (player experience evaluation).
---

> **Screenshot workflow:** `godot-mcp-runtime:take_screenshot()` → `read(path)` → write analysis (`Scene`/`Entity`/`Issues`/`Verdict`/`Next`). Do not substitute `godot-mcp-runtime:run_script` structural checks for `read()` — that's a known failure mode.

> **Analysis template (write in your response after every screenshot):**
> ```
> - **Scene:** <what is rendered>
> - **Entity:** <entity: name, position, color, shape>
> - **Issues:** <none> or <describe>
> - **Verdict:** PASS or FAIL
> - **Next:** <next action>
> ```

## What I do

Five execution modes (fast-verify, scene-verify, functional, vision, critique), each with a distinct evaluator lens. **Always uses `background=true`** (invisible window — deterministic screenshots, no display interference with the agent's own environment).

### Step 0: MCP Health Check (MANDATORY)

Before any MCP tool call, verify bridge availability:

```
godot-mcp-runtime:get_project_info(projectPath=".")
```

If this returns an error or times out → **FAIL IMMEDIATELY**. Report "MCP bridge unavailable" and stop. No fallback.

**If the `godot-mcp-runtime_*` tools are absent from your toolset entirely** (you cannot even attempt the call — the tool names don't exist for you) → **STOP IMMEDIATELY and return a hard failure.** This is NOT recoverable by any agent: the MCP server is a child process of the opencode primary process, and restarting *a subagent* (or asking the build agent to re-delegate) inherits the same dead toolset. The ONLY recovery is the human restarting the entire opencode process. Report: `⛔ BLOCKED: MCP server down — engine tools missing from toolset. I cannot continue; a new subagent will hit the same wall. The human must restart opencode (the primary process) to restore MCP; do not retry or re-delegate this task.` Do NOT proceed with shell-based substitutes (headless drivers, custom validators, screenshot scripts): a missing MCP toolset means the harness is broken, and working around it silently degrades every downstream verification (observed: a run continued 11+ subagents / several hours without engine tools, building unsanctioned parallel test infrastructure).

**Diagnostic precision matters — distinguish WHY tools are absent.** There are two different causes with the same symptom, and conflating them misleads the human:
- **Server death** (e.g. the engine-stop incident): a `MCP connection closed` event exists, or earlier sessions in the same opencode process HAD the tools. Restart is the fix.
- **Toolset-snapshot race** (observed 09-01): the session snapshotted its toolset before the async MCP handshake finished (npx cold-start). Sessions that start within seconds of opencode boot can be born without tools even though the server process is alive and later sessions have the tools. Restart ALSO fixes this, but the correct report wording is `⛔ BLOCKED: engine tools missing from toolset — likely toolset-snapshot race at opencode boot (server process may be alive). Human must restart opencode and avoid prompting within the first ~60s after boot, then re-verify via this health check.` Reporting "server down" when the server is up sends the human debugging the wrong layer. *(Upstream status: inherent to opencode's toolset snapshot-at-spawn behavior, no version-specific bug identified — retirement check: if a future opencode release defers toolset snapshots until MCP handshake completion, this race becomes impossible and this bullet can be deleted.)*

| Mode | When | Purpose | Testing Method |
|------|------|---------|----------------|
| **functional** | After all tasks complete | Verify every mechanic works per spec | Scenario runner + invariant checker (automated, no screenshots needed unless violation) |
| **vision** | After functional passes | Does it match the creative vision? | Long-form scenario with pursuit/replay bot, 6-8 evenly spaced screenshots across the run |
| **critique** | After vision passes | Is it fun? Would players care? | 120s replay/chaos playback, 8-10 evenly spaced screenshots grounding the narration |

For quick dev checks during implementation, use `scene-verify` (launches single scene, runs chaos scenario, returns invariant report).

The framework uses genre-agnostic bots (chaos, pursuit, replay, nav_agent) and invariants — see `./.opencode/skills/setup-project/reference/testing-patterns.md` for the configuration schema.

## Parameters

- **mode**: `"fast-verify"` \| `"scene-verify"` \| `"functional"` \| `"vision"` \| `"critique"`
- **scene**: Scene path — required for `scene-verify` only (e.g. `"res://scenes/player.tscn"`)
- **scenario**: Scenario config path — optional, overrides default scenario for mode

---

## Common Workflow

**Scenario-Based Execution** (replaces old simulate_input loop):

1. **Ensure harness autoload:** `godot-mcp-runtime:list_autoloads(projectPath=".")` → if `TestPlayer` is not registered, call `godot-mcp-runtime:add_autoload(projectPath=".", autoloadName="TestPlayer", autoloadPath="scripts/test_player.gd")`. The harness script is created by `setup-project` (Step 3b) but deliberately NOT registered there. This start is idempotent — every mode (re)registers it here, and every mode unregisters it at Finish (step 5), so the harness never survives a mode run.

2. **Launch with retry:** `godot-mcp-runtime:run_project(scene=scene, background=true)` → `start_test(scenario)` (Godot autoload) → Godot runs autonomously at 60Hz → `get_test_report()` (Godot autoload) → structured JSON report. `start_test` returns immediately and the simulation keeps running between MCP calls — use that window for spot screenshots (see the vision/critique modes).

3. **Verify invariants:** Report contains `violations[]` array and `metrics` dict. If `violations.is_empty()`, pass. Otherwise, take spot screenshots for each violation type for debugging.

4. **Generate formatted report:** Convert JSON report to human-readable format per mode requirements.

5. **Finish:** `godot-mcp-runtime:stop_project()` then `godot-mcp-runtime:remove_autoload(autoloadName="TestPlayer")` so test infrastructure never ships. The next mode (if any) re-registers it at its own start (step 1), so unregistering here is always safe — do not skip it.

> **If `godot-mcp-runtime:run_project` fails** (bridge timeout, "did not respond", or "process exited"): **Do NOT retry immediately.** Follow the run-recovery procedure in `./.opencode/skills/create-scene-with-script/reference/mcp-patterns.md` (_Error Recovery Pattern_): read `godot-mcp-runtime:get_debug_output()` first, kill and recycle the port, fix the root cause, then retry once. If it fails again with the same error, **STOP** and report to the caller: `⛔ BLOCKED: runtime phase failed after sanctioned recovery` — do not infinite loop, and **do not improvise workarounds** (self-launched Godot, `attach_project`, custom test hooks, shell-based runners). Happy-path-only: if the sanctioned path cannot verify, the result is a BLOCKED report, not an invented alternative.

> ⚠️ **Never run pkill yourself** (any variant): the MCP server process (`npx godot-mcp-runtime`) contains "godot" in its command line and broad patterns kill it — permanently removing all engine tools for the session. Even the previously-safe quoted `pkill -f 'godot --path'` is now forbidden: permission rules string-match (not argv-parse), and repeated denials push models toward unquoted forms that killed a live run. Use the blessed script instead: `bash("./.opencode/skills/create-scene-with-script/scripts/stop_engine.sh")`. See the Critical warning in `create-scene-with-script/reference/mcp-patterns.md`.

**Screenshots are now rare** — taken only when a violation occurs, not as primary verification.

> ⚠️ **Background mode throttles idle frames (macOS).** With `background=true`, the OS throttles the hidden-window engine between MCP calls: frame times of **10-12s** were observed (Run 5), meaning the simulated world advances ≤0.133s per idle wall-second. Consequences: (a) a game that "loses in 1.4s of sim time" survives many wall-minutes — never judge pacing from wall-clock observations; (b) a 60s scenario may be only ~1-2s of simulated interaction; (c) huge single-frame deltas on MCP-call resume can trip game logic (instant loss on first frame) — that is a **harness artifact, not necessarily a game bug**; verify suspected boot-loss in a single awaited `run_script` before diagnosing game code. For gameplay-quality judgments (vision/critique), **drive the gameplay inside one `run_script` body** (await physics frames, actuate inputs, sample state) — do not rely on bot behavior across MCP call gaps.

> ⚠️ **Synthetic input is invisible to event-driven handlers.** `Input.action_press()` (via `run_script`) and `simulate_input` key/action events do **not** generate InputEvents: handlers using `_unhandled_input(event)` or `Input.is_action_just_pressed()` may never see them (`action_press` registers `just_pressed` for only the exact press frame). If restart/menu handlers appear dead under the harness but work for humans, check which input API the handler uses before declaring the game broken. Robust patterns the harness CAN drive: `Input.is_action_pressed` polling in `_process`, or `_input`/`_input(event)` with `parse_input_event`. A critique-mode REWORK citing "unresponsive controls" must be verified against this list first.

> **Script edits under a running engine require a restart.** Playtest itself never edits game files — but you may have edited a `.gd` file (e.g. fixing a parse error the validation step surfaced) while the engine this skill launched is still running. Godot caches compiled script bytecode in a running process; the live process keeps reporting **stale errors at phantom line numbers** — including parse errors you already fixed (observed 09-03: an agent fixed a duplicate-variable parse error, re-validated, saw the identical error pointing at the now-correct line, and burned 5+ steps hunting a nonexistent second bug before guessing "cached bytecode"). If you edited a script and the reported error doesn't match the current file contents, **do not debug the file** — `stop_project()`, relaunch, and re-register the autoload before re-validating.

---

## Mode: fast-verify

**When:** Immediately after creating/editing a scene or script, before logging the task complete. Default per-task verification — roughly one-third the cost of `scene-verify`.
**Purpose:** Catch load-time crashes, parse errors, and gross runtime breakage WITHOUT the full 15-second chaos gauntlet. This mode exists so that "playtest is slow" is never a reason to skip verification (observed 09-04, ling run: an orchestrator skipped playtest entirely on 4 tasks "to avoid timeouts" — a sanctioned-path violation born of cost pressure. The cheap sanctioned path removes that incentive).

**You MUST run at least this mode after every scene/script change before marking a task `[x]`.** Skipping verification entirely is prohibited — if even fast-verify cannot run (MCP down, engine won't start), the outcome is a `⛔ BLOCKED:` report, not an unverified `[x]`.

### Workflow

1. Ensure harness autoload (Common Workflow step 1)
2. Launch Godot with `background=true`, scene as `scene` parameter
3. Run a 5-second chaos scenario — same baseline invariants as scene-verify, shorter duration:
   ```
   start_test(scenario={
       "bot": {"type": "chaos", "seed": 42, "input_rate_hz": 10},
       "duration_s": 5,
       "invariants": [
           {"name": "no_crash", "rule": "no_fatal_errors"},
           {"name": "no_physics_blowup", "rule": "nodes_finite"},
           {"name": "fps_stable", "rule": "custom", "path": "_meta.frame_ms_p99", "check": "below", "value": 33.3}
       ]
   })
   ```
4. `get_test_report()` → if `violations.is_empty()`, PASS
5. Finish: `stop_project()` + `remove_autoload` (Common Workflow step 5)

### Scope and limits

- Covers: parse errors, autoload failures, crash-on-load, NaN/Inf blowups, FPS floor
- Does NOT cover: gameplay logic, score/rate invariants, mechanics correctness — those need `scene-verify` (per-scene) or `functional` (pre-ship)
- A fast-verify PASS is necessary but not sufficient for task completion when the task added interactive mechanics — follow with `scene-verify` in the same delegation if the entity has invariants in `tests/scenarios/`

### Success Criteria
- Scene loads, 5s scenario completes, zero violations
- Verdict reported (PASS/FAIL)

---

## Mode: scene-verify

Quick check after creating a single scene. Pass the scene path via the `scene` parameter.

### Workflow

1. Launch Godot with `background=true`
2. Run chaos scenario via `start_test(scenario={
    "bot": {"type": "chaos", "seed": 42, "input_rate_hz": 10},
    "duration_s": 15,
    "invariants": [
        {"name": "no_crash", "rule": "no_fatal_errors"},
        {"name": "no_physics_blowup", "rule": "nodes_finite"},
        {"name": "stay_on_screen", "rule": "nodes_in_bounds", "min_x": -200, "max_x": 1480, "min_y": -200, "max_y": 920},
        {"name": "fps_stable", "rule": "custom", "path": "_meta.frame_ms_p99", "check": "below", "value": 33.3}
    ]
})`
> **Bounds rationale:** the defaults above are viewport-sized (1280×720) plus a generous margin. Entities legitimately leaving the screen during normal play (camera-follow games, wrap-around fields) violate this — that is a *finding about the game's current state*, not a validator bug: before ship, either walls/camera logic confines actors or the scenario widens bounds DELIBERATELY (with a note in the report), never by silently dropping the invariant. *Observed 09-04 (mimo):* default scene-verify passed while a wall-less ball flew to (3510, −2510) — a "clean PASS" that actually meant "physics runs, containment not yet built."
3. Get report via `get_test_report()`
4. If `violations.is_empty()`, PASS. Otherwise, take 1-2 screenshots for each violation type.

### Success Criteria
- Scene launches without FATAL errors
- Invariant checker runs for full duration
- Report generated with zero violations (or documented violations)
- Verdict reported in task result (PASS/FAIL based on violation count)

---

## Documentation

Write the full report to `reports/<mode>-<subject>.md` in the game project (evidence tables, violation details, screenshot analysis) — the report write is a sanctioned `write` to `reports/**` where your permission config grants it. In your task result return ONLY:
- Verdict (PASS/FAIL or HIGH/MEDIUM/LOW) + violation count
- One-sentence cause for any FAIL
- The report file path

If no file-write path exists in your session (write denied or tool absent), do NOT improvise writes through engine primitives (ConfigFile/FileAccess indirection) — return the verdict plus full report inline and state explicitly: "report could not be persisted; no write path." The caller will persist it. The orchestrator reads the file only on FAIL or when evidence is needed — a full report inline in the task result accumulates in every upstream session's context.

---

## One-Time Modes: functional, vision, critique

These run **once per game** (after all tasks complete), not per task — not before. Each has its own workflow, report format, and success criteria:

- **functional** — exhaustive mechanic verification: collect per-entity invariants via `glob("tests/scenarios/*.json")` + `read()`, apply the counter sanity gate (every game-economy counter needs a `max_delta_per_sec` rate invariant — a counter without a rate invariant is an unverified counter), then run a 60s chaos scenario with merged invariants. `start_test` returns immediately; the simulation runs autonomously between MCP calls.
- **vision** — creative-alignment check: 90s pursuit-bot observation, 6-8 evenly spaced screenshots (`responseMode: "preview"`) analyzed with the template above, rate each vision element ✅/⚠️/❌.
- **critique** — player-experience evaluation: 120s replay/chaos session, 8-10 evenly spaced screenshots, first-person present-tense narration grounded in captures; read README.md only, never sources.

Full workflows, scenario configs, and report templates: [reference/full-modes.md](reference/full-modes.md).

**Rate-limitation gotcha:** start_test invariants are checked for `duration_s` of gameplay — do not confuse run_script probe timeouts (MCP client-side) with the scenario clock. Long in-engine waits from `run_script` bodies hit the MCP client timeout — see `create-scene-with-script/reference/mcp-patterns.md`.
