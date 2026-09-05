# Lint Architecture

How rule enforcement works in this library, and why.

## Why a registry

Before `scripts/rules.yaml`, rule text existed in three drifting places:
AGENTS.md self-check lists, the hardcoded rubric inside
`review_skills_llm.sh`, and check comments in `lint_skills.sh`. A rule could
be added to one and missed by the others (real incident: the citation
rules were unenforced by lint until noticed manually a day after being
written into AGENTS.md). The registry is the single source of truth; every
other artifact derives from or points to it.

## Two enforcement lanes

- **Deterministic (lint):** grep/parser checks. Two tiers, declared per
  check in the registry:
  - `exact` — the check fully decides the rule (pkill presence, GDScript
    parse, citation line regex, doc hygiene).
  - `tripwire` — catches obvious instances of a semantic rule cheaply
    (genre keywords, agent names, fallback wording, actor wording) but
    cannot judge paraphrases, scoped exceptions, or intent.
- **Semantic (LLM judge):** `review_skills_llm.sh` generates its entire
  rubric from registry entries (`enforcement: llm-review`/`both`) including
  each entry's `notes:` — so a new rule is enforced on the next run with
  zero script edits.

A tripwire check must sit on an `enforcement: both` rule, or its semantic
half is uncovered — `--audit` flags this.

## Registry drift protection (`--audit`)

`lint_skills.sh --audit` mechanically cross-references the registry against
the script's own `check_<name>()` function definitions:

- lint-enforced rule with no `check:` name
- registry naming a check the script doesn't implement
- check implemented but absent from the registry (orphans)
- missing `check-tier`
- tripwire on a non-`both` rule

The audit discovers implemented checks by regex over the script itself, so
neither side can drift silently.

## Review scope

The LLM judge reviews `skills/**/*.md`, `agents/*.md`, and `AGENTS.md` —
matching the registry's `scope:` fields. Each rule is applied only to files
in its scope (agent rules don't fire on skills and vice versa).

## Conventions

- Rule text lives ONLY in `scripts/rules.yaml`. Duplicating it in AGENTS.md,
  skills, or agents is itself drift.
- The lint skill is harness-level (`.opencode/skills/lint/`): top-level
  `skills/` is what mounts into consumer game projects; this skill stays in
  the harness repo.
- Non-determinism of the LLM judge is accepted (rerun on surprising
  verdicts); deterministic checks provide repeatable proof, the judge
  provides coverage grep can't.
