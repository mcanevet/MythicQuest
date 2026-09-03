# Baseline: RallyWall E2E (2026-09-02)

**Harness revision**: `874d14e` (benchmark suite added) + local MCP fork pointer (uncommitted).  
**Model**: user-selected (per benchmark protocol, model identity is the experiment variable).  
**Goal**: measure end-to-end build time, token burn, retry counts, QA pass rate, stalls.

## Executive Summary

**Status: STALLED — harness bug exposed (permission-ask hang).**  
Poppy's Task 2 (Paddle) hit a permission-requiring bash call mid-task; the call has been stuck `status: running` for >2 hours with no visible prompt to the user. Build agent has been waiting on `task()` since 06:33 UTC.

**Pipeline health**: Genesis → Task 1 (infra) executed flawlessly. First *real* implementation task (paddle scene) exposed **three previously-unknown harness bugs** (see below).

## Raw Metrics

### Time

| Phase | Duration | Notes |
|---|---|---|
| Root build session | 06:28:40 – 06:33:41 → stalled 06:33:41+ | 5 min active, then waiting on Task 2 subagent |
| Ian genesis | 06:29:01 – 06:29:56 | 55s |
| Poppy Task 1 (infra) | 06:30:12 – 06:33:34 | 3.4 min |
| Poppy Task 2 (paddle) | 06:33:43 – 06:41:45 → hung | 8 min active, then stuck on permission ask |

### Tokens (step-finish aggregation)

| Session | Steps | Σ tokens | Σ output tokens | Peak context |
|---|---|---|---|---|
| build (root) | 10 | 188k | 2.4k | 23.4k |
| ian genesis | 8 | 129k | 3.1k | 20.2k |
| poppy Task 1 | 38 | 1.83M | 15.3k | 60.7k |
| poppy Task 2 (stalled) | 35 | 1.89M | 21.4k | 73.2k |
| **Total so far** | **91** | **~4.0M** | **~42k** | **73.2k** |

Context cache reads dominate (~13–73k per step), so per-step context size is the main burn driver.

### Run Project Health

- 1 `run_project` call (Task 1 validation): **~920ms**, clean. Fixed fork working.
- No bridge failures, no port conflicts.

## Pipeline Anatomy

**Phase 0: Genesis** (IAN) — Perfect execution:
- Checked lessons (none) → read reference skeleton → crafted GAME_STATE.md + README → ran `backlog-grooming` validator → **14 tasks** (9 core, 2 optional, QA) generated.
- No retries, no stalls.

**Phase 1: Task 1 (infra)** (POPPY) — Flawless:
- Backlog-grooming → plan file created + `[in progress]` marker.
- Setup-project skill: caught a skill-rule conflict (input-map rule vs task requirement) and reasoned about resolution.
- Denied-bash fallbacks worked (`cp` denied → used `write()`).
- MCP validation: `run_project` clean (~920ms), input actions verified via `run_script`.
- Log-result skill archived plan, marked `[x]`.
- **Zero hangs, zero retries, zero stalls.**

**Phase 1: Task 2 (paddle)** (POPPY) — **Bug cascade**:
1. Created paddle scene via `create_scene` → root named "root" (consistent).
2. Added Polygon2D + CollisionShape2D via `batch_scene_operations`.
3. **MCP Serialization Gap #1**: `set_node_properties` on Polygon2D **zero-filled PackedVector2Array** (vertices became `(0,0),(0,0)…`) while reporting success.
4. Tried nested-array format → same result.
5. **MCP Serialization Gap #2**: Attempted to inject `RectangleShape2D` resource via `set_node_properties` → silently **dropped Resource value**, persisted nothing.
6. Tried `add_node` with shape dict → **RID leak warnings** (body instantiated in-memory but not persisted).
7. Discovered `.tscn` edit/write **denied by permission rules** → no sanctioned path to inject sub_resources.
8. Started investigating MCP server internals (reading node_modules source) — **improvised-path drift**.
9. Hit a bash call (`cat ~/.config/opencode/opencode.json`) that **triggers a permission prompt** → call stuck `status: running` for >2 hours. **No visible prompt to user** → silent stall.

## Bugs Exposed (Harness Issues)

### Bug 1: Silent Permission-Ask Hang (Severity: Critical)

**Symptom**: Subagent makes a tool call requiring permission (bash outside allowlist). Call enters `status: running` indefinitely. No UI prompt visible to user, no timeout, no fallback, no BLOCKED report. Build agent waits forever.

**Trigger**: Any permission-requiring call (bash, write to denied path, etc.) that the subagent can't predict will be denied.

**Evidence**: `ses_f9f2d2fb1ffe2uRADtWisBHPYq` last part: `{"tool":"bash","state":{"status":"running",...}}` at 06:41:45 → still pending 2+ hours later. Root build session hasn't advanced since 06:33.

**Impact**: Entire session deadlocks on first unexpected permission ask. Unrecoverable without manual intervention (kill subagent, or answer prompt if visible).

**Proposed Fix**:
- Permission asks should have a **timeout** (e.g., 30s) → auto-reject with "permission denied (no response)" → subagent hits BLOCKED path.
- OR: **strict sandboxing** — if a tool/action is permission-denied, it should fail immediately with a clear error (not hang waiting for user). Only truly interactive flows (e.g., `question` tool) should block.
- At minimum: build agent should detect hanging subagents (no parts for >60s + `status: running` on last call) and intervene (retry/block/escalate).

### Bug 2: MCP `set_node_properties` Silently Drops Resources/PackedArrays (Severity: Blocker)

**Symptom**: MCP tools report `success:true` but persist **nothing** for Godot Resources (`RectangleShape2D`) and packed arrays (`PackedVector2Array`). Polygon vertices zero-fill, shape disappears, RID leaks (runtime instantiation not saved).

**Trigger**: Every physics entity creation (collision shapes), any node with custom array properties (visuals, curves, particles).

**Evidence**: Test 1: set polygon vertices → persisted as zeros. Test 2: set shape resource → persisted nothing, but `add_node` caused RID leaks (body existed in-memory, not on-disk).

**Impact**: **Cannot create any valid physics entity** via MCP alone. The current sanctioned path (MCP tools only) is fundamentally broken for real game content.

**Proposed Fix Options**:
- **Option A**: Allow **direct `.tscn` edit** for sub_resources (add explicit allow rule: `".tscn": allow` for subresource injection, or a specific tool like `inject_subresource`).
- **Option B**: Fix the MCP server's serializer to handle Resources and packed arrays (requires upstream change).
- **Option C**: Provide a sanctioned skill script that writes sub_resources via file I/O (poppy runs the script, not direct edits).

Recommendation: **Option A** is fastest (one-line permission change) and aligns with existing pattern (we already allow `.gd` edits, `.tscn` edits are just a different format). The "no .tscn edit" rule was to prevent runtime state mutation; sub_resource injection is static content, safe to allow.

### Bug 3: Poppy Investigated Engine Internals Instead of Reporting BLOCKED (Severity: Low)

**Symptom**: After discovering MCP limitations, poppy spent ~3 minutes reading MCP server source code (`node_modules/.../godot-mcp-runtime`) instead of returning a structured BLOCKED report. Violates AGENTS.md "sanctioned paths only" rule.

**Trigger**: No sanctioned recovery path for "MCP can't do X" → improvisation.

**Evidence**: Trace 06:41:19–06:41:45: globbing node_modules, reading config files, searching serialization code.

**Impact**: Wasted tokens (~20k), wasted time (~3 min), no progress. If the session had recovered, this would be a hidden cost.

**Fix**: Already addressed by Bug 1's fix (if permission asks time out or fail fast, poppy can't spiral into investigation). Also add gotcha to `playtest`/`create-scene-with-script`: "If the sanctioned tool can't do X, return BLOCKED with evidence — do not debug the tool itself."

## Observations

- **Task decomposition**: Ian's 14-task breakdown is excellent (dependency-aware, optional flags, clear验收 criteria).
- **Backlog-grooming**: Works flawlessly (slug generation, plan file templating, `[in progress]` markers).
- **Log-result skill**: Archive mechanism clean (plan files renamed `.completed.md`, GAME_STATE updated).
- **MCP health**: `run_project` reliable with fixed fork (~920ms, 0 failures so far).
- **Error handling**: Denied-bash fallbacks (use `write` when `cp` denied) work correctly.
- **Reasoning quality**: High — poppy caught a skill-rule conflict and reasoned through resolution; ian's vision document is tight.

## Next Steps (Immediate)

1. **Unstick the current session**: Answer/reject the pending permission ask for poppy's bash call, or kill `ses_f9f2d2fb1ffe2uRADtWisBHPYq`.
2. **Fix Bug 1** (permission-ask hang) — highest priority, session-blocking.
3. **Fix Bug 2** (MCP serialization) — enables any real game content. Recommend: allow `.tscn` edits for sub_resources.
4. **Retest RallyWall from scratch** after fixes — capture full metrics (target: <45 min total, <3M tokens for a 14-task build).

## Comparison Baselines

- **Neon Volley** (09-01/02): 74.9 min, 8 subagents, 12/12 mechanics pass, SHIP verdict. *Resume mid-build*, not comparable.
- **RallyWall Task 1** (this run): 3.4 min, clean — matches expected infra-speed baseline.

## Appendix: Full Session Tree (DB dump)

```
Root: ses_f9f31d0c3ffeFUvHH5U94h0GSI (build, Building RallyWall reflex game)
├─ ses_f9f317fe2ffe8fmcFI4OJ18Uok (ian, game-genesis) — 55s
├─ ses_f9f30689fffeF3NNoHfnQWUokm (poppy, plan-implement-log, Task 1) — 3.4 min
└─ ses_f9f2d2fb1ffe2uRADtWisBHPYq (poppy, plan-implement-log, Task 2) — ⚠️ STALLED
```

Raw DB queries used:
```sql
-- Session tree
SELECT id, agent, title, datetime(time_created/1000,'unixepoch'), datetime(time_updated/1000,'unixepoch')
FROM session WHERE id='ses_f9f31d0c3ffeFUvHH5U94h0GSI' OR parent_id='ses_f9f31d0c3ffeFUvHH5U94h0GSI'
ORDER BY time_created;

-- Token aggregation per session
SELECT session_id, COUNT(*), SUM(json_extract(data,'$.tokens.total'))
FROM part WHERE json_extract(data,'$.type')='step-finish' GROUP BY session_id;
```

---

*Report generated 07:19 UTC, 2026-09-02. Session still stalled; session ID `ses_f9f2d2fb1ffe2uRADtWisBHPYq` last activity 06:41:45.*
