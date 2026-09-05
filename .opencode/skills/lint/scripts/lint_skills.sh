#!/usr/bin/env bash
# lint_skills.sh — deterministic checks for the agent-swarm library.
#
# RULE TEXT lives in scripts/rules.yaml next to this script (single source of truth). This script
# only IMPLEMENTS the checks named there (`check:` field, enforcement: lint
# or both). Each check below is a `check_<name>` function named to match its
# registry entry — `--audit` cross-references the two so drift is detected.
# Interpretive notes, exemptions, and rationale live in rules.yaml `notes:`,
# not here.
#
# Usage: ./scripts/lint_skills.sh [--audit]
# Exit codes: 0 = clean, 1 = violations found

set -uo pipefail
cd "$(dirname "$0")/../../../.."

AUDIT=0
[ "${1:-}" = "--audit" ] && AUDIT=1

issues=0
warn() { printf '⚠️  %s\n' "$1"; issues=$((issues + 1)); }

# ---------------------------------------------------------------------------
# check_genre_keywords — genre mechanics + cultural commentary in skills
# (registry: genre-agnostic-skills; details of what's a keyword vs incidental
# vocabulary are in that entry's notes)
# ---------------------------------------------------------------------------
check_genre_keywords() {
  if grep -rn "platformer\|fps_shooter\|tower_defense\|beat_em_up" skills/*/scripts/*.gd 2>/dev/null; then
    warn "genre-specific code detected in skill scripts"
  fi
  if grep -rn "like Pong\|similar to Breakout\|streamer reaction\|On stream\|Rage-quit\|Clip moments" skills/*/SKILL.md 2>/dev/null; then
    warn "cultural commentary detected in SKILL.md"
  fi
}

# ---------------------------------------------------------------------------
# check_agent_names_in_skills — skills must be agent-agnostic (registry:
# agent-agnostic-skills; paraphrase judgment is LLM-review territory)
# ---------------------------------------------------------------------------
check_agent_names_in_skills() {
  if grep -rn "Poppy\|Ian\|Pootie" skills/ 2>/dev/null; then
    warn "agent names in skills detected (skills must be agent-agnostic)"
  fi
}

# ---------------------------------------------------------------------------
# check_pkill_ban — no pkill outside stop_engine.sh's safe internal use and
# the documented historical gotcha in mcp-patterns.md (registry: no-pkill)
# ---------------------------------------------------------------------------
check_pkill_ban() {
  if grep -rn "pkill" agents/ skills/ 2>/dev/null \
     | grep -v "stop_engine.sh:" \
     | grep -v '^[^:]*:[0-9]*: *>.*pkill' \
     | grep -v "NEVER run pkill\|Never run pkill\|never invoke pkill\|pkill yourself\|The only sanctioned engine stop"; then
    warn "direct pkill usage/instruction found — use create-scene-with-script/scripts/stop_engine.sh instead"
  fi
}

# ---------------------------------------------------------------------------
# check_alt_path_wording — obvious fallback-suggesting phrases; prohibition
# lines exempt (registry: sanctioned-paths-only; full semantics in LLM review)
# ---------------------------------------------------------------------------
check_alt_path_wording() {
  alt_hits=$(grep -rniE "as a (last )?(resort|fallback)|fall back to|you can alternatively|alternatively, you|if .* fails, (try|use) " \
    skills/*/SKILL.md skills/*/reference/*.md 2>/dev/null \
    | grep -viE "no (self-)?fallback|do (not|n't) fall|forbidden|prohibit|never fall|BLOCKED|workaround.*(forbidden|banned)|alternative paths")
  if [ -n "$alt_hits" ]; then
    printf '%s\n' "$alt_hits"
    warn "alternative-path wording found — state the sanctioned recovery (→ BLOCKED) instead"
  fi
}

# ---------------------------------------------------------------------------
# check_actor_wording — second-person edit imperatives must attribute file
# mutation to the acting party (registry: misleading-actor-wording).
# Opt-out marker for skills whose purpose IS editing.
# ---------------------------------------------------------------------------
check_actor_wording() {
  for sm in skills/*/SKILL.md; do
    [ -f "$sm" ] || continue
    if grep -q '<!-- lint: this skill edits files by design -->' "$sm"; then
      continue
    fi
    hits=$(grep -niE "(you|after you|when you) (edit|edited|modify|changed?|write|wrote|create|created|saved?) " "$sm" \
      | grep -viE "never edits?|(do not|dont) edit|caller|may have (edit|chang)|edits? by design|SKILL itself never" || true)
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits" | sed "s|^|$sm: |"
      warn "second-person edit imperative in SKILL.md — attribute file edits to the acting skill or mark the caller explicitly"
    fi
  done
}

# ---------------------------------------------------------------------------
# check_observed_citation_resolvable — "observed NN-DD" lines must carry a
# resolvable in-repo reference (registry: citation-resolvable; whitelist
# mirrors that entry's notes)
# ---------------------------------------------------------------------------
check_observed_citation_resolvable() {
  obs_bad=$(grep -rniE "observed [0-9]{2}-[0-9]{2}" agents/ skills/ 2>/dev/null \
    | grep -viE "benchmarks/results/|[0-9a-f]{40}|[0-9a-f]{7} [0-9a-f]|commit [0-9a-f]|(qwen|ling|nemotron|mimo|lumo)[- ]?[0-9.]* *(run|benchmark)|(qwen|ling|nemotron|mimo) run|git log" || true)
  if [ -n "$obs_bad" ]; then
    printf '%s\n' "$obs_bad" | head -20
    warn "unresolvable 'observed <date>' citation(s) — add a benchmark-report path, commit hash, or '<model> run' qualifier, or drop the date"
  fi
}

# ---------------------------------------------------------------------------
# check_gdscript_parse — every skills/*/scripts/*.gd must parse headless.
# godot --check-only exits 0 even on parse errors — gate on SCRIPT ERROR.
# ---------------------------------------------------------------------------
check_gdscript_parse() {
  GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
  if [ -z "$GODOT_BIN" ] && [ -x "/Applications/Godot.app/Contents/MacOS/godot" ]; then
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/godot"
  fi
  if [ -z "$GODOT_BIN" ]; then
    echo "ℹ️  godot binary not found — skipped GDScript parse check"
    return
  fi
  gd_tmp=$(mktemp -d)
  printf 'config_version=5\n[application]\nconfig/name="lint-gd-check"\n' > "$gd_tmp/project.godot"
  for gd in skills/*/scripts/*.gd; do
    [ -e "$gd" ] || continue
    cp "$gd" "$gd_tmp/check_target.gd"
    err="$("$GODOT_BIN" --headless --path "$gd_tmp" --check-only --script res://check_target.gd 2>&1)"
    if printf '%s' "$err" | grep -q "SCRIPT ERROR\|Parse Error"; then
      warn "GDScript parse error in $gd:"
      printf '%s\n' "$err" | grep -v '^Godot Engine' | sort -u | head -5 | sed 's/^/    /'
    fi
  done
  rm -rf "$gd_tmp"
}

# ---------------------------------------------------------------------------
# check_skill_md_size / check_frontmatter_hygiene / check_inline_code_cap —
# SKILL.md doc hygiene (registry: progressive-disclosure, trigger-quality,
# deterministic-logic-in-scripts)
# ---------------------------------------------------------------------------
check_doc_hygiene() {
  python3 - <<'EOF' || issues=$((issues + 1))
import glob, re, sys

issues = 0
for f in sorted(glob.glob("skills/*/SKILL.md") + glob.glob(".opencode/skills/*/SKILL.md")):
    src = open(f, encoding="utf-8").read()
    if src.count("\n") + 1 > 500:
        print(f"⚠️  Review: {f} exceeds 500 lines (progressive-disclosure cap)")
        issues += 1
    m = re.match(r"^---\n(.*?)\n---\n", src, re.S)
    if not m:
        print(f"⚠️  Review: {f} has no parseable frontmatter")
        issues += 1
        continue
    keys = re.findall(r"^([a-z][\w-]*):", m.group(1), re.M)
    extra = sorted(set(keys) - {"name", "description"})
    if extra:
        print(f"⚠️  Review: {f} frontmatter keys ignored by opencode: {extra}")
        issues += 1
    d = re.search(r"^description:\s*(\S.*?)\s*$", m.group(1), re.M)
    if not d:
        print(f"⚠️  Review: {f} missing description (carries the trigger burden)")
        issues += 1
    elif len(d.group(1)) > 1024:
        print(f"⚠️  Review: {f} description over 1024 chars")
        issues += 1
    nm = re.search(r"^name:\s*(\S+)\s*$", m.group(1), re.M)
    if nm:
        name = nm.group(1)
        dirname = f.rstrip("/SKILL.md").rstrip("/").split("/")[-1]
        if name != dirname:
            print(f"⚠️  Review: {f} name '{name}' != directory name '{dirname}'")
            issues += 1
    for i, block in enumerate(re.findall(r"```[\w-]*\n(.*?)```", src, re.S), 1):
        n = block.count("\n") + 1
        if n > 20:
            print(f"⚠️  Review: {f} code block #{i} is {n} lines (>20) — deterministic logic belongs in scripts/, templates in reference/")
            issues += 1

sys.exit(1 if issues else 0)
EOF
}

if [ "$AUDIT" -eq 1 ]; then
  echo "== rules.yaml audit =="
  python3 - "$0" <<'EOF'
import re, sys
txt = open('.opencode/skills/lint/scripts/rules.yaml').read()
impl = set(re.findall(r'^check_(\S+)\(\)', open(sys.argv[1]).read(), re.M))
entries = []
for block in re.split(r'\n- id:', '\n'+txt)[1:]:
    idm = re.match(r'\s*(\S+)', block)
    en = re.search(r'^\s*enforcement:\s*(\S+)', block, re.M)
    ck = re.search(r'^\s*check:\s*(\S+)', block, re.M)
    tr = re.search(r'^\s*check-tier:\s*(\S+)', block, re.M)
    entries.append((idm.group(1) if idm else '?',
                    en.group(1) if en else '?',
                    ck.group(1) if ck else '-',
                    tr.group(1) if tr else '-'))
print(f"{len(entries)} rules registered; lint checks implemented here: {sorted(impl)}")
bad = 0
for rid, e, ck, tr in entries:
    if e in ('lint', 'both') and ck == '-':
        print(f"⚠️  {rid}: enforcement={e} but no check name in registry"); bad += 1
    elif e in ('lint', 'both') and ck != '-' and ck not in impl:
        print(f"⚠️  {rid}: names check '{ck}' which this script does not implement"); bad += 1
    if ck != '-' and ck in impl:
        tier = f" [{tr}]" if tr != '-' else " [tier MISSING]"
        if tr == '-':
            print(f"⚠️  {ck}{tier}: lint check has no check-tier in registry"); bad += 1
        if tr == 'tripwire' and e != 'both':
            print(f"⚠️  {rid}: tripwire check '{ck}' but enforcement={e} — semantic half uncovered (should be 'both')"); bad += 1
orphans = impl - {ck for _,_,ck,_ in entries}
if orphans:
    print(f"⚠️  checks implemented but not in registry: {sorted(orphans)}"); bad += 1
print("✅ registry and lint implementations agree" if not bad else f"⚠️  {bad} drift issue(s)")
EOF
  exit 0
fi

check_genre_keywords
check_agent_names_in_skills
check_pkill_ban
check_alt_path_wording
check_actor_wording
check_observed_citation_resolvable
check_gdscript_parse
check_doc_hygiene

if [ "$issues" -eq 0 ]; then
  echo "✅ lint clean"
  exit 0
else
  echo "⚠️  $issues issue(s) — review required (genericize or document intentional exception)"
  exit 1
fi
