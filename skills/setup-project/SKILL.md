---
name: setup-project
description: Create Godot 4.x project infrastructure using direct file creation. Use after genesis to set up project.godot, icon, and directory structure before any scene creation.
---

## What I do

Creates bare-minimum Godot 4.x project infrastructure by:
- Writing `project.godot` configuration file via `write` tool
- Adding placeholder `icon.svg` via `write` tool
- Setting up basic input actions if needed

**Note**: Directory structure (scenes/, scripts/, etc.) will be created automatically when files are written. No need to pre-create folders.

## Execution

### Step 1: Write project.godot

**Before writing:** check if `GAME_STATE.md` exists. If it does, read its first line — it has the format `# Game Title`. Use that title as `config/name`. If `GAME_STATE.md` doesn't exist yet, use `"Untitled Game"` as a placeholder.

Create `project.godot` with Godot 4.x format. Copy the template in [reference/project-godot-template.md](reference/project-godot-template.md) verbatim, substituting the game title for `config/name`. For `config/features`, discover the installed engine version first (engine project-info tooling, e.g. `get_project_info`) — never hardcode a guessed version.

### Step 2: Create Placeholder icon.svg

Minimal SVG placeholder:

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
  <rect width="128" height="128" fill="#444"/>
  <circle cx="64" cy="64" r="32" fill="#fff"/>
</svg>
```

### Step 3: Initialize .gitignore

Create `.gitignore` for Godot projects:

```gitignore
# Godot 4+ specific ignores
.godot/
export.cfg
.export/

# OS generated files
.DS_Store
Thumbs.db

# Optional: Hide asset source files
!*.svg
*.png
*.jpg
*.webm
```

### Step 3b: Create Test Harness Autoload

Create `scripts/test_player.gd` — a game-agnostic test framework autoload providing `start_test()`, `get_test_report()`, and bot implementations.

See [`scripts/test_player.gd`](scripts/test_player.gd) for the full implementation. Copy it verbatim to the game project's `scripts/test_player.gd`.

> **Project organization conventions** (file/dir names `snake_case`, node names `PascalCase`, third-party code in `addons/`, `.gdignore` for non-imported folders): consult `./.opencode/skills/create-scene-with-script/reference/godot-best-practices.md` §8. The scene/architecture practices (hierarchy, coupling, autoload discipline) live there too and apply to everything built after this step.

**API surface:**
- `start_test(scenario: Dictionary)` — begin a scenario (see schema doc below)
- `get_test_report()` — returns `{status, violations[], metrics, frame_count}`
- `finish_test()` — stop and release inputs

**Do NOT register as autoload yet** — that happens at playtest time via `godot-mcp-runtime:add_autoload()`. The file just needs to exist so it can be loaded at runtime.

**Schema documentation:** Consult [`reference/testing-patterns.md`](reference/testing-patterns.md) for the complete scenario config schema (all bot types, invariant rules, metrics).

**Game-specific mechanic coverage:** Rather than a separate generation step, each interactive entity gets its own `tests/scenarios/<entity_name>.json` invariant config authored directly by the implementing agent during `create-scene-with-script` (see that skill's Step 5c) — using real knowledge of the entity's actual node paths and behavior, not inference from task titles after the fact. `playtest`'s `functional` mode aggregates all `tests/scenarios/*.json` files alongside the generic baseline invariants (see `./.opencode/skills/playtest/SKILL.md`).

### Step 4: Validate

Run validation (mandatory):

```bash
./.opencode/skills/setup-project/scripts/validate.sh
```

Run from the project root. Exit code must be 0 before declaring success.

---

## Critical Rules

1. **Godot 4.x format** — Use `config_version=5` and correct section names
2. **Main scene set** — Configure `run/main_scene` before first run
3. **Window size defined** — Set viewport dimensions early
4. **Input map if needed** — Define actions before creating scripts that use them
5. **Validate immediately** — Test project loads after creation
6. **Execute without questions** — Follow minimal viable structure
7. **Don't pre-create directories** — Let filesystem handle automatic folder creation when files are written
8. **No default input actions** — Never pre-define `[input]` actions in `project.godot`. Leave the section empty with a comment. The first implementation task owns the input map and adds game-specific actions based on `GAME_STATE.md`.

---
*Project scaffolding. Creates foundation for Godot 4.x development.*
