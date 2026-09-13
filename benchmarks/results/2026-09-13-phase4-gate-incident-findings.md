# Phase-4 Incident Findings: Gate-Closure Failure Chain (Runs 1–2, bd-formula era)

**Bead:** MythicQuest-25a
**Date recorded:** 2026-09-13 (incidents occurred during the bd-ledger migration runs)
**Scope:** The wrapper-based Phase-3 gate failure (run 1) and its recovery path, plus validation status of the fixes.

## Timeline

- **Run 1 (beads-era rallywall, 2026-09-13 morning):** game passed functional QA with 0 violations, but the build session could not execute the release-gate step. Three defects stacked at the same decision point:
  1. The sanctioned helper (`bd_ledger.sh`) lived at a path unguessable from build.md prose — hidden `.opencode/` directory, invisible to `glob()` from the sandbox root.
  2. `bd gate create` was missing from the bash verb allowlist in agent frontmatter — even a perfectly-formed call would have been denied.
  3. Compound commands (`X && Y`, pipes to `grep`/`head`) defeated opencode's bash permission pattern matcher — allowed prefixes matched the first token only, so chained gate-create sequences were denied as unrecognized.
- **Fix commit:** `a6437b3` — explicit sanctioned path in every agent file, `bd gate create` verb added to allowlist + lint verb-set registry, single-command discipline rule ("each tool call a SINGLE simple command").
- **Run 2 (recovery run):** completed Phase 3 with the fixed wrapper. However, its opencode process survived session end unnoticed (see Run-15 incident, bead MythicQuest-o3x) and later contaminated Run 3's relaunch.
- **Run 3 / final stack (reported as Run 15, `2026-09-13-pong-lumo-max-formula-stack-validated-run15.md`):** with the wrapper deleted entirely (`290d15f`), all Phase-3 gates — `bd gate create`, sequenced `bd gate resolve`, `bd close` on the release bead — executed natively with zero permission denials. The Phase-3 gate chain is now **verified** end-to-end, including a consumer-FAIL rework cycle that re-entered the chain without stacking duplicate gates.

## Root Causes

1. **Undiscoverable sanctioned path** — procedural prose referenced a helper whose location was neither in the agent's read scope nor enumerable; the failure surfaced as improvisation (agents attempting alternate paths) rather than a clean ⛔ BLOCKED. Rule violated: sanctioned-paths-only.
2. **Verb allowlist drift** — the ledger migration added new verbs (`gate create/resolve/check`) to procedures without updating the frontmatter permission profiles. Permissions are config; the config trailed the procedure.
3. **Compound commands vs pattern matcher** — the bash permission layer matches single command prefixes; the procedural examples themselves contained `&&` chains copied from interactive shell habits.

## Fixes Applied

| Defect | Fix | Commit |
|--------|-----|--------|
| Undiscoverable helper path | Explicit path in every agent file; later superseded by wrapper deletion | `a6437b3`, `290d15f` |
| Missing `gate create` verb | Allowlist + lint registry verb-set update | `a6437b3` |
| Compound commands | Single-command discipline rule in agent instructions | `a6437b3` |
| Wrapper fragility (class) | Deleted `bd_ledger.sh`; agents call `bd` directly with wide verb allowlist | `290d15f` |
| Orchestration duplication | Four-loops formula as SSOT; loop topology trimmed from build.md | `0133952`, `c8e0ea2` |
| Sandbox wipe under live session | Pre-flight opencode-cwd guard in prepare_test_dir.sh | post-Run-3 (MythicQuest-o3x) |

## Verification Status

- **Phase-3 gate chain: VERIFIED** (Run 15 — qa/vision/consumer gates created and resolved in sequence, rework re-entry correct).
- **Direct-bd stack: VERIFIED** (Run 15 — zero wrapper invocations, zero permission denials).
- **Milestone cadence adaptive logic: partially verified** — one milestone + one vision checkpoint fired correctly; multi-milestone cadence math (3/5/7 task intervals) exercised only once.

## Recommendations

1. **Keep verb allowlists in lockstep with procedures** — any new `bd` verb introduced into an agent instruction must be added to its frontmatter in the same commit; consider a lint rule pairing `bd <verb>` mentions against declared allows.
2. **Single-command discipline generalizes** — apply the no-compound-command rule wherever the bash pattern matcher gates execution; don't reintroduce `&&` in future procedural examples.
3. **Cadence-table coverage** — a future benchmark with a larger backlog (>14 beads) would exercise the adaptive milestone cadence more thoroughly than Run 15's 13-bead ledger.
