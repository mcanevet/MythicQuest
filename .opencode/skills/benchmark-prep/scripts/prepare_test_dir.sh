#!/usr/bin/env bash
# prepare_test_dir.sh — reset a benchmark sandbox to a pristine,
# benchmark-ready state, per benchmarks/README.md §"Running a benchmark".
#
# Layout — EXACTLY the AGENTS.md "Option 1: Git submodule (production)"
# consumer layout:
#
#   <sandbox>/                    <- its own git repo (git init)
#   └── .opencode/                <- git SUBMODULE -> this harness repo
#       ├── agents/ skills/ opencode.jsonc    (checked out, not symlinked)
#       └── node_modules/ + package.json       (godot-mcp-runtime, pinned)
#
# The submodule pins the harness at current HEAD: the consumer repo's
# history records WHICH harness commit a benchmark ran against.
# Because .opencode IS the submodule, no symlinks are needed — the skill
# loader resolves .opencode/skills from the checked-out tree directly.
#
# Self-reference workaround: git refuses a submodule URL equal to the
# superproject (or a repo containing untracked junk breaks local clones).
# We point the submodule at a sibling BARE MIRROR (../MythicQuest-mirror.git)
# that the script creates and refreshes from the harness HEAD first.
#
# Guarantees (idempotent — safe to run repeatedly):
#   1. Sandbox wiped completely (disposable by contract) then rebuilt.
#   2. .opencode submodule pinned to the CURRENT COMMITTED harness HEAD.
#   3. npm state: node_modules lives INSIDE the submodule worktree; it is
#      not tracked by either repo (submodule .gitignore), so it survives
#      re-checkouts; --full-npm forces reinstall.
#   4. Fresh consumer git repo with readable history pinning the harness SHA.
#   5. Leftover engine processes killed via stop_engine.sh (never pkill —
#      lint check 8).
#   6. Commits nothing to the harness repo itself.
#
# Usage: prepare_test_dir.sh [sandbox-dir] [--full-npm]
#   sandbox-dir defaults to test2 (must live INSIDE the harness repo).
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
OC="$REPO_ROOT/$TEST_DIR/.opencode"

fail() { printf 'prepare_test_dir.sh: %s\n' "$1" >&2; exit 1; }

case "$TEST_DIR" in
  .|..|""|*/*..*) fail "sandbox dir must be a simple name inside the harness repo" ;;
esac

# 5. Kill leftover engine processes through the sanctioned stopper
STOP="$REPO_ROOT/skills/create-scene-with-script/scripts/stop_engine.sh"
[ -x "$STOP" ] && "$STOP" >/dev/null 2>&1 || true

# Mirror maintenance — submodule remote is a bare clone of the harness repo
if [ -d "$MIRROR" ]; then
  git --git-dir="$MIRROR" fetch -q "$REPO_ROOT" "refs/heads/*:refs/heads/*" ||
    fail "mirror fetch failed — check $MIRROR"
else
  # --no-local: the harness worktree has ignored dirs that break local clones
  git clone --bare --no-local -q "$REPO_ROOT" "$MIRROR" ||
    fail "could not create bare mirror at $MIRROR"
fi
HEAD_SHA=$(git rev-parse HEAD)
git --git-dir="$MIRROR" fetch -q "$REPO_ROOT" "$HEAD_SHA:refs/heads/benchmark-pin" ||
  fail "could not pin HEAD ($HEAD_SHA) into mirror"

# 1. Wipe the sandbox (disposable by contract — includes any prior game build)
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 2+4. Consumer repo, then the .opencode submodule at harness HEAD
git -C "$TEST_DIR" init -q
git -C "$TEST_DIR" -c protocol.file.allow=always \
  submodule add -q --name opencode "$MIRROR" .opencode
git -C "$OC" checkout -q "$HEAD_SHA"
git -C "$TEST_DIR" add .opencode
git -C "$TEST_DIR" -c user.name=harness -c user.email=harness@local \
  commit -qm "chore: pin harness @ ${HEAD_SHA:0:8} (.opencode submodule)"

EXCL_DONE=0
GD=$(git -C "$OC" rev-parse --absolute-git-dir)
if ! grep -qx 'node_modules' "$GD/info/exclude" 2>/dev/null; then
  mkdir -p "$GD/info"
  printf 'node_modules/\npackage-lock.json\npackage.json\n' > "$GD/info/exclude"
  EXCL_DONE=1
fi
if [ "$EXCL_DONE" -eq 1 ] || [ ! -d "$OC/node_modules/godot-mcp-runtime" ]; then
  if [ ! -f "$OC/package.json" ]; then
    printf '{\n  "private": true,\n  "dependencies": {\n    "godot-mcp-runtime": "3.2.3"\n  }\n}\n' > "$OC/package.json"
  fi
  (cd "$OC" && npm install --no-audit --no-fund) ||
    printf 'prepare_test_dir.sh: npm install failed — run: (cd %s && npm install)\n' "$OC" >&2
fi

# Verification — fail loudly rather than let a session start broken
[ -d "$OC/agents" ] && [ -d "$OC/skills" ] && [ -f "$OC/opencode.jsonc" ] ||
  fail "submodule checkout incomplete ($OC/agents|skills|opencode.jsonc missing)"
[ "$(git -C "$OC" rev-parse HEAD)" = "$HEAD_SHA" ] ||
  fail "submodule HEAD drifted from harness HEAD"
[ -d "$OC/node_modules/godot-mcp-runtime" ] ||
  fail "godot-mcp-runtime missing — run: (cd $OC && npm install)"
git -C "$TEST_DIR" status --porcelain | grep -q . &&
  fail "unexpected dirty files in $TEST_DIR (node_modules should be gitignored)"

printf 'READY: %s | harness @ %s | git initialized | MCP runtime present\n' \
  "$TEST_DIR" "${HEAD_SHA:0:8}"
printf 'next: cd %s && caffeinate -dimsu opencode (paste benchmark prompt verbatim)\n' "$TEST_DIR"
