# Phase 11 — PR: Headless Layout/Viewport-Containment Check

Kind: PR (extension of `validate` or `get_ui_elements` family) · Status: not
started · Discovered: RallyWall run post-mortem (pootie win-screen bug)

## Importance to us: HIGH

- **Why (trace evidence):** the ONE real bug the 5.2h RallyWall run shipped
  with — WinScreen labels rendering off-screen (post-critique fix task) —
  was caught by luck-of-vision (pootie playing with a keyboard), not by
  any systematic gate. It survived: every invariant check, 19 screenshots
  analyzed by models, and the initial pootie critique pass. Yet the bug is
  statically computable: Control global rects are derivable from
  anchors/offsets/size at scene-load time, no game loop needed.
- **Impact area:** every UI overlay the swarm builds (game-over/win
  screens, HUDs, menus) — a recurring class, currently gated only by VLM
  attention on a screenshot.
- **Cost:** small-medium. Pure math over scene properties; headless.

## Proposal

Extend the existing `validate` tool (or add a `validate` mode) that, for
each scene:

1. Loads the scene headless (existing path)
2. Computes each Control/Node2D's global rect from its
   anchors/offsets/position/size (scene-local — no running game needed)
3. Flags:
   - nodes whose visible rect lies fully or mostly outside the designed
     viewport (`get_viewport_rect` equivalent / project settings resolution)
   - siblings sharing effectively identical overlapping rects (stacked
     duplicates — we also observed a doubled Background node in the final
     RallyWall tree)
   - controls with zero/minimal size that are expected visible (empty rect
     = invisible UI)
   - anchors inconsistent with layout_mode (the trace caught MCP-dropped
     `anchors_preset = 8` producing default-anchor mispositioning — this
     check would have caught THAT too, on the same feature, earlier the
     same day)

## Maintainer-fit notes

- Verification-not-playtesting: deterministic static check, squarely his
  "agent confirms its work" thesis
- Extends `validate` — no new tool; one more check in the existing report
- No new dependencies, no runtime needed (works on `.tscn` directly —
  cheap and headless-first)
- Anchor/offset math needs care per Control layout modes; that's the bulk
  of the implementation — keep v1 conservative (containment + identical-
  rect dupes only), report remaining classes as additive follow-ups
- tool-authoring.md: update `validate` docs entry; tool count unchanged

## Evidence for the issue

- The RallyWall win-screen bug: shipped through all gates, caught only by
  a vision model playing the game; the layout lint would have flagged it
  in seconds during scene creation
- The duplicate Background node observed in the same final tree
- The anchors-dropped-by-MCP incident (trace reasoning: "The MCP tool
  dropped `anchors_preset = 8`") — silent Resource/anchor coercion has a
  documented history (our PR #29 territory)

## Verification

- Unit tests: in-bounds control (clean), off-screen control (flagged),
  duplicate full-overlap (flagged), anchored-center control (clean)
- Live: re-check RallyWall's pre-fix WinScreen — must flag the exact bug
  pootie caught
