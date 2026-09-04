#!/usr/bin/env bash
# lint_skills.sh — static checks for the agent-swarm library.
#
# Checks:
#   1. Genre-specific keywords in skill scripts (review required)
#   2. Cultural-commentary phrases in skill docs (review required)
#   3. Agent names inside skills/ (skills must be agent-agnostic)
#   4. SKILL.md progressive-disclosure cap (500 lines)
#   5. Frontmatter hygiene (parseable; opencode ignores all but name/description)
#   6. Description length cap (1024 chars)
#   7. Inline code blocks >20 lines (deterministic logic belongs in scripts/)
#   8. pkill anywhere in agents/ or skills/ (must use stop_engine.sh instead —
#      unquoted `pkill -f godot --path` binds pattern "godot" and kills the MCP
#      server; any pkill allow-rule or instruction reintroduces that footgun)
#   9. Alternative-path wording in skills (sanctioned-paths-only rule, AGENTS.md:
#      skills must offer one sanctioned path; failure ends in BLOCKED, not a
#      fallback. Lines that are themselves prohibitions are exempt.)
#  10. GDScript syntax check — every skills/*/scripts/*.gd must parse headless.
#       Motivated by 09-03 incident: shipped test_player.gd with duplicate
#       `var pos` across if/elif sibling scopes (GDScript rejects same-name vars
#       in sibling scopes) — latent parse error invisible to all other checks,
#       detonating in every consumer project at setup time.
#  11. Misleading actor wording — second-person edit imperatives ("you edit…",
#       "after you edited…") in SKILL.md misattribute file mutation to the wrong
#       actor: a reader assumes the SKILL edits files when it was the CALLER who
#       did (observed 09-04: playtest's stale-bytecode gotcha read as "playtest
#       edits scripts" — playtest never edits game files; the edit was a
#       mid-playtest caller fix). Lines carrying actor attribution ("never
#       edits", "caller", "may have edited") are exempt; skills whose core
#       purpose IS editing (create-scene-with-script, log-result) opt out with
#       a self-documenting marker line: <!-- lint: this skill edits files by design -->
#
# Usage: ./scripts/lint_skills.sh
# Exit codes: 0 = clean, 1 = violations found

set -uo pipefail
cd "$(dirname "$0")/.."

issues=0

warn() { printf '⚠️  Review: %s\n' "$1"; issues=$((issues + 1)); }

# 1-3. Keyword scans
if grep -rn "platformer\|fps_shooter\|tower_defense\|beat_em_up" skills/*/scripts/*.gd 2>/dev/null; then
  warn "genre-specific code detected in skill scripts"
fi
if grep -rn "like Pong\|similar to Breakout\|streamer reaction\|On stream\|Rage-quit\|Clip moments" skills/*/SKILL.md 2>/dev/null; then
  warn "cultural commentary detected in SKILL.md"
fi
if grep -rn "Poppy\|Ian\|Pootie" skills/ 2>/dev/null; then
  warn "agent names in skills detected (skills must be agent-agnostic)"
fi

# 8. pkill ban (agents/ frontmatter+instructions, skills/ docs+scripts).
# Matches any pkill mention except stop_engine.sh's internal (safe, quoted) use
# and except the documented gotcha in mcp-patterns.md (historical incident
# record — exempted by content marker, not line number, so edits to the file
# don't silently re-trigger this check).
if grep -rn "pkill" agents/ skills/ 2>/dev/null \
   | grep -v "stop_engine.sh:" \
   | grep -v '^[^:]*:[0-9]*: *>.*pkill' \
   | grep -v "NEVER run pkill\|Never run pkill\|never invoke pkill\|pkill yourself\|pkill yourself\|The only sanctioned engine stop"; then
  warn "direct pkill usage/instruction found — use create-scene-with-script/scripts/stop_engine.sh instead"
fi

# 9. Alternative-path wording (sanctioned-paths-only, see AGENTS.md).
# Cheap deterministic tripwire for OBVIOUS fallback-suggesting phrases; exempt
# lines that forbid alternatives. Semantic judgment (e.g. bare "preferred",
# context-dependent rankings) is NOT lintable by word list — run the optional
# scripts/review_skills_llm.sh LLM-judge pass in harness-build sessions for that.
alt_hits=$(grep -rniE "as a (last )?(resort|fallback)|fall back to|you can alternatively|alternatively, you|if .* fails, (try|use) " \
  skills/*/SKILL.md skills/*/reference/*.md 2>/dev/null \
  | grep -viE "no (self-)?fallback|do (not|n't) fall|forbidden|prohibit|never fall|BLOCKED|workaround.*(forbidden|banned)|alternative paths")
if [ -n "$alt_hits" ]; then
  printf '%s\n' "$alt_hits"
  warn "alternative-path wording found — state the sanctioned recovery (→ BLOCKED) instead"
fi

# 11. Misleading actor wording — see header note above.
edit_skill_hits=""
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

# 10. GDScript parse check — every skills/*/scripts/*.gd must parse headless.
# Motivated by 09-03 incident: shipped test_player.gd with duplicate `var pos`
# across if/elif sibling scopes (GDScript rejects same-name vars in sibling
# scopes) — latent parse error invisible to all other checks, copied into every
# consumer project by setup-project and detonating at first headless load.
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
if [ -z "$GODOT_BIN" ] && [ -x "/Applications/Godot.app/Contents/MacOS/godot" ]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/godot"
fi
if [ -n "$GODOT_BIN" ]; then
  gd_tmp=$(mktemp -d)
  printf 'config_version=5\n[application]\nconfig/name="lint-gd-check"\n' > "$gd_tmp/project.godot"
  for gd in skills/*/scripts/*.gd; do
    [ -e "$gd" ] || continue
    cp "$gd" "$gd_tmp/check_target.gd"
    # NOTE: godot --check-only exits 0 even on parse errors (errors go to
    # stderr) — gate on SCRIPT ERROR output, not the exit code.
    err="$("$GODOT_BIN" --headless --path "$gd_tmp" --check-only --script res://check_target.gd 2>&1)"
    if printf '%s' "$err" | grep -q "SCRIPT ERROR\|Parse Error"; then
      warn "GDScript parse error in $gd:"
      printf '%s\n' "$err" | grep -v '^Godot Engine' | sort -u | head -5 | sed 's/^/    /'
    fi
  done
  rm -rf "$gd_tmp"
else
  echo "ℹ️  godot binary not found — skipped GDScript parse check (check 10)"
fi

# 4-6. SKILL.md hygiene (skills/ + .opencode/skills/, excluding harness-only consumers)
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
    # Inline code must be short: deterministic logic -> scripts/, templates -> reference/
    for i, block in enumerate(re.findall(r"```[\w-]*\n(.*?)```", src, re.S), 1):
        n = block.count("\n") + 1
        if n > 20:
            print(f"⚠️  Review: {f} code block #{i} is {n} lines (>20) — deterministic logic belongs in scripts/, templates in reference/")
            issues += 1

sys.exit(1 if issues else 0)
EOF

if [ "$issues" -eq 0 ]; then
  echo "✅ lint clean"
  exit 0
else
  echo "⚠️  $issues issue(s) — review required (genericize or document intentional exception)"
  exit 1
fi
