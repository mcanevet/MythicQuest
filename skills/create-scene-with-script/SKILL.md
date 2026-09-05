---
name: create-scene-with-script
description: Create and assemble Godot scenes with scripts and collision physics. Use when implementing game entities (characters, projectiles, enemies, obstacles), UI screens (menus, HUD, pause), or complete game levels. Applies architecture patterns from project docs. Includes validation via scripts/validate.sh.
---

## What I do

Creates complete Godot scenes by:
- Reading plan file from GAME_STATE.md link for requirements
- Consulting `CONVENTIONS.md` (if present) for project-specific patterns
- Writing `.tscn` scene files with proper node hierarchies
- Writing `.gd` scripts with correct architecture
- Creating supporting resources (shapes, placeholders)
- Validating according to component type checklist

**See reference files for detailed patterns:**
- **Physics nodes & collision** → [reference/physics-nodes.md](reference/physics-nodes.md)
- **MCP tool usage & error recovery** → [reference/mcp-patterns.md](reference/mcp-patterns.md)
- **Worked examples** (player entity, pickup trigger, physics projectile — exact node hierarchies + script skeletons): [reference/examples.md](reference/examples.md) — read the one matching your entity type before Step 3
- **Testing & validation** → `./.opencode/skills/setup-project/reference/testing-patterns.md` (canonical schema: bot types, invariant rules, metrics, test hooks)
- **Godot architecture best practices** → [reference/godot-best-practices.md](reference/godot-best-practices.md) — consult when designing hierarchy, node coupling, autoloads, or choosing process callbacks

## Execution Flow

### Step 0: MCP Health Check (MANDATORY)

Before any MCP tool call, verify bridge availability:

```
godot-mcp-runtime:get_project_info(projectPath=".")
```

If this returns an error or times out → **FAIL IMMEDIATELY**. Report "MCP bridge unavailable" and stop. No fallback to file-based patterns.

### Step 1: Context Discovery

Read files in this order — stop once you have what you need:

1. Plan file (linked in GAME_STATE.md's `[in progress]` line) → Task requirements (always read first)
2. `CONVENTIONS.md` → Project-specific collision layers (if present, only if you need collision layer assignments)
3. `GAME_STATE.md` → Vision context (only if the plan references visual style or feel)
4. `./.opencode/skills/setup-project/reference/testing-patterns.md` → Testing requirements schema (if implementing interactive entity)

**Optional Step 1a — cross-project lessons check:** `glob("LESSONS.jsonl")`. If present, `grep` it for tags matching the current task's domain (e.g. "signals", "collision", "instanced-nodes"). This is the harness-level cross-project lessons store — a cheap keyword lookup, not a blocking step. If the file doesn't exist, skip silently; most projects won't have it unless a human has placed a copy. This repo does not generate the file itself.

Do NOT read `project.godot` unless you need to verify specific input action names.
Do NOT call `godot-mcp-runtime:get_project_info` more than once.

Extract from the plan file:
- Component name and type (Player, Enemy, Item, System)
- Root node type (CharacterBody2D, Area2D, Control, etc.)
- Required child nodes
- Script requirements (signals, methods, constants)
- Definition of Done checklist

Extract from `CONVENTIONS.md` (if present):
- Collision layer assignment
- Input action names
- Signal naming conventions
- Node organization standards

**Standard entity scaffolding:** For CharacterBody2D-based entities (player, enemies, NPCs), the plan file's `player.gd` excerpt (see `backlog-grooming`'s `reference/plan-template.md`) is the canonical scaffold. Adapt it to the specific entity's behavior — and always add the mandatory test hooks from Step 4 — rather than rewriting from scratch.

**Built-in gotchas (check before marking task complete):** the full annotated list with failure evidence lives in [reference/gotchas.md](reference/gotchas.md). Triggers — verify each before closing a task:
- Instanced node identification (use groups, not `.name`)
- Unconnected emitted signals
- `AudioStreamPlayer.play()` ordering
- Input action names, not raw key codes
- Continuous-contact re-fire on "on hit" effects (**mandatory stationary perfect-contact verification**)
- Integration into parent scene (Step 4b — dead code otherwise)
- Discrete input events in `_input`, not polled
- Never save scene files during a live run/playtest
- Generated tooling scripts → `tools/`, never skill directories

### Step 1b: Physics Node Selection

See [reference/physics-nodes.md](reference/physics-nodes.md) for complete decision tree and collision setup patterns.

Quick reference:
- Player/AI movement → CharacterBody2D
- Physics objects → RigidBody2D  
- Triggers/pickups → Area2D
- Walls/platforms → StaticBody2D

### Step 1c: MCP Node Path Convention

Node paths are scene-root-relative. Use `root` for the scene root node and `root/<Child>` for descendants; bare child names and `root/<RootName>` (the root node's own name) also resolve.

```
✅ Root node:  nodePath: "root"
✅ Descendant: nodePath: "root/Player"   (bare "Player" also works)
✅ Root by name: nodePath: "root/MyScene"   (the root node's own name also works)
```

If unsure what the root node name is, call `godot-mcp-runtime:get_scene_tree()` first and read the top-level node name from the result.

### Step 2: Pre-Flight Validation

**Architecture Compliance Check:**
- Collision layers match scheme? Node naming PascalCase? Scripts snake_case?
- Hierarchy relationally structured (Main/World/GUI), coupling uses weakest link that works (signal → method → Callable → ref → NodePath), autoloads only for genuinely global systems? See [reference/godot-best-practices.md](reference/godot-best-practices.md) when designing scene structure, node coupling, autoloads, or process callbacks.
- See [reference/mcp-patterns.md](reference/mcp-patterns.md) for error recovery patterns

### Step 3: Scene File Creation

**Node hierarchies: MCP tools.** `godot-mcp-runtime:create_scene` / `add_node` / `batch_scene_operations` build nodes, set primitive properties, and attach scripts.

**Resource-typed values: direct `.tscn` edit** (see Step 5a): `[sub_resource]` blocks, Resource-typed properties (`shape`, `polygon`, fonts, materials), and `PackedVector2Array`/`PackedColorArray` values. This is a domain split, not a preference — MCP tools silently drop these (they report success and write nothing, observed 09-02; root cause: the runtime's value coercer has no Resource-construction path). Edit the `.tscn` directly (direct scene-file edit is permission-granted to the implementing agent) — **but never while a run/playtest is active** (live engine sessions serialize runtime state into scene files; stop the project first).

See [reference/mcp-patterns.md](reference/mcp-patterns.md) for:
- Tool selection strategy (batch vs individual)
- Path conventions (scene-relative vs res://)
- Error recovery patterns
- Validation strategy

Do NOT re-read scene files after writing — trust the write succeeded.

### Step 4: Script File Creation (.gd)

See `./.opencode/skills/setup-project/reference/testing-patterns.md` (_Test Hooks_) for state exposure requirements; scenario configs are covered in Step 5c below.

**Required for interactive entities:** join the `test_exposed` group in `_ready()` and expose a `get_test_state() -> Dictionary` returning the entity's gameplay-relevant values (position, velocity, plus entity-specific keys) — see `testing-patterns.md` (_Test Hooks for Entities_) for the exact hook contract.

### Step 4b: Integrate into Parent/Main Scene (MANDATORY)

A created entity that is not in the scene tree is dead code. Every entity, UI screen, or level MUST be added to its parent scene — default: the project's `Main` scene under the node path the plan specifies (e.g. `root/GameArea`).

- Add the node via `godot-mcp-runtime:add_node` (or `batch_scene_operations`) under the parent; attach its script; set position and other values from the plan
- For reusable/instanced entities: instance the entity scene as a child of the parent — add the node directly under the parent scene when the entity is scene-specific; use `PackedScene.instantiate()` in code when instances are created dynamically at runtime
- **Verify integration:** `godot-mcp-runtime:get_scene_tree()` shows the node under its parent, THEN run `godot-mcp-runtime:run_project` and confirm it renders/behaves in the running main scene
- Success = the entity is present, positioned as planned, and functional inside the running main scene — not just a standalone file that happened to validate

> **Failure mode from real builds:** entities created and validated as standalone files but never added to `main.tscn` caused full task retries (each entity had to be re-done). This step exists because of those failures.

### Step 5: Validate Before Running

Call `godot-mcp-runtime:validate` before `godot-mcp-runtime:run_project`:
- `godot-mcp-runtime:validate(projectPath=..., scenePath=path)` — checks `.tscn`
- `godot-mcp-runtime:validate(projectPath=..., scriptPath=path)` — checks `.gd`
- `godot-mcp-runtime:validate(projectPath=..., targets=[...])` — batch

If `valid: false`, fix all errors and re-validate. Only call `godot-mcp-runtime:run_project` after validation passes.

See [reference/mcp-patterns.md](reference/mcp-patterns.md) for error recovery patterns.

### Step 5a: Setting Resource-Type Properties (Collision Shapes)

MCP tools silently drop Resource-typed values (they report success and write nothing; mechanism and upstream lifecycle status: [reference/physics-nodes.md](reference/physics-nodes.md), error-recovery details: [reference/mcp-patterns.md](reference/mcp-patterns.md)). Trust nothing Resource-typed through `set_node_properties`/`add_node`.

> **Upstream status (upstream-worthy):** identified 09-02 in godot-mcp-runtime; issue drafted for the coercer gap + unconditional success reporting. This direct-edit workaround retires when a godot-mcp-runtime release supports Resource-typed property coercion — re-check against the runtime changelog before relying on it.

**Sanctioned path:** Direct-edit the `.tscn` to embed `[sub_resource]` blocks (direct scene edit is allowed for this exact purpose; no run/playtest active). Full templates and patterns: [reference/physics-nodes.md](reference/physics-nodes.md) (_Collision Shape Setup_), failure-recovery details: [reference/mcp-patterns.md](reference/mcp-patterns.md). Then confirm the persisted file on disk actually contains the `shape = SubResource(...)` binding — this class of write has failed silently before (Bug 2, observed 09-02), and the runtime read-back can lag the bridge's in-memory state.

**Runtime-only assignment (special case):** Use `godot-mcp-runtime:run_script` to assign shape via GDScript. Only when dynamic modification is required after creation.

### Step 5b: Signals & Callback Wiring

**Design first:** use the weakest coupling that works — signal → method call → Callable → node reference → NodePath. Signals are best when one thing happens and several listeners respond; emit from the origin with a past-tense verb (`item_collected`), connect in the consumer. See [reference/godot-best-practices.md](reference/godot-best-practices.md) §2.

**Choose the connection method by domain:**
- `godot-mcp-runtime:connect_signal()` — static connections known at design time (persisted in the `.tscn`)
- Code-based in `_ready()` (`signal.connect(method.bind(...))`) — conditional connections, runtime-created nodes, or extra params

**Callback methods must:**
- Accept the same parameter list as the signal — a signature mismatch is a silent no-op or runtime error
- Follow `_on_<node>_<signal>` naming (e.g. `_on_ball_body_entered`) for debuggability
- Exist on the receiving node before the connection fires (create them, don't assume)

**Verify (mandatory):**
1. `godot-mcp-runtime:get_node_signals(nodePath)` for each source node → connection present (target, method)
2. Fire manually at runtime (`run_script` or input) → confirm the handler runs and produces the expected effect
3. Inspect `godot-mcp-runtime:get_debug_output()` for `SCRIPT ERROR` / "method not found" / "signal not connected" backtraces
4. If missing/mismatched → re-wire or fix the signature, then re-verify

**Common wiring failures this catches:** typo in the scene-relative path; method-name mismatch (signal calls `_on_scored` but the handler is `_on_score`); connection lost after duplication/rename.

### Step 5c: Test Scenario Config

For interactive entities, create `tests/scenarios/<entity_name>.json` using the canonical schema in `./.opencode/skills/setup-project/reference/testing-patterns.md` (bot types, invariant rules, metrics).

- Start from the canonical scenario schema and the full example in `testing-patterns.md` (_Scenario Configuration_, _Full Scenario Example_); add a `custom` invariant per game-specific behavior (requires `get_test_state()` on the entity — see Step 4)
- **This file is not just documentation** — `playtest`'s `functional` mode globs `tests/scenarios/*.json` and merges these invariants into the final QA scenario, so entity-specific correctness gets checked automatically at final QA, not just at scene-verify time.
- **Never invent a `rule` name** — an unknown rule is silently ignored by the harness (appears to pass while nothing is checked). Use only the canonical list in `testing-patterns.md` (_Invariant Rules_).

### Step 6: Validation Matrix

See `./.opencode/skills/setup-project/reference/testing-patterns.md` (_Verification Strategies_) for full testing strategies.

**Quick reference:**
- **Static** — `godot-mcp-runtime:run_project(background=true)` → `godot-mcp-runtime:get_debug_output()`
- **Interactive** — Run chaos scenario. Zero violations = pass; screenshots are debugging aids for reported violations only, never an alternative pass path
- **UI** — Same as interactive + `godot-mcp-runtime:simulate_input` with `click_element`

> **If `godot-mcp-runtime:run_project` fails:** the full error-recovery procedure (retry ladder, BLOCKED terminus, do-not-improvise list, pkill prohibition) lives in [reference/mcp-patterns.md](reference/mcp-patterns.md) — follow it there, do not re-derive it.

### Step 7: Run Shell-Based Validators (MANDATORY)

**Required before marking task complete.** After visual/invariant verification passes, run the validator:

```bash
./.opencode/skills/create-scene-with-script/scripts/validate.sh "scenes/<scene_name>.tscn" "scripts/<script_name>.gd"
```

**Exit code must be 0.** If the validator fails:
- Fix all errors reported
- Re-run validator until it passes

> **One scene↔script pair per invocation.** The validator binds the script to the scene it
> checks; it does not accept or batch multiple pairs in one call, and it does not follow
> PackedScene instancing (a script referenced only via an instanced child scene must be
> validated against that child scene, not the parent — observed 09-04 twice in one run:
> agents re-derived the one-pair rule from validator failures in two different sessions).
- Do NOT mark task complete until validation succeeds

The validator checks:
- Scene file exists and has content
- Root node present
- Attached scripts exist
- Scene references attached scripts
- ALL CollisionShape2D nodes have `shape` properties ← Critical for physics

For a headless engine parse check (catches script errors the text validator can't):

```bash
./.opencode/skills/create-scene-with-script/scripts/headless_check.sh
```

This loads the project headlessly and quits — any script parse errors will surface. Run after `validate.sh` passes, before runtime verification.

## Success Criteria

- Scene + script created and pass `godot-mcp-runtime:validate()` (no errors, loads without FATAL/ERROR)
- **Shell validator passes** — `validate.sh` exits 0 (plus `headless_check.sh` before runtime verification)
- **Entity integrated into parent/main scene and verified in the running scene tree** — not just a standalone file that validates
- Signal connections verified via `get_node_signals()`; test hooks + `tests/scenarios/` config present for interactive entities
- Invariant-based verification passed (zero violations); screenshots are diagnostic aids for violations, never a pass path

## Failure Patterns & Recovery

Common errors and their fixes are tabulated in [reference/mcp-patterns.md](reference/mcp-patterns.md) (_Common errors and fixes_) — consult before diagnosing. **Retry:** parse error → identify pattern → apply fix → re-validate. Max 3 attempts, then `⛔ BLOCKED`.

## Critical Rules

1. Read plan file from GAME_STATE.md link first, then CONVENTIONS.md if present
2. No post-write re-reads — if write returned no error, file was created
3. Screenshot → `read()` → analysis before next tool call
4. Validate each file exactly once
5. **MCP tools for node setup; direct `.tscn` edit for sub_resources/Resource-typed properties (never during a run)** — see Step 5a
6. **Collision shapes** → embed `[sub_resource]` blocks via direct `.tscn` edit and verify on disk (see Step 5a and [reference/physics-nodes.md](reference/physics-nodes.md))
7. No repeated directory scans — one glob per directory
8. EXECUTE IMMEDIATELY — no questions when skill loads
