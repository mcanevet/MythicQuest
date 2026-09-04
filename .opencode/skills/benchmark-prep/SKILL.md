---
name: benchmark-prep
description: Prepare or reset a benchmark sandbox for a game-build session before running a benchmark prompt from benchmarks/prompts/. Use when starting a new harness benchmark run (e.g. with a new model), when the previous run's sandbox is dirty or partially built, when switching sandboxes (test/, test2/), or when verifying a sandbox is launch-ready (git init, library submodule, MCP runtime, symlinks). Harness-level — this is not part of consumer game-build projects.
---

## What I do

Reset a disposable consumer sandbox to a pristine, verified, benchmark-ready
state — one deterministic script, not a hand-typed cleanup sequence. Lives in
the harness repo (`.opencode/skills/`), NOT in the consumer-facing `skills/`;
never mounted in game projects.

## When to use

- About to start a benchmark run (`benchmarks/prompts/*.md`) with any model
- Previous run died mid-way (quota, stall, kill) and the sandbox is dirty
- Want to switch sandbox directories (default `test2/`, or pass any path)
- Suspect a sandbox is broken (dangling symlinks, missing MCP runtime)

## Layout this script creates

```
<sandbox>/                    # fresh git repo, initial commit — opencode cwd anchor
└── .opencode/
    ├── lib/                  # git submodule -> bare mirror of THIS harness repo
    │                         #   pinned to current HEAD (commit recorded in consumer git)
    ├── agents    -> lib/agents
    ├── skills    -> lib/skills
    ├── opencode.jsonc -> lib/opencode.jsonc
    ├── package.json          # godot-mcp-runtime, version-pinned
    └── node_modules/         # preserved across resets unless --full-npm
```

Why a submodule (vs the old direct symlinks): the consumer repo records
**which harness commit it ran against** — benchmark reproducibility — and the
sandbox is fully self-contained; a `git clean` in either repo cannot break the
other. The submodule points at a bare **mirror** of the harness repo
(`../MythicQuest-mirror.git`, auto-created and refreshed by the script)
because git refuses a submodule URL equal to the superproject itself.

## Run it

```bash
.opencode/skills/benchmark-prep/scripts/prepare_test_dir.sh [sandbox-dir] [--full-npm]
```

- `sandbox-dir` defaults to `test2`; must be inside the harness repo (it is
  gitignored — no harness commits happen).
- `--full-npm` wipes and reinstalls node_modules (default: reuse/install once).
- Idempotent: re-running rebuilds the whole sandbox from scratch — **any
  existing content in the sandbox directory is deleted**, including a game
  built by a prior run. If the prior run's artifacts matter, save them first
  (benchmark reports belong in `benchmarks/results/` anyway).
- Exit 0 = verified ready; the script prints the pinned harness SHA and the
  launch command. Exit 1 = verification failed — read the printed reason
  (dangling link, missing runtime, dirty tree) and fix before launching.

## After prep — launching the run

1. `cd <sandbox>`
2. Run opencode under a power assertion: `caffeinate -dimsu opencode`
   (host sleep is indistinguishable from stalls in the session DB — see
   benchmarks/README.md).
3. Paste the benchmark prompt **verbatim** from `benchmarks/prompts/`.
4. Monitor the live session with the `debug-harness` skill
   (`scripts/watch_root.sh`), then record results in
   `benchmarks/results/<date>-<label>.md`.

## Gotchas

- **Mirror is the submodule's remote, not the harness working tree.** The
  script fetches current HEAD into the mirror before adding the submodule —
  uncommitted harness changes are NOT included in the benchmarked library.
  Commit harness changes first (that is the point: pin a SHA you can cite).
- **`git submodule add` needs `protocol.file.allow=always`** — the script
  sets it per-invocation (`-c`) so global config stays untouched.
- **Do not point the sandbox at a path outside the harness repo** — the
  script `rm -rf`s the target and references the mirror relative to the
  harness root; an outside path deletes real files without the gitignore
  safety.
