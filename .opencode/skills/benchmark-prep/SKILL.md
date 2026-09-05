---
name: benchmark-prep
description: Prepare or reset a benchmark sandbox for a game-build session before running a benchmark prompt from benchmarks/prompts/. Use when starting a new harness benchmark run (e.g. with a new model), when the previous run's sandbox is dirty or partially built, when switching sandboxes (test/, test2/), or when verifying a sandbox is launch-ready (git repo, harness submodule, MCP runtime). Lives at `.opencode/skills/` in the harness repo — top-level `skills/` is what mounts into consumer game projects; this skill stays behind.
---

## What I do

Reset a disposable consumer sandbox to a pristine, verified, benchmark-ready
state — one deterministic script, not a hand-typed cleanup sequence. Lives in
the harness repo (`.opencode/skills/`), NOT in the consumer-facing `skills/`;
never mounted in game projects.

## When to use

- About to start a benchmark run (`benchmarks/prompts/*.md`) with any model
- Previous run died mid-way (quota, stall, kill) and the sandbox is dirty
- Want to switch sandbox directories (default `test2/`, or pass any name)
- Suspect a sandbox is broken (missing MCP runtime, drifted submodule)

## Layout this script creates

The AGENTS.md **"Option 1: git submodule (production)"** consumer layout —
`.opencode` itself IS the submodule, so there are no symlinks at all:

```
<sandbox>/                  # its own fresh git repo (opencode cwd anchor)
└── .opencode/              # git SUBMODULE -> this harness repo, pinned at HEAD
    ├── agents/             # checked out from the harness repo
    ├── skills/             # checked out (loader resolves .opencode/skills directly)
    ├── opencode.jsonc       # checked out
    └── node_modules/       # godot-mcp-runtime 3.2.3 (checkout-local git excludes —
                            #   invisible to both repos' status)
```

Why pinning matters: the consumer repo's history records **which harness
commit a benchmark ran against** — reproducible A/B comparison across models
and harness versions. Why a mirror: git refuses a submodule URL equal to the
superproject, so the script points it at a sibling bare mirror
(`../MythicQuest-mirror.git`) that it creates/refreshes from harness HEAD
before each prep run.

## Run it

```bash
.opencode/skills/benchmark-prep/scripts/prepare_test_dir.sh [sandbox-name] [--full-npm]
```

- `sandbox-name` defaults to `test2`; must be a simple name inside the harness
  repo (gitignored there — no harness commits happen).
- `--full-npm` wipes and reinstalls node_modules.
- Idempotent, and destructive by design: **any existing content in the
  sandbox is deleted**, including a game built by a prior run. Preserve
  benchmark reports in `benchmarks/results/` first.
- Exit 0 = verified ready (prints the pinned SHA + launch command);
  exit 1 = verification failed — read the printed reason and fix before launch.

## After prep — launching the run

1. `cd <sandbox>`
2. `caffeinate -dimsu opencode` (power assertion — host sleep is
   indistinguishable from stalls in the session DB; see benchmarks/README.md)
3. Paste the benchmark prompt **verbatim** from `benchmarks/prompts/`
4. Monitor with the `debug-harness` skill (`scripts/watch_root.sh`), then
   record results in `benchmarks/results/<date>-<label>.md`

## Gotchas

- **The submodule pins the last COMMITTED harness HEAD.** Uncommitted harness
  changes are excluded from the benchmarked library — commit first (that is
  the point: pin a SHA you can cite in the benchmark report).
- **`protocol.file.allow=always` is set per-invocation** (`git -c`) for the
  `submodule add` — global git config stays untouched.
- **npm artifacts use checkout-local excludes** (`.git/info/exclude` of the
  submodule), not committed `.gitignore`s — so neither the harness repo nor
  the consumer repo ever sees node_modules as dirty, and the submodule pointer
  can't be flipped by an install.
