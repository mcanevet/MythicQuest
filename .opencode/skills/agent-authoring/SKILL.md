---
name: agent-authoring
description: Author, revise, or port agent instruction files in this agent-swarm library. Use when creating a new agent, editing any agents/*.md, porting the swarm to a new game engine, adjusting agent permission frontmatter, or when a session postmortem exposes a behavioral failure that should become an agent protocol (respawn rules, batching caps, structured failures).
---

## What I do

Encode the library's agent-authoring standards: role definition, portability
layering, permission configuration, bounded-execution protocols, and
delegation discipline. Apply when creating or revising any agent file.
Enforced rules live in the lint skill's registry — this skill owns craft,
not enforcement.

## What belongs in an agent (vs a skill)

Agents are the portable decision layer. Two questions decide placement:

1. **Would this survive an engine switch?** Decision logic, role
   responsibilities, workflow patterns, quality standards — agent.
2. **Does it name APIs, file formats, MCP tools, or process mechanics?**
   Implementation — skill, referenced by path, never inlined.

The test: an agent file should read as a job description plus judgment
criteria, delegating all mechanics to skills the agent invokes.

- ✅ Role definition & persona, decision frameworks, quality gates
- ✅ Pre-flight checklists (conceptual), error-handling protocols
- ✅ Skill invocation choices (which skill, when to chain)
- ❌ Engine API names, file formats, MCP tool signatures
- ❌ Process management (`pkill`, spawning, sleeps)
- ❌ Anything a consumer project's game session would need to re-derive

When an agent needs engine mechanics, it says "consult
`skills/<name>/SKILL.md`" — that indirection IS the portability mechanism.

## Permission frontmatter

Permissions are **configuration, not instruction** — they may reference
engine-specific tools, with a portability comment:

```yaml
permission:
  # Engine-specific MCP permissions — update these patterns for your engine
  "godot-mcp-runtime_*": allow
```

Patterns to follow (see existing agents' frontmatter):
- `edit: "**/*.gd": allow` — game logic scripts are engine-specific but
  portable within an engine
- Deny-by-default for skill internals (`skills/*/scripts/*.gd`) — protect
  implementations from runtime edits; scope denies narrowly so bootstrap
  steps that legitimately copy files aren't blocked
- Grant narrow write scopes only where a role genuinely produces artifacts
  (e.g. report directories)

Every permission grant needs a reason comment: what task it unblocks, and
what its scope limits.

## Bounded execution & structured failure

Every unit of delegated work needs a bounded horizon (see AGENTS.md
"Stopping Conditions & Bounded Execution" for the full doctrine):

- **Delegations bound their retries** — a task that can't converge after
  its attempts (default cap: 3) returns `⛔ BLOCKED: <cause>` + attempts +
  evidence. Never a loop, never a silent detour.
- **Missing mandated deliverables** — if a subagent dies mid-task and the
  deliverable is absent, spawn ONE completion run for the same deliverable;
  if that also fails to produce it, escalate BLOCKED to the orchestrator.
  Don't re-run open-ended.
- **Orchestrators never do the work themselves** — root build sessions
  delegate via task(); anti-recursion guards are part of the agent's
  instructions.

## Role definition craft

- Define the role by responsibilities and quality criteria, not by
  mechanics ("reviews for invariant coverage", not "runs the playtest
  validator script then checks report.json fields").
- Specify collaboration contracts: what this agent delivers, to whom, in
  what format — keep formats aligned with skills that produce/consume them.
- Encode failure-history lessons as protocol steps (e.g. probe-before-
  verdict, respawning dead subagents), citing the evidence in the
  harness's benchmark reports — the citation rules from the lint registry
  apply here too (resolvable + earning their place).
- A role that can't be described without naming the engine is a skill
  wearing an agent costume — factor it out.

## When porting to a new engine

1. Agents stay unchanged — verify no engine references leaked in (the lint
   skill's reviewer covers `agents/**`).
2. Update opencode.jsonc to the new engine's MCP/LSP.
3. Swap skill implementations (same skill names, new internals).
4. Adjust permission patterns in frontmatter comments (config, not logic).

## Mandatory checks before finishing

Run both gates (see the `lint` skill):
`.opencode/skills/lint/scripts/lint_skills.sh` and
`.opencode/skills/lint/scripts/review_skills_llm.sh` — the reviewer reads
`agents/*.md` too.
