# One-Time Playtest Modes: functional, vision, critique

Loaded from `../SKILL.md` — these run once per game (after all tasks complete), not per task.
Referenced back as the full workflows behind the SKILL.md one-time-modes summary.

## Mode: functional

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
        "type": "replay",  # use only when a recorded input session exists; otherwise use "chaos"
        "inputs": []  # Optional: array of {frame, action, pressed} entries
    },
    "invariants": [
        { "name": "no_crash", "rule": "no_fatal_errors" }
    ]
})
```

### Step 3: Play session (120 seconds)

`start_test` returns immediately and playback runs at 60Hz. **Capture 8-10 screenshots evenly spaced (~one every 12-15s)** — don't wait for "noteworthy moments" (you can't know what's noteworthy without seeing it first; with sparse sampling you'll miss the moment anyway). Use `responseMode: "preview"` to keep token cost down. Ground your narration in what you actually see from these captures; if a screenshot shows something interesting, mention it in first-person present tense. Extra captures without full analysis are acceptable and available for debugging.

> ⚠️ **Before declaring controls "unresponsive" or the game "stuck":** consult the two gotchas in SKILL.md's Common Workflow (background-mode idle throttling; synthetic input invisible to `_unhandled_input`/edge-detected handlers). In Run 5, three consecutive critiques REWORK'd a game whose controls actually worked for humans — each was a harness-path artifact. If the bot can't restart a game-over screen, verify via a scripted probe (e.g. `Input.parse_input_event` in `run_script`, or programmatic scene reload) before flagging it as a game bug. Also verify the input map actually contains the advertised bindings — a dead binding (keycode 0) is a real bug the harness's action-press path can expose.

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

