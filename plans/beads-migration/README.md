# Beads Migration: MythicQuest task tracking on bd (beads)

Decision (2026-09-13, user-approved): migrate MythicQuest's game-build task
tracking from `GAME_STATE.md` markdown to bd (beads), for BOTH arms (swarm +
solo), dropping GAME_STATE.md entirely (no mirror), with markdown-mode skills
deleted after the Phase-4 benchmark passes.

Why: bd natively provides what GAME_STATE.md hand-rolls — atomic claims
(eliminates the parallel-delegation pre-claiming race), dependency-gated
readiness (the four loops' task queue), discovered-from provenance, audit
history per issue, and JSON output sized for agent context windows. The
orchestration policy (cadences, caps, verdicts) stays in MythicQuest
formulas/skills per beads' project charter — beads is the graph engine, not
the orchestrator.

## Phase 0 — Spike (COMPLETE, 2026-09-13)

Sandbox: `/private/tmp/opencode/beads-spike` (bd 1.2.2, embedded Dolt,
`bd init --stealth`, prefix rq). Results:

| Capability | Result |
|---|---|
| Four-loop mechanics | ✅ claim→close→dependent-promoted-to-ready; gate create/resolve blocks/unblocks tasks; `create --deps discovered-from:<id>` files bug beads with provenance |
| Atomic claims | ✅ racing claimant rejected with clear error (`already claimed by`) |
| Payload bounds | ✅ `ready --json` 1.8 KB @ 7 beads (~5–8 KB projected @ 40); `show` 600 B; `list` 3.8 KB |
| Audit channel | ✅ `bd history <id> --json`; `bd export --all` one-call snapshot. NOTE: `bd events tail` does NOT exist in 1.2.2 — the journal surface is HTTP-API/`bd history` |
| Formula pour | ⚠️ works (`.beads/formulas/*.formula.toml`, `bd mol pour` → epic + steps + id_mapping) but step-level `depends_on` did not appear as graph blocks edges — Phase 2 must verify whether genesis wires deps itself via `bd dep add` |
| Claim pools | ⚠️ `--actor pool:...` accepted but assignee resolution came from git identity; pool config (`claim.pools`) belongs in setup-project |
| `bd unclaim` | ❌ absent in 1.2.2 (upstream proposal bd-zccb9/#4727 lineage); fallback `bd update --assignee "" --status open` works |

## Phase 1 — Permission profiles (COMPLETE, 2026-09-13)

Per-agent `bd` verb allowlists in frontmatter bash sections; enforced by new
lint registry rule `bd-verb-surface` (check `bd_verb_surface`, tripwire +
LLM review). Convention: unset verb = deny; absence IS the policy.

| Agent | Profile | Has | Never |
|---|---|---|---|
| poppy | implementer | read, claim/unclaim/update, close, create, dep add/remove, note/comment, history | gate verbs |
| rachel | QA read+file | read, create (bugs), dep add, note/comment | claim/close/update/gate |
| ian | vision director | read, create, dep add, note/comment, ALL gate verbs | claim/close dev tasks |
| pootie | code-blind critic | read-only (ready/show/list/prime) | everything mutating |
| build | orchestrator | read, gate list/show/check/resolve, count/stats | claim/close/create/update |
| solo | solo control | implementer + QA-filing surface | gate verbs (ship decision stays outside the arm) |

## Phase 2 — Skill ports (COMPLETE, 2026-09-13)

Shared helper: `skills/genesis/scripts/bd_ledger.sh` — the single sanctioned
bd entrypoint (symlinked into backlog-grooming, log-result, setup-project,
playtest scripts/). Subcommands: init, ready (filters gates/human beads),
claim (atomic), close, create_task, file_finding (discovered-from provenance),
plan_link, attempts/bump_attempts (retry counter in metadata), show, backup,
complete_check. Validated end-to-end in a sandbox (claim conflicts, dep
promotion on close, metadata round-trip, backup export).

- genesis → `bd_ledger.sh init` + VISION.md + `create_task` beads (labels
  core/optional/future, P0 loop tasks); validator now checks ledger + ≥10
  labeled task beads + VISION.md + README.
- setup-project → reads title from VISION.md; ensures `bd_ledger.sh init`.
- backlog-grooming → `ready` JSON → (priority, creation) selection → ATOMIC
  `claim` FIRST → plan at `plans/<bead-id>-<slug>.md` (slug.sh now keys by
  bead id) → `plan_link` metadata. Parallel pre-claiming protocol DELETED —
  atomic claim makes it unnecessary (build.md updated accordingly).
- log-result → archive plan → `close` (dependents auto-promoted to ready) →
  validate (bead closed, no stray in_progress) → `backup` snapshot. Validators
  rewritten for ledger state; batched-delegation in_progress allowance kept.
- playtest → one-time-mode findings additionally filed as beads
  (`file_finding`); per-task FAILs stay inline to poppy. full-modes.md now
  reads VISION.md + `bd list --status closed`.
- create-scene-with-script → plan file recovered from bead `plan=` metadata.
- build.md → all four loops, phases 0-3, retry/circuit-breaker, decomposition
  (child beads `--parent`), completion report, and the parallel-delegation
  protocol rewritten for the ledger. SKIP_CONSUMER_LOOP is now a flag FILE
  (ledger has no free-text declarations).
- Agent frontmatter write surfaces: GAME_STATE.md allow → VISION.md allow
  (build, ian, solo); poppy's queue-write grant dropped (ledger verbs cover it).
- build's bd profile extended with `create`/`dep add` (append authority
  mirrors its old append-to-queue duty; still no claim/close).
- solo.md, rachel.md, ian.md body refs migrated; README.md + AGENTS.md
  pipeline docs migrated; debug-harness failure-modes/SKILL updated.
- task-grammar.md replaced by bead-conventions doc (fields, loop labels,
  discovered-from, attempts metadata, SKIP_CONSUMER_LOOP flag file).

GAME_STATE.md string-parsing tooling (grep grammars, checkbox flips,
attempt-line markers) removed everywhere; ledger queries replace them.

## Phase 3 — Declarative orchestration (COMPLETE, 2026-09-13)

Decision: **procedural gates** (not formula-poured) — release flow is
verdict-driven, not a static DAG; poured steps would pollute the dev loop's
ready queue as claimable task beads.

Spike confirmations (bd 1.2.2):
- `bd gate create --blocks <id> --type human -r <reason>` suppresses the
  blocked bead from `ready`; `bd gate resolve <id>` / `bd close <id>` releases.
- Gates ARE beads (issue_type gate), but `ready` excludes them natively.
- `bd create` has NO `--set-metadata` (bd update does) — two-step tagging.

Implemented:
- `bd_ledger.sh` gained `gate_create`, `gate_close`, `gate_list`,
  `release_entry` (creates release bead `label: release` + qa/vision/consumer
  gate chain, prints `RID G1 G2 G3`), and `complete_check` now EXCLUDES
  `release`-labeled beads (re-entry fix: a reworked Phase 3 isn't wedged by
  its own open release bead — validated in sandbox).
- build.md Phase 3 rewritten around the Release-Gate Chain: entry protocol
  (check `gate_list` first, never stack chains), verdict→gate_close mapping,
  FAIL leaves the gate unresolved, ship = all gates closed + release bead
  closed. SKIP_CONSUMER_LOOP = flag file → resolve G3 with skip reason.
- Vision halt: on `drifted`, build gates remaining FEATURE beads with
  `vision-halt` gates (bug beads stay ungated); resolved on Ian's re-check
  `aligned`.
- Rework-cycle cap (2): critique beads tagged `rework_cycle=<n>` via
  `bd update --set-metadata`; second cycle files a BLOCKED bead, consumer
  gate left unresolved.
- build frontmatter: added `*scripts/*.sh*`/`*scripts/*.py*` allows (the body
  relied on bd_ledger.sh via "skill-script bash allows" that didn't exist —
  real permission hole closed).

Full protocol simulated in sandbox: release entry → QA close → vision-drift
halt/unhalt → vision close → rework-cycle tagging → taste-divergence BLOCKED →
fixes + re-entry (complete_check correctly 0) → CONFIRM_SHIP → release closed.
Lint + registry audit clean.

## Phase 4 — Benchmark gate (NEXT)

Fresh baseline BOTH arms on rallywall: markdown-before vs beads-after,
objective triad (outcome first, then wall-clock, then tokens incl. bd JSON
overhead). Track: claim-race incidents (expect zero), retry loops,
stall-diagnosis time. Decision gate: no outcome regression; ≤10% token
regression acceptable iff wall-clock improves or claim races eliminated.
On pass: delete markdown-mode skill code; record new baseline. On fail:
postmortem via `bd history`, salvage gates/claims even if migration reverts.

## Open risks

## Open risks

- ~~Formula step-dep wiring semantics~~ — resolved by the procedural-gates
  decision (Phase 3): no poured formula, genesis owns task deps via create_task.
- `bd unclaim` missing in 1.2.2 — either pin bd to a release with it or keep
  the `update --assignee ""` fallback in skills (cite upstream status).
- Subagent token cost of polling `bd ready --json` — measured acceptable at
  spike scale; re-measured in Phase 4.
- Benchmark comparability breaks with all prior baselines — accepted; new
  baseline mandatory before any model comparison.
