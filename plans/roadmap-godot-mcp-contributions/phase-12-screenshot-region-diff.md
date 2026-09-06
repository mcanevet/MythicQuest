# Phase 12 — PR: Screenshot Region-Diff

Kind: PR (extension of `take_screenshot`) · Status: not started · Depends
conceptually on Phase 4 (shares the embedding/similarity code) · Discovered:
RallyWall vision-playtest trace

## Importance to us: MEDIUM

- **Why (trace evidence):** vision playtests are screenshot-hungry — 19
  captures in the final tasks alone — and every capture costs a full VLM
  analysis pass ("does this look right?" over the whole frame) just to
  answer a narrow question ("did the win overlay appear where expected?",
  "did the color tier shift?"). Most comparisons are before/after pairs
  where the agent already knows WHERE change should occur.
- **Impact area:** vision playtest cost and precision; degenerate-run
  detection (Phase 4) is the same math with a different question.
- **Cost:** small once Phase 4's grayscale-similarity code exists — this is
  its second consumer, which strengthens both proposals.

## Proposal

Optional params on `take_screenshot`:

- `diff_against` — previous capture id (screenshots are already persisted
  under `.mcp/screenshots`; id or path both workable)
- Response adds: `changed_fraction`, bounding rect(s) of significant
  change regions (coarse grid, not pixel-exact), similarity score
- No behavioral change when the param is absent (his rules: additive,
  zero-cost for non-users)

Classification shared with Phase 4 (IDENTICAL / STATIC / CHANGED + where).
An agent verifying "game-over overlay appears centered" gets
`changed_region: {x: 240, y: 200, w: 560, h: 200}` — one number to assert,
no VLM round-trip.

## Maintainer-fit notes

- Additive param on an existing tool — no tool-count cost
- Frame the shared-math synergy with Phase 4 up front (one embedding
  pipeline, two evidence-grade features)
- Careful: don't promise pixel-perfect diffs; the maintainer's honesty
  culture means docs must state it's a coarse change detector (compression
  noise, sub-pixel animation), thresholds configurable

## Verification

- Unit: identical frames → 0 change; synthetic shift → bounds match
- Live: RallyWall game-over transition; changed-bounds must land on the
  overlay area, not the HUD jitter
