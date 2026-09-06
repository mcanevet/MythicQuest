# Roadmap: Stay on godot-mcp-runtime — Contribution Plan

Decision: stay on godot-mcp-runtime, close gaps via upstream PRs. Do not migrate.
Derived from the 2026-09-05 landscape survey (3 blind model reviews, 2 rounds)
and a full maintainer/history audit. See `survey-conclusion.md` for rationale.

## Phase index

| Phase | File | Kind | Status |
|---|---|---|---|
| 0 | `phase-0-close-out.md` | PR support | **COMPLETE** — #29/#30 merged, released in v3.2.4 |
| 1 | `phase-1-validate-autoload-aware.md` | Bugfix PR | Not started |
| 2 | `phase-2-incremental-log-capture.md` | Issue + PR | Not started |
| 3 | `phase-3-deterministic-playtest.md` | Issue-first (design) | Not started |
| 4 | `phase-4-degenerate-run-detection.md` | PR | Not started |
| 5 | `phase-5-harness-side-qa.md` | MythicQuest-only | Not started |
| 6 | `phase-6-doc-updates.md` | MythicQuest-only | Not started |
| 7 | `phase-7-runscript-error-diagnostics.md` | Bugfix PR (sibling of 1) | Not started — top trace finding |
| 8 | `phase-8-async-runscript-jobs.md` | Issue + PR | Not started — zombie-script safety |
| 9 | `phase-9-background-framerate.md` | Investigation + PR/docs | Not started — macOS evidence integrity |
| 10 | `phase-10-test-state-protocol.md` | Issue-first (convention) | Exploratory — emergent-pattern discovery |
| 11 | `phase-11-layout-lint.md` | PR (`validate` extension) | Not started — HIGH, bug-class evidence in hand |
| 12 | `phase-12-screenshot-region-diff.md` | PR (`take_screenshot` param) | Not started — shares Phase 4 math |
| 13 | `phase-13-input-record-replay.md` | Part of Phase 3 scope | Gated on Phase 3 |

## Reference files

- `survey-conclusion.md` — landscape survey verdict + comparison table
- `maintainer-alignment.md` — history/issues/PR audit: philosophy, receptivity,
  declined items, caveats
- `evidence-2026-09-05-glm-trace.md` — session-DB trace analysis that spawned
  Phases 7–10 (findings → phase mapping)
- `_original-monolith.md` — pre-split original document (superseded; keep for
  provenance until Phase 0 completes, then delete)

## Sequencing rules

- Phases 1–2 must land (or be clearly accepted in review) before opening the
  Phase 3 design issue — the maintainer's trust is earned per-PR, and Phase 3
  is the only framework-sized ask
- Phase 4 can proceed in parallel with Phase 3's issue discussion
- Phases 7+8 can combine with Phase 1 (shared stderr-parse helper for 1+7;
  both are bugfix-class, his sweet spot)
- Phase 9 starts harness-side (macOS repro he cannot run) regardless of
  upstream sequencing; Phase 10 is skill-side first, upstream issue only
  after a second-run evidence baseline
- Phase 11 is independent — HIGH priority, and its evidence (a real bug
  that survived every gate) is fresh; it slots naturally into the Phase
  1/7/8 bugfix-PR wave
- Phase 12 rides Phase 4's embedding work — same PR family or immediately
  after; Phase 13 folds into Phase 3's design issue, never pitched apart
- Phase 5/6 are unconstrained (harness-side, MythicQuest repo)

## Verification (applies to every PR phase)

- `npm run verify` (typecheck → lint → format → test → build) in this repo
- Live validation in MythicQuest `test/` sandbox via integration-build dist
- Final proof: one benchmark run on the GLM/qwen prompt series with all merged
  contributions active; compare invariant pass rates and retry counts vs prior
