# Phase 8 — Issue + PR: Async Job Model for `run_script` (`submit` + poll)

Kind: issue-first, then PR · Status: not started · Discovered: 2026-09-05
GLM-run trace analysis

## Importance to us: HIGH

- **Why (trace evidence):**
  1. **Timed-out scripts keep spinning in-engine.** One probe script looped
     forever; after its 30s MCP timeout the next script appeared to queue
     behind the zombie ("run_script slots were stuck"). Worse: a runaway
     `while true` script keeps consuming frames and mutating the game under
     test — corrupting subsequent probes silently (the agent observed
     state changes it didn't cause and had to reason about "why is the ball
     already out?" — twice).
  2. **Long-running test awaits fight the MCP timeout.** Median run_script
     0s, but scenario/probe scripts legitimately run 20–70s (max 70.3s).
     Today the caller passes `timeout` and prays; 2 of the traced errors
     were pure 30s/45s timeouts on otherwise-working scripts.
  3. Agents compensate with `bash sleep` between polls — 324s of pure
     sleeping in one session.
- **Impact area:** all harness-side playtest/QA orchestration (Phase 3's
  step_until runs in the same danger zone).
- **Cost:** medium — needs bridge-side job registry.

## Proposal sketch

- `run_script` gains a mode: submit-and-return-job-id when the caller opts
  in (or transparently when a call times out, so the zombie becomes
  observable instead of invisible)
- `job_status`/`get_debug_output`-adjacent surface: job state (running/
  done/error), elapsed, result or error, and **cancel**
- Cancel must work even if the script is in an infinite loop (flag checked
  by a physics-frame watchdog, or SceneTree quit-guard; needs careful
  design — a looping GDScript coroutine doesn't yield to the bridge unless
  it awaits; a frame-hooked watchdog flag is the workable pattern)
- Heartbeat interaction: our merged PR #30 progress heartbeat should feed
  job progress, not client-side timeout guesses

## Maintainer-fit notes

- Danger zone: this smells like "workflow orchestration", which leans
  against lean-tool taste. Framing:
  - it is *resource safety* (zombie scripts corrupt game state under test
    — an evidence-integrity problem, his own "agents check their work"
    thesis)
  - audit first: grep how the bridge currently guards concurrent
    evaluateScript calls (may already serialize — then the zombie-hang
    observation needs re-verification; the trace suggested queueing but
    we should prove it before claiming it)
  - smallest acceptable version: just `cancel_running_script` — kills the
    zombie class outright with one boolean tool. Consider leading with that.
- Alternative that avoids upstream entirely: make ALL harness playtest
  scripts self-terminating by convention (skill-side rule) — already partly
  true; the residual risk is agent-authored probe scripts (exactly what
  died here), which is why upstream is the right home.

## Verification

- Regression: submit infinite-loop script, cancel it, submit another,
  confirm it runs and returns (serial, unblocked)
- Trace-derived e2e: the stuck-loop scenario from the GLM run, replayed
