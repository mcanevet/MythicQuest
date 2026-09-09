# Run 13: OrbField E2E — SHIPPED (lumo-max / medium; 3D exploratory run; post-run analysis of background-mode visual verification)

**Status: SHIPPED — 20/20 tasks (18-task backlog + critique-loop Tasks 19–20), 0 blocked, 0 harness interventions.** Full pipeline: ian genesis → poppy dev loop (tasks 1–16 in 10 sessions, no respawns) → rachel functional QA **PASS, 0 violations** → ian vision ALIGNED → pootie consumer critique **REWORK 0.5** (ball too fast for the arena; uncontrollable) → poppy fix (acceleration ramp, braking, lower top speed, glowing edge rim — tasks 19–20) → rachel QA re-run **PASS** → ian vision re-check ALIGNED → pootie round 2: **SHIP, 1.5 B-holes** (verified 8/8 clear, zero deaths, full win/restart loop). Root session `ses_f7ae76fe0ffeGyvKtxAGaeVoWm` ("brave-mountain"), 2026-09-09 07:36–13:23 UTC (~5h47m wall, of which **3h45m was host sleep** — one freeze gap 08:01→11:47, self-recovered; engine telemetry showed 0 stall ticks during live windows, cleanly distinguishing suspension from throttle).

**Primary purpose of this record:** (1) first 3D run — grades the pre-registered predictions in `benchmarks/prompts/orbfield.md`; (2) exposes the background-mode **visual-verification weakness cluster** (stale/identical screenshots, illegible small HUD text, narrated-but-uncaptured events) that motivated playtest-skill changes on 2026-09-09.

## Prediction scorecard (from the OrbField prompt)

1. **2D-only physics decision table → 3D mapping: CONFIRMED CLEAN.** Poppy mapped analogically without stalls across all dev sessions: `RigidBody3D` rolling sphere, `BoxShape3D`/`SphereShape3D` collisions, `WorldEnvironment` + `DirectionalLight3D`, `Area3D` triggers, camera follow via `Camera3D` script. One self-corrected mistake (CylinderMesh radial-4 "square" — switched to box, caught in the same session). No BLOCKED reports attributable to 3D.
2. **Camera setup improvised, fast:** dedicated `follow_camera.gd` (fixed-offset + smoothing) written in the same session as the player; no stall, no ian consultation needed.
3. **3D bounds derivation: CLEAN.** QA scenarios derived `nodes_in_bounds` from the 25×25 arena correctly (±12.5 + margin); a wall-less fall-off game was handled as intended — falling is the lose condition, not a bounds violation.
4. **Materials/lighting improvised adequately** (emissive orb material, cyan rim glow via inline `StandardMaterial3D` typed dicts).
5. **Consumer critique in 3D: PARTIAL — the main weakness (see findings).** Pootie drove the ball (real movement verified, orbs collected, restart verified), but every vision/critique session fought screenshot artifacts.

## Finding 1: background mode degrades VISUAL verification, not simulation

Three independent sessions hit it (traces reviewed post-run):

- **Ian (vision):** consecutive screenshots returned identical dark frames (idle ball at center) across differing timestamps — idle-frame aliasing under background throttle, initially read as "maybe the game is frozen." Small 3D HUD text unreadable even at `responseMode: full` — verdicts hedged on "'Orbs: 1 / 8'? … I believe (can't fully read)".
- **Pootie (critique rounds 1–2):** narrated score counts (2/8→7/8) that his captures contradicted — every frame since his first fall showed the frozen Game Over screen; caught only when the counter appeared to go DOWN, followed by an on-stream retraction and an honest replay. Round 1 verdict (REWORK 0.5) was still substantively correct — the game WAS uncontrollable — but parts of the narration were fiction-adjacent before the correction.
- **Rachel (functional QA):** unaffected in substance — her probes are programmatic — but burned multiple rounds on (a) probes run against a PAUSED tree after an accidental lose between calls (all-zero displacement readings misread as "steering broken"), and (b) reading `.visible` on freed orb refs after `queue_free()`. Also one `run_script` inline-source corruption incident (structural brace error the authored source did not contain; suspected transport mangling — **unconfirmed, repro pending**).

**Engine-side telemetry (deployed this run) worked:** `stall_ticks_over_100ms: 0`, `warmup_resets: 0` across all scenario reports — the 3h45m freeze was cleanly attributed to host sleep (kernel sleep/wake pair 09:19:59/09:20:00; `caffeinate` was running), NOT engine throttling. On prior overnight runs the same signature was misattributed; this is the telemetry paying for itself in its first deployment.

→ Codified 2026-09-09 in `skills/playtest/reference/full-modes.md`: probe-authoring rules (probe step 0 = unpause+reload+assert preconditions; node PATHS not refs across gameplay events; whole-suite-in-one-awaited-script; reformat-on-suspected-transport-mangling), vision-mode evidence-channel rule (programmatic text sampling beats pixel reading for HUD/text; static capture series ≠ frozen game), and the narration-screenshot correspondence rule (retract uncaptured narration before continuing).

## Finding 2: upstream candidates (investigate before filing — empirical-first)

- **`simulate_input` `wait(ms)` sim advancement under background throttle:** critics/vision sent input with 600–1500ms waits and the world often didn't visibly advance between captures. Either `wait` should deterministically pump frames, or the tool should document that it is not a sim-time guarantee. Needs an isolated repro (now cheap: the telemetry exists).
- **`run_script` inline-source corruption on long nested dicts (unconfirmed):** if reproducible (send a known long nested-dict script repeatedly, diff what arrives), it is a real godot-mcp-runtime transport bug.
- **`take_screenshot` freshness under background mode (unconfirmed):** identical-content captures at differing timestamps could be stale render output rather than a static world. Same repro session as above.
- **Stale arena photograph gotcha avoided:** no `tests/scenarios` drift this run (run-12 lesson held).

## Objective Triad

1. **Outcome:** PASS — shipped; vision aligned twice; consumer REWORK was a real defect (untunable speed) fixed in one cycle; final replay verified 8/8 + win screen + restart loop.
2. **Speed:** ~5h47m wall including 3h45m host sleep → ~2h effective. Healthy session pacing (longest single subagent session 32m; 21 subagents, no retries/respawns).
3. **Tokens:** ~8.9M input across the tree (root 0.38M; largest subagent 0.83M — pootie round 2, artifact-fighting included). No timeout ladders; QA batched probes as trained (quick-island's single-mechanic-suite probe is the exemplar).
