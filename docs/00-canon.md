# Dragon Heroes — Canon (Decision Log & Glossary)

> **Status:** v0.2 draft — 2026-07-08 (adds, per Ricardo: C++ systems-language directive,
> gen-AI art production, 60 FPS mandate, Monster-Hunter-grade boss canon, pet skill-pool
> system). This file is the single source of truth for names,
> numbers, and decisions. Every other document must agree with it. Numbers marked
> **(proposal)** are starting values expected to change with playtesting; everything else
> is a decision that requires an explicit revision here to change.
>
> **Decision provenance:** choices below were made with Ricardo (2026-07-07) or derive
> from the July 2026 research pass (see `docs/README.md` for the research digest paths).

---

## 1. Product identity

- **Working title:** Dragon Heroes. Studio: IntelliGames.
- **Genre:** fast-paced online action-RPG roguelite-style hunter. Infinite procedurally
  generated open world (PvE "Hunt" mode), plus structured PvP (1v1, 3v3, battle royale).
  Co-op hunts are designed as *real adventures with friends* — boss fights are
  Monster-Hunter-grade encounters, not stat checks (see §4).
- **Performance identity:** locked **60 FPS** client on all platforms, mid-range mobile
  included; GPU-driven particles and dynamic lighting; "beautiful AND optimized" is a
  standing directive (Ricardo, 2026-07-08). The 30 Hz simulation is decoupled from
  rendering — the client interpolates to 60+ FPS and animations must never hitch.
- **Fidelity raise (Ricardo, 2026-07-08 pm):** "128-bit" pixel art — hero/creature
  sprites in the 48–128 px band with rich detail (reference: the approved concept
  sheets), **engine bloom/glow on emissive pixels** (HDR 2D + WorldEnvironment glow),
  and heavy elemental spectacle: fire that ignites, lightning, meteors, tornado winds,
  earthquake cracks. Quality bar: beyond Wizard of Legend's VFX. Bloom requires the
  Vulkan renderers (verified on target hardware); gl_compatibility fallback fakes
  glow with additive sprites.
- **Art identity:** high-fidelity retro pixel art — "the 2D games a 64-bit console
  generation would have produced". Dark fantasy tone with deliberate contrast: a
  beautiful, luminous world under a dark surface. See `design/17-art-direction.md`.
- **Perspective:** the simulation runs on a **flat 2D top-down plane** (precise 2D
  hitboxes: circles, capsules, swept arcs) with a scalar **z-height** for flight/jumps.
  Rendering is **3/4 "isometric-look" angled top-down** with Y-sorted sprites
  (CrossCode/Hades school). This gives isometric aesthetics with top-down hitbox
  precision — decided with Ricardo 2026-07-07.
- **Platforms:** PC (Steam) + Android + iOS, **cross-play from day 1** (Ricardo,
  2026-07-07). Consequences (canonical):
  - The real-money marketplace is a **web-only surface** — never inside the mobile
    apps (app-store policy; see `business/30-legal-payments-compliance.md`). Strict
    no-link posture: mobile builds contain no cash-out/purchase UI **and no links to
    the marketplace** (safe default pending counsel + store-policy review).
  - Ranked/competitive queues are **segregated by input class** (mouse+kb vs
    touch/controller) at launch (proposal — revisit with data). Casual/Hunt cross-play
    is unrestricted.
  - Weekly content drops are **data-only** on mobile (iOS forbids downloaded code).
- **Audience/rating:** **18+ with strong age verification** (CPF/document-grade) at
  launch. This is a legal launch blocker, not a preference — see §8 and
  `business/30-legal-payments-compliance.md`. **Confirmed by Ricardo, 2026-07-08.**
- **Language:** game and docs in English first; pt-BR localization at launch (Brazil is
  the home market).

## 2. Monetization (hard rules)

1. **No paid randomness, ever.** No purchasable loot boxes, keys, chests, gacha, paid
   rerolls, or any mechanic where money buys a random outcome. All random drops come
   exclusively from gameplay. (Because items are cashable, paid RNG would legally
   classify the game as unlicensed gambling in Brazil — Lei 14.790/2023, Lei
   15.211/2025, TJDFT June 2026 rulings.)
2. **No paid power.** Direct purchases are cosmetics, seasonal cosmetic pass, and
   convenience that never touches combat math.
3. **Marketplace fee** is the core revenue: **10% (proposal)** of each player-to-player
   item sale, taken as an automatic PSP split. **20% (proposal)** of fee revenue accrues
   to the seasonal tournament prize pool.
4. **Phased cash-out:** Phase A (launch) — closed-loop: sale proceeds are marketplace
   credit (held in PSP subaccounts), spendable on the marketplace. Phase B — Pix
   cash-out, enabled only after a formal legal opinion (parecer) and proven KYC/AML
   controls. Architecture supports Phase B from day 1. **Player flow decided (Ricardo,
   2026-07-08):** balance accrues; cash-out unlocks once the player completes KYC and
   registers their own Pix key (PSP ownership-verified). The parecer remains the
   studio-side gate for switching Phase B on at all.
5. **Custody rule:** player balances are **never** held in the studio's bank account —
   they live in PSP subaccounts in the player's name (see §8). Commingling player
   funds with company funds would make IntelliGames an unlicensed payment institution
   (Res. BCB 506/2025) and expose player money to studio insolvency.

## 3. Character & progression

- **Base character model:** one androgynous humanoid base rig; all classes, gear
  visuals, and combat animations layer onto it.
- **Classes:** launch with **6 (proposal)**: Warden (bulwark/control), Reaver
  (melee damage), Hunter (ranged physical), Occultist (curses/summons), Elementalist
  (burst caster), Ritualist (support/blood magic). Classes are pure data + skill trees;
  adding a class is a content drop, not an engine change.
- **Attributes (shared path, all classes):** Might, Agility, Intellect, Vitality,
  Willpower. Level cap **60 (proposal)**; **5 attribute points per level (proposal)**
  spent on a shared attribute web.
- **Skills:** each class ships a tree of **~30 nodes (proposal)**. Loadout: **6 active
  skill slots + 3 passive slots (proposal)**. Skills are data definitions referencing
  shared animation/behavior primitives on the base rig.
- **Creature-derived progression (three layers, canonical names):**
  - **Pets** — captured creatures fighting alongside you (companion slot). A pet
    *instance* rolls random attributes **and a random skill set** drawn from its
    creature family's pool: sparse **family-shared skills** (lore-coherent — e.g.
    Abyssal creatures share a few abyssal skills) plus **species-signature skills**.
    Sharing is deliberately rare so skill permutations stay novel. Pets are fully
    tradable; perfect-roll pets are intended to be **among the most valuable assets on
    the marketplace** (Ricardo, 2026-07-08). Players carry **up to 3 active pets**
    simultaneously; pets never permanently die — a downed pet rests, and pets
    **respawn with the player** (Ricardo, 2026-07-08 pm).
  - **Bestial Skills** — creature abilities looted as skill stones, socketable into
    skill slots.
  - **Spirit Essences** — spirits of slain creatures, materials for enchantments/buffs
    on gear.

## 4. World, creatures, items

- **World:** infinite, seeded, deterministic chunked generation. Chunk = **64×64
  tiles**; 1 tile = 1 m (simulation units are meters, f32). Persistence stores only
  deltas against the regenerable base world; every chunk is stamped with a generator
  version so new biomes/content generate in virgin space with seam blending.
- **Biomes at launch: 5 (proposal):** Everbloom Wilds (luminous forest), Gloamfen
  (bioluminescent swamp), Cinderwastes (volcanic), Palecrown Peaks (frozen), Umbral
  Depths (caverns). New biome cadence: **every 4–6 weeks**; items/creatures/skills drop
  **weekly**. Each biome owns an expanding creature set.
- **Creature tiers:** **Normal, Elite, Legendary**. Within each tier, rarities:
  **Common, Uncommon, Rare, Epic, Legendary** ("Common" replaces the earlier "normal"
  rarity name to avoid colliding with the Normal *tier*). Creatures roam in packs of
  **3–8 (proposal)**, each led by an Elite or Legendary boss. Bosses are genuinely hard;
  Legendary drops are genuinely rare (they anchor marketplace value).
- **Boss canon (Ricardo, 2026-07-08):** Elite bosses fight like Monster Hunter hunts —
  **at least 5 signature skills** composing one coherent, learnable combat strategy
  (telegraphs, punish windows, phases). **Legendary creatures carry up to 10 skills**
  with richer strategies and may hunt in **coordinated duos** whose kits combine into
  **field combos** (e.g. fire dragon + earth elemental producing lava tiles) — the
  simulation therefore includes an elemental field-interaction system on the tile grid.
- **Creature archetype rigs:** 10 canonical archetypes — quadruped, humanoid/biped,
  winged beast, avian, dragon, giant, serpent, spirit/ethereal, arachnid/insectoid,
  amorphous. **6 rigs at launch (proposal):** quadruped, humanoid, winged beast, avian,
  spirit, dragon. Every creature = archetype rig + palette/part variants + stat block +
  skill set + AI profile, all data.
- **Damage types (canonical, added v0.2.1):** **Physical, Fire, Frost, Storm, Venom,
  Umbral, Blood** — one seven-type list shared by combat, items, VFX language, and the
  content registries (`content/core/registries/damage_types.json`). Class mapping
  lives in `design/11-combat-and-controls.md`.
- **Runes (added 2026-07-08 pm, proposal):** socketable skill-modifier items looted
  from the world — they alter skill *behavior* (echo, fork, ignite trail, chain...),
  socketed per-skill. A fourth buildcraft layer alongside gear affixes, Bestial
  Skills, and Spirit Essences.
- **Items:** rarities Common → Uncommon → Rare → Epic → Legendary. Depth comes from a
  PoE-style **affix system** (separate item-base, affix, and stat tables with tag-based
  spawn weights); Legendaries are hand-authored uniques. There is a hard **power cap**:
  the meta stays fresh through diversity (new bases, affixes, Bestial Skills, Spirit
  Essences), never through power inflation. Best-in-slot must be reachable by playing —
  the marketplace accelerates, it must never exceed the cap.
- **Party size (Hunt mode):** 1–4 **(proposal)**.

## 5. PvP & tournaments

- **Modes:** 1v1 duel, 3v3 arena, **Gloomfall** — battle royale, **40 players
  (proposal)**, on procedurally generated maps, closing edge called **the Gloom**.
- **Trophies** = ranked rating (per mode). **Glory** = points from kills/objectives,
  spendable **only on cosmetics/effects**.
- **Anti-pay-to-win stance (ranked gear policy decided, Ricardo 2026-07-08):**
  equipment **takes effect** in ranked and tournaments — builds are strategy — but
  leveraged by power: **power-bracketed matchmaking** (no level 10 vs level 100) plus
  the per-slot power budget. No fully-normalized "tournament realm"; the global power
  cap remains the wallet ceiling.
- **Tournaments:** weekly solo + guild tournaments; seasonal grand tournament. Season =
  **12 weeks (proposal)**. Prize pool funded from marketplace fees (§2). **No entry
  fees, ever** (entry fees + chance-influenced outcomes = regulated betting in Brazil).
  Payouts via PSP Pix rails after CPF/KYC, with 30% IRRF withholding on cash prizes.
- **Champion Ghosts:** each week's tournament winners' builds train sparring bots
  (behavioral cloning + RL fine-tune) that players can challenge as PvP practice —
  requires ToS consent + champion credit/revenue share.

## 6. Engine & simulation (tech canon)

- **Engine:** Godot **4.6+**. One project, two exports: client, and headless Linux
  `dedicated_server`.
- **Language rule (strict — revised 2026-07-08, supersedes the earlier Rust decision):**
  - **C++ (C++20)** — everything performance-critical and authoritative: simulation
    core, netcode, procgen, content loading. "Write everything possible in C++ with
    maximized performance" is a standing directive (Ricardo). Delivered as a CMake
    workspace (`sim/`), exposed to Godot via GDExtension (**godot-cpp**, the first-party
    binding), compiled standalone as the zone/match server binary, and exposed to Python
    for RL training via a C API + nanobind binding (PufferLib-native environments are
    C — a direct fit).
  - **GDScript** — presentation only: UI, menus, VFX, animation drivers, content glue.
  - **No C#, no Rust** — one systems language, one script language.
  - Carve-out: the economy core stays **Go** (memory-safe language for money code, see
    §8) — confirmed as open question #7.
- **Simulation:** fixed-tick **30 Hz**, data-oriented (struct-of-arrays entity store,
  not Godot nodes), own 2D geometry for all combat (no engine physics in the combat
  path). Deterministic within a build (fixed timestep, per-system seeded PCG RNG) — for
  replays and RL training; cross-platform bit-exactness is NOT required (server is
  authoritative).
- **Netcode:** custom, over raw ENet/UDP. Byte-packed delta-compressed snapshots at
  **20 Hz**; client-side prediction + reconciliation for the local hero; snapshot
  interpolation for everything else; server-side lag compensation with a **300 ms**
  hitbox history. Do **not** use Godot's MultiplayerSynchronizer/Spawner for combat.
  Interest management: spatial-hash AOI — clients only ever receive nearby state (this
  is also the wallhack defense).
- **Client rendering:** MultiMesh/RenderingServer for crowds and projectiles; Y-sort;
  palette-LUT shader for recolors; GPUParticles2D with explicit per-scene particle
  budgets. Hard target: 60 FPS on mid-range mobile — every visual feature ships with a
  measured frame-time budget.
- **Zones:** the infinite world shards into zone processes (one server process per
  active area, target **50–80 CCU each (proposal — validate by load test)**), orchestrated
  behind a thin abstraction: **Agones on Kubernetes (sa-east-1 / southamerica-east1)**
  for persistent world zones, **Edgegap** for burst capacity (tournaments, Gloomfall).
  Never couple to one host vendor (Hathora shut down May 2026 and stranded shipped games).

## 7. Content & data (tech canon)

- **Everything is data:** items, affixes, skills, classes, creatures, AI profiles,
  biomes, loot tables, spirits, pets — pure data definitions with **stable snake_case
  string IDs**, namespaced `pack.type.name` (e.g. `core.item.emberfang_blade`).
  JSON Schemas in `content/schemas/` validate every definition in CI.
- **One canonical content repo** (`content/`) compiles into both the server build and
  client packs. Client presents a content-version hash at login; mismatch = graceful
  reject. Balance numbers are server-readable → hotfixes without client patches.
- **Weekly drops** ship as data-only PCK patches (runtime `load_resource_pack`, Godot
  4.6 partial-resource patches). **Never scripts in downloaded content.**
- **Art pipeline:** one shared rig per creature archetype, baked in CI to plain frame
  atlases (runtime is simple frame-based sprites); Aseprite CLI in CI; the exported
  per-tag/per-frame JSON is the single source of truth for **both** client animation
  and server per-frame hitboxes; elemental/rarity recolors via palette-LUT shader at
  runtime, not asset variants.
- **Gen-AI production (Ricardo, 2026-07-08):** generative AI is a first-class art
  production tool — concepting, sprite/variation generation, and animation assistance —
  behind a curated pipeline: style-locked models, palette enforcement, and human art
  direction/cleanup on everything that ships. AI-asset use is disclosed where
  storefronts require it (Steam AI disclosure) and the IP posture is reviewed with
  counsel alongside the marketplace parecer.
- **GenForge — the generation service (Ricardo, 2026-07-08):** a dedicated repo area
  (`genforge/`) holding the **world bible** (history, factions, biome lore,
  creature-family stories) and **season themes**, exposing internal endpoints that,
  grounded in that corpus, generate NEW candidate content — creatures, items, skills:
  (a) 64-bit-style sprite sheets + animation frames via image generation, and
  (b) schema-conforming JSON metadata (stats, effects, descriptions, mechanics) via
  text generation. Output lands as **candidates** in the weekly-drop authoring stage —
  human curation, the CI validation gauntlet, and balance lints remain mandatory
  gates; GenForge has **no live path** to game servers. See
  `tech/28-generation-service.md`.

## 8. Backend, economy & legal (tech + business canon)

- **Meta-game backend:** self-hosted **Nakama** (Apache-2.0) on managed **PostgreSQL**
  (PITR + synchronous replica) — accounts/auth, guilds, chat, matchmaking,
  leaderboards, tournaments API.
- **Economy core:** one small **Go** service, the **sole writer** of real-money item and
  money state. Append-only **double-entry ledger**; item instances with DB-enforced
  unique GUID + single-owner constraint; item state machine
  (owned → listed → escrowed → settled/consumed/destroyed); idempotency keys on every
  mutation; SERIALIZABLE isolation; nightly reconciliation (ledger sums to zero, no
  double ownership) with alarms. Game servers and Nakama never write these tables.
- **Payments:** the studio **never touches funds**. Buyer pays the PSP; funds sit in
  PSP escrow/subaccounts; release to seller only after the economy core commits the
  item transfer; studio fee via automatic split. PSP shortlist: **Asaas** (primary),
  OpenPix/Woovi, Efí (alternates) — pending written confirmation each accepts
  game-item RMT. Pix only, BRL only.
- **Legal hard lines (from July 2026 research — validate with counsel before launch):**
  18+ with real age verification (Lei 15.211/2025 — ECA Digital); no paid randomness
  (§2); publish exact drop-probability tables + randomness warnings + refund channel
  (TJDFT June 2026 standard); no tournament entry fees; voluntary COAF-aligned PLD/AML
  program (verified-CPF sellers, payouts only to the verified holder's own Pix key,
  wash-trade monitoring, 5-year records); LGPD: DPO + DPIA covering payments and age
  verification. **A parecer from a Brazilian gaming-law firm is a launch gate.**
- **Kill switches** for every wealth-transfer vector (trade, marketplace, mail, drop)
  and mint-rate anomaly alerts exist **before** the marketplace opens.

## 9. Creature AI (tech canon)

- **Hybrid, strictly scoped:** behavior trees / utility AI (data-defined AI profiles)
  for all normal creatures; **RL policies only** for Elite/Legendary bosses, PvP
  sparring bots (Champion Ghosts), and Gloomfall lobby fill.
- **Training:** PufferLib 3.x over the C++ sim wrapped as a vectorized env (`dh-env`,
  C API + Python binding);
  self-play league for arena policies; behavioral cloning from server-side replay logs
  (obs+action pairs logged from the first playtest — canonical requirement).
- **Serving:** ONNX (INT8) on server CPU only. **Policy weights never ship to clients.**
- **Fairness baked into training** (not post-hoc): 150–250 ms observation delay, burst
  action-rate caps, aim noise, client-equivalent observations only.
- **Weekly-content compatibility:** observation/action schema uses entity-set encodings
  with learned embeddings per content ID (new content = new embedding rows, not new
  tensor shapes); warm-start fine-tunes per patch; automated eval gate before any bot
  redeploys.

## 10. Repository layout (canonical)

```
dragon-heroes/
├── docs/                  # this document set
├── sim/                   # C++20 CMake workspace — the authoritative heart
│   └── libs/
│       ├── dh-math/       # fixed-tick math, 2D geometry, seeded RNG
│       ├── dh-content/    # content definition loading + validation
│       ├── dh-sim/        # entity store, combat, hitboxes, projectiles, BT/utility AI
│       ├── dh-procgen/    # seeded chunk/biome generation
│       ├── dh-net/        # snapshot encode/delta, prediction support
│       ├── dh-server/     # headless zone/match server binary (ENet, Agones SDK)
│       ├── dh-godot/      # GDExtension bindings via godot-cpp (client embeds the sim)
│       └── dh-env/        # C API + Python binding for the vectorized RL training env
├── game/                  # Godot 4 project — presentation ONLY
│   ├── scenes/            # UI, HUD, menus
│   ├── presentation/      # entity views, VFX, animation, palette shaders
│   └── addons/
├── content/               # canonical content repo (pure data)
│   ├── schemas/           # JSON Schemas per content type
│   ├── core/              # launch content: classes/ skills/ creatures/ items/
│   │                      #   affixes/ loot-tables/ biomes/ spirits/ pets/ ai-profiles/
│   └── drops/             # weekly drops: 2026-w40/ ...
├── backend/
│   ├── nakama/            # Nakama config + runtime modules
│   ├── economy-core/      # Go — ledgers, marketplace, prize pools (sole DB writer)
│   └── liveops/           # content publishing, flags, scheduled activation
├── web/
│   ├── marketplace/       # the ONLY real-money surface (web)
│   └── account/           # portal, age verification, seller onboarding (KYC)
├── ml/
│   ├── training/          # PufferLib configs, league self-play, BC pipelines
│   ├── eval/              # bot eval gates, regression suites
│   └── serving/           # ONNX export, policy registry
├── genforge/              # generation service — lore-grounded content candidates
│   ├── lore/              # world bible: history, factions, biome & family canon
│   ├── seasons/           # season theme definitions
│   ├── prompts/           # grounded prompt templates per content type
│   └── service/           # API: generate creature/item/skill → sprites + JSON
├── art/                   # source art: aseprite files, archetype rigs, palettes
├── tools/                 # content validator, atlas baker, balance sims, bot load-test
└── infra/                 # terraform, k8s/agones, docker, CI
```

**Coupling rules (canonical):**
1. `sim/` never imports Godot (except `dh-godot`), never does I/O (except `dh-server`,
   `dh-net`). It is a pure library — that's what makes it a training env and a server.
2. `game/` contains **zero gameplay rules** — it renders replicated state and plays
   animations. If a number affects combat, it lives in `content/` and runs in `sim/`.
3. `backend/` never simulates combat; `dh-server` never writes economy tables (RPC to
   economy-core only).
4. Everything cross-references content by stable string ID; no definition is ever
   deleted or renamed, only deprecated.

## 11. Glossary

| Term | Meaning |
|---|---|
| The Hunt | PvE explore mode in the infinite world |
| Gloomfall / the Gloom | Battle royale mode / its closing edge |
| Trophies | Ranked PvP rating |
| Glory | Kill/objective points, cosmetics-only currency |
| Gold | In-game soft currency (never cashable, not tradable for BRL) |
| Marketplace credit | Seller proceeds held at PSP (Phase A closed-loop) |
| Pets / Bestial Skills / Spirit Essences | The three creature-derived loot layers |
| Champion Ghost | RL sparring bot trained on a tournament winner |
| Tier / Rarity | Creature power band (Normal/Elite/Legendary) / drop-rate class (Common→Legendary) |
| Content pack | Versioned set of data definitions (e.g. `core`, `2026-w40`) |
| Zone process | One headless server process simulating an active world area |
| Field combo | Elemental field interaction on the tile grid (e.g. fire + earth → lava tiles), incl. Legendary duo combos |
| Creature family | Lore group (e.g. Abyssal) whose members draw from a shared skill pool for pet rolls |

## 12. Decisions log (2026-07-08) & remaining opens

Resolved with Ricardo:

1. ~~18+ positioning~~ → **18+ confirmed.**
2. ~~Ranked gear policy~~ → **equipment takes effect in tournaments, leveraged by
   power: power-bracketed matchmaking + per-slot power budget** (§5).
3. ~~Class count/names~~ → **6 launch classes confirmed as proposed.**
4. ~~Fees~~ → **10% marketplace fee / 20% of fees to prize pool confirmed.**
5. ~~Phase A→B player flow~~ → **balance accrues; cash-out after KYC + registered,
   ownership-verified Pix key** (§2.4); parecer still gates enabling Phase B.
6. ~~Economy-core language~~ → **Go confirmed** (§8): payments code wants memory
   safety, mature PSP/HTTP tooling, and audit-friendly simplicity; the C++ directive
   applies to the game runtime. Player funds live at the PSP, never in studio accounts
   (§2.5).

Still open:

7. Team shape: Ricardo is a C++ programmer (no GDScript). The sim/server/procgen core
   is therefore home turf; plan to keep the GDScript presentation layer thin and
   consider hiring/contracting for Godot presentation + pixel art before M1.
8. Kubernetes vendor (GKE southamerica-east1 vs EKS sa-east-1), M0 benchmark gate
   numbers, player-made field combos at launch — see `docs/README.md` opens list.

### Additions (2026-07-10, Ricardo)

9. **Pet stables:** pets are NEVER abandoned. Capturing past the 3 active slots
   moves the OLDEST bond to the character's stables (unlimited); active/stabled
   swaps are free at the character panel. Every captured roll is retained — they
   are future marketplace assets.
10. **Mounts (proposal numbers):** walking AND flying mounts. M mounts/dismounts;
   no combat from the saddle; taking damage dismounts. Walking respects terrain
   (Gloam Strider, x1.6, vendor 400 g). Flying crosses water/rock and must land
   on walkable ground (Emberwing Drakeling, x1.9, bonds on first Matriarch kill).
   Mounts are owned instances (tradable later, like pets).
11. **Skill progression (proposal):** +1 skill point per level; class-tree nodes
   (requires-gated: active/passive/modifier/keystone) are learned by spending
   points and feed the live StatBlock. Keystones carry real tradeoffs
   (blood_price: +10% melee leech, -15 armor).
12. **Effects registry:** `content/core/registries/effects.json` is the living
   index of every status/condition/mechanic/enchant/affix/field (in-game CODEX
   renders it). New effects are ADDED to the registry in the same change that
   ships them — it is documentation-as-data and a validator input.
13. **Per-hunt worlds:** every hunt generates a fresh world (dh-procgen seed per
   hunt). Prototype: the client shells out to `dh-server --dump-chunks 4 --seed
   <random>`; shipping path generates in-process via dh-godot (docs/tech/24).
14. **Characters persist** (prototype): named saves in `user://saves/` loaded at
   login. Shipping path: server-authoritative character store (docs/tech/26) —
   the client-side save dies with the prototype harness.
15. **Docs discipline (standing):** docs/ stays current as the single source of
   truth — architecture decisions to marketing material draw from it. Every
   feature/decision lands with its docs/canon update in the same change.
16. **v7 world/UX pass (2026-07-10, Ricardo):** fast 1→100 leveling (level n needs
   10 + n/2 kills — the beloved 1-10 pace all the way up); 14 packs per hunt
   (map must never feel empty); class-lite roster at login (Reaver / Emberkin /
   Frostbinder — shared kit, distinct casts; full six-class kits stay design/10);
   Whirlwind (E) as a universal class active; monster actives (brute radial slam
   w/ telegraph, lunger pounce); mount hotkey Z (reachable from WASD); UI: bag
   filter+sort, one-click junk selling, skill cards with rune-socket chips,
   stable cards. Sprite fidelity raised via procedural outline/shading kit —
   the real "modern-day pixel art" ceiling is the GenForge art pipeline (§7),
   which replaces procedural placeholders entirely.
17. **Economy QoL (2026-07-10, Ricardo):** enchanting NEVER destroys equipment —
   the destroy risk is removed everywhere; the essence is the only cost. Vendor
   gets per-rarity one-click sell-alls (non-equipped bag gear) and a stable
   layout (rows never shift under the cursor mid-spree). The Haven gains a
   120-slot CHEST (bag <-> chest, free moves). Materials STACK (qty on one
   slot, stack-aware consume/sell). Design/14 updated accordingly.
18. **Three boss hunts per map (2026-07-11):** the difficulty ladder is live —
   Fenwitch Hag (Elite mid-boss, pack 8: Hex Bolt volley, Blink, Wispling Call,
   Creeping Mire slow fields, Shrieking Curse enrage), the Pyre Sovereign +
   Terravore Colossus LEGENDARY DUO (pack 11: meteors, cinder breath,
   earthshatter, stone spikes; survivor enrages) with the first playable
   **Duologue** — while both live, fire fields over earth fields fuse into LAVA
   (14 dps, 10 s, strongest glow) per registries/fields.json — and the Emberwing
   Matriarch (pack 13). The field system is generalized to kinds
   (fire/earth/mire/lava) with per-kind visuals and slow. Vulkan HDR glow is
   opt-in via tools/run_vulkan.sh only (gl_compatibility stays the default).
19. **Mass content + five classes (2026-07-11, Ricardo):** GenForge batch
   generation produces the bestiary as data — 100 legendary creatures (per-hunt
   sampled scaled boss, power scaling with player level) and 1000 normal
   creatures (catalog-driven pack spawning: name/element/tint/scale/stat rolls
   over archetype chassis + art bundles). Classes grow to five: Gloam Mage
   (ranged Arcane Bolts, Frost Nova) and Veilblade rogue (Swift Stab cadence,
   Fan of Knives) join Reaver/Emberkin/Frostbinder — class KITS now reshape
   LMB and E, not just stats. Friendly projectiles enter the sim contract.
   VFX pass: pooled shockwave rings + slash trails; particle budgets raised
   (desktop proposal). All numbers (proposal); catalogs live in
   content/generated/ with provenance.
20. **Flow tuning + level-scaled loot (2026-07-11, Ricardo):** difficulty must
   engage, not bore — hunt legendaries roll a NORMALIZED HP budget (x1.4-3.0
   of the 900 reference, threat carried by dmg x1.3-2.2) instead of
   multiplying chassis base HP (killed the 13.8k level-1 colossus walls).
   Hitboxes follow sprites (bestiary scale multiplies collision radius;
   lunger/brute get matched radii). The hunt must reward: items roll at the
   hunter's level (ilvl, +4% per level on every stat roll, ~x5 at 100) and
   boss/legendary kills are quality-floored to the upper roll band — no more
   level-1 rolls from legendary kills. All numbers (proposal).
21. **Class skill trees (2026-07-11, Ricardo):** every class gets a real tree —
   20 actives + 8 passives (one keystone with a tradeoff) + free root, 145
   nodes total, ALL data (registries/skill_trees.json) run by ONE generic
   executor (projectile/nova/cone/melee_arc/dash_strike/buff/field/chain) —
   weekly skills never require engine work (directive 4). Synergies are
   data-expressed: bonus_vs/consumes status payoffs, Emberkin Ignite
   spread/detonate, Frostbinder Shatter, Gloam Mage Attunement and Veilblade
   Combo charge stacks (max 5, +25%/stack spenders). New creature statuses:
   Bleed (5 stacks), Expose (+20% taken), Stagger (0.5 s). Skill bar on 1-4,
   assigned in CHARACTER -> Skills, loadout saved per character. Numbers
   (proposal); full six-class kits with resources remain design/10 (planned).
22. **UI/feel/localization pass (2026-07-12, Ricardo):** Haven nav became a
   2-wide grid (QUIT was cropped off the 360 px viewport — now test-guarded
   on-screen). Skills tab is a VISUAL tree: drawn prerequisite connectors,
   kind-icon chips with element accents, pulsing learnable states, pinned
   detail card with live stat numbers and Learn/assign actions. Fresh hunters
   start with 3 skill points and two level-1 actives per class (variety from
   the start). Animation juice pass: directional swing leans, cast wind-ups,
   dodge afterimages, hit squash, death collapses, boss anticipation tells —
   all tweened/pooled, 60 FPS lock intact. PT-BR is the first supported
   locale: ProtoLang (EN/PT chrome table + _pt data twins, user://settings
   .json, menu + Haven toggles), skill trees fully bilingual; EN stays the
   default. Registry PT twins for the CODEX: planned.
23. **Spectacle VFX vocabulary (2026-07-15, Ricardo).** Reference: three
   commercial-ARPG screenshots (orbital ribbon trails, screen-filling novas,
   damage-number storm, post-processing). Full authoritative build spec:
   docs/design/18-spectacle-vfx-spec.md. Landed as the prototype's spectacle
   layer: screen-filling orbital ribbon trails (pooled MultiMesh2D, 640 inst /
   1 draw call), a full-frame post shader (chromatic aberration + vignette +
   over-bright), pooled converging-beam/danger-ring telegraphs, a
   protective/enrage aura, and pooled punchy damage numbers. Budget: ~5 fixed
   draw calls on bounded pools, < 120 draw calls/frame, additive overdraw
   < 4x screen, locked 60 FPS on gl_compatibility (fx_stress gate measured
   ribbons 40/40, labels 48/48, telegraphs 20/24, 0 nodes after warmup,
   5.9 ms/frame). One intensity in [0,1] (mobile default MED) gates usage,
   never allocation; telegraphs exempt. **Engine decision** (deep-research,
   verified): stay on Godot — genre (Brotato, Halls of Torment) and our exact
   Godot+C++-sim+MultiMesh architecture are proven in production; the bloom
   wall was a renderer setting, not an engine limit. **Renderer split
   ("Layered now + Vulkan-ready", Ricardo's call):** the full look ships on
   the gl_compatibility default with faked additive bloom; the Vulkan opt-in
   (tools/run_vulkan.sh) adds real HDR WorldEnvironment glow on top via the
   single ProtoPost.set_hdr_mode() seam inside the existing renderer branch —
   the gate CONDITION is unchanged (a Vulkan window once crashed the dev's X;
   only the dev tests that flip on real hardware). Mid-range mobile 60 FPS on
   Godot's Vulkan path is unproven (not disproven) and must be measured
   first-party. Four per-event allocators (damage_number, _spark_burst,
   telegraph.gd nodes, per-bolt projectile trail) converted to pools in the
   same pass; net node/tween count DROPS while on-screen density rises.
24. **Real gen-AI image provider — provider-agnostic (2026-07-15, Ricardo).**
   GenForge's PartsProvider seam gains a real model path. New provider-agnostic
   image backend (genforge/pipeline/image_backend.py): stdlib-HTTP, NO SDK
   coupling, one `ImageBackend.generate(prompt) -> [Image]` interface with an
   OpenAI backend (gpt-image-1, transparent-PNG sprites) selected by env; a new
   backend is one class + registry entry. ModelPartsProvider (model_provider.py)
   sits behind the SAME seam as the stub; `GENFORGE_PROVIDER=model` swaps it in,
   default stays 'stub' so nothing spends API budget by accident. Key is read
   from OPENAI_API_KEY at call time — never hardcoded/logged/committed. v1 emits
   a single full-figure concept sprite (one 'body' region); turning generated
   figures into SKELETAL animated bundles needs template-layout generation or a
   segmentation pass + matching rig (next step, ties into the image->3D->render
   route). Mocked tests (no network) cover backend/provider/factory. The backend
   is general — it will also drive VFX-frame and concept-art generation.
25. **Shader-art VFX land in-game (2026-07-16, Ricardo).** Ricardo's bar:
   effects read in the blink of an eye and match modern references (Children
   of Morta et al.); pure shader math can hit it. The five vfx_lab effects —
   slash, nova, vortex, firestorm, impact (SDF + fBm + domain-warp +
   chromatic dispersion) — were authored as numpy contact-sheet previews
   (sources + re-renderable previews now IN-REPO at genforge/vfx_lab/), ported
   1:1 to canvas_item shaders (game/prototype/shaders/), and wired through a
   pooled 12-quad system (shader_fx.gd, fx.shader_burst): melee/executor
   slashes, frost/skill novas, Whirlwind + Shadow Rend vortices, Cinderburst/
   fire-field firestorm plumes, crit/slam/finisher impact stars. KEY RENDERING
   FACT: canvas_items stretch evaluates fragments at WINDOW resolution, so
   these composite as smooth hi-res effects over the chunky pixel world — the
   Children-of-Morta layering with zero extra viewport machinery. Perf: all
   5x12 materials pre-compiled at load (a mid-fight shader swap spiked frame
   time 21.7 ms in the fx_stress gate — caught and fixed; gate now 13.4 ms
   under over-fire). Review verdict on the lab: vortex/firestorm/impact clear
   the bar, nova good, slash flagged for a sharpen pass. Lab outputs must
   live IN-REPO (a /tmp cleanup deleted the originals; recovered by replaying
   64 Write/Edit ops from agent transcripts).
26. **Phantom Tower reference pass (2026-07-16, Ricardo).** Phantom Tower
   (Steam 3988410) confirmed as THE reference (it is the game in Ricardo's
   original spectacle screenshots; Hades named as the ceiling). Its language,
   decoded from store screenshots: THIN crisp blade-light slashes (not fat
   smears), colored RIM-GLOW silhouettes on elites, dark world where effects
   are the light source. Applied: slash sharpened (band 0.24->0.15, core
   sigma 0.34->0.20, halo smear halved, decay-ballooning halved — now reads
   as knife-light, verified on the re-rendered contact sheet); nova shards
   de-symmetrized (seeded low-freq angular warp — no more clock face); NEW
   rim_glow.gdshader (8-tap alpha-edge outline) on elites (affix color),
   boss chassis (bar color), hunt legendaries (magenta), materials cached
   per color (ProtoGlow.rim_material). Renderer previews and shaders kept
   in exact parity (same constants edited in both).
27. **Media-grade VFX: fire/darkness are MEDIA, effects light the world
   (2026-07-17, Ricardo).** Ricardo's verdict on v0.1.11: effects still read
   as "hard shapes on top of the rest instead of actual fire and darkness
   aura" — and he asked whether to swap engines. Engine question RE-ANSWERED,
   decision unchanged: NO overhaul. The hard-shape read is authorship, not
   engine — (a) crisp SDF bands with one flat tint instead of advected media,
   (b) additive-only blending (additive DARKNESS is physically impossible),
   (c) effects casting no light on the scene. The same math renders equally
   hard in Unreal/Unity; Hades-grade fire is media shaders + scene lighting,
   all expressible on gl_compatibility. Built ground-up instead (v0.1.12):
   (1) firestorm upgraded to a persistent medium — TIME-based advection (a
   10 s field burns at burst speed, never syrup slow-mo), `hold` sustain
   envelope, `flash_amt`; fire/lava fields now BURN their whole duration
   (persist-flagged pool quads, stolen last, faded early on lava fusion).
   (2) NEW umbra.gdshader — the first MIX-BLEND medium: occluding near-black
   violet smoke (alpha<=0.90), erosion dissolve (threshold rises — the cloud
   burns off in patches, never alpha-fades), narrow violet rim + motes;
   wired to Shadow Rend, umbral creature deaths, legendary deaths (lab:
   genforge/vfx_lab/umbra). (3) NEW lights.gd (ProtoLights): ONE MultiMesh,
   32 pooled additive ground ellipses at z=-3 (under entities, above field
   decals, below telegraph rings) — fire fields flicker light onto the
   ground, energy bolts carry glow pools, the hero/legendaries/bosses stand
   in their own light; intensity gates usage, never allocation. (4) Heat
   haze folded into the EXISTING post pass (uniform vec4[6], world-tracked
   sources, ZERO extra backbuffer copies) — fire fields and Cinderburst
   shimmer the air. fx_stress extended (lights 32-clamp, umbra over-fire,
   persistent flames, haze eviction past HAZE_MAX): 13.78 ms worst frame,
   0 nodes after warmup, all pools clamped.
28. **The 2D lighting model + the capture loop (2026-07-17, Ricardo).**
   Ricardo: v0.1.12 still "far from the presented examples — push to the
   limits, otherwise full overhaul." Breakthrough #1: the CAPTURE HARNESS
   (tests/vfx_showcase.tscn boots the real hunt, fires signature moments,
   saves viewport PNGs; tests/vfx_iso.tscn isolates single systems;
   SHOWCASE_NULL=1 bisects environmental paint) — for the first time the
   COMPOSITED frame is reviewable in-loop, not just isolated lab sheets.
   First capture diagnosed the real gap in minutes: the WORLD WAS FLAT-
   BRIGHT — no amount of effect polish can make effects read as light
   sources over a uniformly lit scene. Built ProtoDarkness (darkness.gd,
   z=10 camera-glued multiplicative quad): dark blue-violet ambient + up to
   16 nearest light holes (fed by the ground-light pools + static
   glowshroom sources registered by world_gen). Everything above z=10
   (pool tints 11, fx 18+, shader quads 21) reads as LIGHT. Plus: hero
   lantern pool, split-tone grade in post (cool shadows / warm highlights),
   soft breathing field edges (hard vector ring killed), per-kind auto
   light-halos under bursts (tight "hole" scale so a skill pop doesn't
   spotlight-reveal the map), telegraph alphas rebalanced ~x0.55 for the
   dark world + per-wedge beam alpha normalized by count. Breakthrough #2,
   found VIA the capture loop ("blinding disc of triangles", Ricardo):
   fx.ring() scaled a Line2D node to the target radius, but Line2D width
   is LOCAL-space — every shockwave since v0.1.5 rendered as a ~300 px
   thick annulus, masked until now by the bright world. Fixed (width /
   final scale): shockwaves are thin elegant expanding circles. Nova
   shards bead-eroded radially (no more clock face). Ricardo verdict
   in-session: "NOW we are talking. Things are actually beautiful."
   LESSON (permanent): review the COMPOSITE through captures after every
   visual change; lab sheets validate effects, captures validate frames.
29. **Atmosphere layers on the lighting model (2026-07-17, Ricardo:
   "further polish lighting, perhaps add shaders").** Four systems riding
   the darkness model, all capture-verified: (1) GROUND MIST — ProtoFog,
   camera-glued mix-blend quad at z=12, domain-warped fBm scrolled by TIME;
   density THINS near the same light holes the darkness pass lifts (fire
   burns fog off) and rises at night — coupled, so it reads as one
   atmosphere. (2) FIREFLIES — ProtoMotes, ONE MultiMesh of 40 additive
   glints (70% ember / 30% cold spirit) wandering the camera view at z=13,
   intensity-gated count. (3) ANIMATED WATER — world_gen builds one
   MultiMesh quad per water tile (single draw call per map);
   water.gdshader scrolls two noise layers + specular glints + shore foam
   hugging real coastlines via an INSTANCE_CUSTOM neighbor mask.
   (4) FOLIAGE SWAY — vertex-only prop_sway.gdshader on trees/shrooms:
   wind sway pinned at the base + gaussian bend-away when the hero walks
   through (shared material, player_pos fed per frame). Plus the night
   cycle now drives the lighting model (ambient 0.46/0.50/0.66 day ->
   0.30/0.34/0.55 night; fog 0.18 -> 0.30). Layer map at this point:
   tilemap < water(-6) < fields(-5) < telegraphs(-2) < entities(0) <
   darkness(10) < light tints(11) < fog(12) < motes(13) < fx(18+) <
   post(L5) < damage(L6) < HUD(L10+). Gates: FXSTRESS OK 7.66 ms, boots
   clean, CLICKTEST ALL PASS.
30. **The five-overhaul program (2026-07-17, Ricardo: "do all of those,
   and also radiance cascades" + "keep the code reusable and decoupled").**
   Executing docs/design/19-visual-om-catalog.md top-5 in dependency order.
   LANDED v0.1.15 (Phase 1): (a) THE LIGHT REGISTRY — darkness.gd packs the
   gathered holes into a 16x2 RGBAF data texture published as shader
   GLOBALS dh_light_tex/dh_light_count (row0 x,y,radius,strength; row1
   rgb,casts). One gather, many consumers — fog already migrated; water
   glints and sprite N·L shading read the same registry next; consumers
   are fully decoupled from the gatherer. (b) SDF SHADOWS — world_gen
   bakes a tile-res chamfer distance field over T_ROCK per hunt;
   caster-flagged lights (lantern/fields/legendaries/bosses) sphere-trace
   it (12 steps, penumbra k=9, dithered start); caster count rides
   intensity 0/4/6. Light no longer crosses walls. The SDF is the literal
   substrate Radiance Cascades marches later. (c) ORDERED DITHER — 4x4
   Bayer (branchless) anchored to world pixels quantizes falloffs into
   authored bands (steps=7); replaces hash dither. IN FLIGHT via
   file-partitioned agents: automated normal-map gen (genforge bevel+
   Sobel) for the Dead Cells sprite-lighting stack; macro variation +
   dual-grid autotiling; 3D-LUT grading (2D-strip, per-biome data);
   pixel-crisp typography (PT-BR diacritics gated). Radiance Cascades is
   a scheduled bet: fragment-only port at 320x180 light field, must be
   profiled on mid-Android before commitment (no published benchmark).
31. **Typography postscript — the default-theme trap (2026-07-17).** Setting
   `ThemeDB.fallback_font` is NOT enough to re-font bare Labels: controls
   with no Theme anywhere in their ancestry (HUD lines on CanvasLayers,
   world-space nameplates) resolve through the engine DEFAULT THEME, whose
   built-in vector font wins before the fallback is consulted. The doctrine
   (ui/theme.gd apply_doctrine) therefore restamps BOTH: fallback_font AND
   ThemeDB.get_default_theme().default_font/size. Sibling lesson: any
   system applied "at the menu" must also self-apply on direct boots —
   main.gd calls apply_doctrine() in _ready (idempotent), so headless
   gates and capture harnesses see the same frame the player sees. Landed
   v0.1.18 with the full pixel-grid migration (menu recomposed as name-chip
   class cards; every override routed through SIZE_BODY/SIZE_TITLE).
32. **Infinite world (v0.2.0, 2026-07-17, Ricardo: "what do we need for
   infinite world generation? Work on this for the next patch").** The
   generator was born infinite (dh-procgen: stateless coordinate hashing,
   constant-time random access per chunk); the finite parts were the dump
   CLI and the prototype's one-shot world build. v0.2.0: dh-server gains
   `--dump-window cx0,cy0,cx1,cy1` (same JSON, any inclusive rect —
   determinism verified byte-identical against the radius path), and the
   prototype streams a 5x5-chunk window around the player (load radius 2,
   unload 3, hysteresis; per-frame apply budgets; SDF/minimap-block/JSON
   work on a worker thread; walkability outside loaded chunks reads
   T_ROCK = a self-retreating stream fence). Full architecture + budgets +
   the STREAMTEST gate: docs/tech/29-infinite-world-streaming.md. The
   authored hunt (14 packs, bosses, the Matriarch) stays anchored near
   origin ON PURPOSE — frontier chunks repopulate deterministically with
   distance-scaled danger instead. Hard line kept: no worldgen logic
   engine-side — the engine renders windows the C++ generator emits, and
   the shipping path only swaps the transport (dh-godot in-process instead
   of subprocess JSON). Streaming windows are also the future AOI story
   (multiplayer roadmap: docs/design/21).
33. **The 3D alternative view experiment (v0.2.1, 2026-07-18, Ricardo:
   "create an alternative 3D version... reusing our 2d creations, mechanics
   and stuff. Keep the 2d version").** game/prototype3d/hunt3d.tscn renders
   the SAME dh-server chunk dump, tile atlas, prop textures and GenForge
   bundles as a perspective 3D night scene (ground planes from the 2D atlas,
   T_ROCK extruded to occluding boxes, actors as AnimatedSprite3D billboards
   fed by frames_for(), real Omni/Directional lights in the 2D palette).
   ~400 lines, zero edits to the 2D game — the 2D VIEW REMAINS CANON. The
   experiment's finding (docs/design/22): worldgen/sim/content/art reuse is
   total because those layers never bound to a renderer; the 2D FX/lighting/
   combat-feel stack is the actual cost of any 3D product. One adapter
   exists: bundle frames are CanvasTextures (2D-only type), unwrapped to
   diffuse for 3D. HD-2D is a plausible future direction, parked without a
   directional call.
34. **Image-to-3D: local open weights, two tiers (2026-09-02, Ricardo: "go
    with the max quality ones which can be run locally").** Character/creature
    meshes are generated from GenForge CONCEPT RENDERS (never the 52px
    sprites) by open-weight image-to-3D models under our control — no
    per-asset SaaS. Hardware audit set the shape: the RTX 4050 (6 GB, CUDA
    12.8 driver ✓, system nvcc still 11.5) runs the DRAFT tier (TripoSR /
    Hunyuan3D-2mini shape); MAX QUALITY (TRELLIS(.2) / Hunyuan3D full,
    16-24 GB) runs the SAME adapters on a rented 24 GB box for single-digit
    dollars per weekly batch — open weights + our provenance = still "local"
    in every sense that matters. Stage landed: genforge/pipeline/mesh_gen.py
    (MeshProvider protocol mirroring the parts pipeline, deterministic CI
    stub, VRAM-preflighted external adapters in their OWN venvs,
    candidates/mesh.* provenance; 5 tests green). Payoff loop: one accepted
    mesh feeds BOTH views — GLB into the 3D scene (design/22) and
    3D-to-sprite re-renders with TRUE baked normals for the canon 2D game.
    Spike gate before scaling: fen_boar + gloamfen_stalker, judged in-scene
    and as sprite re-renders (docs/tech/31 §5). Hero assets (Matriarch,
    legendaries) stay hand-directed.
35. **The Arena: observable self-play + the two policy lineages (2026-09-02,
    Ricardo: "create the arena system where self-play can be ran and observed...
    a specific neural net for each creature type... and a global version that
    learns from every episode... include player models with different builds").**
    game/arena/ runs creature/creature, build/creature and build/build matches
    on the prototype combat code — windowed for watching, headless for
    training (design/23). Two minimal seams make it possible (additive ARENA
    HOOK patches, hunt behavior unchanged): target_override (creatures/
    projectiles/pets can hunt a node other than the "player" group) and
    bot_drive + ProtoBuild (external policies drive bodies; Session-compatible
    build objects let two geared builds share one scene). EVERY fighter is
    targeted through one ArenaProxy child. Policy lineages: per-species nets
    (fine-tuned per creature type) AND one global net with an embedding row
    per content id learning from all episodes — both load through ONE runtime
    (arena.obs.v1 schema, 31 obs + 16-dim embedding, versioned). Fairness
    baked in per §9: 150-250 ms obs delay, aim noise, burst-binding action
    cap. Episodes log obs+action JSONL (R0 dataset, ml/data/episodes). ml/ is
    live: numpy policy twin, ES league trainer (bootstrap until dh-env — the
    registry/gate/schema port unchanged to PufferLib), eval gate whose failure
    mode is "fleet stays on previous pin". The arena roster (content/core/
    arena/builds.json + schema) also defines BOUNTY HUNTERS — player-shaped
    NPCs with class/attributes/rolled gear/runes/skill loadouts/pets and
    COSMETIC loadouts (element auras, Grand-Chase necklaces, weapon glows —
    the GenForge cosmetics pack, presentation-only per §2). Gates: ARENA
    SELFTEST OK, COSMETICS OK, ml pytest 10/10.
36. **P2P co-op for friends & LAN (2026-09-02, Ricardo: "allow both lan play
    and lobby play via peer-to-peer… Nakama server will be the way to go
    futurely… keep things simple for now, just me and friends playing").**
    game/mp/ lands prototype-grade co-op: ENet P2P (one HOST, up to 3 JOIN by
    IP — party cap 4 per §4), a lobby (name/class/ready/start), HOST-
    AUTHORITATIVE hunt (the one real sim runs on the host; clients send 30 Hz
    inputs and render 20 Hz hand-rolled RPC snapshots — no
    MultiplayerSynchronizer/Spawner for combat, §6 respected). The world never
    crosses the wire: the lobby picks the hunt seed and every peer regenerates
    the identical world (dh-procgen determinism). Remote hunters are real
    ProtoPlayers via the arena seams (bot_drive + ProtoBuild, auto-rolled from
    class at party level). SHIPPING architecture unchanged (§6 zones + Nakama
    matchmaking, design/21 M-A) — this is the friends-and-LAN bridge and M-A
    de-risking, with honest v1 simplifications (shared party profile: loot/XP
    are the host's Session; no prediction; no NAT traversal — port-forward or
    overlay for internet). MP HOOK patches: creatures/bolts target the
    NEAREST hunter; remote deaths respawn via the driver; world forced_seed.
    Gate: tools/mp_test.sh (two headless processes, loopback) → MP TEST OK.
    Docs: tech/33; usage manual: docs/USAGE.md.
37. **Open source + moddable (2026-09-02, Ricardo: "make it full open source
    — extensible and extremely moddable").** Anti-piracy-by-cryptography is
    rejected outright: client binaries are inherently crackable, DRM costs
    performance (violates the 60 FPS directive), and our value is
    server-resident BY DESIGN (authoritative combat, economy-core sole writer,
    web-only marketplace, server-only policy weights, account-bound
    entitlements) — a pirated client is a sandbox, not a business. Decision:
    client, sim, tools, ml, genforge and docs are OPEN SOURCE; license split
    CONFIRMED: code MIT, art/content PROPRIETARY (all rights reserved,
    LICENSE-ASSETS — modders distribute code/data, assets come from official
    builds), secrets never in-repo. Modding = the existing content-pack system formalized: mods are
    schema-validated data packs (NO scripts — §7 already), loaded via the
    weekly-drop PCK path; solo = anything goes, P2P co-op = content-hash match,
    ranked/economy = official packs only (mod IDs quarantined by namespace).
    Cheating (not piracy) is the residual risk: server authority + AOI +
    replay anomaly detection are the answer; no kernel anything. Full spec +
    checklist: business/32.
38. **Cloud GPUs PAUSED for budget — local hardware for now (2026-09-10,
   Ricardo: "Don't run anything into cloud gpu on google. We don't have
   settings anymore. Arenas will be run on local gpus!" + "comment out
   previous max quality settings, don't simply delete code" + "log the
   whole history... remember to use full quality when budget is
   sufficient").** THE HISTORY, so no future harness misreads it:
   (a) 2026-09-02 — image-to-3D chosen as open-weight, max quality, under
   our control (§12.34); (b) same day — the RTX 4050's 6 GB forced a
   two-tier split, and the MAX-QUALITY tier was designed for Google Cloud
   Run GPU (nvidia-l4 24 GB, scale-to-zero, ~cents per asset): container
   `genforge/service/mesh_cloudrun/`, `CloudRunMeshProvider`, credentials
   map in tech/31 — the PREFERRED design, never deployed; (c) 2026-09-10 —
   the GCP account/budget went away, so the tier is PARKED, not rejected:
   code kept commented-out in place (mesh_gen.py, its tests, the service
   dir with a deploy guard; tech/31 §7). STANDING RULE: while budget is
   absent, arena self-play training (tech/32 — ES league over headless
   Godot workers), image-to-3D (tech/31 — offload path on the 4050, bigger
   local card later through the same adapters) and any other ML run on
   LOCAL GPUs. THE DAY BUDGET IS SUFFICIENT: re-enable the Cloud Run tier
   (uncomment, deploy.sh, set DH_MESH_CLOUDRUN_URL) — full quality is the
   intended path; local offload is the stopgap. Also this date: the
   **harness memory** was centralized at docs/harness/ (Ricardo: "so any
   harness can continue your work") — README = start-here, 10-systems-map =
   current-state spec per system with file pointers and gates,
   20-roadmap = one consolidated roadmap pointing at each law doc. HANDOFF.md
   stays the volatile delta; docs/harness/ is the durable layer.

39. **Training speed: CPU-bound `--speed max`, and no GPU in this loop
   (2026-09-11, Ricardo: "is the arena training script using my gpu? as i
   increase the number of jobs, it doesn't seem to accelerate much. it should
   be able to become faster with more compute!").** Diagnosis: (a) nothing in
   the ES loop touches the GPU — the trainer is numpy on a tiny MLP, every
   worker is Godot physics + GDScript; (b) fast mode was WALL-LOCKED at 4×
   (240 Hz ticks × time_scale 4), so a 4-episode match took ≥ 45 s however idle
   the machine was; (c) a generation is pop × opponents independent matches
   (12 by default) — the most workers that can ever be busy, so `--jobs 32`
   ran 12 processes. Decision: `arena.gd --speed` — `max` (training's default:
   the engine flag `--fixed-fps 60` advances exactly one 1/60 s tick per
   frame, CPU-bound and deterministic — results bit-identical to 4× and 16×; a
   2-episode set 0.91 s vs 22.1 s) or a wall-locked `N` for watching. Measured
   on the 20-core dev box: 1 worker ≈ 110× real time, 16 workers ≈ 870×
   aggregate (≈ 70k episodes/hour vs 3.8k before), flat past 16. Rules:
   `--jobs` ≤ pop × opponents (raise `--pop` to use more cores — a better ES
   gradient too); training workers never build the camera/HUD (only
   `--selftest` does, to gate that code path); GPUs enter with dh-env (tech/32
   tier 2), not this tier; gameplay bookkeeping runs per physics tick, never
   per frame (the projectile group tagging moved). The training console
   (design/25) exposes jobs + speed and states the ceiling. Also this date:
   Claude background agents/workflows are OFF by default — two workflows
   exhausted the session quota mid-flight; work runs inline unless Ricardo
   asks otherwise (CLAUDE.md, docs/harness/README.md).

40. **dh-env tier 2 landed: C++ arena + GPU PPO, local (2026-09-11, Ricardo:
   "why aren't we using modern libs like pytorch... we want sota gaming ai,
   ppo and other rl techniques... use my GPU... with a cap based on my GPU
   capacity in VRAM").** The §12.39 tier-1 loop stays (cheap ES breadth over
   Godot workers); tier 2 adds DEPTH: (a) **dh-sim arena** — a deterministic
   C++20 twin of game/arena (same 60 Hz tick, same arena.obs.v1 31 floats,
   same kits/fields/projectiles/fairness delays, native + scripted + frozen-MLP
   opponents), no Godot, no I/O (canon boundaries); (b) **dh-env C API**
   (create/reset/step/winner/destroy) consumed from Python via **ctypes**
   (nanobind deferred — zero vendored deps); (c) **specs.json is GENERATED**
   from the real Godot bodies (game/arena/tools/dump_specs.tscn) — balance
   changes reach training by re-dumping, never by hand tables; (d) throughput
   gate ≥100k steps/s/core PASSED: 216k (native) / 256k (scripted) over the
   full ctypes path; (e) **PyTorch venv** at ml/.venv (torch 2.6+cu124 on the
   RTX 4050; venv created without sudo — python3-venv STILL missing on the box,
   get-pip workaround in tools docs); **VRAM hard cap 50%** via
   ml/training/gpu_guard.py (set_per_process_memory_fraction + rollout-batch
   clamp — no OOMs by construction); (f) **PPO** (ml/training/ppo.py): GAE,
   clipped objective, factorized move/act/dodge policy, self-play = the
   learner's own frozen snapshot as the C++ MLP opponent (the past-self league
   inside the env), SAME reward shaping as ES fitness, exports schema
   "arena.policy.v1" so the Godot arena gates PPO nets verbatim (a 250k-step
   smoke net lost 0-4 there — the gate stays the honest arbiter; real runs are
   ≥5M steps). ES → PPO warm-start via from_policy_net. Also this date: arena
   creature KITS (species actives in builds.json skills[]: bolt_volley,
   radial_slam, pounce, field_cast, enrage — native fires them boss-style, bot
   policies via cmd_skill, cooldowns in obs[7..10]) and the DUO build kind
   (core.arena.the_duologue: two partnered bodies, one fighter, nearest-proxy
   targeting, alive_body()/living_proxies() guards for the freed-member crash
   class; the selftest's 4th matchup is the duo so the gate sees member-death
   mid-fight every run). Display fit (§12.38's missing entry, same date):
   ProtoDisplay.fit_windowed — largest integer 640×360 scale inside the usable
   screen rect, centered; the training console is a desktop TOOL with its own
   logical-canvas ladder (1600×900 → 960×540 by what fits) — its buttons no
   longer render outside the window.

41. **League shape + combo combat rules (2026-09-11, Ricardo: "pitch nets
   against themselves... exploit their strategies... no creature is allowed to
   be absolutely poor on skills... mobs rely on skill combos... electric AOE
   through a pool of water").** (a) PPO opponent pools are MIXED thirds —
   native / scripted / past-self snapshots — never self-play alone (the 5M
   run's 1.00 win rate vs its own snapshots was an inflated metric; vs real
   opponents the same net showed 0.05 — the honest gradient). (b) EXPLOITER
   mode: `ppo.py --exploit <policy_v1.json>` trains a dedicated counter-net
   against a FIXED main agent, registered with kind "exploiter" (AlphaStar
   league shape: mains, past-selves, exploiters; main-exploiters next). (c)
   COMBO incentives in the reward: R_KIT per cast (beats LMB spam), R_CHAIN
   for firing a DIFFERENT kit within a 90-tick window — mobs must learn
   sequencing, not spam. (d) EMERGENT FIELD INTERACTIONS (combat canon —
   both sims, parity-gated): lava fusion (fire+earth, existing) is joined by
   CONDUCT: a storm bolt inside a mire field detonates it — 2x bolt damage
   over 1.5x radius on the field owner's enemy, field consumed. In 1v1 this
   is an anti-synergy (your storm punishes THEIR mire); in 2v2 (roadmap) it
   is the ally combo Ricardo described. Fire×frost (steam?) and other pairs:
   open question, same pattern. (e) Windows cross-build unblocked WITHOUT
   sudo: portable llvm-mingw toolchain at ~/.local/share/dh-toolchains +
   sim/cmake/mingw-w64-x86_64.cmake → sim/build-windows/dh-server.exe (the
   sim has no sockets yet, so zero portability shims were needed).

42. **Audio settings: Music + SFX buses with persisted switches (2026-09-11,
   Ricardo: "include a settings option as to control audio (mute songs and
   effects for god's sake)").** The slice has no audio assets — every sound
   is synthesized (sfx.gd) and there is no music yet — so the fix is the
   seam, not a track: `ProtoAudio` (prototype/ui/audio.gd) creates the
   "Music" and "SFX" buses in code at first use, persists ON/OFF + linear
   volume per bus in user://settings.json ("audio", beside display and
   language) and applies them at every boot, menu or direct scene; all SFX
   players bind to the SFX bus; the title screen carries MUSIC/SFX switches
   above FIT/MODE. Rule: any future music plays on the Music bus, any effect
   on SFX — never on Master — so the switches keep working without
   retrofits. The MENU OK gate proves the mute reaches the mixer.
