---
name: skill-authoring
description: Author, revise, or review skills in this agent-swarm library. Use when creating a new skill, editing any SKILL.md, adding skill scripts or reference docs, porting a skill between engines, or when a playtest/validation run exposes a failure mode that should become a skill rule or gotcha.
---

## What I do

Encode the library's skill-authoring craft: trigger descriptions,
progressive disclosure, script/ACI design, and eval-first iteration.
Apply when creating or revising any skill. Enforced rules (lint checks and
the LLM judge rubric) live in the `lint` skill's registry — this skill owns
authoring method, not enforcement.

## Rules grounded in the [Agent Skills](https://agentskills.io) spec

(`best-practices`, `optimizing-descriptions`, `evaluating-skills`,
`using-scripts` guides.)

### Descriptions Carry the Trigger Burden

Progressive disclosure loads only `name` + `description` at session start —
the description alone decides activation.

- **Imperative trigger phrasing:** "Use when …" / "Use after …"; name the
  concrete inputs, scenarios, and user intents that should activate it. Be
  pushy — a skill that doesn't trigger is dead weight.
- **Intent-first, not implementation-first:** "Connect game events to their
  handlers" *before* mentioning a specific tool (e.g. `connect_signal`).
- **Cover plus enforcement:** 40-80% coverage of a task beats over-claiming;
  every false trigger costs context and trust.
- Directory naming: this repo uses `reference/` (spec standard is
  `references/`); pick one and stay consistent.

### Progressive Disclosure & Size

Full `SKILL.md` body loads only on activation (~5000-token budget), then
`reference/`/`scripts/` on demand.

- Keep `SKILL.md` well under the lint cap; push detail into `reference/`
  files loaded on demand.
- **Tell the agent WHEN to load each reference file** — never leave a
  reference unreachable from the workflow.
- Local file references one level deep from the skill root; avoid nested
  reference chains. Cross-skill references to a canonical schema are the one
  deliberate exception.
- **Provide defaults, not menus.** **Favor procedures over declarations.**
- **Match specificity to fragility:** hard rules where failure is
  catastrophic, lighter guidance where craftsmanship applies.
- Templates/checklists belong in the skill (or `reference/`), not agent files.
- Deep-dive research lives in `reference/`, never inline.

### Scripts (Agentic Interface)

Everything in `scripts/` is executed by an agent with no human to clarify:

- Self-contained, or dependencies documented in a header comment.
- Non-interactive: `--help`/usage line, helpful errors, distinct exit codes
  (0 = pass, non-zero = fail).
- Structured output on stdout, diagnostics on stderr; bounded and deterministic.
- Idempotent.
- Pin one-off external invocations (e.g. `npx -y <pkg>@<version>`).

Logic you execute → `scripts/`; content you copy → `reference/`. Prose
describing a concrete mechanical transform ("lowercase it, strip special
chars") is the signal that it should be a script, not instructions left to
execution-by-judgment.

### Agent-Computer Interface (ACI)

Skills, validator scripts, and tool conventions form the agent-computer
interface — design it as carefully as the prompts:

- **Poka-yoke — make errors structurally hard.** Unambiguous, fully-specified
  inputs over forms the model must resolve; explicit absolute/fully-qualified
  references over ambiguous ones.
- **Stay close to natural model output.** Formats the model writes fluently
  (whole files, JSON objects) beat formats with formatting overhead.
- **Document for a junior engineer:** example usage, edge cases, explicit
  boundaries in descriptions and parameter docs.
- **Draw clear boundaries between similar tools** so the agent can't pick the
  wrong one (run vs attach, validate vs run_script, save vs save-as).
- **Test how the agent uses it, then tighten.** Run representative inputs,
  observe the mistakes, convert each into a gotcha, validator check, or
  parameter constraint.

### Eval-First Authoring

- Before finalizing a skill, define 2-3 representative invocations + expected
  outputs; keep checkable cases in `evals/evals.json` inside the skill directory.
- When a playtest/validation run exposes a failure mode, turn it into an
  explicit rule, gotcha line, or validator check — a skill that never fails in
  practice isn't being exercised.
- When revising, re-run expected cases (own validators + evals), not just
  prose review.

## Mandatory Checks Before Finishing

Run both gates from the `lint` skill (its registry defines all enforced
rules; frontmatter hygiene, size caps, genre/agent-agnosticism, citation
rules and more live there):

```bash
.opencode/skills/lint/scripts/lint_skills.sh
.opencode/skills/lint/scripts/review_skills_llm.sh
```

If an observed playtest/validation failure motivated the change, it must
appear as an explicit rule/gotcha/validator check — not just prose.
