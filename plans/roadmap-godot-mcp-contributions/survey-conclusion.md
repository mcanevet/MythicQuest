# Survey Conclusion: Godot MCP Landscape (2026-09-05)

Method: own deep research + 3 blind model reviews (Claude/Gemini/ChatGPT) with
project-agnostic prompts, two rounds:

- Round 1: "best off-the-shelf server for the use case"
- Round 2: "best base to contribute to — architecture is a disqualifier,
  missing features are PRs"

Round 1 split (enhanced vs runtime); round 2 was unanimous for godot-mcp-runtime.
Our final decision adopted the round-2 framing (we contribute anyway).

## Verdict table

| Project | ★ | Verdict |
|---|---|---|
| Erodenn/godot-mcp-runtime | ~60 | **Winner** (current base) |
| wgt19861219/godot-mcp-enhanced | 92 | Strongest verification features (deterministic playtest, QA suites, frame-verify); rejected under architecture-first framing: Chinese tool schemas (context cost), single maintainer at extreme cadence, QA tooling mutates test projects, determinism verified only on toy fixtures (seed covers global randi/randf only; snapshots property-only), silent-success/exit-code bugs as recent as v0.32.11. Its verification layer is what we want to *own* upstream, not inherit |
| tugcantopaloglu/godot-mcp | 446 | Best `validate_script` (autoload-aware, line numbers) + deepest `game_eval`/await; rejected: fixed port 9090, no batching, no CI on GDScript side, untrimmable 157-tool schema, zero external-PR evidence |
| beremaran/godot-agent-loop | ~2 | Best engineering culture (real Godot e2e CI, golden-agent acceptance, honest reversals); rejected: display required for runtime/screenshot paths + optional editor architecture. Design reference only |
| Coding-Solo/godot-mcp | 5.5k | Common ancestor; no runtime bridge at all — disqualified |
| hi-godot/godot-ai | 2.1k | Editor-attached — disqualified |
| satelliteoflove/godot-mcp | 105 | Excellent deterministic-playtest ideas; editor-addon architecture — disqualified, but its freeze/step/digest model is the blueprint for Phase 3 |
| NPGameDev/godot-mcp-toolkit | ? | Best CI (479 e2e cases, 4.2–4.7 matrix, token budgeting); editor-plugin — disqualified |
| aivarsliepa/godot-mcp, Vollkorn-Games/godot-mcp | 0–2 | Architectural twins of runtime with weaker history — evidence transient injection is the natural pattern |

## Deciding factors (unanimous, round 2)

- Transient, zero-footprint bridge (autoload injected per-run, cleaned up)
- Headless-first (no editor process, no display dependency)
- Automatic free-port selection (multi-instance / parallel-session safe)
- `run_script` arbitrary GDScript eval with `await` — architectural insurance:
  most missing runtime features are expressible through this hatch
- Modular codebase where missing features slot in as new tool groups
- Proven merge relationship (ours: #28 merged → v3.2.3; johanravn: 6 merged PRs)

## Bias note

The prompts' hard requirements (headless-first, transient bridge, eval hatch)
were derived from real failure modes in our 7 benchmark runs, not from wanting
runtime to win — but requirement-setting is inherently authored by us.
Mitigation: the features those runs proved we need but runtime lacks
(determinism, degenerate detection, validation quality) are exactly what the
roadmap contributes.

## Techniques to mine from other projects (phase inputs)

- tugcantopaloglu: SceneTree-at-`_initialize` validation; `game_eval` await semantics
- enhanced: `since_seq` ring buffer; freeze/step/step_until; 32×32 grayscale
  cosine-similarity frame-verify; avoid-randi-for-port-randomization detail
- satelliteoflove: frozen-clock stepping model (docs sufficient to port concept)
- beremaran: evidence/correlated-diagnostics schema design
