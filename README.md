# MythicQuest

Autonomous Godot game generation powered by opencode's agent architecture.

## Quick Start

```bash
# One command builds the entire game:
opencode run "Build a pong-like game"
```

That's it. The build agent handles everything automatically:
- ✅ Checks prerequisites (GAME_STATE.md, project.godot) → creates them if missing
- ✅ Loops through all tasks in the backlog
- ✅ Plans, implements, validates each task
- ✅ Runs final playtest + vision + critique evaluation when complete

## Core Philosophy

**Agent-based orchestration, not bash scripts.**

MythicQuest replaced complex pipeline scripts with a simple build agent system prompt. Benefits:

- **Simple agent roles** — Each agent has a clear responsibility (planning vs implementation)
- **Embedded validation** — Each skill has success criteria built-in, validated automatically
- **Error handling in context** — Build agent retries blocked tasks, continues loop gracefully
- **True autonomy** — Single command from scratch to playable game
- **Guardrails enforced by permissions, not just prose** — the build agent's `edit`/`bash`/engine-tool access is structurally denied outside status files, so it *cannot* bypass its subagents even under pressure.

## Architecture

### Agents and Skills

MythicQuest uses a **root-level agent library** structure for reusability:

```
MythicQuest/                    # Reusable agent library
├── agents/                     # Agent definitions
│   ├── build.md               # Primary agent (game builder)
│   ├── ian.md                 # Creative Director / Vision QA
│   ├── poppy.md               # Lead Engineer + Planner
│   └── pootie.md              # Streamer Critic
├── skills/                     # Skill implementations
│   ├── genesis/
│   ├── setup-project/
│   ├── create-scene-with-script/
│   ├── backlog-grooming/
│   ├── log-result/
│   └── playtest/
├── opencode.jsonc              # MCP/LSP configuration
└── test/                        # Benchmark sandbox (disposable; prepared by the benchmark-prep skill)
    └── .opencode/              # git submodule -> this repo, pinned at a committed SHA
```

**To consume this library in a real game project, an `.opencode/` runtime view must exist at the consumer project's root** — either a git submodule pointing at this repo (production; the layout `test/` above uses), or a directory of symlinks (`agents`, `skills`, `opencode.jsonc`) back to a checkout of this repo (development only). Full setup recipes — including the path conventions that make skill cross-references resolve — are documented in [AGENTS.md § Library Consumption Pattern](AGENTS.md#library-consumption-pattern).

| Agent | Role |
|-------|------|
| **build** | Game builder, delegates to subagents |
| **ian** | Creative Director, planning & evaluation |
| **poppy** | Lead Engineer, MCP-based implementation |
| **pootie** | Streamer Critic, code-blind final playtest gate |

### MCP + LSP Integration

MythicQuest uses both MCP and LSP for comprehensive Godot development:

| Protocol | Purpose | Tool |
|----------|---------|------|
| **MCP** (Model Context Protocol) | Scene creation, script writing, project control | `godot-mcp-runtime` |
| **LSP** (Language Server Protocol) | GDScript autocomplete, diagnostics, navigation | `opencode-godot-lsp` |

**MCP** enables agents to create scenes, attach scripts, run projects, and simulate inputs.

**LSP** provides real-time code intelligence while editing `.gd` files (autocomplete, error detection, go-to-definition).



## How It Works

### Autonomous Mode (recommended)

```bash
opencode run "Build a pong-like game"
```

The build agent orchestrates the entire development lifecycle:

```mermaid
flowchart TB
    Start["opencode run"] --> Check{Prerequisites?}
    Check -->|Missing| Genesis[Ian: Genesis<br/>Creates GAME_STATE.md]
    Check -->|Missing| Setup[Poppy: Setup-Project<br/>Initializes Godot project]
    Check -->|Present| ReadBacklog[Read GAME_STATE.md]
    
    Genesis --> Setup
    Setup --> ReadBacklog
    
    ReadBacklog --> FindTask[Find next unchecked task]
    FindTask --> Plan[Poppy: Backlog-Grooming<br/>Creates plan file]
    
    Plan --> Implement[Poppy: Create-Scene-With-Script<br/>Implements task]
    Implement --> Playtest[Poppy: Playtest<br/>Functional validation]
    
    Playtest --> Log[Poppy: Log-Result<br/>Records outcome]
    Log --> Complete{All tasks done?}
    
    Complete -->|No| FindTask
    Complete -->|Yes| QA[Final QA Phase]
    
    QA --> FunctPlaytest[Poppy: Functional Playtest<br/>Custom invariants]
    FunctPlaytest --> Vision[Ian: Vision Evaluation<br/>Creative alignment]
    Vision --> Critique[Pootie: Streamer Critique<br/>Player experience gate]
    
    Critique -->|Pass| End["Game Complete!"]
    Critique -->|Fail| NewTasks[Ian: Creates new tasks]
    NewTasks --> FindTask

    %% Feedback loop is bounded by agent.build.steps cap (default 300 in opencode.jsonc).
    
    style Start fill:#e1f5ff
    style End fill:#d4edda
    style Genesis fill:#fff3cd
    style Setup fill:#fff3cd
    style Plan fill:#f8f9fa
    style Implement fill:#f8f9fa
    style Playtest fill:#f8f9fa
    style Log fill:#f8f9fa
    style FunctPlaytest fill:#e2e3e5
    style Vision fill:#e2e3e5
    style Critique fill:#f5c6cb
    style NewTasks fill:#f5c6cb
```

**Key orchestration patterns:**
1. **Sequential OR parallel delegation** — Build agent tasks one subagent per session, spawning parallel subagent sessions only when the next 2-3 tasks are independent (no shared files, no interdependencies).
2. **State-driven loop** — Reads `GAME_STATE.md` to determine next action
3. **Automatic retry** — If validation fails, task remains unchecked and gets retried
4. **Quality gates** — Three-stage final QA (functional → vision → critique) before completion
5. **Feedback loop** — Failed critique creates new tasks, loop resumes. This cycle is bounded by the `agent.build.steps` structural iteration cap (`opencode.jsonc`) — when reached, opencode forces a text-only summary instead of letting the loop spin indefinitely.

### Manual Mode (for testing individual skills)

Skills are invoked by agents through the `skill` tool — there is no direct skill-invocation syntax. To exercise a single skill, prompt the agent to use it:

```bash
# Step-by-step control (prompts are natural language; the agent invokes the named skill):
opencode run --agent ian "Use the genesis skill to create GAME_STATE.md for a small arcade game"
opencode run --agent poppy "Use the setup-project skill"
opencode run --agent poppy "Use the backlog-grooming skill on the current GAME_STATE.md"
opencode run --agent poppy "Use the create-scene-with-script skill to implement the next planned scene"
opencode run --agent poppy "Use the playtest skill in scene-verify mode"
opencode run --agent poppy "Use the log-result skill for the current task"
```

## Validation

Each skill includes **embedded success criteria**. After running a skill, the build agent checks completion using its own tools — `glob()` for file existence, `read()`/`grep()` for content:

```
# Example: verify genesis created a valid GAME_STATE.md
glob("GAME_STATE.md")                              # ✓ File exists
grep("## Task Backlog", "GAME_STATE.md")           # ✓ Backlog section found
grep("^- \[ \] Task", "GAME_STATE.md")             # Should show 10-20 tasks
```

The build agent does **not** have unrestricted `bash` — its `bash` permission is scoped to a single stale-process cleanup pattern, and its `edit` permission is scoped to `.md` status files only. This is deliberate: every guardrail in this project that can be enforced by permission config is, so the orchestrator physically cannot bypass its subagents.

## Known Gotchas

Common patterns and bug prevention are embedded in the skill descriptions themselves. Each skill includes a validation checklist with recurring gotchas (never identify instanced nodes by `.name`, verify signal connections, proper `AudioStreamPlayer` ordering). These checks happen automatically before a task is marked complete.

## Coordination & Memory

Every generated project maintains `GAME_STATE.md` for task tracking and plan files in `plans/` for historical context. Performance metrics and agent behavior analysis are observed externally via the session database, not tracked by the game-build session itself. This split is deliberate — see [AGENTS.md § Session Types](AGENTS.md#session-types) for the game-build vs. harness-build contract, including how the harness monitors live build sessions via the SQLite session DB.

## Commands

```bash
opencode run "Build the game"   # Full autonomous game generation

# Benchmark: prepare the sandbox first (see the benchmark-prep skill), then:
cd test && caffeinate -dimsu opencode "Build a game"
```

---

*Simple games need simple backlogs. One task at a time.*
