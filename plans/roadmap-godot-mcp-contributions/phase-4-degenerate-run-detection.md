# Phase 4 — PR: Degenerate-Run Detection

Kind: PR · Status: not started · Can proceed in parallel with Phase 3's
issue discussion

## Importance to us: MEDIUM

- **Why:** we have benchmark evidence of degenerate games passing
  screenshot-based QA (blank/static screens counted as "running"). That's a
  scoring-validity hole — false PASSes corrupt the exact metric
  (invariant pass rates) the harness iterates on.
- **Impact area:** QA trustworthiness; complements Phase 3 (determinism
  makes runs reproducible, this makes them meaningful).
- **Cost:** small-medium, self-contained math; nice-to-have rather than
  blocker — scoring already partially mitigated by harness-side UI checks.

## Problem

The "silent black-screen game passes QA" failure class: a benchmark session
builds a game that renders nothing/stuck frames, and screenshot-based
playtests can't tell without human eyes.

## Design

Frame-similarity on consecutive screenshots:

- 32×32 grayscale resize, L2-normalized embedding, cosine similarity
- Classify: IDENTICAL / STATIC / STALLED (port enhanced's thresholds as
  starting values)
- Compute the embedding **in GDScript inside the bridge** — zero new npm
  dependencies, self-contained (precedent: enhanced does the same
  deliberately; matches this maintainer's minimal-deps taste)

## Surface decision

Present BOTH options in a design issue and let the maintainer pick (his
consolidation philosophy):

- Additive result payload on `take_screenshot` (preferred — no new tool)
- Small follow-up tool (only if he prefers separation)

## Verification

- Unit tests on embedding math (synthetic images: identical, shifted,
  noisy, blank)
- Live: rerun the degenerate-game seed from prior benchmark sessions;
  confirm classification catches it
