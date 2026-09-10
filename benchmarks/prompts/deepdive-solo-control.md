# Control variant — DeepDive Solo (agent-swarm vs single-agent baseline)

**Status: DESIGN — do not run until run 14's record is complete and the
multiplier numbers are graded.** This is the control experiment for the
efficiency question: does the 5-role swarm (build orchestrator + poppy +
rachel + ian + pootie fanout, per-task session fanout, playbook ceremony)
buy proportionate reliability over ONE agent with the same toolset, or is
most of the 50-100x token multiplier orchestration tax?

Rationale (harness session, 2026-09-09, post run-14 trace analysis):
run 14 measured ~14M input + ~19M cache-read tokens, ~2.7h+, 23 sessions
for a ~40-task game. Waste classes identified in-trace (skill-reload
churn ~860 KB, stale-LSP noise in 95 tool results, per-file edit rounds,
session re-orientation) suggest a single agent with the SAME MCP tools and
validation discipline could land within 3-5x of one-shot cost while
retaining verified outcomes. This run puts a real number on that.

## Setup — what is held constant

Same game prompt as `deepdive.md` (identical text, including completion
criteria), same engine pin, same model. The ONLY variable is the agent
topology:

- **Swarm arm (= run 14, already done):** standard harness — root build
  agent delegates to poppy/rachel/ian/pootie subagents per phase/task.
- **Solo arm (this run):** one agent, no subagents, no `task()` fanout.
  It reads the same skills, uses the same MCP tools, runs the same QA
  scenarios and TestPlayer gauntlet — but is itself responsible for
  planning, implementation, QA probes, and self-critique in one session.

Solo-arm configuration (needed because the harness normally FORCES
delegation — build.md's anti-recursion guard requires every work item to
go through `task()`):
- Use a dedicated agent file (not build/poppy) with `mode: primary`,
  `task: deny` in its frontmatter — the denial enforces "no fanout"
  mechanically, same trick as poppy's bash deny.
- **Engine identity lives in the agent file, not the prompt.** The game
  prompt is genre-agnostic by design (never names Godot or tools), and
  the swarm derives engine binding from agent files + skills + the
  sandbox's `opencode.jsonc` (mounted godot-mcp-runtime MCP + LSP). The
  solo agent must do the same, explicitly: its instruction text states
  "implementation targets Godot 4.x via the mounted godot-mcp-runtime
  tools; all scene mutation goes through those tools; validation follows
  the skills' engine-specific scripts" and its permission block grants
  `godot-mcp-runtime_*`. Without this, engine choice becomes a soft
  variable — a solo agent that hand-rolls files instead of using the
  mounted tools would corrupt the arms comparison.
- Grant it the union of poppy+rachel permissions (implementation +
  QA/report paths), including `.tscn: deny` (MCP-only scene mutation,
  unchanged) and `skill: allow` for all five skills.
- Give it ONE prompt addition beyond the deepdive text: a compact
  protocol header telling it to work through the skills in order
  (setup-project → genesis-equivalent self-vision → backlog-grooming →
  create-scene-with-script per task → milestone smoke tests → playtest
  → log-result), and to alternate implement/verify roles itself rather
  than delegating. No multi-agent vocabulary, no disposition loop — it
  renders its own ship/rework verdict at the end.

## Measurements (both arms, from the session DB)

Primary:
1. **Token multiplier** — (input + cache-read) solo vs swarm, same
   prompt. Prediction: solo lands at 15-30% of swarm cost.
2. **Outcome parity** — grade BOTH games against the same checklist:
   the deepdive.md completion criteria (8 items) plus the 8
   pre-registered predictions' observable consequences (save-across-
   restart actually verified? interaction invariants covered? dominant
   strategy caught?). Outcome axis dominates per the objective triad —
   a cheaper solo run that ships a broken/unverified game is a
   regression-shaped result, NOT a win for solo.
3. **Wall-clock** and session count.

Secondary (efficiency-axis attribution):
4. Skill-reload churn per arm (solo can't dedupe across sessions it
   never leaves — does one big session beat 23 small ones even at
   worse cache locality?)
5. Validation-failure recovery shape — when the solo agent hits the
   same wedges (stale diagnostics, transport timeouts), does the
   playbook absence make it WORSE (unbounded loops) or fine (modern
   models self-regulate)? This is the reliability claim under test,
   not just cost.
6. Self-critique quality — solo renders its own verdict; compare
   against ian's disposition + pootie's critique for the same game.
   Prediction: solo under-critiques (misses dominant strategy), which
   is the swarm's best defense.

## Predictions (pre-registered)

1. Solo tokens: 15-30% of swarm (≈3-7M input+cache vs 33M).
2. Solo wall-clock: 40-60% of swarm (fewer session startups, no
   orchestrator round-trips) IF it doesn't wedge; one wedge without
   the bail-fast playbook erases the advantage.
3. Outcome parity: solo passes the completion checklist at roughly
   equal rate BUT prediction-2/3-shaped gaps (unverified interaction
   invariants, weaker persistence probing) surface more often —
   prediction: solo ships with ≥1 unverified coupled invariant that
   the swarm's rachel pass caught.
4. Dominant-strategy detection: swarm catches it (prediction 5 of
   deepdive); solo does not self-flag it — the strongest single data
   point either way.
5. Solo suffers ≥1 unbounded retry loop the swarm's Bounded Work
   Contract would have capped — visible as a >10x spike in one tool
   pattern (prediction from run-6/10 wedge history).

## Why this comparison is fair (and where it isn't)

Fair: same prompt, model, engine pin, skills, MCP tools, and completion
criteria; the QA gauntlet (TestPlayer scenarios + probes) is in the solo
arm too, so "verified" means the same thing on both arms.

Unfair bits to disclose in the record: (a) the swarm got today's
context-economy fixes mid-life (run 14 ran WITHOUT poppy.md's new
section 7 — it was written from run-14 traces); for parity, run the solo
arm with the same commit the swarm started from (aeee2be), NOT current
main; (b) solo benefits from one-session skill caching the swarm
structurally can't — that's intrinsic to the topology difference being
measured, not a confound; (c) n=1 per arm — this is an exploratory
control, directional only.

## Running it

After run 14 completes and its record grades the 8 predictions:
1. Prepare a fresh sandbox (benchmark-prep skill) pinned to commit
   aeee2be (the run-14 starting commit) so both arms see identical
   harness content.
2. Create the solo agent file (design above) in the HARNESS repo,
   commit, and mount it in the sandbox via the submodule pin.
3. Launch with the deepdive.md prompt text verbatim plus the protocol
   header; watch with the debug-harness watcher as usual.
4. Record as `benchmarks/results/<date>-deepdive-solo-lumo-max-*.md`
   with the arms-comparison table as the headline.
