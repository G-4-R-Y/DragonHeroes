# genforge/ — the lore-grounded content generation service

GenForge turns the weekly-content treadmill into a factory: grounded in the **world
bible** (`lore/`) and the active **season theme** (`seasons/`), it generates *candidate*
creatures, items, and skills — 64-bit-style sprite sheets + animation frames (image
generation through the style-locked pipeline of [docs/design/17 §5](../docs/design/17-art-direction.md))
and schema-conforming JSON metadata: stats, effects, descriptions, mechanics (text
generation constrained by [content/schemas/](../content/schemas/)).

```
lore + season theme + request
        │
        ▼
  text-gen ──► definition.json (schema-constrained: stats/effects/mechanics/description)
  image-gen ─► sprites/ (style-locked, palette-quantized, archetype-rig conditioned)
        │
        ▼
  candidate bundle (+ provenance.json: prompts, model versions, lore refs)
        │
        ▼  MANDATORY GATES — nothing generated ships ungated
  human curation → tools/validate_content.py gauntlet → balance lints
        → RL exploit-finder pass (docs/tech/25) → content/drops/<week>/
```

## The v0 pipeline (implemented): parts sheet → skeleton → baked frames

The image half runs today, end to end, in `pipeline/` + `service/`. The approach:
**one image-generation call produces a PARTS SHEET per entity** — like a professional
concept parts sheet: head/torso/arms/legs/cape/weapon for humanoids;
head/neck/body/wings/legs/tail segments for dragons; plus VFX strips. A
**programmatic skeleton pipeline** then rigs those parts onto per-archetype 2D bone
hierarchies, poses them through reusable animation libraries (stepped keys, no
interpolation), and **bakes plain frame strips** — no video generation anywhere.

```
request ──► provider.generate_parts() ──► parts.png + parts.json   (ONE image call)
                                              │
     skeletons/<archetype>.json  ─┐           ▼
     poses/<archetype>.json      ─┴──► assemble.Assembler ──► strips/<anim>.png
                                                              sheet.png
                                                              atlas.json  (Godot-ready)
```

| Module | Role |
|---|---|
| `pipeline/manifest.py` | The **parts-sheet contract**: PNG + `parts.json` mapping named parts to `{rect, pivot, angle_hint}` regions. Schema: `pipeline/schemas/parts_manifest.schema.json`. |
| `pipeline/skeletons.py` + `skeletons/*.json` | Per-archetype bone hierarchies as data: parent, attach offset, default rotation, z-order. `humanoid` and `dragon` shipped. |
| `pipeline/poses.py` + `poses/*.json` | Reusable animation libraries: named animations as frame lists of per-bone `{rotation_deg, offset}` stepped keys. Written once per archetype, reused by **every** entity on that skeleton. |
| `pipeline/assemble.py` | The baker: FK-resolves bones per frame, rotates parts around their pivots (NEAREST, pixel-crisp; optional `--supersample` for smoother high-fidelity rotation), composites by z-order, emits strips + combined sheet + `atlas.json` (frame sizes, fps, loop flags). |
| `pipeline/stub_provider.py` | The **provider interface** + a procedural (Pillow-drawn) first implementation — the whole pipeline runs with zero model calls. A real style-locked image model (17 §5) plugs in behind the same `generate_parts(request) → manifest` seam. |
| `service/app.py` | FastAPI service: `POST /generate/creature`, `GET /health`. Writes bundles **only** under `candidates/`, each with `provenance.json`. |

### Why this beats per-frame generation and video models

- **One image call per entity, ~zero marginal cost per animation.** Per-frame
  generation pays the model for every frame of every animation and fights
  cross-frame consistency the whole way; video models are slower, costlier, and
  blur/hallucinate at pixel scale. Here, the model is only asked for what models are
  good at — *appearance* — once. Motion comes from deterministic, hand-tuned,
  archetype-level pose data reused forever. A new dragon gets fly/breath/walk for free.
- **Deterministic frames preserve the per-frame hitbox contract.** Baked strips with
  known frame timelines keep the per-tag/per-frame JSON the single source of truth
  for client animation *and* server hitboxes ([docs/tech/23 §8](../docs/tech/23-content-pipeline.md));
  the runtime stays "play a strip" — no rigs, no runtime IK, nothing to hitch the 60 FPS budget.
- **Every stage after the one image call is inspectable data** (skeletons, poses,
  manifests are JSON in git) — a bad frame is a diffable pose key, not a re-roll.
- **Animation models can still slot in LATER, as a post-pass** — frame interpolators
  for organic secondaries (cloth flutter, fire, hair) over the baked strips. They are
  currently weaker on pixel-crisp cross-frame consistency, which is exactly what the
  baker guarantees — so they remain an optional enhancement, never the load-bearing path.

### Usage

```bash
pip install --user -r genforge/requirements.txt

# 1) generate a parts sheet (stub provider — no model needed)
python -m genforge.pipeline.stub_provider \
    --archetype dragon --entity ember_drake --family emberkin \
    --palette-hints red --out /tmp/drake

# 2) bake animations from it
python -m genforge.pipeline.assemble \
    --manifest /tmp/drake/parts.json --skeleton dragon \
    --out /tmp/drake_baked [--animations fly,breath] [--supersample]

# or run both behind the service
uvicorn genforge.service.app:app --reload         # from the repo root
curl -X POST localhost:8000/generate/creature -H 'Content-Type: application/json' \
  -d '{"archetype":"dragon","family":"emberkin","tier":"elite","palette_hints":["red"]}'

# proof suite — also regenerates the demo bundles
python3 -m pytest genforge/tests/test_pipeline.py -v
```

Demo bundles (a violet/gold hooded mage and a red dragon) are baked by the test suite
into `candidates/demo/{gloam_mage,ember_drake}/` — open `baked/strips/*.png` and
`baked/sheet.png` there. `candidates/` is quarantined output and **gitignored**
(only `.gitkeep` is tracked): nothing generated is ever inside a tree that CI
compiles into server images or client packs.

### The parts-sheet contract (what any provider must produce)

```jsonc
// parts.json — schema: pipeline/schemas/parts_manifest.schema.json
{
  "schema_version": 1,
  "entity": "ember_drake",
  "archetype": "dragon",             // must name a skeleton in pipeline/skeletons/
  "sheet": "parts.png",              // relative to this file
  "sheet_size": [487, 87],
  "parts": {
    "head": {
      "rect":  [x, y, w, h],         // region on the sheet, px
      "pivot": [px, py],             // bone attachment point, local to rect
      "angle_hint": 0.0              // degrees the part is pre-drawn at (cw+, y-down)
    }
    // ... every part named by the skeleton's bones, plus VFX strip cells
  }
}
```

## The candidate contract (non-negotiable)

- GenForge writes **only** to a candidates area — never to `content/core|drops`
  directly, and it has **no live path** to game servers.
- Every candidate carries provenance (prompt, model versions, lore references).
- Canon rules are encoded in the prompts AND re-checked by the gauntlet: tier skill
  counts (Elite ≥5, Legendary 5–10), the seven damage types, power-budget bounds,
  family skill-sharing that follows family lore (canon §3).

## API sketch (internal only — see docs/tech/28)

```
POST /generate/creature  {archetype, family, tier, palette_hints, theme_tags} → bundle   ✅ v0 (stub provider)
POST /generate/item      {slot, tags, rarity_band, season, theme_tags}        → bundle   (planned)
POST /generate/skill     {behavior, damage_type, family?, season}             → bundle   (planned)
POST /generate/batch     {drop_manifest}                                      → bundles  (planned)
```

Stack: Python FastAPI; models are open proposals (style-locked image model
fine-tuned on approved art; JSON-schema-constrained text decoding). Roadmap: lore +
prompts now (M0–M1), text-gen candidates in the weekly rehearsal (M2–M3), image-gen
after the art-pipeline test (M4), fully in the runbook M5+ — see
[docs/business/31](../docs/business/31-roadmap.md).
