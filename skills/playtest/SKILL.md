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

> **If `godot-mcp-runtime:run_project` fails** (bridge timeout, "did not respond", or "process exited"): **Do NOT retry immediately.** Follow the run-recovery procedure in `./.opencode/skills/create-scene-with-script/reference/mcp-patterns.md` (_Error Recovery Pattern_): read `godot-mcp-runtime:get_debug_output()` first, kill and recycle the port, fix the root cause, then retry once. If it fails again with the same error, **STOP** and report to the build agent: `⛔ BLOCKED: runtime phase failed after sanctioned recovery` — do not infinite loop, and **do not improvise workarounds** (self-launched Godot, `attach_project`, custom test hooks, shell-based runners). Happy-path-only: if the sanctioned path cannot verify, the result is a BLOCKED report, not an invented alternative.

> ⚠️ **Never run pkill yourself** (any variant): the MCP server process (`npx godot-mcp-runtime`) contains "godot" in its command line and broad patterns kill it — permanently removing all engine tools for the session. Even the previously-safe quoted `pkill -f 'godot --path'` is now forbidden: permission rules string-match (not argv-parse), and repeated denials push models toward unquoted forms that killed a live run. Use the blessed script instead: `bash("./.opencode/skills/create-scene-with-script/scripts/stop_engine.sh")`. See the Critical warning in `create-scene-with-script/reference/mcp-patterns.md`.

**Screenshots are now rare** — taken only when a violation occurs, not as primary verification.

> **Script edits under a running engine require a restart.** Godot caches compiled script bytecode in a running process; after you `edit()` any `.gd` file while the engine runs, the live process keeps reporting **stale errors at phantom line numbers** — including parse errors you already fixed (observed 09-03: an agent fixed a duplicate-variable parse error, re-ran, saw the identical error pointing at the now-correct line, and burned 5+ steps hunting a nonexistent second bug before guessing "cached bytecode"). If you edited a script and the reported error doesn't match the current file contents, **do not debug the file** — `stop_project()`, relaunch, and re-register the autoload before re-validating.

---

## Mode: fast-verify

**When:** Immediately after creating/editing a scene or script, before logging the task complete. Default per-task verification — roughly one-third the cost of `scene-verify`.
**Purpose:** Catch load-time crashes, parse errors, and gross runtime breakage WITHOUT the full 15-second chaos gauntlet. This mode exists so that "playtest is slow" is never a reason to skip verification (observed 09-04, ling run: the build agent skipped playtest entirely on 4 tasks "to avoid timeouts" — a sanctioned-path violation born of cost pressure. The cheap sanctioned path removes that incentive).

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
        {"name": "fps_stable", "rule": "custom", "path": "_meta.frame_ms_p99", "check": "below", "value": 33.3}
    ]
})`
3. Get report via `get_test_report()`
4. If `violations.is_empty()`, PASS. Otherwise, take 1-2 screenshots for each violation type.

### Success Criteria
- Scene launches without FATAL errors
- Invariant checker runs for full duration
- Report generated with zero violations (or documented violations)
- Verdict reported in task result (PASS/FAIL based on violation count)

---

## Mode: functional

**Role pairing (guidance, not a restriction):** typically the engineering-focused agent — any agent may run this mode
**When:** After all tasks are marked `[x]` in GAME_STATE.md
**Purpose:** Verify every mechanic works per spec — exhaustive, evidence-based, systematic

### Preamble: Read the spec

Read **GAME_STATE.md** (completed tasks) and **README.md** (controls, rules, scoring, win conditions, game flow). This is your verification matrix.

### Step 0b: Collect per-entity invariants

`glob("tests/scenarios/*.json")` — each interactive entity created during `create-scene-with-script` has its own invariant config authored with real knowledge of that entity's node paths (see that skill's Step 5c). `read()` each file found and merge their `invariants` arrays into the scenario below, appended after the generic baseline. If no files are found, proceed with the baseline alone — not every project will have interactive entities yet.

**Counter sanity gate (mandatory):** for every game-economy counter you find in the collected `get_test_state()` dictionaries (score, currency, combo, ammo, lives — any monotonically accruing numeric), verify a `max_delta_per_sec` invariant exists for it in the collected set. If one is missing, ADD it to the merged invariants before running, sized to a plausible human ceiling for that game (e.g. a score that legitimately accrues ~1/second gets a ceiling of 5–10/sec). Rationale (observed 09-03): a per-tick collision-handler bug inflated a score at 60/sec and won the game in one catch — every point-in-time invariant passed because the final value was individually "plausible"; only rate-of-change caught it. A counter with no rate invariant is an unverified counter.

### Step 1: Launch with scenario runner

Launch Godot with `background=true`, then run the full functional test scenario. Start from this baseline and append any invariants collected in Step 0b to the `invariants` array before calling `start_test`:

```gdscript
start_test(scenario={
    "scenario_id": "functional_verification",
    "duration_s": 60,
    "bot": {
        "type": "chaos",
        "seed": 123,
        "input_rate_hz": 15  # Higher rate for stress testing
    },
    "invariants": [
        { "name": "no_crash", "rule": "no_fatal_errors" },
        { "name": "no_physics_blowup", "rule": "nodes_finite" },
        { "name": "fps_stable", "rule": "custom", "path": "_meta.frame_ms_p99", "check": "below", "value": 33.3 },
        { "name": "min_30fps", "rule": "fps_floor", "value": 30 }
        # ...append entries from each tests/scenarios/*.json found in Step 0b here
    ]
})
```

**Rule names matter:** the harness matches `rule` exactly — an unknown name is a silent no-op (verification appears to pass while nothing is checked). See `./.opencode/skills/setup-project/reference/testing-patterns.md` for the canonical rule list. `no_fatal_errors` is a marker for process-level crash detection verified externally (crash kills the engine before the harness could check) — the other invariants do the in-run work.

### Step 2: Get structured report

```gdscript
var report = get_test_report()
# report = {
#   "status": "running" or "complete",
#   "violations": [ { "frame": N, "rule": ..., "detail": ..., "node"?: ... } ],
#   "metrics": { "start_frame": ..., "end_frame": ..., "input_count": ...,
#                "crash_detected": ..., "frame_times": [...],
#                "frame_ms_p99": ..., "fps_floor_violations": ... },
#   "frame_count": N
# }
```

### Step 3: Generate verification table

Convert the JSON report into a human-readable format:

```
## Functional Verification Report

| Invariant | Status | Evidence |
|----------|--------|----------|
| No crash during 60s | ✅ PASS | No fatal errors in debug output (process-wide, external check) |
| Physics stability | ✅ PASS | No NaN/Inf in position values (`nodes_finite`) |
| FPS stability | ✅ PASS | p99 frame time = XXms (< 33.3ms threshold) |
| Min FPS floor | ✅ PASS | Average FPS stayed above 30 (`fps_floor`) |
| Input responsiveness | ✅ PASS | ChaosBot fired XXX inputs without hang |

**Overall: PASS / FAIL**

**Violations Found:** N (if any, see report for details)
```

### Success Criteria
- Full scenario runs for specified duration (no premature exit)
- Invariant checker evaluates all declared properties
- Report generated with structured metrics
- Overall PASS if `violation_count == 0`, FAIL otherwise
- Verdict reported in task result (PASS/FAIL)

Note: Screenshots taken only if violations detected — not as primary verification method.

---

## Mode: vision

**Role pairing (guidance, not a restriction):** typically the creative/vision-focused agent — any agent may run this mode
**When:** After functional mode passes
**Precondition:** TestPlayer autoload registered (see Common Workflow)
**Purpose:** Evaluate whether the game matches the original creative vision — art direction, pacing, game feel, emotional core

### Step 1: Read GAME_STATE.md (vision statement, art direction) and README.md (intended player experience)

### Step 2: Launch with extended observation scenario

```gdscript
start_test(scenario={
    "scenario_id": "vision_observation",
    "duration_s": 90,
    "bot": {
        "type": "pursuit"  # use "replay" only when a recorded input session exists (replay requires a prior recording)
        "agent_path": "/root/Game/Player",  # Configure per game
        "target_path": "/root/Game/Enemy",  # Target to pursue
        "deadzone": 10.0  # Movement deadzone
    },
    "invariants": [
        { "name": "no_crash", "rule": "no_fatal_errors" }
    ]
})
```

### Step 3: Observation session (90 seconds)

`start_test` returns immediately and the simulation runs autonomously. **Capture 6-8 screenshots evenly spaced across the run** (~one every 12-15s — place `take_screenshot` calls at different points in the 90-second window; the engine keeps simulating between MCP calls, so each lands on a different phase of gameplay). Use `responseMode: "preview"` to keep token cost down. Judging pacing, art direction, and game feel from 2-3 frames is guesswork — temporal coverage is the point of this mode. Analyze each screenshot with the analysis template (line 10); extra captures without full analysis are acceptable and available for debugging.

Analyze the returned data:
- **Pacing:** Does gameplay tempo match vision? (check interaction lengths from report)
- **Visual feedback:** Are impacts, scores, wins visually clear? (review spot screenshots)
- **Tension curve:** Does difficulty ramp appropriately? (analyze success/failure rates)

### Step 4: Stop and evaluate

```
## Vision Achievement Report

**Vision:** [from GAME_STATE.md]

**Rating per element** (✅/⚠️/❌):
- Emotional core: [assessment]
- **Art direction:** [assessment based on screenshots]
- **Game feel:** [assessment based on response times]
- **Pacing:** [assessment based on interaction/session length stats]

**Overall: HIGH / MEDIUM / LOW**

**Strengths:** [what delivered, reference specific metrics]
**Gaps:** [what missed, reference specific observations]
**Next:** [improvements with priority]
```

### Success Criteria
- 90-second observation session completes (or game over)
- 6-8 screenshots taken across the session (visual descriptions provided)
- Each vision element rated ✅/⚠️/❌ with reasoning
- Verdict reported in task result (HIGH/MEDIUM/LOW rating)

---

## Mode: critique

**Role pairing (guidance, not a restriction):** typically the player-experience critic agent — any agent may run this mode
**When:** After vision mode passes
**Precondition:** TestPlayer autoload registered (see Common Workflow)
**Purpose:** Consumer evaluation — is it beautiful, is it fun, would a real player care?

### Step 1: Read README.md only (controls, rules, scoring, game flow, art style)

Never read source files, scene files, or GAME_STATE.md.

### Step 2: Launch with extended play scenario

```gdscript
start_test(scenario={
    "scenario_id": "critique_playthrough",
    "duration_s": 120,
    "bot": {
        "type": "replay",  # Or "chaos" if no replay available
        "inputs": []  # Optional: array of {frame, action, pressed} entries
    },
    "invariants": [
        { "name": "no_crash", "rule": "no_fatal_errors" }
    ]
})
```

### Step 3: Play session (120 seconds)

`start_test` returns immediately and playback runs at 60Hz. **Capture 8-10 screenshots evenly spaced (~one every 12-15s)** — don't wait for "noteworthy moments" (you can't know what's noteworthy without seeing it first; with sparse sampling you'll miss the moment anyway). Use `responseMode: "preview"` to keep token cost down. Ground your narration in what you actually see from these captures; if a screenshot shows something interesting, mention it in first-person present tense. Extra captures without full analysis are acceptable and available for debugging.

At each significant moment, note how a player experiences it (first-person, present tense), grounded in what actually happened:

```
**Player reactions:** [reaction keyed to events, present tense]
"That's how the object moves… nice and responsive."
"Missed that one — but it felt fair; the angle was readable."
```

### Step 4: Stop and critique

```
**Key moments:** [up to 3 timestamps grounded in actual events from report, or "nothing notable"]
- T=23s: Perfect deflection against odds (replay_t23.png)
- T=87s: Epic interaction, 15 exchanges (replay_t87.png)

**Frustration risk:** [moments a player would give up on, or "held attention"]
- "The learning curve feels smooth — no frustrating spikes detected"

**Verdict:** [one-sentence takeaway a player would give a friend]
"This one's got juice — I want to keep playing it."

**Hand-off:** [bugs/crashes flagged from violation report, or "looked clean"]
```

If game crashes: stop immediately, hand off with abort reason and violation details.

### Success Criteria
- 120-second play session completes (or game over/crash)
- 8-10 screenshots taken across the session, narration grounded in what they show
- All five critique sections produced
- Verdict reported in task result

---

## Documentation

Write the full report to `reports/<mode>-<subject>.md` in the game project (evidence tables, violation details, screenshot analysis). In your task result return ONLY:
- Verdict (PASS/FAIL or HIGH/MEDIUM/LOW) + violation count
- One-sentence cause for any FAIL
- The report file path

The orchestrator reads the file only on FAIL or when evidence is needed — a full report inline in the task result accumulates in every upstream session's context.
