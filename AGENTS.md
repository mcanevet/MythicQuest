# Agent Architecture Guidelines

## Commands

- Lint skills (run before committing skill/agent changes): invoke the `lint` skill (`.opencode/skills/lint/`) — `./.opencode/skills/lint/scripts/lint_skills.sh`
- Harness debugging/monitoring: invoke the `debug-harness` skill (`.opencode/skills/debug-harness/`)
- Agent authoring: invoke the `agent-authoring` skill (`.opencode/skills/agent-authoring/`)
- Skill authoring: invoke the `skill-authoring` skill (`.opencode/skills/skill-authoring/`)

## Core Principle: Engine and Genre Agnosticism

**Agents must be engine-agnostic AND genre-agnostic in decision logic and role definition.**  
**Skills can be engine-specific but must be genre-agnostic in implementation patterns.**

This separation allows the agent swarm to be portable across game engines (Godot, Unity, Unreal, custom) and across any game genre (puzzle, action, strategy, simulation) while keeping implementation knowledge localized.

---

## Architectural Boundaries

### What Belongs in Agents (Engine-Agnostic)

✅ **Role Definition & Persona**
- Who the agent is (Creative Director, Lead Engineer, QA, etc.)
- Decision-making frameworks
- Quality standards and expectations

✅ **Workflow Logic**
- Pre-flight checklists (conceptual, not tool-specific)
- Validation matrices (component type → test type)
- Error handling protocols
- Collaboration patterns between roles

✅ **Skill Invocation**
- Which skills to execute
- When to chain skills
- High-level approach selection

❌ **What Does NOT Belong in Agents**
- Engine API names (e.g., `RectangleShape2D`, `CollisionShape2D`)
- File format specifics (e.g., `.tscn`, `.prefab`, `.uasset`)
- MCP tool names and parameters
- Process management (`pkill`, process spawning)
- Engine-specific coordinate systems or physics concepts

### What Belongs in Skills (Engine-Specific Allowed)

✅ **Implementation Patterns**
- Engine API usage
- File format templates
- Node/component hierarchies
- Resource instantiation

✅ **Tool Integration**
- MCP tool calls
- LSP configurations
- Build pipeline scripts
- Validation commands

❌ **What Does NOT Belong in Skills**
- Genre-specific game mechanics (e.g., "platformer jumping", "FPS aiming")
- Specific game references (e.g., "like Pong", "similar to Breakout")
- Streaming/cultural commentary (e.g., "streamer reactions", "chat interaction")
- Agent-specific role knowledge (e.g., "Poppy checks...", "Ian evaluates...") — skills are agent-agnostic

**Skills are agent-agnostic:** Any agent can execute any skill. Role-specific judgment is applied by the agent, not encoded in the skill.

---

## Skill File Organization

To save tokens and improve reliability, skills should follow this organization:

**`scripts/` subfolder** — All deterministic, reusable code:
- GDScript files (`.gd`) — standalone scripts, autoloads, utility functions
- Shell scripts (`.sh`) — validators, build commands, process management
- Any executable logic that is called by reference rather than embedded inline

**Deterministic logic lives in `scripts/`, never inline.** Any logic a skill
executes mechanically — parsing rules, transformation/formatting functions,
filename/slug generation, validators, report rendering — must be a standalone
script in `scripts/` that `SKILL.md` references, not steps the agent hand-types.
**Prose that describes a concrete mechanical transform** ("lowercase the
description, replace spaces with hyphens, strip special chars", "convert the JSON
report into a block") is a signal that the transform should be a script, not
instructions left to execution-by-judgment. A skill may not state a deterministic
rule in prose or a code block when it can be a script.

**Templates belong in `reference/`, not `scripts/`.** A structural template (a
`project.godot` skeleton, a README outline, a plan-file layout) is a reference
artifact for agents to copy — `reference/`, not executable logic in `scripts/`.
Distinguish: *logic* you execute → `scripts/`; *content* you copy → `reference/`.

**`reference/` subfolder** — Documentation and examples:
- Pattern guides (`.md`) — architectural patterns, API usage examples
- Schema definitions — JSON schemas, data format specifications
- Reference implementations — example code snippets for complex patterns

**`SKILL.md`** — Should reference external files, not embed them. Embed only
minimal inline examples (≤20 lines) for illustration. Detailed authoring rules
(frontmatter, trigger descriptions, progressive disclosure, size caps, eval-first)
are in the **`skill-authoring`** skill (`.opencode/skills/skill-authoring/SKILL.md`).

---

## Library Consumption Pattern

This repo is a **reusable agent library**. When consumed by a game project, agents and skills are mounted at `.opencode/` at the consumer project's root — the standard opencode runtime location:

```
GameProject/                    # Consumer project
├── .opencode/                  # Runtime view (symlinks or git submodule)
│   ├── agents    -> .../MythicQuest/agents
│   ├── skills    -> .../MythicQuest/skills
│   └── opencode.jsonc -> .../MythicQuest/opencode.jsonc
├── GAME_STATE.md
├── plans/
└── project.godot
```

**Two contexts, one source of truth:**
- **Harness-build sessions** (developing this library) work directly in `./skills/` and `./agents/` — the source of truth.
- **Game-build sessions** (consumers) see the same files at `./.opencode/skills/` and `./.opencode/agents/` — the runtime view via symlink or git submodule.

**Consequence:** All cross-references inside `SKILL.md` files, skill `reference/` docs, and agent files use `./.opencode/skills/...` paths — these are **runtime-resolvable paths** (correct from the consumer project's perspective), not repo-relative paths. Do not "fix" them to `./skills/` — that breaks every consumer.

**Setup for new consumer projects** (the benchmark sandbox `test/`, prepared by the `benchmark-prep` skill, uses the production layout):

```bash
# Option 1: Git submodule (production — recommended)
# Pins the library to a specific commit; consumers update deliberately.
# The whole repo becomes the submodule at .opencode/ — the loader resolves
# .opencode/agents and .opencode/skills from the checked-out tree directly.
git submodule add <library-url> .opencode

# Option 2: Direct symlinks (development/testing only)
# Live-links to a checkout of this repo — changes apply instantly, no pinning.
mkdir -p .opencode
ln -s /path/to/MythicQuest/agents .opencode/agents
ln -s /path/to/MythicQuest/skills .opencode/skills
ln -s /path/to/MythicQuest/opencode.jsonc .opencode/opencode.jsonc
```

**Gotcha:** The symlinks must exist before `opencode run`. "Skill not found" errors usually mean `.opencode/skills` doesn't resolve — verify with `ls -la .opencode/skills`.

---

## Skill Authoring Best Practices

When creating or revising skills, follow the **`skill-authoring`** skill (`.opencode/skills/skill-authoring/SKILL.md`) — it owns the full authoring rules (frontmatter, triggers, progressive disclosure, scripts/ACI design, eval-first iteration). The enforced rules and their checks live in the `lint` skill's registry (`.opencode/skills/lint/scripts/rules.yaml`); run both of its gates before committing.

---

## Permission Model

### Frontmatter Permissions

Permission declarations are **configuration**, not logic. They may reference engine-specific tools:

```yaml
permission:
  "godot-mcp-runtime_*": allow  # OK - this is config, not instruction
  "unity-mcp-*": deny           # Would update for Unity projects
```

**Important:** Comments should indicate portability:
```yaml
# Engine-specific MCP permissions — update these patterns for your engine
"godot-mcp-runtime_*": allow
```

### File Access Rules

- `edit: "**/*.tscn": allow` for poppy — engine MCP scene tools cannot persist Resource-typed properties (their value coercer maps only Vector/Color dicts; typed assignments fail silently while reporting success — godot-mcp-runtime coercer gap, docs/upstream-backlog.md), so sub_resource injection requires direct scene-file edits. Safe only when no run/playtest is active (procedural rule in create-scene-with-script). Other agents keep it denied.
- `edit: "**/*.gd": allow` — Game logic scripts are engine-specific but portable within engine
- `edit: "skills/*/scripts/*.gd": deny` — Skill implementations protected from runtime edits (note: `setup-project` legitimately *copies* `test_player.gd` into consumer projects, so scoping the deny to skill dirs — not `**/test_*.gd` — avoids blocking that bootstrap step)
- `bash: "*": deny` — No direct shell access; skills handle process management

---

## Portability Layers

### Layer 1: Agents (Portable)
- Decision logic independent of engine
- Role responsibilities universal
- Workflow patterns transferable

### Layer 2: Skills (Per-Engine Forks)
- Each engine has its own skill implementations
- Same skill name, different internals
- Example: `setup-project` differs between Godot/Unity/Unreal

### Cross-Engine Parity Tracking

When multiple engine forks exist, track feature drift:
- Each skill should document its API surface (bot types, invariant rules, config schema)
- Adding a bot type or invariant to one fork requires a tracking note in the other fork(s)
- Before migration, diff the API surfaces to identify missing capabilities
- Not urgent with one engine, but noted to prevent migration surprises

### Layer 3: Configuration (Project-Specific)
- `opencode.jsonc` defines MCP/LSP for current engine
- `project.godot` vs `ProjectSettings.asset` vs `DefaultInputSettings`
- Auto-discovered via `projectPath`

### Upstream Contribution Rule (External Dependencies)

This library depends on external tools (MCP runtimes, LSP servers, opencode itself).
When a build or benchmark exposes a bug or missing feature in one of them:

1. **Prefer contributing a fix over filing a feature request.** A repro + patch
   upstream removes the need for workarounds in *every* consumer project; an
   issue alone leaves our skill-level workarounds in place indefinitely.
2. **Workflow:** fork (or use the existing fork remote) → TDD regression test →
   fix on a feature branch → open a PR upstream → pin the published release in
   `opencode.jsonc` once merged (interim: point the MCP command at the fork
   branch, marked TEMPORARY with a revert condition).
3. **Workarounds in skills/agents must cite their upstream status** — a gotcha
   that exists only because of an upstream gap says so (e.g. "upstream-worthy"),
   so the workaround can be deleted when the fix ships.
4. **Track the lifecycle:** record in the failure-modes reference (or the issue
   link) whether the item is filed → patched → released → workaround retired.
   A workaround whose upstream fix has shipped is tech debt — retire it on the
   next run that touches the affected skill.

Example: the relative-`projectPath` bug (09-01) — reproduced, patched with a
regression test on a fork branch, PR-ready upstream, released in
godot-mcp-runtime v3.2.3, and `opencode.jsonc` repointed from the fork to the
published package. That is the model to follow.

---

## Migration Path

To switch engines:

1. **Keep agents unchanged** — No modification needed
2. **Update opencode.jsonc** — Point to new engine's MCP/LSP
3. **Swap skill implementations** — Replace Godot skills with Unity skills (same names)
4. **Adjust permissions** — Update MCP tool patterns in frontmatter comments

Estimated effort: 2-4 hours per new engine (mostly skill rewrites).

---

## Current Implementation Status

### ✅ Completed
- Agent instructions refactored (all Godot-specific implementation removed)
- Testing framework generalized (references `skills/playtest` for engine details)
- Scene creation patterns extracted to `skills/create-scene-with-script/reference/`
- Process cleanup instructions moved from agent logic into skills (agent permission rules still gate the skill-invoked `pkill`/`sleep` commands)
- Performance guidance in agent files uses engine-agnostic real-time budgets (frame time, tick rate, scene complexity) — no engine API specifics
- Stopping-condition guidance and ACI (tool-layer) design principles adopted per Anthropic's "Building Effective Agents"

### ⚠️ Remaining Work
- Permission frontmatter still contains Godot MCP patterns (acceptable as config)
- Subagent-level stopping conditions are prose guidance (this file + agent files) — no hard per-subagent step cap mechanism yet; enforced by the root steps cap plus agent discipline

### ❌ Not Planned
- Full removal of all engine references from agent files (unnecessary overhead)
- Generic skill abstractions (over-engineering; skills are meant to fork per engine)

---

## Session Types

### Game-Build Session

**Purpose:** Build a specific game from concept to completion.

**Responsibilities:**
- Track task progress via `GAME_STATE.md` and `plans/` directory
- Delegate work to poppy (implementation) and ian (creative/vision) agents
- Ensure each task completes with validation before moving to the next

**What it DOES NOT do:**
- Track its own performance metrics (retry counts, success rates, attempt history)
- Analyze agent behavior patterns
- Calculate productivity statistics

These are **external observability concerns** — handled by the harness-build session.

### Harness-Build Session (You)

**Purpose:** Improve the agent swarm and skill library across projects.

**Responsibilities:**
- **Actively monitor live game-build sessions** — when a build session is running, poll the SQLite session DB to track subagent spawning, detect stalls, and identify failures in real time
- Read Opencode's SQLite session database to analyze agent performance
- Study execution logs from game-build sessions (primary, subagent, and skill invocations)
- Identify patterns: which agents succeed/fail on which task types
- Correlate retry attempts with skill choices, prompt phrasing, or task decomposition strategies
- **Correlate skill/agent changes against playtest report outcomes** — ingest playtest reports across game-build sessions and track invariant pass rates, not just session efficiency metrics
- Update agent instructions or skill implementations based on empirical evidence

**Active Monitoring Protocol:**

When invoked while a game-build session is in progress, follow the **`debug-harness`** skill (`.opencode/skills/debug-harness/SKILL.md`) for the concrete queries and the polling script. In summary:

1. **Discover the active build session** — query the SQLite DB for sessions with recent `time_updated` and `parent_id IS NULL` in the project directory
2. **Map the session tree** — recursively find all child sessions (subagents, retries) and their statuses
3. **Poll for liveness** — check `time_updated` on leaf sessions every 5-10 seconds; a session that hasn't updated in 60+ seconds may have stalled
4. **Detect stall conditions** — a session with zero child spawns and no `time_updated` change for >60s likely indicates a silent failure or hang. *Caveat:* large wall-clock gaps can be host sleep — confirm via tool-call activity before intervening (see Stopping Conditions below)
5. **Diagnose root causes** — when a stall is detected, inspect `GAME_STATE.md`, `plans/`, and the project filesystem to determine what was completed vs. what failed
6. **Intervene or log findings** — either restart the stalled workflow manually, or document the failure pattern in session output for later harness analysis

**Key Principle:** The game-build session is blind to its own performance. It just builds. You observe via the SQLite DB — both actively (during builds) and asynchronously (post-hoc) — and iterate on the harness itself.

**Boundary Rule: Harness-build NEVER modifies `test/`.** The `test/` directory is the *consumer project's workspace* (the development sandbox owned by game-build sessions). Harness-build may **read** `test/` for diagnostics (GAME_STATE.md inspection, plan archaeology, playtest report ingestion), but must never write, edit, move, or delete anything inside it. Any fix discovered via `test/` belongs in `agents/`, `skills/`, or `scripts/` — if the fix would require touching `test/`, it is out of scope: document the finding and stop.

**Evidence Loop:** Process metrics (retries, session timing) are necessary but not sufficient. A skill change that reduces retries while quietly increasing invariant violations is a regression. Harness-build must correlate both axes:
- **Efficiency axis:** retry counts, session duration, skill invocation success, stall detection
- **Outcome axis:** playtest pass rates, invariant violation counts, crash rates

**Why this separation?**
- **Cleaner game-build sessions:** Less cognitive load, no dual-tracking (building + self-monitoring)
- **Better data quality:** External observation avoids bias from the building agent trying to "optimize" its own metrics
- **Cross-project learning:** The harness correlates patterns across sessions through external SQLite DB analysis
- **Real-time intervention:** Active monitoring catches stalls and silent failures before they waste hours of idle wall-clock time
- **Asynchronous iteration:** Post-hoc analysis happens between builds for deeper pattern analysis

---

## Debugging the Harness

When a game-build session stalls, fails, or produces unexpected results, invoke the **`debug-harness`** skill (`.opencode/skills/debug-harness/SKILL.md`). It covers:

- Querying the opencode SQLite session DB (WAL mode, direct reads)
- Inspecting reasoning traces (spin loops, permission denials, format errors)
- Correlating with filesystem state (GAME_STATE.md, plans/, skill symlinks)
- Real-time stall monitoring (`scripts/watch_session.sh`)
- Full session-tree trace extraction for offline analysis
- Failure-modes table (MCP suicide, silent subagent deaths, bridge contention, partial log-result, and more — `reference/failure-modes.md`)

The skill lives at `.opencode/skills/debug-harness/` in this repo. Only top-level `skills/` and `agents/` are mounted into consumer projects; `.opencode/skills/` content (harness tooling) stays behind — consumer `.opencode/skills/` resolves to the library's `skills/` tree, so these skills are unreachable there.

---

## Stopping Conditions & Bounded Execution

Autonomous LLM workers trade latency and cost for capability, and errors compound across many
unbounded turns. Every unit of autonomous work therefore needs a **bounded horizon**
(Anthropic, "Building Effective Agents": *"include stopping conditions ... to maintain
control"*). Guidance:

- **Root build session:** bounded by `agent.build.steps` in `opencode.jsonc` plus the
  anti-recursion guards in `agents/build.md` (the build agent must never do work itself —
  always a further `task()` delegate).
- **Subagent tasks:** every delegation should bound its own retries. A task that cannot
  converge after its defined attempts must return a **structured failure** to the orchestrator
  (`⛔ BLOCKED: <cause>` + attempts made + evidence) rather than loop. Retries are the typical
  compounding-error mode — default cap is 3 attempts at the task level (as in
  create-scene-with-script's retry rule and the agent error-handling protocol).
- **Skill execution:** skills that loop (validate → fix → re-validate) must state a maximum
  iteration count and the escalation path — never an indefinite loop.
- **Monitoring caveat — wall-clock gaps ≠ stalls.** Host sleep produces large `time_updated`
  gaps with no failure and no agent activity. Diagnose liveness by **progress in tool-call
  activity**, not raw timestamp gaps: a live-but-spinning subagent shows repeated model + tool
  calls with no forward progress, whereas a sleeping host shows a break with none at all.

### Sanctioned Paths Only (No Alternative Paths in Skills)

Rule text lives in the **`lint` skill's registry** (`.opencode/skills/lint/scripts/rules.yaml`; entries `sanctioned-paths-only`, `no-improvised-alternatives`) — including the wording red flags, exemptions, and enforcement. Summary: skills define the one sanctioned path per phase; failures end in a structured `⛔ BLOCKED:` report, never a fallback. An unblocking hack that silently skips validation is worse than a failure — treat work done outside the sanctioned path as not done.

Known incidents that motivated this rule: the engine-stop pkill-suicide chain, the
shadow test-infrastructure (shell scripts reimplementing engine tools), and the
attach-dance improvisation around a failing `run_project` — each converted a diagnosable
failure into silent infra drift.

---

## Enforcement

All rules live in the **`lint` skill's registry** (`.opencode/skills/lint/scripts/rules.yaml`) — the single source of truth (id, rule, audience, scope, enforcement, notes, check, check-tier). This file contains no rule text.

- **Reading the rules:** `cat .opencode/skills/lint/scripts/rules.yaml`
- **Adding/changing a rule:** edit the registry only — never hand-write rules here (see the `lint` skill for the full workflow)
- **Deterministic checks:** `.opencode/skills/lint/scripts/lint_skills.sh` (implements `enforcement: lint`/`both` checks)
- **Semantic checks:** `.opencode/skills/lint/scripts/review_skills_llm.sh` (judge rubric generated from the registry; reviews skills/, agents/, AGENTS.md)
- **Registry health:** `--audit` (verifies registry and lint implementations agree)

Run both before committing skill or agent changes. **Lint failure mode:** flagged line → genericize or document an intentional exception (rare).

---

## Examples

### ❌ Bad (Engine-Specific in Agent)
```markdown
Use `add_node(projectPath=".", scenePath="scenes/main.tscn")` to create nodes.
Add `CollisionShape2D` children with `RectangleShape2D` resources.
Run `godot --headless --script tests/run_all.gd` to validate.
```

### ✅ Good (Engine-Agnostic in Agent)
```markdown
Consult `skills/create-scene-with-script/SKILL.md` for scene creation patterns.
Follow the skill's engine-specific collision setup guide.
Execute the skill's validation script before marking complete.
```

---

*Last updated: 2026-09-01*  
*Status: Active enforcement (including real-time harness monitoring)*
