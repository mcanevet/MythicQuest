---
name: apply-material
description: Generate and assign a procedural material or shader to an existing visual node in a scene. Use when a task has created mesh/visual entities (scene-creation skill output) and the visual layer needs real materials — standard-engine PBR material setups or custom shader files for procedural textures. Executed by art-focused builders.
---

## What this skill does

Applies the visual layer to implemented entities: chooses, generates, and
assigns materials — standard PBR configurations for simple surfaces,
procedural `.gdshader` files when a surface needs generated texture or
animated effects. Fully self-generated output; no external asset
dependency (CC0 sourcing only when the delegation explicitly enables the
fallback flag).

Input: a node/mesh reference (scene path + node path) from the current
task, plus the entity's visual identity from the delegation brief and
`GAME_STATE.md`'s art-style charter.

## Execution

### Step 0: Locate the target node (MANDATORY)

Call `godot-mcp-runtime:get_scene_tree(scenePath=<scene>)` and confirm the
briefed node path exists. If the node is absent: report
`⛔ BLOCKED: node <path> not found in <scene> — verify the brief or ask
the orchestrator to re-check` and stop. Never guess node names; if the
brief omits the path, find candidate visual nodes (MeshInstance3D,
Sprite2D, Polygon2D, Mesh nodes) in the tree and report them back asking
for disambiguation.

Read current properties (`get_node_properties`) for any node you'll touch —
know what's there before changing it.

### Step 1: Decide the material class (surface-type inference)

Infer the surface type from the entity name, the brief, and the charter's
art style, then choose the LIGHTEST approach that meets the look:

| Surface type | Typical entities | First choice |
|---|---|---|
| terrain/environment | ground, walls, platforms, rock, wood | custom `.gdshader` (noise-based procedural texture) if visual richness demanded; else StandardMaterial3D |
| character | player, enemies, NPCs | StandardMaterial3D (PBR params) or vertex-colored look |
| prop/digit | pickups, obstacles, decorations | StandardMaterial3D (solid PBR + emission tint for interactables) |
| hazard/energy | lava, spikes, power cores, lasers | `.gdshader` or StandardMaterial3D with animated/pulsing emission |
| UI/background | menus, HUD chrome, skyboxes | GradientTexture or flat StandardMaterial3D — rarely shader work |

**Decision rule: don't force a custom shader.** A StandardMaterial3D with
the right albedo/roughness/metallic/emission parameters satisfies most
surfaces and carries zero shader-compile risk. Custom shaders are for
when standard parameters demonstrably can't produce the look: procedural
noise texture (rock grain, wood, moss), animated effects (flowing,
pulsing, scrolling), or stylized non-PBR looks. When in doubt, standard
first.

### Step 2: Write the material

#### 2a. StandardMaterial3D (no shader file)

Assign directly through the engine MCP tools with inline Resource
construction (`set_node_properties` / `batch_scene_operations`; see
`skills/create-scene-with-script/reference/mcp-patterns.md` Step 5a
patterns — same typed-dict construction):

```
material: {type: "StandardMaterial3D", albedo_color: {r,g,b,a},
           roughness: 0.8, metallic: 0.0,
           emission_enabled: true, emission: {r,g,b,a}, emission_energy_multiplier: 1.5}
```

Tune PBR values for the surface's material identity: metal (metallic ~1.0,
low roughness), stone (metallic 0, roughness ~0.9), plastic/coating
(roughness 0.3–0.5), glow (emission with modest multiplier — bright
enough to read, not bloom-blown).

#### 2b. Custom .gdshader

Write the shader to `shaders/<descriptive_name>.gdshader` (naming and
location follow project conventions — `CONVENTIONS.md` if present).
Requirements:

- Correct `shader_type spatial;` (3D) or `shader_type canvas_item;` (2D)
- Engine noise built-ins or self-defined hash/value-noise helpers — no
  external texture uniforms unless a procedural texture is also generated
  and assigned
- Declare uniforms with sensible defaults (`uniform vec3 albedo : source_color = vec3(0.5);`) so the material renders meaningfully even with zero uniform configuration
- Respect the target's dimensionality: canvas_item shaders use `UV`/`COLOR`/`TEXTURE_PIXEL_SIZE`; spatial shaders use `UV`, `NORMAL`, `VERTEX` — mixing the vocabularies is a compile error or a silent no-op
- Keep it performant: per-fragment noise math should stay cheap (a few
  octaves, no loops over 8 iterations) — this runs every frame on every
  covered pixel

Then assign through the MCP tools:

```
material: {type: "ShaderMaterial", shader: {type: "Shader", code: "<load via res:// path>"}}
```

Where practical, prefer assigning the shader by reference:
`{type: "ShaderMaterial", shader: <res://shaders/<name>.gdshader via the path form supported by the tools>}` — consult mcp-patterns.md's Resource-forms section for the exact accepted forms (typed dict vs `res://` path); if neither form expresses shader-by-reference, inline the `code` property in the typed dict (the Shader resource carries source inline).

#### 2c. Shared material resources

Prefer the inline typed-dict construction (2a/2b) — it assigns atomically
and cannot orphan. If the same material must be shared across several
nodes/scenes, construct it once as a saved resource and reference it via
its `res://` path on each node (the path form the tools accept for
pre-existing resources). An orphaned resource file (written, never
referenced by any node) is a defect — see Gotchas.

### Step 3: Validate (MANDATORY)

1. `godot-mcp-runtime:validate(projectPath, targets=[<scene>])` — the
   scene must validate after assignment. If `valid: false`, fix and
   re-validate (max 3 attempts, then degrade per Step 5).
2. For `.gdshader` files: the scene validation catches reference errors,
   but shader compile errors surface at RUN time — after `run_project`,
   check `godot-mcp-runtime:get_debug_output()` for shader compile errors
   (`SHADER ERROR`, `Cannot compile`) before judging the look.

### Step 4: Verify visually (MANDATORY)

1. `godot-mcp-runtime:run_project` (background) → wait a moment
2. `godot-mcp-runtime:take_screenshot` → `read()` the screenshot
3. Assess against the brief: does the material read as its intended
   surface identity? Is it distinguishable from neighbors? Aligned with
   the charter's art style?
4. `godot-mcp-runtime:stop_project` when done.

**Assigned-ness check (mandatory):** re-read
`get_node_properties(<node>)` after assignment — the `material` property
must show your material (non-null, expected type). A resource that
validates but isn't on the node is NOT done.

### Step 5: Outcome paths

- **Success:** material assigned, validated, renders correctly → report
  verdict + files touched (+ report path if a report was written).
- **Fell short but functional:** working material in place, look below
  the charter → file a follow-up issue (see Tracker Integration below),
  keep the working material, report the deferral explicitly.
- **Failed after 3 attempts:** graceful degradation — leave/restore a
  default (StandardMaterial3D with a reasonable flat color for the
  surface type), file the follow-up issue, report. NEVER leave a task
  blocked on shader generation; the dev loop continues.

## Tracker Integration (filing follow-ups)

When a pass falls short (flat look, missing animation, wrong feel), file a
`material`-type issue via the **tracker** skill (bd allowlist carries the
`-t material` create pattern):

```bash
bd create --silent "<one-line gap, e.g. Grass shader reads flat — needs wind animation>" -t material -d "<node path + scene, what was applied, what's missing, suggestion for the follow-up pass>" -l reporter:<agent> --actor <agent>
```

The actor/reporter identity is supplied by the calling role (not assumed).
Follow-ups are filed as issues — never edited into an existing comment
thread; the issue is the durable record.

## Critical Rules

1. **MCP tools only for assignment** — `.tscn` is denied; all scene
   mutation goes through `set_node_properties`/
   `batch_scene_operations`. A tool-inexpressible operation is a
   `⛔ BLOCKED` report, never a hand-edit.
2. **Assigned ≠ done; rendered = done** — material on the node, scene
   validates, screenshot shows the look. All three.
3. **Degrade, never block** — default material + `material:N` follow-up
   beats a stalled dev loop. Report the degradation; don't hide it.
4. **No external assets unless the delegation explicitly enables the
   CC0 fallback flag** — default path is fully procedural.
5. **Max 3 attempts per material**, then Step 5's degradation path.
6. **Never modify node structure, scripts, or signals** — you paint
   existing nodes; you don't build or rewire them.
7. **One bash invocation per command** — no compounds (allowlist denies
   them); no exploratory bash at all (glob/read/grep instead).

## Known Gotchas (verify each before reporting done)

- **Wrong shader-type vocabulary:** `canvas_item` shaders using spatial
  varyings (or vice versa) — compile error or silent no-op. Match the
  shader_type to the node family (Sprite2D/Polygon2D → canvas_item;
  MeshInstance3D → spatial).
- **Orphaned material:** a beautiful `.tres`/`.gdshader` that no node
  references renders nothing and validates fine — the assigned-ness
  check (Step 4) exists to catch this. Orphan files created while
  iterating must be deleted before reporting done.
- **Emission without `emission_enabled`:** setting `emission` color alone
  does nothing — the enabled flag is separate from the color.
- **Uniform defaults missing:** a shader whose uniforms lack defaults
  renders black/white when the ShaderMaterial sets none — always default
  uniforms in the shader source.
- **Texture channels need import:** if you build a procedural texture
  file and reference it by path, it must be imported first (same
  fresh-project rule as sprites — see create-scene-with-script Step 5a).
  The default path (pure shader code, no texture files) avoids this
  entirely.
- **Never save/edit scenes during a live run** — stop the project before
  mutating scene properties (live sessions serialize runtime state).
- **render_priority/transparency:** materials on overlapping transparent
  surfaces (glows, glass) sort by `render_priority`; forgetting it on a
  layered effect produces z-fighting flicker. Set it when stacking
  transparency.

## Success Criteria

- [ ] Material assigned to the target node (confirmed via `get_node_properties`)
- [ ] Scene validates (`godot-mcp-runtime:validate` → valid)
- [ ] No shader compile errors in `get_debug_output` after running
- [ ] Screenshot shows the intended surface identity
- [ ] Any fallen-short looks filed as `material:N` follow-up issues
- [ ] No orphaned material files left in the tree

---
*Art-layer skill. Conventions (node identification, validation, engine
tool patterns): `skills/create-scene-with-script/reference/mcp-patterns.md`.
Actor identity is supplied by the caller; graceful degradation is encoded
here, role choreography belongs to the orchestrator.*
