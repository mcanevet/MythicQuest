# Phase 9 — PR: Background-Mode Frame-Rate Contract (macOS throttle fix or honest documentation)

Kind: investigation, then bugfix PR and/or docs change · Status: not
started · Discovered: 2026-09-05 GLM-run trace analysis

## Importance to us: HIGH (silent evidence corruption)

- **Why (trace evidence):** with `run_project(background=true)` on macOS,
  off-screen windows get severely frame-throttled. Observed:
  - Physics advancing ≤0.133s of sim per wall-second → a 15s scenario took
    minutes of wall clock; agent burned 324s in `bash sleep` loops just
    waiting for sim time that arrived arbitrarily late
  - **Incoherent QA evidence**: the playtest report simultaneously showed
    `frame_ms_p99: 21ms` in metrics AND violations citing frame times of
    **55,297ms** and **67,296ms** (first ~100 frames of a scenario, right
    after engine-resume spikes / throttle gaps). The agent spent multiple
    long reasoning chains diagnosing which number to believe ("p99
    incoherent", re-ran the scenario twice to chase the phantom violations)
  - Frames ran at ~6.8ms/frame when visible-foreground earlier in the same
    run — same machine, same scene
- **Impact area:** every background-mode runtime test on macOS — i.e., our
  default benchmark configuration. Doubles as the biggest
  wall-clock-efficiency leak (throttled sims stretch every scenario).
- **Cost:** unknown until root-cause — could be one Godot windowing flag.

## Approach

1. **Reproduce & isolate** (harness-side first, macOS, his blind spot):
   - Godot only delivers "can't draw" for off-screen windows on macOS
     (issue #24 precedent — same platform family). His #24 fix forced a
     draw; throttling is plausibly the sibling: `window.can_draw` false →
     low-power mode, or `DisplayServer` mac-specific frame pacing.
   - Candidate flags to test in order: `Engine.max_fps` interplay,
     `window.mouse_passthrough`/`unfocusable` combos from his background
     implementation, `OS.low_processor_usage_mode` (off by default?), and
     forcing `RenderingServer.force_draw()` on a timer if `can_draw` is
     false. ALSO: does `background=false` fix it (visible window, just
     annoying)?
2. **Fix if feasible** (likely: force periodic draw or set
   `DISPLAYSERVER`-level pacing when backgrounded on macOS) — PR with the
   reproduction harness, macOS-verified (we are his macOS tester — he
   cannot reproduce this class at all)
3. **If unfixable cleanly:** at minimum surface it honestly —
   `run_project(background=true)` response or docs stating the macOS frame
   budget implication, and document that wall-clock timing assertions are
   invalid in background mode on macOS (protects every future consumer of
   frame-time evidence)
4. Separate but adjacent: frame-time **warm-up exclusion** — first ~100
   frames after resume carry resume-spike times that pollute invariant
   math (observed in trace even at healthy p99). Consider a bridge-side
   or skill-side warm-up discard window. Cheap fix, big evidence-quality
   win. Could ride this PR or Phase 2's ring buffer (timestamped entries
   make the gap visible).

## Maintainer-fit notes

- This is a **bug in a feature he shipped for us** (background mode,
  v2.1.0, issue #3) — bugfix-framing is perfect, macOS evidence is
  something he actively needs from users (issue #24 precedent)
- If the fix is a Godot-side quirk requiring an ugly workaround, present
  the honest-docs fallback in the same PR — he values honest limitations
  (security.md culture)

## Verification

- macOS repro script: background project, sample
  `Engine.get_frames_drawn()` per wall-second for 30s before/after fix
- Trace-derived e2e: re-run the traced scenario config; confirm sim
  advances at ≥0.9s sim/s per wall-second and no 4+-digit frame times in
  fresh samples
