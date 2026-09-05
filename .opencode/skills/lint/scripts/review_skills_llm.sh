#!/usr/bin/env bash
# review_skills_llm.sh — LLM-judge pass over library files (skills, agents,
# AGENTS.md).
#
# Complements lint_skills.sh: lint stays deterministic and fast (mechanical
# checks + obvious-keyword tripwires); this pass handles the SEMANTIC checks.
#
# DYNAMIC RULE SOURCE: the judge rubric is generated entirely from
# scripts/rules.yaml (rule text + notes of enforcement: llm-review/both
# entries). Adding a rule to the registry enforces it on the next run —
# no edits to this script. Run in harness-build sessions when touching
# skills/agents — not wired into pre-commit.
#
# Usage:
#   .opencode/skills/lint/scripts/review_skills_llm.sh [file...]
#   # default: changed library docs, else all reviewable docs
#
# Requires `opencode run` (uses the current project's default model).
# Exit codes: 0 = clean / judge unavailable / inconclusive, 1 = violations.

set -u
cd "$(dirname "$0")/../../../.."

if ! command -v opencode >/dev/null 2>&1; then
  echo "ℹ️  opencode CLI not found — skipping LLM review (deterministic lint only)"
  exit 0
fi

# Scope: changed library docs if git reports any, otherwise every reviewable
# doc. Scopes mirror the registry (rules.yaml scope: fields): skills/**,
# agents/**, AGENTS.md.
if [ "$#" -gt 0 ]; then
  FILES=$(printf '%s\n' "$@")
else
  FILES=$( { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
    | grep -E '^(skills/.*\.md|agents/.*\.md|AGENTS\.md)$' || true)
  if [ -z "$FILES" ]; then
    FILES=$( { ls skills/*/SKILL.md skills/*/reference/*.md 2>/dev/null; \
               ls agents/*.md 2>/dev/null; echo AGENTS.md; } )
  fi
fi

if [ -z "$FILES" ]; then
  echo "ℹ️  no library docs to review"
  exit 0
fi

# Build the semantic rubric dynamically from scripts/rules.yaml:
#  rule text + interpretive notes for entries with enforcement llm-review/both
RUBRIC=$(python3 - <<'EOF'
import re

def parse_entries(path):
    """Line-based YAML-list parser: '- id:' starts an entry; '  key:' or
    '  key: >' starts a field; indented continuation lines fold into it."""
    entries, cur, field = [], None, None
    for line in open(path):
        if re.match(r'- id:', line):
            cur, field = {}, None
            entries.append(cur)
            cur['id'] = line.split(':', 1)[1].strip()
        elif cur is not None and re.match(r'  \w[\w-]*:', line):
            m = re.match(r'  ([\w-]+):\s*(.*)', line)
            field = m.group(1)
            val = m.group(2).strip()
            cur[field] = [] if val in ('>', '|', '') else [val]
        elif cur is not None and field and re.match(r'\s+\S', line):
            cur[field].append(line.strip())
    return [{k: ' '.join(v) if isinstance(v, list) else v for k, v in e.items()}
            for e in entries]

out = []
for e in parse_entries('.opencode/skills/lint/scripts/rules.yaml'):
    if e.get('enforcement') not in ('llm-review', 'both'):
        continue
    entry = f"- [{e['id']}] {e.get('rule', '(no text)')}"
    if e.get('notes'):
        entry += f"\n  Interpretation notes: {e['notes']}"
    out.append(entry)
print('\n'.join(out) if out else '(no llm-review rules registered — check the registry next to this script)')
EOF
)

JUDGE_PROMPT="You are reviewing an agent-swarm library (skills/, agents/, AGENTS.md) for architectural rule violations. For EACH file, judge the SEMANTIC rules below (do not flag style, typos, or things a grep could catch — the deterministic lint already covers those). Apply each rule only to files matching its scope (skills/, agents/, AGENTS.md respectively).

$RUBRIC

AGENTS.md's Enforcement section points at the rule registry (scripts/rules.yaml in the lint skill) as the single source of truth; read AGENTS.md for architectural context if a rule references it.

Output: for each violation, one line: \"<file>:<approx-line>: <rule-id>: <why>\". If a file is clean, do not mention it. End with \"VERDICT: CLEAN\" if no violations, else \"VERDICT: VIOLATIONS\"."

PROMPT="$JUDGE_PROMPT

FILES TO REVIEW:
$FILES

Read each file listed above with your file tools, then apply the rules. Report only substantive violations — no nitpicks."

OUT=$(opencode run "$PROMPT" 2>&1) || true
printf '%s\n' "$OUT"

if printf '%s' "$OUT" | grep -q "VERDICT: VIOLATIONS"; then
  echo "⚠️  LLM review found violations — see output above"
  exit 1
elif printf '%s' "$OUT" | grep -q "VERDICT: CLEAN"; then
  echo "✅ LLM review clean"
  exit 0
else
  echo "ℹ️  Judge did not emit a VERDICT (model error or refusal) — treat as inconclusive"
  exit 0
fi
