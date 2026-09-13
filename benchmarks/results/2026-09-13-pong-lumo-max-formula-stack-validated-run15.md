# Pong MVP — lumo-max — Formula Stack Validation (Run 15, "Run 3" of the bd-formula series)

**Date:** 2026-09-13
**Model:** proton-lumo/lumo-max (build agent)
**Prompt:** `benchmarks/prompts/pong-minimal.md` (verbatim: "Build a pong-like game with minimal scope: ball, paddle, score. MVP only, no polish.")
**Sandbox:** `test/` pinned at harness `e0039082`
**Stack under test:** direct `bd` CLI (no wrapper), `game-four-loops` formula installed into sandbox `.beads/formulas/`, trimmed `build.md`

## Objective Triad

| Axis | Result |
|------|--------|
| **1. Outcome** | ✅ SHIPPED — "Paddle Clash", all 3 release gates passed (QA / vision / consumer), COMPLETION_REPORT READY=YES |
| **2. Speed** | ~2h45m wall clock, no stalls, no manual intervention |
| **3. Token efficiency** | Root context stayed healthy (small-step discipline); report-return convention held; 2-task batching deployed |

Outcome first: the game works and honors the MVP constraint (4 polish beads correctly deferred).

## What This Run Validated

1. **Direct `bd` stack** — genesis, claim, gate create/resolve, close, defer all executed natively with zero permission errors and zero wrapper involvement. The deleted `bd_ledger.sh` is not missed.
2. **Gate chain (Phase 3)** — release bead blocked by qa → vision → consumer gates resolved in sequence; consumer FAIL routed back through rework (cycle 1) and the chain re-entered correctly without stacking a second gate chain. This is the exact failure point of Run 1-era incidents; it now holds.
3. **Formula as SSOT** — the trimmed `build.md` (loop topology removed, cadence table removed) still produced correct four-loop behavior with the formula as reference. Agent executed procedurally against the formula's documented pattern.
4. **Rework cap discipline** — one consumer rework cycle (HUD bugs via Pootie), fixed by poppy, re-verified by rachel → ian → ship. Within the cap of 2; no taste-divergence escalation needed.
5. **MVP scope honoring** — "no polish" constraint respected: genesis created polish-adjacent beads, groomer deferred them, only vision-drift-class work (ball speed ramp, a core VISION.md mechanic mislabeled as polish initially) was pulled back in.

## Incident (pre-run): Sandbox Contamination

The first launch of this run was invalidated before it counted:

- **Cause:** `prepare_test_dir.sh` wiped `test/` while run 14's opencode process (PID 37266) was still alive with cwd inside the sandbox. The zombie session kept writing to the rebuilt ledger — a RallyWall VISION.md appeared inside the pong genesis, poisoning the release-bead title and scripts.
- **Root fix:** pre-flight guard in `prepare_test_dir.sh` — refuses to wipe when any `pgrep -x opencode` process has cwd inside the sandbox (validated live; `|| true` guards `set -e` from the loop's last-iteration exit status).
- **Bead:** MythicQuest-o3x (filed and closed).
- **Lesson:** killing engine processes is not process cleanup. A sandbox wipe must check *every* process family that can write to it.

## Evidence

- Completion report: `test/COMPLETION_REPORT.md` (full statistics, gate verdicts, known issues)
- QA/vision/consumer reports: `test/reports/` (functional-qa.md ×2, vision-qa ×3, pootie critique, 5 scene-verify reports)
- Ledger end-state: 13 closed, 4 deferred, 0 blocked; gates all resolved

## Conclusion

The bd-formula stack is validated. Recommended follow-through already committed:

- `bd58ffb` — redundant bd tutorials stripped
- `e003908` — formula made agent-agnostic (lint clean)
- `c8e0ea2` — duplicated loop topology trimmed from build.md
- Zombie-session guard in benchmark-prep

Next: the remaining harness backlog (MythicQuest-pjr bd v1.3.0 upgrade, MythicQuest-9n7 workflow doc, MythicQuest-29a provenance eval).
