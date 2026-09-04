#!/usr/bin/env bash
# prepare_test_dir.sh — reset a consumer sandbox to a pristine benchmark
# starting state, per benchmarks/README.md §"Running a benchmark".
#
# Layout (AGENTS.md production option 1 adapted for local benchmarking):
#
#   test2/                          <- consumer project (fresh git repo)
#   └── .opencode/
#       ├── lib/                    <- git SUBMODULE -> this harness repo (local path)
#       │   ├── agents/ skills/ opencode.jsonc ...
#       ├── agents    -> lib/agents
#       ├── skills    -> lib/skills
#       ├── opencode.jsonc -> lib/opencode.jsonc
#       ├── package.json + node_modules   (godot-mcp-runtime, engine-pinned)
#       └── .gitignore               (ignores node_modules + lockfile)
#
# Why submodule over direct symlinks: the consumer repo records WHICH harness
# commit it ran against (benchmark reproducibility) and test2/ is fully
# self-contained — no symlinks escaping into the harness working tree, so a
# stray `git clean` in either repo can't break the other. The local-path
# submodule needs a bare/mirror clone of the harness repo to point at (git
# refuses a submodule URL that is the superproject itself); we keep a mirror
# at ../.mythicquest-mirror.git and refresh it on each prep run.
#
# Guarantees (idempotent — safe to run repeatedly):
#   1. No run artifacts: GAME_STATE.md, plans/, scenes/, scripts/, reports/,
#      tests/, COMPLETION_REPORT.md, mcp_bridge.gd, project.godot, .mcp/,
#      nested .git — all removed.
#   2. npm state (node_modules, lockfile) is PRESERVED across resets —
#      restoring costs a multi-minute install; it is engine-pinned, not run
#      state. --full-npm forces a wipe.
#   3. Submodule + symlink trio recreated, verified to resolve, and pinned
#      to the CURRENT HEAD of the harness repo (mirror updated first).
#   4. FRESH git repo in the sandbox with an initial commit.
#      Rationale: opencode derives the session cwd from the repo root; without
#      .git the build session inherits the harness repo as its workspace and
#      MCP paths break (observed 09-03/09-04).
#   5. Icon placeholder restored.
#   6. Leftover engine processes killed via stop_engine.sh (never pkill —
#      lint check 8).
#   7. Commits nothing to the harness repo itself.
#
# Usage: prepare_test_dir.sh [sandbox-dir] [--full-npm]
#   sandbox-dir defaults to test2 (relative to CWD or the harness root).
# Exit codes: 0 = ready, 1 = verification failed
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
TEST_DIR=""
FULL_NPM=0
for arg in "$@"; do
  case "$arg" in
    --full-npm) FULL_NPM=1 ;;
    *) TEST_DIR="$arg" ;;
  esac
done
TEST_DIR="${TEST_DIR:-test2}"
cd "$REPO_ROOT"
MIRROR="$REPO_ROOT/../MythicQuest-mirror.git"

fail() { printf 'prepare_test_dir.sh: %s\n' "$1" >&2; exit 1; }

# 6. Kill leftover engine processes through the sanctioned stopper
STOP=skills/create-scene-with-script/scripts/stop_engine.sh
if [ -x "$STOP" ]; then "$STOP" 2>/dev/null || true; fi

# 3a. Maintain a local bare mirror of the harness repo (submodule target).
#     Direct self-reference (URL = superproject) is refused by git; a sibling
#     mirror decouples them while still testing EXACTLY the current HEAD.
if [ -d "$MIRROR" ]; then
  git --git-dir="$MIRROR" fetch -q "$REPO_ROOT" "refs/heads/*:refs/heads/*" ||
    fail "mirror fetch failed — check $MIRROR"
else
  # --no-local: the harness working tree contains ignored dirs (test/, test2/)
  # that break a local-clone object walk — remote-style copy avoids it
  git clone --bare --no-local -q "$REPO_ROOT" "$MIRROR" ||
    fail "could not create bare mirror at $MIRROR"
fi
HEAD_SHA=$(git rev-parse HEAD)
git --git-dir="$MIRROR" fetch -q "$REPO_ROOT" "$HEAD_SHA:refs/heads/benchmark-pin" ||
  fail "could not pin HEAD ($HEAD_SHA) into mirror"

# 1. Wipe the sandbox entirely (it is disposable by contract)
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR/.opencode"
OC="$TEST_DIR/.opencode"

# 4. Consumer repo FIRST, so the submodule is recorded in a real commit history
git -C "$TEST_DIR" init -q
git -C "$TEST_DIR" -c user.name=harness -c user.email=harness@local \
  commit -q --allow-empty -m "chore: benchmark sandbox init"

# 3b. Submodule = harness repo at current HEAD
git -C "$TEST_DIR" -c protocol.file.allow=always \
  submodule add -q --name lib "$MIRROR" .opencode/lib
git -C "$TEST_DIR" -C . checkout -q "$HEAD_SHA" 2>/dev/null || \
  git -C "$TEST_DIR/.opencode/lib" checkout -q "$HEAD_SHA"
git -C "$TEST_DIR" add .opencode/lib
git -C "$TEST_DIR" -c user.name=harness -c user.email=harness@local \
  commit -qm "chore: pin harness @ ${HEAD_SHA:0:8}"

# 3c. Symlink trio into the submodule (AGENTS.md consumer layout)
ln -sfn lib/agents "$OC/agents"
ln -sfn lib/skills "$OC/skills"
ln -sfn lib/opencode.jsonc "$OC/opencode.jsonc"
printf 'node_modules\npackage-lock.json\n' > "$OC/.gitignore"
printf '{\n  "private": true,\n  "dependencies": {\n    "godot-mcp-runtime": "3.2.3"\n  }\n}\n' > "$OC/package.json"

# 2. npm: reuse node_modules from the legacy test/ sandbox if available,
#     else install fresh (saves the multi-minute install on every prep)
LEGACY="$REPO_ROOT/test/.opencode"
if [ "$FULL_NPM" -eq 0 ] && [ -d "$LEGACY/node_modules" ]; then
  cp -R "$LEGACY/node_modules" "$OC/node_modules"
fi
if [ ! -d "$OC/node_modules/godot-mcp-runtime" ]; then
  (cd "$OC" && npm install --no-audit --no-fund) ||
    printf 'prepare_test_dir.sh: npm install failed — run: (cd %s && npm install)\n' "$OC" >&2
fi

# 5. Icon fixture
printf '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><rect width="128" height="128" fill="#1a1a2e"/></svg>\n' > "$TEST_DIR/icon.svg"

# Commit the fixture layer
git -C "$TEST_DIR" add -A
git -C "$TEST_DIR" -c user.name=harness -c user.email=harness@local \
  commit -qm "chore: opencode mount (submodule lib @ ${HEAD_SHA:0:8}) + npm fixture"

# Verification — fail loudly rather than let a session start broken
for l in agents skills opencode.jsonc; do
  [ -e "$OC/$l" ] || fail "$OC/$l does not resolve"
done
[ -d "$OC/node_modules/godot-mcp-runtime" ] ||
  fail "godot-mcp-runtime missing — run: (cd $OC && npm install)"
[ "$(git -C "$TEST_DIR/.opencode/lib" rev-parse HEAD)" = "$HEAD_SHA" ] ||
  fail "submodule HEAD drifted from harness HEAD"
git -C "$TEST_DIR" status --porcelain | grep -q . &&
  fail "unexpected dirty files in $TEST_DIR"

printf 'READY: %s pristine | harness @ %s | git initialized | MCP runtime present\n' \
  "$TEST_DIR" "${HEAD_SHA:0:8}"
printf 'next: cd %s && caffeinate -dimsu opencode (paste benchmark prompt verbatim)\n' "$TEST_DIR"
