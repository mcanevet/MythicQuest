#!/usr/bin/env bash
# review_skills_llm.sh — optional LLM-judge pass over skill docs.
#
# Complements ./lint_skills.sh: lint stays deterministic and fast (mechanical
# checks + obvious-keyword tripwires); this pass handles the SEMANTIC checks
# that word lists cannot decide (AGENTS.md sanctioned-paths rule, agent-name
# leakage, genre assumptions). Run it in harness-build sessions when touching
# skills — not wired into pre-commit.
#
# Usage:
#   ./scripts/review_skills_llm.sh [file...]     # default: changed skill docs
#
# Requires `opencode run` (uses the current project's default model).
# Exit codes: 0 = clean / judge unavailable / inconclusive, 1 = violations.

set -u
cd "$(dirname "$0")/.."

if ! command -v opencode >/dev/null 2>&1; then
  echo "ℹ️  opencode CLI not found — skipping LLM review (deterministic lint only)"
  exit 0
fi

# Scope: changed skill docs if git reports any, otherwise every skill doc.
if [ "$#" -gt 0 ]; then
  FILES=$(printf '%s\n' "$@")
else
  FILES=$( { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
    | grep -E '^skills/.*\.md$' || true)
  if [ -z "$FILES" ]; then
    FILES=$(ls skills/*/SKILL.md skills/*/reference/*.md 2>/dev/null)
  fi
fi

if [ -z "$FILES" ]; then
  echo "ℹ️  no skill docs to review"
  exit 0
fi

JUDGE_PROMPT='You are reviewing game-agent skill docs for architectural rule violations. For EACH file, judge ONLY these semantic rules (do not flag style, typos, or things a grep could catch):
1. SANCTIONED PATHS ONLY: skills must present ONE path per domain. Flag any place that presents two or more ways to accomplish the same thing with a ranking or an alternative ("preferred", "old way/new way", "you could also", "as a fallback"). A scoped exception stated with its reason ("visual verification only when invariants cannot judge") is LEGAL. The BLOCKED escape hatch is legal.
2. AGENT-AGNOSTIC: skills must not contain role-specific judgment ("Poppy should...", "the Lead Engineer ensures...") — judge the paraphrases, not just names. Generic pronouns are fine.
3. GENRE-AGNOSTIC: no game-genre assumptions — specific mechanics ("double jump", "aim assist", "wave spawning"), named games, or streaming culture. Judge the assumption, not the vocabulary: "respawn timer" is a violation; "tick rate budget" is not. Engine API names ARE allowed (skills are engine-specific by design); rule 4 covers what must not leak.
4. ROLE/PERSONA LEAKAGE BEYOND NAMES: persona voice, evaluation rubrics of a specific role, or collaboration patterns tied to one agent.
5. GOTCHA FRESHNESS: any documented "gotcha" or workaround that cites an upstream dependency gap (often marked "upstream-worthy" or citing a version) — flag it ONLY if the file gives no indication of its lifecycle status. Per AGENTS.md upstream-contribution rule, workarounds must be checkable for retirement (filed → patched → released → retired); a gotcha with no status trail is a violation. Do NOT judge whether the fix actually shipped — only whether the file records enough to check.
6. TRIGGER QUALITY: does the SKILL.md `description:` state what the skill does AND when to use it, specifically enough that an agent choosing between skills picks correctly? Vague descriptions ("helps with scenes") are violations. Only applies to SKILL.md frontmatter descriptions.
7. PROGRESSIVE DISCLOSURE: SKILL.md should reference `reference/` docs rather than duplicate them. Flag substantial content that exists in BOTH SKILL.md and a reference doc of the same skill (short ≤3-line summaries are fine).
8. CONFIG-VS-HARDCODE: game-specific values (input action names, node paths, bounds, thresholds) appearing as literals inside scripts/ or embedded code blocks instead of being parameters/config. Illustrative snippets in reference docs with clearly generic values are fine.
9. INLINE CODE CLASS: code blocks that implement deterministic logic (transforms, validators, parsers) belong in scripts/, not in SKILL.md prose blocks — regardless of length. Illustrative snippets (schema examples, API usage) are fine. Judge the LOGIC-vs-ILLUSTRATION distinction, not line count.
Output: for each violation, one line: "<file>:<approx-line>: <rule#>: <why>". If a file is clean, do not mention it. End with "VERDICT: CLEAN" if no violations, else "VERDICT: VIOLATIONS".'

PROMPT="$JUDGE_PROMPT

FILES TO REVIEW:
$FILES

Read each file listed above with your file tools, then apply the rules. Be strict about rule 1 but remember: prohibition lines (\"never fall back\", \"no fallback\") and domain splits with stated reasons are legal. For rule 5, also read AGENTS.md (upstream-contribution rule) if needed for lifecycle context. Report only substantive violations — no nitpicks."

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
