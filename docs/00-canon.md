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
