# Maintainer & History Audit (2026-09-05)

Full read of commit history (168 commits), all issues (9), all PRs (20),
discussions (none exist), and docs. Purpose: verify the roadmap doesn't
conflict with the project's rationale or the maintainer's preferences.

## Who and what

- Maintainer: **Erodenn (Owen)**, solo, NYC. Built and dogfoods it on his own
  games; built "with Claude Code". Busy, multiple projects, explicitly no
  private consulting (issue #17).
- **Identity statement** (README): "Playwright MCP, but for Godot" — a
  *verification loop closer* for agents. Explicitly NOT a playtesting
  replacement or test framework.
- Conscious niche: "zero-footprint game-runtime" (transient injection + npx +
  guardrails), defended by self-authored `docs/comparison.md` (~20 servers,
  honestly flagged as self-authored, corrections invited). His taxonomy
  (file/editor-live/game-runtime; footprint axis) matches ours.
- Cadence: bug report → diagnosis → release within ~1–2 days, repeatedly
  (#18, #23, #24). No backlog culture; he ships immediately instead of queuing.

## Receptivity — definitively better than the blind surveys believed

- **johanravn: 6 merged external PRs of core substance** — #5 attach mode,
  #6 stderr error detection, #7 bridge-readiness verification, #11 screenshot
  response modes, #13 multi-runtime bridge support. Attach mode and bridge
  readiness are foundational to our daily usage.
- **Us**: #28 merged (shipped v3.2.3); #29/#30 open (correct as of 2026-09-05
  — the two "merge:" commits of that date are on OUR combined branch, not
  upstream).
- Review style on #13: engaged mid-PR, found a better design (bake port into
  injected bridge), refactored the contributor's approach himself. He reworks
  good ideas rather than rejecting them.

## Declined / closed-not-merged (complete inventory)

| Item | Reason |
|---|---|
| PR #4 (Fronteir AI hosted-deployment note) | "spam" — promotional, not technical |
| PR #19, #21 (TS conventions, his own) | Closed in favor of his consolidated #22 (v3.2.0) |
| PR #1 (badge) | Housekeeping |
| Issue #2 (TCP 0.0.0.0 vuln) | Misdirected — belonged to a different project |
| Issue #17 (agent loops infinitely) | Not-a-bug: "the server's job is to provide tools"; won't absorb agent-discipline problems |

**No substantive external technical PR has ever been declined.**

## Governing philosophy (docs/tool-authoring.md — the operative constraints)

- Every tool ships on every handshake → **context budget is sacred**
  (~500-char description cap; "drop low-value tools")
- Consolidation by outcome, not cardinality; `batch_` prefix is a symptom of
  missed consolidation; `batch_scene_operations` is a documented exception
  only
- Any GDScript-forwarding tool MUST route through the `evaluateScript()`
  security gate — no shortcuts, tier tests mandatory
- v3.0 history proves taste for lean surface (dropped `manage_uids`,
  aggressive consolidation; BREAKING was accepted)

## Alignment verdict

**No fundamental conflict.** Our roadmap phases 1, 2, 4 are bugfix/additive
class — his sweet spot. Phase 3 (determinism) is stylistic friction, not
philosophical opposition: nothing in his writing opposes it; the RCE-safe
declarative-conditions design aligns with his security-gate thinking; but a
framework-sized contribution should expect rework or slower review.

## Caveats (manage, don't ignore)

1. **Determinism module = the friction point.** Issue-first, framed as
   verification infrastructure for agents (his own thesis), never as
   playtesting replacement (explicitly disclaimed in his README).
2. **Horizon mismatch**: his cycle is days, ours is a quarter. Bugfix PRs
   smooth; design debates slow. Expect rework-by-maintainer as a possible
   outcome (precedents #13, #19→#22).
3. **No Mac.** macOS bugs are fixed blind from user reports (issue #24).
   We are plausibly his most motivated macOS tester — contribute macOS
   verification on every PR, it's cheap goodwill.
4. **Elicitation flow**: he treats gate irritations as client bugs and adds
   env workarounds (`GODOT_MCP_DISABLE_ELICITATION`, `GODOT_MCP_STRICT`)
   rather than restructuring. Our old backlog item is superseded — use
   STRICT in benchmark sandboxes.
