# 28 — Generation Service (GenForge)

> **Status:** v0.1 draft — 2026-07-08. Conforms to [canon](../00-canon.md) v0.2.1 — §7 (the
> GenForge bullet, the gen-AI production rule) and §10 (the `genforge/` repo area) govern.
> Siblings: [content pipeline](23-content-pipeline.md) (gauntlet + runbook),
> [art direction §5](../design/17-art-direction.md) (style-locked image pipeline),
> [creature AI & RL](25-creature-ai-and-rl.md) (RL eval / exploit-finder gate),
> [legal & payments](../business/30-legal-payments-compliance.md) (disclosure/IP posture).
> **(proposal)** marks starting positions for Ricardo's review; **model choices are
> deliberately left open** — this document fixes the contracts around the models.

## Purpose

Dragon Heroes ships items, creatures, and skills **weekly, forever** (canon §4); the
[content pipeline](23-content-pipeline.md) makes that a data operation with a runbook, and
GenForge attacks the remaining bottleneck: *authoring* the candidates that enter it. It is an
internal service that, grounded in the world bible (history, factions, biome lore,
creature-family stories) and the active season's themes, generates **candidate** content —
schema-conforming JSON definitions via text generation, and 64-bit-style sprite sheets plus
animation frames via image generation. This document specifies the grounding model, the two
generation modes, the internal API, and — most importantly — the **candidate contract**:
GenForge output is never content until a human curator, the CI validation gauntlet, the
balance lints, and the RL eval/exploit-finder pass have all said yes. **No live path to game
servers, no player-facing generation at launch** (canon §7): a treadmill-feeder, not an oracle.

## 1. What GenForge is — and is not

| GenForge is | GenForge is not |
|---|---|
| An **internal** authoring accelerator: grounded generation over *our* lore corpus and *our* schemas, proposing weekly-drop candidates | A live service any game system calls at runtime; a general chatbot or off-the-shelf image toy |
| A producer of **candidates** into a quarantined candidates area | A writer to `content/` — promotion is a human git action |
| The upstream half of the design/17 §5 curated art pipeline for creature/item/skill sprites | A replacement for the archetype rigs, the artists, or art direction |
| Fully subject to the existing gauntlet (`tools/validate_content.py`) and runbook gates | A second validation system or a bypass around the first one |

The contract, restated from canon §7: **output lands as candidates in the weekly-drop
authoring stage; human curation, the CI validation gauntlet, and balance lints remain
mandatory gates; no live path to game servers.**

## 2. Repo layout

Canon §10 fixes the shape:

```
genforge/
├── lore/        # world bible: history, factions, biome lore, creature-family stories
├── seasons/     # season theme definitions (one file per season)
├── prompts/     # grounded prompt templates per content type (creature, item, skill)
└── service/     # the API service: request composition, generation, bundling, provenance
```

Two deliberate omissions. **No `genforge/models/`** — weights and fine-tunes live in the
registry discipline of [17 §5](../design/17-art-direction.md), owned by the technical artist
(image) and ML engineer (text), referenced by version from provenance records (§6). And **no
candidates directory inside `content/`** — candidates land in a quarantined area,
`genforge/candidates/2026-wNN/` **(proposal — object-storage bucket is the alternative)**, so
nothing generated is ever inside the tree CI compiles into server images and client packs;
GenForge's service account has **no write permission on `content/`**, enforced by repo
permissions, not convention.

## 3. The grounding model

Ungrounded generation produces generic fantasy sludge; GenForge's value is output that already
*belongs* to this world. Grounding has three layers, composed per request.

### 3.1 The world bible — the canonical lore corpus

`genforge/lore/` is the single canonical lore corpus: world history and cosmology, factions,
per-biome lore (the five launch biomes of canon §4 and every biome after), and
**creature-family stories** — the same families whose shared skill pools canon §3 makes
lore-coherent ("Abyssal creatures share a few abyssal skills"). Structure **(proposal)**:
markdown files with stable front-matter IDs (`lore.biome.gloamfen`, `lore.family.abyssal`),
chunked and indexed for retrieval. The bible is versioned like code — a lore change is a
reviewed PR, because it is what every future candidate grounds on. Design docs
([12](../design/12-world-and-biomes.md), [13](../design/13-creatures-and-bestiary.md)) own
design *intent*; the bible owns narrative *fact*, and it is the machine-read copy.

### 3.2 Season themes

`genforge/seasons/` holds one definition per 12-week season (canon §5): narrative arc, motifs
and theme tags (e.g. `theme: blood_tide`, `motifs: [drowned, crimson, tidal]`), featured biomes
and families, and any season-reserved visual accents. A request names its season; the composer
injects the theme file so week 7's creatures rhyme with week 2's. The season schema is small
and lands at M0 with the world bible — both are pure authoring work, useful before any model
exists (GenForge track, [31-roadmap](../business/31-roadmap.md)).

### 3.3 Prompt composition — lore + schema + canon rules

A generation request is compiled by `service/` into a constrained prompt from three sources:

1. **Lore excerpts** — retrieved from the world bible by the request's biome, family, and
   theme tags. Excerpts carry lore IDs, recorded in provenance (§6), so a curator can check a
   candidate against exactly what grounded it.
2. **The content JSON Schema** — the *same* files from `content/schemas/` that CI validates
   against ([23 §2/§4](23-content-pipeline.md)). The schema is both prompt material (the model
   sees the target shape, its enums, its closed tag vocabulary) and the decoding constraint
   (§4.1). GenForge never carries a private copy of a schema.
3. **Canon rules as hard constraints**, injected as structured instruction blocks, never
   paraphrased from memory: boss-tier skill counts (**Elite ≥ 5 signature skills, Legendary
   5–10** — canon §4); the per-slot **power budget** and tier stat envelopes
   ([14](../design/14-items-loot-and-affixes.md), `content/schemas/budgets/`); the **seven
   canonical damage types** — Physical, Fire, Frost, Storm, Venom, Umbral, Blood — read from
   `content/core/registries/damage_types.json`, never hardcoded in a template.

Templates in `genforge/prompts/` are per content type and versioned; a template change is a PR
reviewed like code, because a bad template silently degrades every candidate after it.

## 4. Generation modes

### 4.1 Text generation — schema-conforming JSON metadata

Produces candidate *definitions* — stats, effects, descriptions, mechanics: a creature stat
block with a skill kit, an item base, a skill with costs, timings, and effect lines, in exactly
the shapes of [23 §2](23-content-pipeline.md).

- **JSON-Schema-constrained decoding** against the target `content/schemas/` schema (via a
  structured-generation layer such as [Outlines](https://github.com/dottxt-ai/outlines)
  **(proposal)**), so output is *syntactically* valid by construction — no free-text JSON
  repair loop.
- Constrained decoding guarantees shape, **not** truth: it cannot know that a referenced skill
  ID exists or that a stat total busts the weapon-slot budget. So every candidate immediately
  runs through **the same `tools/validate_content.py` gauntlet CI uses**
  ([23 §4](23-content-pipeline.md)): schema, referential integrity, balance lints (including
  the elite ≥ 5 / legendary 5–10 counts that tool already implements), probability-export
  compilability. One validator, two callers — never a private fork of the rules.
- Gauntlet failures feed back: the service retries with the validator's errors appended
  **(proposal: max 3 repair rounds)**, then surfaces the candidate as `failed_validation` with
  the error log attached — still useful curator information.

### 4.2 Image generation — style-locked sprite sheets

Produces candidate *art*: 64-bit-style sprite sheets and animation frames, exclusively through
the curated pipeline of [17 §5](../design/17-art-direction.md) — its service form, never an
exception to it:

- **Style-locked models only:** models fine-tuned on our own approved art (the `art/`
  repository); no off-the-shelf general model in any shipping path. The technical artist owns
  the model registry and retrains when the style bible changes (17 §5).
- **Archetype-rig pose sheets as conditioning:** creature frames are generated conditioned on
  the target archetype rig's pose/animation sheets (the 3D-bake output of 17 §4), so candidate
  frames land on rig-consistent poses and map onto **existing animation tags** — the per-tag/
  per-frame JSON stays the single source of truth for client animation *and* server hitboxes
  ([23 §8](23-content-pipeline.md)). GenForge proposes surfaces; the rig owns motion + hitboxes.
- **Palette quantization in post:** every output is quantized to the global 64-color base
  ramps plus the target biome LUT and snapped to the pixel grid at integer scale (17 §3.4/§5);
  non-conforming pixels are a machine-checked hard reject.
- **Human cleanup is not optional:** a named artist's pass — silhouette review, reserved-color
  check, grid/palette verification, hand cleanup — before any sprite is promotion-eligible.
  **No raw AI output ever ships** (17 §5); the acceptance bar is unchanged: indistinguishable
  from hand-authored work under our style rules.

### 4.3 What GenForge does not generate

No code of any kind — no GDScript, no C++, no AI-profile *behavior code*: candidates reference
existing profile IDs or get hand-authored follow-ups. No audio at v1 **(proposal)**. Nothing
at runtime: weekly drops remain baked data (canon §7), which keeps our Steam disclosure in the
pre-generated category (§9).

## 5. API sketch — internal-only REST

`genforge/service/` exposes a small REST API **inside the studio network only** — no public
ingress, no game-server route, mTLS + SSO **(proposal)**:

```
POST /generate/creature
  { "biome": "core.biome.gloamfen", "family": "lore.family.abyssal",
    "tier": "elite", "rarity": "rare",
    "season": "2026-s3", "theme_tags": ["drowned", "tidal"] }
→ 202 { "candidate_id": "cand.2026-w41.creature.0007" }

GET /candidates/{candidate_id}
→ candidate bundle:
   ├── definition.json    # schema-conforming, gauntlet-checked (with result attached)
   ├── sprites/           # sheets + animation frames, post-quantization, pre-cleanup
   └── provenance.json    # §6 — prompt, model versions, lore refs, seeds, gauntlet log

POST /generate/item    { "slot": "...", "tags": [...], "rarity": "...", "season": "...", "theme_tags": [...] }
POST /generate/skill   { "source": "bestial", "damage_type": "core.damage.umbral", "tags": [...], "season": "...", ... }

POST /generate/batch   # weekly-drop mode → a candidates set under genforge/candidates/2026-w41/
  { "drop": "2026-w41", "season": "2026-s3",
    "lanes": [ { "kind": "creature", "count": 6, ... },
               { "kind": "item", "count": 12, ... },
               { "kind": "skill", "count": 8, ... } ] }
```

Generation is asynchronous (image jobs are slow); the batch endpoint is the normal weekly
entry point, sized to **over-generate** — e.g. 6 creature candidates for the 1 the weekly art
budget ships (17 §10) **(proposal)** — because curation selects, and selection needs options.
Definition-first is the default flow: sprites are generated only for shortlisted candidates
**(proposal)**, keeping expensive image work off rejected ideas.

## 6. The candidate contract

**1. GenForge writes only to the candidates area.** Never to `content/`, never to `art/`
source-of-truth directories, never to any store a build reads. Promotion into
`content/drops/2026-wNN/` (cleaned sprites into `art/`) is a **human git commit** on the drop
branch, reviewed like any hand-authored content PR.

**2. Every candidate carries provenance.** `provenance.json` records the full composed prompt
and template version; text- and image-model versions (fine-tune checkpoints included); the
lore IDs of every grounding excerpt; season and theme tags; sampling seeds and parameters;
gauntlet results; and, after curation, the curator's identity and disposition. It follows
promoted assets into the `art/` AI-asset metadata tags so the Steam disclosure stays auditable
(17 §5), and it makes an off-lore candidate diagnosable rather than mysterious.

**3. The mandatory gates, in order:**

| Gate | Owner | What it catches |
|---|---|---|
| **Human curation** | Designer (definitions), artist (sprites) | Off-lore, off-style, boring, incoherent — the taste gate; nothing proceeds unshortlisted |
| **CI validation gauntlet** | `tools/validate_content.py`, same as every hand-authored PR ([23 §4](23-content-pipeline.md)) | Schema violations, broken references, deprecated-ID use, probability-export failures |
| **Balance lints** | Same gauntlet, budgets from `content/schemas/budgets/` | Power-cap/slot-budget busts, tier-envelope violations, skill-count floors/ceilings |
| **RL eval / exploit-finder pass** | `ml/eval` ([25 §9](25-creature-ai-and-rl.md)) | Degenerate DPS/loot outliers, unreachable-position abuse — every drop is attacked pre-ship by unconstrained exploit-finder agents; generated content gets zero exemption |

A promoted candidate then rides the normal runbook — playtest realm, canary, scheduled
activation ([23 §9](23-content-pipeline.md)). To the pipeline, a survivor is indistinguishable
from hand-authored content, which is the point: **one pipeline, one gauntlet, one runbook.**

**4. No live path. No player-facing generation at launch.** No game server, Nakama module, or
client ever calls GenForge; nothing generates at runtime; players never submit prompts.
**(proposal)** One possible later exception — seasonal community events where player-*voted*
themes steer a batch that still passes every gate above — is deferred to an open question,
because it changes the Steam disclosure category and the moderation surface.

## 7. Position in the weekly runbook

GenForge slots into the **Author** stage (T-7 → T-4) of [23 §9](23-content-pipeline.md) and
changes nothing downstream: the batch run lands candidates early in the week; curation
shortlists; artists clean shortlisted sprites; designers adjust definitions; the drop-branch PR
carries the survivors through the unchanged gauntlet → playtest → RL eval → canary → activation
chain. The rollback story is untouched — flags, balance overlays, and ledger-traced rollbacks
neither know nor care that a definition started life in GenForge. If GenForge is down, the
week authors by hand: an accelerator on the authoring stage, never a release-train dependency
**(proposal: permanently)**.

## 8. Lore-consistency guardrails

Grounding reduces off-lore output; guardrails catch what slips through:

- **Family skill-sharing follows family lore.** Canon §3 makes pet skill pools lore-coherent —
  Abyssal creatures share a few *abyssal* skills, and sharing is deliberately sparse. A
  creature candidate's kit is linted against its family's declared pool in
  `content/core/pet-families/` ([23 §1](23-content-pipeline.md)): family-shared skills come
  from that pool, and extending a pool is a curated lore decision (a `genforge/lore/` +
  `pet_family` PR), never a generation side effect.
- **Damage-type and biome affinity checks (proposal):** a lint flags candidates whose damage
  types or tags contradict their grounding excerpts (a Frost-kitted creature grounded in
  Cinderwastes lore) — flag, not hard-fail; deliberate subversion is sometimes the design.
- **Name and description review:** names are checked against existing IDs and a studio
  blocklist; descriptions are curator-reviewed for contradictions the linter cannot see. The
  bible grows as content ships: each promoted candidate's accepted lore text folds back into
  `genforge/lore/` so future generations ground on what is now true.

## 9. Stack (proposal) and disclosure posture

**Service:** Python + [FastAPI](https://fastapi.tiangolo.com/) **(proposal)** — async jobs,
Pydantic request validation, and the ML ecosystem lives in Python; this is tooling, not game
runtime, so the canon C++ directive does not apply (same reasoning as the Go economy-core
carve-out, canon §6). Job queue + object storage for bundles **(proposal)**. **Text model:**
open **(proposal)** — hosted API vs self-hosted open-weights carries real confidentiality and
cost trade-offs (open question 2); the constrained-decoding requirement (§4.1) narrows the
field. **Image model:** per 17 §5, style-locked and fine-tuned on our approved art; base-model
choice is the technical artist's call. Everything provider-shaped hides behind a thin
generation interface in `service/` — a model swap is config plus a provenance version bump.

**Disclosure & IP:** GenForge output that ships is **pre-generated content** — created during
authoring, baked into data packs — declared in Steam's Content Survey under the AI disclosure
policy ([Valve](https://store.steampowered.com/news/group/4145017/view/3862463747997849618));
the stricter live-generation rules stay inapplicable *as long as §6.4 holds*. The IP posture —
training-data provenance, output copyrightability, and the interaction with marketplace item
value (items wearing this art are sold for real money) — is reviewed with counsel alongside
the marketplace parecer, per 17 §5 and [30](../business/30-legal-payments-compliance.md); the
provenance records of §6 are the audit trail for both.

## 10. Failure modes

| Failure | Looks like | Defense |
|---|---|---|
| **Off-lore candidates** | Mechanically valid creature that belongs in a different game; a fire-breathing Gloamfen bog-spirit with no lore excuse | Grounded composition (§3), family/affinity lints (§8), and above all the **human curation gate** — taste is not automatable, and the over-generation posture (§5) means rejection is cheap |
| **Schema drift** | Prompts or the service quietly disagreeing with `content/schemas/` after a schema change | GenForge reads schemas from `content/schemas/` at request time (never a copy), constrained decoding pins output to the live schema, and the same `tools/validate_content.py` runs on both sides — drift fails loudly in the gauntlet |
| **Style drift** | Sprites that pass palette checks but slowly stop looking like our game as models retrain | Style-locked registry with versioned fine-tunes (17 §5), palette/grid machine checks, blind-review acceptance bar, and the named-artist cleanup pass; provenance model versions make drift bisectable |
| **Balance-shaped exploits** | A kit that is fine on paper and degenerate in play | Balance lints catch envelope busts; the RL exploit-finder pass ([25 §9](25-creature-ai-and-rl.md)) attacks what lints cannot see; canary watches realized rates |
| **Volume swamping curation** | 40 candidates a week and a designer rubber-stamping by Thursday | Batch sizes are curation-capacity-derived **(proposal)**, and the runbook rule of §7: a thin hand-authored week always beats a badly-curated generated one |

The pattern across every row: the answer is never "trust the model more" — it is the **human
gate plus the existing pipeline**. GenForge's worst week costs curation time, not player trust.

## Open questions (for Ricardo)

1. **Candidates area:** repo directory `genforge/candidates/` (git-reviewable, but bloats the
   repo with rejected sprites) vs an object-storage bucket with a review UI (cleaner, another
   tool to build). Pick before the M2 text-gen milestone.
2. **Text-model posture:** hosted API vs self-hosted open-weights — lore corpus and unreleased
   content leave the building in prompts under a hosted API. Set the confidentiality bar.
3. **World-bible authorship:** who writes the initial bible (history, factions, five biomes'
   lore, launch family stories)? It is the M0–M1 deliverable and pure writing work — Ricardo,
   the designer, or a contracted writer under review?
4. **Over-generation ratio and curation budget:** confirm ~6:1 candidates-to-shipped
   **(proposal)** and who owns weekly curation (designer for definitions + artist for sprites,
   inside the 17 §10 budget) — batch size derives from curation capacity, not model throughput.
5. **Player-facing generation:** confirm "none at launch" as binding, and whether the
   seasonal-community-event concept (§6.4) merits a post-M5 design spike or stays parked until
   the disclosure/moderation implications are priced.
6. **Skill candidates and animation primitives:** generated skills must reference existing
   animation/behavior primitives (canon §3) — may candidates *propose* new primitives (as
   engineering follow-up tickets), or are they constrained to the shipped primitive library?
7. **Lore feedback loop ownership:** who signs off `genforge/lore/` PRs (§8), so generated lore
   cannot slowly redefine the world without a human owning the change?

## Sources

- [Canon — Dragon Heroes decision log, §7/§10](../00-canon.md)
- [23 — Content pipeline: schemas, validation gauntlet, weekly-drop runbook](23-content-pipeline.md)
- [17 — Art direction §5: the curated gen-AI pipeline, style-locked models, acceptance bar](../design/17-art-direction.md)
- [25 — Creature AI & RL §9: exploit-finder agents as pre-ship QA](25-creature-ai-and-rl.md)
- [30 — Legal, payments & compliance (parecer scope; AI/IP counsel review)](../business/30-legal-payments-compliance.md)
- [Valve — AI content on Steam (disclosure policy, Jan 2024)](https://store.steampowered.com/news/group/4145017/view/3862463747997849618)
- [Outlines — structured (JSON-Schema-constrained) text generation](https://github.com/dottxt-ai/outlines)
- [FastAPI](https://fastapi.tiangolo.com/)
- Internal: research digest [live-content-architecture](../research/live-content-architecture.md) (the data-driven content pattern candidates conform to)
