---
name: skill-authoring
description: Author, revise, or review skills in this agent-swarm library. Use when creating a new skill, editing any SKILL.md, adding skill scripts or reference docs, reviewing a skill for lint compliance, porting a skill between engines, or when a playtest/validation run exposes a failure mode that should become a skill rule or gotcha.
---

## What I do

Encode the library's skill-authoring standards: frontmatter hygiene, trigger
descriptions, progressive disclosure, script/ACI design, and eval-first
iteration. Apply these rules when creating or revising any skill.

## Rules grounded in the [Agent Skills](https://agentskills.io) spec

(`best-practices`, `optimizing-descriptions`, `evaluating-skills`,
`using-scripts` guides.)

### SKILL.md Frontmatter

- Frontmatter carries opencode-supported keys only: `name`, `description`.
  Anything else (`version`, `persona`, `slash`, …) is ignored at load time —
  dead metadata that will drift. Spec fields (`license`, `compatibility`,
  `metadata`, `allowed-tools`) only if actually used; default to absent.
- `name`: 1-64 chars, lowercase letters/digits/hyphens, no leading/trailing/
  consecutive hyphens, **must equal its directory name**.
- Directory naming: this repo uses `reference/` (spec standard is
  `references/`); pick one and stay consistent.

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
- Constraint: 1-1024 chars, non-empty.

### Progressive Disclosure & Size

Full `SKILL.md` body loads only on activation (~5000-token budget), then
`reference/`/`scripts/` on demand.

- Keep `SKILL.md` **under 500 lines** (well under ~5000 tokens). Push detail
  into `reference/` files loaded on demand.
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

### Deterministic Logic Lives in scripts/, Never Inline

Any logic a skill executes mechanically — parsing, transforms, slug
generation, validators, report rendering — must be a standalone script that
`SKILL.md` references, not steps the agent hand-types. Prose describing a
concrete mechanical transform ("lowercase it, strip special chars") is the
signal that it should be a script. Inline code blocks ≤20 lines, illustration
only.

**Templates belong in `reference/`, not `scripts/`.** Logic you execute →
`scripts/`; content you copy → `reference/`.

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

1. Run the lint script (see `.opencode/skills/debug-harness` — lint lives in
   repo `scripts/lint_skills.sh`): genre keywords, agent names in skills,
   500-line cap, frontmatter hygiene, >20-line inline code blocks.
2. Self-check: would this work for another genre? Are all game-specific
   values config parameters? Did I assume naming conventions? Did I encode
   the last real failure this skill hit as a gotcha?
3. If an observed playtest/validation failure motivated the change, it must
   appear as an explicit rule/gotcha/validator check — not just prose.
