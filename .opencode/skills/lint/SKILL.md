---
name: lint
description: Enforce the library's architectural rules on skills/, agents/, and AGENTS.md. Use when authoring or revising skills or agents, before committing harness changes, when a benchmark or review exposes a rule violation that should become an enforced rule, when adding/changing rules in the registry, or when auditing registry health. Owns the rule registry (scripts/rules.yaml), the deterministic lint, and the LLM semantic review.
---

## What I do

Enforce the agent-swarm library's rules — both deterministic (lint) and
semantic (LLM judge) — over skills/, agents/, and AGENTS.md. All rule text
lives in exactly one place: `scripts/rules.yaml` next to this SKILL.md.

## The three artifacts

1. **`scripts/rules.yaml`** — the rule registry. Each entry: `id`, `rule`
   (canonical wording), `audience`, `scope`, `enforcement`
   (`lint` | `llm-review` | `both` | `none`), optional `check` (name of the
   deterministic check implementing it), `check-tier` (`exact` — grep/parser
   fully decides the rule, or `tripwire` — keyword scan catching obvious hits
   only; the LLM judge covers the semantics), and `notes` (interpretive
   calibrations injected into the judge prompt).
2. **`scripts/lint_skills.sh`** — deterministic checks, one `check_<name>`
   function per registry `check:` name. `--audit` cross-references registry
   ↔ implementations: missing check names, unimplemented checks, orphan
   checks, missing tiers, tripwires without semantic coverage.
3. **`scripts/review_skills_llm.sh`** — semantic judge. Rubric generated
   dynamically from the registry (`enforcement: llm-review`/`both` entries +
   notes); scope covers skills/, agents/, AGENTS.md. Requires `opencode run`.

## Workflow

Run both gates before committing skill or agent changes:

```bash
.opencode/skills/lint/scripts/lint_skills.sh
.opencode/skills/lint/scripts/review_skills_llm.sh
```

Adding or changing a rule:

1. Edit `scripts/rules.yaml` only — never hand-write rule text elsewhere
   (AGENTS.md, skill docs, agent files must not duplicate rules).
2. If the rule is lint-enforceable, add a `check_<name>` function to
   `lint_skills.sh` and a `check:` (+ `check-tier:`) field to the entry.
3. Run `--audit` to confirm registry and implementations agree.
4. Tripwire-tier checks must have `enforcement: both` so the LLM judge
   covers their semantic half.

## Interpretation

- **Deterministic vs semantic:** rules whose shape is "X string must (not)
  appear" are lint (`exact`); keyword-detectable subsets of semantic rules
  are lint tripwires backed by the LLM judge; everything else is
  `llm-review`. No rule is enforced in neither lane (that's author
  judgment: `enforcement: none` — visible in the audit).
- **Enforcement is a floor + ceiling:** lint catches every mechanical
  instance; the LLM judge covers semantics grep cannot (scoped exceptions,
  paraphrases, genre assumptions, citation provenance). "Lint passes" means
  all known rules satisfied only after BOTH gates pass.
- Prose that duplicates a registry rule elsewhere is itself drift — the
  rule text lives only in `scripts/rules.yaml`.
