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
#       └── (no node_modules — MCP runtime comes from wherever
#           opencode.jsonc's command points; currently a direct `node`
#           invocation of the local fork checkout)
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
#   3. MCP runtime: resolved by opencode.jsonc's `command` (currently a
#      direct node invocation of the local fork checkout — verified below;
#      former npm-install step retired when the pin moved to local disk).
#   4. Fresh consumer git repo with readable history pinning the harness SHA.
#   5. Leftover engine processes killed via stop_engine.sh (never pkill —
#      lint check 8).
#   6. Commits nothing to the harness repo itself.
#
# Usage: prepare_test_dir.sh [sandbox-dir] [--full-npm]
#   sandbox-dir defaults to test (must live INSIDE the harness repo).
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
TEST_DIR="${TEST_DIR:-test}"
cd "$REPO_ROOT"
MIRROR="$REPO_ROOT/../MythicQuest-mirror.git"
OC="$REPO_ROOT/$TEST_DIR/.opencode"

fail() { printf 'prepare_test_dir.sh: %s\n' "$1" >&2; exit 1; }

case "$TEST_DIR" in
  .|..|""|*/*..*) fail "sandbox dir must be a simple name inside the harness repo" ;;
esac

# 5. Kill leftover engine processes through the sanctioned stopper
STOP="$REPO_ROOT/plugins/engine/godot/skills/create-scene-with-script/scripts/stop_engine.sh"
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

GD=$(git -C "$OC" rev-parse --absolute-git-dir)
if ! grep -qx 'node_modules' "$GD/info/exclude" 2>/dev/null; then
  mkdir -p "$GD/info"
  printf 'node_modules/\npackage-lock.json\npackage.json\n' > "$GD/info/exclude"
fi

# Consumer-owned plugin selection + mount. The submodule is read-only for
# consumers, so plugin choice lives at the consumer project root: one plugin
# per slot in mythic-quest.json, and a root opencode.json mounting the chosen
# plugin directories as skill sources (opencode concatenates skills arrays
# across config documents, composing with the submodule's config). Overrides:
# MYTHIC_ENGINE / MYTHIC_TRACKER env vars.
ENGINE="${MYTHIC_ENGINE:-godot}"
TRACKER="${MYTHIC_TRACKER:-beads}"
[ -d "$OC/plugins/engine/$ENGINE" ] || fail "unknown engine plugin: $ENGINE"
[ -d "$OC/plugins/tracker/$TRACKER" ] || fail "unknown tracker plugin: $TRACKER"
printf '{ "engine": "%s", "tracker": "%s" }\n' "$ENGINE" "$TRACKER" > "$TEST_DIR/mythic-quest.json"
printf '{\n  "skills": [\n    ".opencode/plugins/engine/%s",\n    ".opencode/plugins/tracker/%s"\n  ]\n}\n' "$ENGINE" "$TRACKER" > "$TEST_DIR/opencode.json"
git -C "$TEST_DIR" add mythic-quest.json opencode.json
git -C "$TEST_DIR" -c user.name=harness -c user.email=harness@local \
  commit -qm "chore: select plugins engine=$ENGINE tracker=$TRACKER"

# Verification — fail loudly rather than let a session start broken
[ -d "$OC/agents" ] && [ -d "$OC/skills" ] && [ -f "$OC/opencode.jsonc" ] ||
  fail "submodule checkout incomplete ($OC/agents|skills|opencode.jsonc missing)"
[ "$(git -C "$OC" rev-parse HEAD)" = "$HEAD_SHA" ] ||
  fail "submodule HEAD drifted from harness HEAD"
# MCP runtime verification: resolve the command from opencode.jsonc's
# godot-mcp-runtime entry and prove the server entrypoint + the
# instanced-child serialization fix are actually present on disk.
MCP_CMD=$(python3 - "$OC/opencode.jsonc" << 'PYEOF'
import json, re, sys
raw = re.sub(r'^\s*//.*$', '', open(sys.argv[1]).read(), flags=re.M)
raw = re.sub(r',\s*([\]}])', r'\1', raw)
cfg = json.loads(raw)
print(' '.join(cfg["mcp"]["godot-mcp-runtime"]["command"]))
PYEOF
) || fail "could not parse mcp command from opencode.jsonc"
# shellcheck disable=SC2086
read -r -a MCP_PARTS <<< "$MCP_CMD"
N=${#MCP_PARTS[@]}
[ "$N" -ge 2 ] || fail "mcp command too short: $MCP_CMD"
# npx-pinned command (e.g. ["npx", "godot-mcp-runtime@3.6.0"]): vendor the
# package into the sandbox's checkout-local node_modules and rewrite the
# sandbox's opencode.jsonc to invoke it directly — npx resolution inside
# the sandbox would hit the network/cache per MCP server start, and the
# original unpinned form must not silently diverge from the version the
# benchmark records. (Local node/dir pins fall through unchanged.)
ENTRY="${MCP_PARTS[$((N-1))]}"
if [ "${MCP_PARTS[0]}" = "npx" ]; then
  PKG_SPEC="$ENTRY"
  case "$PKG_SPEC" in
    godot-mcp-runtime@*) PKG_VER="${PKG_SPEC#godot-mcp-runtime@}" ;;
    *) fail "unsupported npx pin: $PKG_SPEC (expected godot-mcp-runtime@<ver>)" ;;
  esac
  NM="$OC/node_modules/godot-mcp-runtime"
  if [ ! -f "$NM/dist/index.js" ] || \
     ! grep -q "\"version\": \"$PKG_VER\"" "$NM/package.json" 2>/dev/null; then
    mkdir -p "$OC/node_modules"
    ( cd "$OC" && npm pack "godot-mcp-runtime@$PKG_VER" >/dev/null 2>&1 ) ||
      fail "npm pack godot-mcp-runtime@$PKG_VER failed"
    TARBALL="$OC/godot-mcp-runtime-$PKG_VER.tgz"
    [ -f "$TARBALL" ] || fail "npm pack produced no tarball for $PKG_VER"
    ( cd "$OC/node_modules" && tar xzf "$TARBALL" && mv package godot-mcp-runtime ) ||
      fail "tar extract of godot-mcp-runtime-$PKG_VER failed"
    rm -f "$TARBALL"
  fi
  # Rewrite the sandbox copy to invoke the vendored entrypoint directly.
  python3 - "$OC/opencode.jsonc" << PYEOF || fail "failed to rewrite sandbox mcp command"
import json, re, sys
p = sys.argv[1]
raw = open(p).read()
new_cmd = '["node", "node_modules/godot-mcp-runtime/dist/index.js"]'
pattern = re.compile(r'("command":\s*)\[[^\]]*"npx"[^\]]*\]')
rewritten, n = pattern.subn(r'\1' + new_cmd, raw, count=1)
if n != 1:
    print("npx command not found for rewrite", file=sys.stderr); sys.exit(1)
open(p, "w").write(rewritten)
PYEOF
  # Record the rewrite as a submodule-local commit and re-point the parent:
  # the pin must reflect the exact config the benchmark ran against, and a
  # dirty submodule would fail the clean-tree verification below.
  git -C "$OC" add opencode.jsonc
  git -C "$OC" -c user.name=harness -c user.email=harness@local \
    commit -qm "chore: vendor mcp runtime $PKG_VER into checkout-local node_modules"
  git -C "$TEST_DIR" add .opencode
  git -C "$TEST_DIR" -c user.name=harness -c user.email=harness@local \
    commit -qm "chore: pin harness @ ${HEAD_SHA:0:8} (+vendored mcp $PKG_VER)"
  HEAD_SHA=$(git -C "$OC" rev-parse HEAD)
  ENTRY="$NM/dist/index.js"
fi
case "$ENTRY" in
  /*) ;;                                  # absolute path — use as-is
  *) ENTRY="$OC/$ENTRY" ;;                # relative — resolve against sandbox
esac
[ -f "$ENTRY" ] ||
  fail "MCP entrypoint missing: $ENTRY (build the checkout it points at)"
# Fix marker lives in the GDScript operation source, not the bundled JS
# (node pin → dist/scripts sits beside dist/index.js).
GD_SRC="$(dirname "$ENTRY")/scripts/godot_operations.gd"
[ -f "$GD_SRC" ] || fail "godot_operations.gd missing beside entrypoint: $GD_SRC"
grep -q '_claim_for_serialization' "$GD_SRC" ||
  fail "MCP checkout lacks the instanced-child serialization fix (_claim_for_serialization not in $GD_SRC) — rebuild the MCP checkout"
git -C "$TEST_DIR" status --porcelain | grep -q . &&
  fail "unexpected dirty files in $TEST_DIR (node_modules should be gitignored)"

printf 'READY: %s | harness @ %s | git initialized | MCP runtime present\n' \
  "$TEST_DIR" "${HEAD_SHA:0:8}"
printf 'next: cd %s && caffeinate -dimsu opencode (paste benchmark prompt verbatim)\n' "$TEST_DIR"
