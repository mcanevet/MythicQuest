# Plugin Mount Contract

Plugins are swappable slots. Consumers choose one plugin per slot in
`mythic-quest.json` (project root) and mount the corresponding plugin
directory as a skill source in their consumer-root `opencode.json`. Both
files are consumer-owned — the `.opencode/` submodule is never written.

## Mount table

| Slot | `mythic-quest.json` key | `opencode.json` skills entry |
|---|---|---|
| Engine | `"engine": "<choice>"` | `.opencode/plugins/engine/<choice>` |
| Tracker | `"tracker": "<choice>"` | `.opencode/plugins/tracker/<choice>` |

A consumer-root `opencode.json` for the default choices:

```json
{
  "skills": [
    ".opencode/plugins/engine/godot",
    ".opencode/plugins/tracker/beads"
  ]
}
```

Rules:
- Exactly one choice per slot. Appending to an existing `skills` array is
  fine; replacing other entries is not.
- opencode concatenates `skills` arrays across config documents, so the
  consumer mount composes with the submodule's config untouched.
- Plugins are invoked via their stable skill names (`tracker`,
  `setup-project`, ...). Nothing outside `plugins/` may reference a
  plugin's internal tree in operational instructions — cross-plugin
  coordination goes through this contract.
- `setup-project` (or any bootstrap flow) writes both consumer files with
  defaults if absent, using this table.

## Slots

- `engine/` — engine-specific skills. Current: `godot`.
- `tracker/` — tracker backend adapters. Current: `beads`.
