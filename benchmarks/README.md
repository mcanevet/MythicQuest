# Benchmark Suite

Fixed, reusable prompts for end-to-end benchmarking of the MythicQuest harness.
Each prompt is versioned in-repo so harness changes can be A/B compared against
recorded baseline runs.

## Prompts

| File | Purpose | Profile |
|---|---|---|
| `prompts/rallywall.md` | **Primary / fast baseline** — minimal entity count, full pipeline coverage | Fastest feedback, lowest token burn |
| `prompts/brickfall.md` | Coverage variant — instancing (node grids), lives, destruction | Stress path for create-scene-with-script |

Run the primary prompt (`rallywall.md`) for regression benchmarking after any
harness change. Reach for `brickfall.md` when testing code paths involving
repeated-node instancing (brick grids, item spawners) that the primary prompt
doesn't reach.

## Running a benchmark

1. Reset the consumer sandbox (deterministic — do not hand-type a cleanup):
   ```bash
   .opencode/skills/benchmark-prep/scripts/prepare_test_dir.sh [sandbox-name]
   ```
   Default sandbox: `test/`. Creates the git-submodule consumer layout
   (`.opencode` IS the submodule, pinned at committed harness HEAD) and
   verifies it launch-ready. See the `benchmark-prep` skill for details.
2. Start opencode from `test/` (so it sees `.opencode/agents` +
   `.opencode/skills`), note the wall-clock start time.
   **Run under `caffeinate -dimsu` (or equivalent power-assertion).**
   Host sleep is indistinguishable from stalls in the session DB after the
   fact — the 09-03 run lost 5.8 of 9.2 wall-clock hours to sleep and the
   active-time figure had to be reconstructed from tool-activity bursts.
   Record `pmset -g assertions` output (or system sleep log) alongside the
   metrics so sleep-time can be subtracted deterministically instead of
   inferred.
3. Paste the prompt verbatim. Do not edit it, clarify it, or answer
   agent questions beyond the minimum required — consistency is the
   experiment control.
4. While it runs, monitor with the `debug-harness` skill
   (SQLite session DB polling) to record subagent spawns, stalls,
   retries.
5. On completion, record the metrics below.

## Metrics to record (efficiency + outcome axes)

| Metric | Source |
|---|---|
| Total wall-clock time | session timestamps (root session `time_created` → `time_updated`) |
| Token usage (if exposed) | session DB / provider dashboard |
| Subagent count + per-agent durations | session DB, `parent_id` tree |
| Retry counts (`(attempt: N)` markers) | `GAME_STATE.md` |
| `run_project` success/fail + durations | session DB tool parts |
| Stalls (>60s no tool activity) | live monitor or DB gap analysis |
| Functional QA pass rate + FAIL items | poppy's QA report |
| Vision-qa rating + consumer verdict | ian / pootie results |
| Invariant violations | validate.sh / QA reports |
| Chinese/other language drift | reasoning-part scan |
| Improvised-workaround incidents | BLOCKED reports, skill-dir writes |

Store results as `results/<date>-<label>.md` where label identifies the harness
version under test (e.g. `pre-perm-fix`, `post-perm-fix`).

## Baselines

- 2026-09-01/02, "Neon Volley" (resume + Phase 3 completion): 74.9 min,
  8 subagents, 12/12 mechanics pass, 0 harness stalls, SHIP verdict.
  Reference only — it resumed mid-build, so it is not a comparable
  full-pipeline baseline. First true baseline should be a fresh run
  of the primary prompt on the current harness.
