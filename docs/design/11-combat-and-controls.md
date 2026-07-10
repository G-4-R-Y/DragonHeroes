# 11 — Combat & Controls

> **Status:** v0.2.1 draft — 2026-07-08 (aligned with canon v0.2.1: seven canonical damage types;
> telegraph color chart deferred to [art direction](17-art-direction.md) §6.1; TTK bands aligned with
> [creatures and bestiary](13-creatures-and-bestiary.md)). Owner: combat design. Depends on
> [canon](../00-canon.md) §1, §4, §6, §7.
> Numbers marked **(proposal)** are starting values for playtesting; everything unmarked either restates
> canon or is a structural rule.

## Purpose

This document defines how Dragon Heroes *feels* to play moment to moment and how that feel survives contact
with the network. It specifies the combat pillars, movement, the damage model (types, mitigation, crits,
status effects, elemental ground fields), the exact hitbox representation on the flat 2D simulation plane,
projectile design rules,
time-to-kill philosophy for PvE and PvP, the hard constraints the 30 Hz simulation and 300 ms lag
compensation impose on designers, controls for all three input classes, camera and readability rules, and
baseline accessibility. Class kits and attribute math live in
[classes and progression](10-classes-and-progression.md); the geometry and determinism implementing
everything here live in [simulation core](../tech/21-simulation-core.md); the network behavior we design
around is specified in [netcode and hosting](../tech/22-netcode-and-server-hosting.md).

## 1. Combat feel pillars

1. **Fast.** Heroes are agile hunters: short attack windups, generous cancel windows on recovery, movement
   that never feels sticky. The pace target is Hades-school action, not Souls-school deliberation — but
   speed comes from the *player's* actions, never from unreadable enemy speed.
2. **Readable.** Every damage source is visible before it lands. Enemy attacks telegraph with a standardized
   color/shape language (§9); danger areas are drawn on the ground plane where the simulation actually
   resolves them, never implied by animation alone. If a playtester dies and cannot say what killed them,
   the encounter is wrong, not the player.
3. **Honest.** Hard bosses are hard because their patterns demand mastery, not because they cheat. Canon
   requires bosses to be "genuinely hard" — Monster-Hunter-grade hunts, not stat checks
   ([canon](../00-canon.md) §4); this doc's corollary: **a
   full-health hero never dies to a single untelegraphed hit**, lethal mechanics carry the longest
   telegraphs (§7.2), and everything is server-authoritative — the client never computes damage
   ([architecture](../tech/20-architecture-overview.md) coupling rules). Honesty also binds us: aim assist
   may help select targets, never change hit math (§8.4).

## 2. Movement

- **Base run speed: 5 m/s (proposal).** Simulation units are meters (1 tile = 1 m, [canon](../00-canon.md)
  §4), so this is 5 tiles/s. Movement input is an analog direction vector; animation quantizes to 8 facings
  ([art direction](17-art-direction.md)) but the simulation moves in true 2D.
- **Sprint: +40% speed (7 m/s) (proposal)**, engages automatically after **2 s (proposal)** without
  attacking, casting, or taking damage, and drops on any combat action. Sprint is for traversal in
  [the Hunt](12-world-and-biomes.md), not combat kiting — tying it to combat state keeps chase/disengage
  math in PvP predictable without a stamina bar.
- **Dodge: displacement-only, no i-frames (proposal — flagged for Ricardo, §Open questions).** A dash of
  **4 m over 8 ticks (~267 ms) (proposal)**, cooldown **2 s (proposal)**, usable to cancel attack
  *recovery* but not *active* frames. Rationale: with 300 ms server-side lag compensation
  ([canon](../00-canon.md) §6), i-frames create systematic "I dodged that!" disputes — the server rewinds
  hitboxes up to 300 ms to favor the attacker, so a defender's client-perceived i-frame window routinely
  disagrees with the rewound authoritative one. Displacement dodges degrade gracefully under latency: you
  either moved out of the swept area or you didn't. I-frames remain available as *explicit skill effects*
  (e.g., a Reaver phase-step) tuned case by case, where the fantasy justifies the netcode cost.
- **Facing and aim are decoupled.** Heroes strafe and backpedal at full speed **(proposal)**; attacks aim
  at the cursor/stick/smart-cast target, not the movement direction.

## 3. Damage model

### 3.1 Damage types

Seven damage types — **Physical, Fire, Frost, Storm, Venom, Umbral, Blood** — are canonical
([canon](../00-canon.md) §4): one list shared by combat, items, the VFX language
([art direction](17-art-direction.md) §7), and the content registries. Canon assigns the class mapping to
this document; the mapping, biome affinities, and signature statuses below are **(proposal)**:

| Type | Primary classes | Biome affinity | Signature status |
|---|---|---|---|
| Physical | Reaver, Hunter, Warden | all | Bleed |
| Fire | Elementalist | Cinderwastes | Burn |
| Frost | Elementalist | Palecrown Peaks | Chill → Freeze |
| Storm | Elementalist | Palecrown Peaks (storm-lashed summits) | Shock |
| Venom | Occultist | Gloamfen | Poison |
| Umbral | Occultist | Umbral Depths | Wither |
| Blood | Ritualist | Everbloom Wilds | Expose |

Damage types, like all combat numbers, are data in `content/`
(`content/core/registries/damage_types.json`, [content pipeline](../tech/23-content-pipeline.md)); adding
an eighth type later is a content-schema change, not an engine change — but the seven-type list itself is
canon and changes only through a canon revision.

### 3.2 Mitigation

- **Armor** mitigates Physical only, on a diminishing-returns curve:
  `mit = armor / (armor + K × attacker_level)`, **K = 60 (proposal)** — flat armor never reaches immunity
  and stays level-relative.
- **Resistances** (one per non-Physical type) are percentage reductions, hard-capped at **75% (proposal)**.
  Resistance penetration exists only as gear affixes ([items and affixes](14-items-loot-and-affixes.md))
  and is itself capped so capped resistance never drops below **50% effective (proposal)**.
- Which attributes feed armor/resistances is owned by
  [classes and progression](10-classes-and-progression.md); this doc only fixes the mitigation *shapes* so
  the balance sims (`tools/`) can be built early.

### 3.3 Critical hits

- Base crit chance **5% (proposal)**, base crit multiplier **×1.5 (proposal)**; both affix-extensible with
  caps: chance ≤ **50% (proposal)**, multiplier ≤ **×2.5 (proposal)** — caps defend the power cap
  ([canon](../00-canon.md) §4).
- **Damage-over-time effects cannot crit (proposal).** DoTs snapshot their damage at application; keeping
  crits out of them keeps burst identifiable and PvP TTK bounded.
- Crit rolls happen server-side per hit event using the per-system seeded RNG
  ([simulation core](../tech/21-simulation-core.md)); clients only ever see results.

### 3.4 Status effects and stacking rules

Every status belongs to one of **three canonical stacking models**, so designers never invent bespoke
stacking logic per effect:

| Model | Rule | Used by |
|---|---|---|
| **Stacking** | Independent instances up to a cap; each keeps its own timer and damage snapshot | Bleed, Burn, Poison |
| **Buildup** | Applications fill a 0–100 meter; intensity scales with the meter; at 100 a payoff triggers, the meter resets, and the target gains temporary immunity | Chill→Freeze, Shock, Stagger |
| **Strongest-only** | One instance; strongest source applies, reapplication refreshes duration | Wither, Expose, Slow |

Launch status set **(all numbers proposal)**:

| Status | Type | Model | Effect |
|---|---|---|---|
| Bleed | Physical | Stacking (cap 5) | DoT, 6 s per stack |
| Burn | Fire | Stacking (cap 3) | DoT, 4 s per stack, higher tick damage than Bleed |
| Chill / Freeze | Frost | Buildup | 10–40% slow scaling with meter; at 100: Freeze 1.5 s, then 10 s Freeze immunity |
| Shock | Storm | Buildup | −10–25% attack/cast speed scaling with meter; at 100: 1 s Shock stun, then 10 s Shock immunity |
| Poison | Venom | Stacking (cap 5) | DoT, 8 s per stack, lower tick damage than Bleed — the attrition profile |
| Wither | Umbral | Strongest-only | −40% healing received, 6 s |
| Expose | Blood | Strongest-only | −15% armor and resistances, 8 s |
| Stun / Root / Knockback | any (skill-tagged) | — | Hard CC; see PvP rules below |

- DoTs tick every **15 sim ticks (0.5 s) (proposal)**, aligned to the 30 Hz grid.
- **Bosses (Elite/Legendary tiers) are immune to hard CC** and instead expose a **Stagger** buildup meter:
  filling it triggers a short vulnerability window ([bestiary](13-creatures-and-bestiary.md) owns
  per-archetype stagger values). This keeps control classes (Warden) relevant against bosses without
  trivializing them.
- **PvP diminishing returns on hard CC (proposal):** within a 15 s window, a target's second hard CC from
  any source lasts 50%, the third grants immunity for the rest of the window. Per-mode overrides live in
  [PvP and tournaments](16-pvp-and-tournaments.md).

### 3.5 Elemental fields and field combos

Canon v0.2 adds an **elemental field-interaction system on the tile grid** ([canon](../00-canon.md) §4,
glossary "Field combo"). A field is a ground surface occupying whole tiles (1 tile = 1 m, canon §4),
applied by skills and creatures. Each field instance carries a **type, an intensity meter (0–100), and a
duration in ticks (all proposal)** — reapplication adds intensity and refreshes duration, decay drains it.
Per-tile field state lives in the chunk tile grid inside `dh-sim`
([simulation core](../tech/21-simulation-core.md)); fields deal their damage and statuses on the same
0.5 s cadence as DoT ticks (§3.4).

Launch field set **(all numbers proposal)**, named to align with the damage types (§3.1):

| Field | Type | Standing in it |
|---|---|---|
| Burning ground | Fire | Fire DoT per field tick; applies Burn at intensity ≥ 50 |
| Lava | Fire (combo product) | Heavy Fire DoT; 20% slow |
| Ice sheet | Frost | Chill buildup per field tick; dashes crossing it slide +1 m |
| Static field | Storm | Shock buildup per field tick |
| Venom pool | Venom | Venom DoT per field tick; applies Poison at intensity ≥ 50 |
| Wither mist | Umbral | Applies Wither; visually obscures targets inside (presentation only — no sim vision change) |
| Sanguine ground | Blood | Allies: minor heal-over-time; enemies: Expose |

- **Combination rules are deterministic.** Field interactions are a data-defined, order-independent pair
  table in `content/` — `source A + source B → product field` — resolved per tile on the tick both are
  present, with no RNG, so replays and RL training see identical fields
  ([simulation core](../tech/21-simulation-core.md)). The second operand may be a terrain/ground state
  rather than a damage-type field — this doc has no Earth damage type; earth is creature-applied ground
  matter. Canonical example ([canon](../00-canon.md) §4): **fire + earth → lava**. Second example
  **(proposal)**: fire + ice annihilate into a short-lived steam cloud (obscures, no damage).
- **Reading fields.** Fields render as ground-plane tile overlays in the owning damage type's hue with
  the standardized hazard-edge treatment ("persistent — stand elsewhere"), per the master color chart in
  [art direction](17-art-direction.md) §6.1/§7 — friendly-only signals mark ally-beneficial fields
  (Sanguine ground), and the reserved persistent-hazard grammar is never used for instant hits — drawn as
  the exact tile footprint the simulation tests (decals are simulation-truthful, §9). A tile about to
  convert via combo pre-flashes for **12 ticks (400 ms) (proposal)** — Pressure-class warning — so a
  combo never instantly transforms the ground under a hero's feet; any field whose per-contact damage can
  exceed the 40%-max-HP threshold obeys the Lethal telegraph rules (§7.2).
- **Movement and dodge.** Fields punish *position*, not reaction: crossing a field with a dodge applies at
  most **one field tick (proposal)**, so displacement dodges (§2) cross narrow fields cleanly; fields
  never apply hard CC by themselves — control comes only through their listed statuses and the §3.4
  stacking models.
- **Legendary duos weaponize this.** Legendary creatures may hunt in **coordinated duos** whose kits are
  authored to combine — the fire dragon + earth elemental duo painting lava tiles is the canonical hunt
  ([canon](../00-canon.md) §4). Duo kit authoring and per-creature field application live in
  [bestiary](13-creatures-and-bestiary.md); the tile-field system itself is implemented in
  [simulation core](../tech/21-simulation-core.md).

## 4. Hitboxes on the flat 2D plane

Canon fixes the representation ([canon](../00-canon.md) §1, §6): the simulation is a flat 2D top-down plane
with a scalar z-height, all combat geometry is our own code in `dh-sim` (no engine physics in the combat
path), and per-frame hitbox timing comes from the same Aseprite-exported JSON that drives client animation
(canon §7) — animation and hit data literally cannot drift apart.

### 4.1 Bodies

- Every combatant is a **circle** (default) or **capsule** (elongated archetypes: serpent, some dragons) on
  the 2D plane, plus a vertical extent `[z, z + height]`.
- Hero body radius **0.4 m (proposal)**, height **1.8 m (proposal)**. Creature radii are per-archetype data
  ([bestiary](13-creatures-and-bestiary.md)); nothing smaller than **0.25 m (proposal)** so bodies stay
  hittable at 30 Hz.
- Body hitboxes (getting hit) are honest-sized to match the sprite silhouette; hurt-dealing shapes may be
  slightly generous for the player and slightly forgiving from enemies — classic action-game asymmetry,
  tuned in playtest.

### 4.2 Melee — swept arcs with active frames

- A melee attack is a **swept arc**: origin (attacker position), radius, angular width, and a start→end
  sweep angle, evaluated only during the attack's **active frames**.
- Active frames are authored as Aseprite frame tags; the CI atlas baker exports them into the content JSON
  consumed by both client and server ([canon](../00-canon.md) §7). A designer widening an attack edits
  data, not code.
- Per active tick, the arc sector is tested against body circles/capsules whose z-extent overlaps the
  attack's z-band (§4.4). Each attack instance hits a given target at most once unless explicitly tagged
  multi-hit.
- Example light melee anatomy **(proposal)**: windup 6 ticks (200 ms) → active 3 ticks (100 ms) → recovery
  9 ticks (300 ms); recovery is dodge- and skill-cancelable, active frames are not.

### 4.3 Projectiles — swept-circle CCD

- A projectile is a circle moved along a segment each tick; collision tests the **swept circle** (capsule
  from previous to current position) against bodies — continuous collision detection, so fast projectiles
  cannot tunnel through targets between 33 ms ticks.
- Projectiles carry: radius, speed, max range or lifetime, pierce count, z-profile (flat or lobbed arc),
  and optional homing parameters (§5).

### 4.4 z-height rules (flying vs ground)

- Attacks declare a **z-band** `[z_min, z_max]`. Defaults **(proposal)**: ground-slam effects `[0, 0.5]`,
  standard melee `[0, 2.0]`, standard projectiles travel at z 1.0 with a `±0.75` hit band, lobbed
  projectiles resolve at their impact point against `[0, 2.0]`.
- **Flying creatures** (winged beast, avian, dragon archetypes) hover at z **3.0 (proposal)** — above
  standard melee. Two fairness rules keep this honest:
  1. **Attacking anchors them down:** a flyer's own attack pulls it to z ≤ 1.5 for the attack's active +
     recovery frames, so melee always gets a punish window ("swoop windows").
  2. Skills that hit airborne targets are tagged `anti_air` in content data; every class must have at least
     one `anti_air` option reachable without respec — enforced in CI by the content validator
     ([content pipeline](../tech/23-content-pipeline.md)).
- Knock-up effects set a target's z ballistically; while airborne (z > 0.5) a target cannot act and counts
  as airborne for z-band checks.

## 5. Projectile design space

Speed bands **(all proposal)**, bounded above by readability rather than by CCD (which handles any speed):

| Band | Speed | Design intent |
|---|---|---|
| Slow | 6–10 m/s | High-damage lobs and AoE payloads; always dodgeable on reaction |
| Standard | 12–18 m/s | Bread-and-butter skillshots for heroes and creatures |
| Fast | 20–30 m/s | Low damage per hit, or paired with a long windup telegraph |
| Hard cap | 40 m/s | Above this, 20 Hz snapshot interpolation (50 ms between snapshots ⇒ 2 m visual gaps) makes remote projectiles unreadable |

- **No hitscan attacks in PvP (proposal).** Everything that crosses the screen is a simulated projectile a
  defender can, in principle, move away from.
- **Piercing:** pierce count is explicit data; damage falls off **−25% per pierce (proposal)**, floor 25%.
  Piercing projectiles never also home.
- **Homing fairness:** homing is a turn rate, not a guarantee. Turn rate ≤ **90°/s (proposal)** with an
  enforced minimum turning radius of **6 m (proposal)** — a hero strafing perpendicular at base 5 m/s
  escapes any legal homing projectile. Homing breaks acquisition if the target dodges **(proposal)**. These
  bounds are schema-validated in CI so no weekly drop
  ([content pipeline](../tech/23-content-pipeline.md)) can ship an unfair projectile by accident.
- **Simulation budget:** zones target 50–80 CCU per process ([canon](../00-canon.md) §6) with hundreds of
  creatures; the data-oriented sim is expected to handle hundreds-to-low-thousands of entities per zone,
  but that is an extrapolated budget, not a proven one (July 2026 research pass; Godot's own guidance caps
  node-based approaches at "hundreds" — see
  [Godot optimization docs](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)).
  Working designer budget until load tests say otherwise: ≤ **20 live projectiles per hero, ≤ 300 per zone
  (proposal)**. Skills wanting bullet-hell density should use fewer, larger swept shapes or ground-decal
  AoEs instead of many projectiles.

## 6. Time-to-kill philosophy

**PvE — the power fantasy has a floor and a ceiling.** Boss TTK bands are owned and balance-sim-enforced
by [creatures and bestiary](13-creatures-and-bestiary.md); the numbers below restate them. At level- and
gear-parity **(all proposal)**: Normal-tier creatures die in 1–3 s individually; in a full pack of 3–8
([canon](../00-canon.md) §4) the trash bodies fall in **20–45 s** collectively, and the Elite leader is a
hunt of its own at **90–180 s solo** — Monster-Hunter pacing, with **at least 5 signature skills**
composing one coherent, learnable strategy of telegraphs, punish windows, and phases
([canon](../00-canon.md) §4). Party durations derive from 13's **+60% boss HP per party member beyond the
first**: a full party of 4 fights ×2.8 HP with ×4 damage output, putting the Elite leader at roughly
**65–125 s**. A Legendary boss carries **up to 10 skills** with a richer strategy and is tuned for a
party of 4 at **4–8 min** (13's band — roughly 6–11 min solo under the same scaling); it may hunt in a
coordinated duo that weaponizes field combos (§3.5) at **8–12 min for a party of 4** (13). Incoming
damage follows the honesty pillar: chip damage is constant pressure, but any hit dealing over **40% of
hero max HP (proposal)** must carry a lethal-class telegraph (§7.2), and nothing untelegraphed may
one-shot from full health.

**PvP — decisive but contestable.** Median 1v1 TTK target **6–10 s (proposal)**: long enough that a
mispositioned player can dodge, heal, or reverse; short enough to stay fast-paced. Implementation: a global
PvP damage scalar **0.6 (proposal)** applied to all hero-vs-hero damage, plus an optional per-skill
`pvp_coefficient` in content data for outliers — both server-readable numbers, hotfixable without a client
patch ([canon](../00-canon.md) §7). Burst floor: no combo executable inside 1 s may exceed **50% of target
max HP (proposal)**, checked continuously by the balance sims in `tools/`. Mode-specific pacing
(Gloomfall's 40 players vs 1v1) belongs to [PvP and tournaments](16-pvp-and-tournaments.md).

## 7. Designing inside 30 Hz and 300 ms

These are the network-reality rules every combat designer must internalize. The stack is canon
([canon](../00-canon.md) §6): 30 Hz fixed-tick simulation, 20 Hz delta-compressed snapshots, client
prediction for the local hero, snapshot interpolation for everything else, and server-side lag compensation
with a 300 ms hitbox history.

### 7.1 The tick is the atom

- One tick = **33.3 ms**. All combat timing — windups, active frames, DoT periods, buff durations — is
  authored in integer ticks in content data. Anything specified in milliseconds gets rounded by the schema
  validator; the minimum meaningful window is **2 ticks (~67 ms)**.
- **The sim ticks at 30 Hz; the screen never does.** Canon v0.2 locks the client at **60 FPS on all
  platforms, mid-range mobile included** ([canon](../00-canon.md) §1, §6): the renderer interpolates
  entity state between ticks and animations must never hitch. Design consequence for combat content:
  every combat VFX — telegraph decals, status effects, field surfaces (§3.5), skill effects — ships with
  a measured **frame-time budget** on GPU-driven particles (GPUParticles2D per-scene budgets, canon §6).
  "Beautiful AND optimized" is the standing directive; a skill whose VFX cannot hold 60 FPS on mid-range
  mobile is not done.
- Remote entities render from interpolated snapshots roughly **100–150 ms in the past** (50 ms snapshot
  interval plus an interpolation buffer — the same scheme netfox implements for Godot; see
  [netfox](https://github.com/foxssake/netfox)). Design consequence: never build mechanics requiring
  players to react to *each other* faster than ~150 ms, and never require sub-100 ms coordination between
  party members.

### 7.2 Minimum telegraph durations

A "reactable" telegraph must cover: human visual reaction (~250 ms) + remote-view delay (~150 ms, §7.1) +
dodge startup (~100 ms). Hence **(all proposal)**:

| Telegraph class | Minimum windup | Use |
|---|---|---|
| Pressure | 12 ticks (400 ms) | Light, non-lethal chip attacks; may be read from animation alone |
| Standard | 24 ticks (800 ms) | Any attack ≥ 15% hero max HP; requires a ground decal |
| Lethal | 36 ticks (1.2 s) | Any attack ≥ 40% hero max HP or hard CC from a boss; decal + audio cue + rim-flash |

These minimums are per-attack data fields validated in CI. RL-driven bosses
([creature AI](../tech/25-creature-ai-and-rl.md)) cannot shrink them: telegraph timing lives in the attack
definition, outside the policy's action space.

### 7.3 What lag compensation gives and takes

- The server rewinds body hitboxes up to 300 ms to validate hits from the shooter's point of view.
  Attackers on Brazilian residential connections get honest hit registration; the cost is the classic
  "killed behind cover / hit through a dodge" for defenders.
- Designer rules that follow: dodge is displacement-only by default (§2); i-frame skill effects must last
  ≥ **10 ticks (333 ms) (proposal)** so they exceed the rewind window and feel dependable; very-fast +
  high-damage projectile combinations are forbidden by the speed-band table (§5) because lag compensation
  amplifies their unfairness.
- Hit-stop, screen shake, and hit flashes are **client-side presentation only** — the authoritative
  simulation never pauses ([canon](../00-canon.md) §10 coupling rule 2). Hit-stop budget: ≤ **3 ticks
  equivalent (100 ms) (proposal)** on kills, less on ordinary hits.

## 8. Controls per input class

Cross-play is day-1 canon; ranked queues are segregated by input class (mouse+kb vs touch/controller,
[canon](../00-canon.md) §1). The loadout is 6 active skills + 3 passives ([canon](../00-canon.md) §3);
dodge and basic attack are universal and sit outside skill slots.

### 8.1 Mouse + keyboard

- **WASD movement + mouse aim (proposal)** — not click-to-move; the game is a fast action hunter, and
  decoupled strafe/aim (§2) is the skill expression. Click-to-move is revisited only as an accessibility
  option (§10, open question).
- Default map **(proposal)**: LMB basic attack, RMB skill 1, Q/E/R/F skills 2–5, Shift skill 6, Space
  dodge. **Smart-cast (cast on press at cursor) is the default**, with per-skill opt-out to targeted
  confirm.

### 8.2 Controller

- Left stick move, right stick aim; face buttons + bumpers/triggers cover basic attack, six skills, and
  dodge **(proposal)**.
- Aim assist: **soft magnetism only (proposal)** — a **15° (proposal)** cone applies target friction and a
  gentle snap at cast time. No hard lock-on in PvP modes.

### 8.3 Touch

- **Virtual stick (left thumb) + skill cluster (right thumb) with smart-cast (proposal).** Tap = cast at
  the auto-selected target; hold-and-drag = manual aim with a cancel zone; flick on the movement-stick
  region = dodge in that direction.
- Auto-aim target selection scores candidates by distance, angle from movement vector, threat (currently
  attacking you), and a stickiness bonus for the current target **(proposal)** — effectively a soft aimbot,
  which is precisely why ranked is input-segregated: touch needs this assist to be playable at all, and it
  would be unfair against raw mouse aim. Casual Hunt cross-play stays unrestricted (canon).

### 8.4 The honest-assist rule

All assists (touch auto-aim, controller magnetism) operate **only on the aim vector at command-creation
time on the client**. The command sent to the server is an ordinary "cast skill X toward direction/target
Y"; the authoritative simulation in `dh-sim` is identical for every input class — assists never touch
damage, cooldowns, hit math, or projectile behavior. This keeps the server code single-path and makes
input-class fairness a pure tuning question, not a simulation fork.

## 9. Camera and readability

- **Camera:** 3/4 angled top-down ("isometric-look", canon §1), **fixed rotation** — pixel sprites are
  authored for one camera angle, and a non-rotating camera keeps ground-decal telegraphs geometrically
  truthful. Zoom offers **2–3 fixed presets (proposal)**; PvP modes lock zoom (zoom = vision advantage).
  Maximum on-screen vision must stay inside the AOI radius so the client always has state for what it can
  see ([netcode](../tech/22-netcode-and-server-hosting.md)).
- **Telegraph color language:** the specific color assignments live in one place — the standardized
  grammar and master reserved-color chart in [art direction](17-art-direction.md) §6.1 (windup flash,
  committed-attack decal, Legendary unavoidable mechanic, persistent hazard, friendly signals). This
  document owns the *principles* the chart must satisfy:
  - **Reserved colors.** Each threat class (interruptible windup, committed attack, unavoidable
    mechanic, persistent hazard) and the friendly signal each own a reserved hue; no biome palette,
    rarity tint, or elemental VFX may collide with them (17 maintains the master chart; collisions are
    blocking bugs).
  - **Enemies never emit the friendly hue,** and the persistent-hazard grammar is never used for
    instant hits.
  - **Decals are simulation-truthful:** they always render the *simulation shape* (the actual
    arc/circle/capsule being tested) on the ground plane where the hit resolves.
  - **Meaning survives color-vision deficiency:** lethal-class telegraphs add a hatched fill pattern
    plus an audio cue (§7.2, §10), so no signal is color-only.
- **Silhouette rules:** hero, pets, creatures, and projectiles must read as distinct silhouettes at
  gameplay zoom; rarity/elemental recolors use the palette-LUT shader (canon §7) and therefore never alter
  silhouettes. Enforcement pipeline lives in [art direction](17-art-direction.md).

## 10. Accessibility baseline

Launch commitments **(proposal)**: full input remapping on all platforms; colorblind support via alternate
telegraph palettes (cheap through the existing palette-LUT shader) plus the shape/pattern redundancy above;
toggles for screen shake, hit flashes, and camera effects with a photosensitivity-safe preset;
hold-vs-toggle options for all held inputs; scalable UI/text and damage-number options; directional audio
cues mirrored to visual indicators for every lethal telegraph (each lethal telegraph is audible *and*
visible, never one only). Difficulty in PvE comes from where you choose to hunt
([world and biomes](12-world-and-biomes.md) risk/reward), so no separate difficulty slider is planned;
accessibility here means input and perception, not combat math — combat math must stay identical for
economy integrity ([security](../tech/27-security-anticheat-and-economy-integrity.md)).

## Open questions (for Ricardo)

1. **Dodge model:** approve displacement-only dodge as the baseline (with i-frames only as explicit skill
   effects), or mandate universal i-frames despite the 300 ms lag-compensation disputes? This gates the
   first combat prototype.
2. **PvP TTK band:** approve the 6–10 s median 1v1 target and the global 0.6 PvP damage scalar approach
   (vs authoring fully separate PvP numbers per skill from day 1)?
3. **Class/status mapping for the canonical seven damage types:** the seven-type list is canon
   ([canon](../00-canon.md) §4, resolving this doc's earlier five-type question), but the §3.1 mapping is
   proposal — confirm Elementalist tri-element (Fire/Frost/Storm) vs splitting Storm out, the
   biome-affinity column, and the two new signature statuses (Shock, Poison).
4. **Click-to-move:** exclude entirely, or commit to it as a PvE-only accessibility option (it cannot be
   competitive with WASD in ranked)?
5. **Hard CC in PvP:** keep Freeze/Stun with diminishing returns as proposed, or convert all hard CC to
   slows/soft CC in PvP modes only?
6. **Controller queue placement:** canon groups controller with touch in ranked (proposal status in
   canon). After aim-assist tuning, controller may prove closer to mouse+kb than to touch — approve
   revisiting the grouping with beta data, and with what metric (win-rate delta threshold)?
7. **Fields in PvP:** do elemental ground fields and field combos (§3.5) apply in PvP modes at launch?
   They pressure the 6–10 s TTK band and the 1 s burst floor (§6) and add readability load in Gloomfall's
   40-player fights — PvE-only at launch is the conservative option.

## Sources

- [Godot docs — Optimization using servers (entity-count guidance underlying the simulation budget)](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)
- [netfox — Godot netcode addon (reference for the snapshot-interpolation buffer and CSP behavior cited in §7.1)](https://github.com/foxssake/netfox)
- Internal: engine/netcode research digest (July 2026 research pass — CCU targets, entity-budget caveats), summarized in [netcode and hosting](../tech/22-netcode-and-server-hosting.md).
