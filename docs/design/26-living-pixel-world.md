# 26 — The living pixel world

Ricardo's 2026-09-12 direction: modern, beautiful 2D pixel art; dynamic ARPG
combat; storied artifacts; an extensible engine for weekly creatures, effects,
items and lore. Law: canon §§1, 3–4, 7 and §12.45. Implementation and runbook:
[tech/34](../tech/34-living-content-pipeline.md).

This branch implements an **offline authoring and review pipeline**, generated
art candidates, an authored chapter, and a C++ effect-command evaluator. It does
not replace the current Hunt, item roller, animation library or skill executor.
The first chapter is now playable in a separate C++-driven Codex trial
([tech/35](../tech/35-playable-living-trial.md)): Orun's five phases, the four
artifact presets, Wet/Storm and companion interactions, lore, victory and a
temporary bond. It uses the generated idle atlas plus authored movement and
telegraphs; full action-animation authoring remains pending.
The broader combat design below is a proposal for production integrations. The new rarity
rules are enforced in the candidate format; existing live items keep their IDs,
rarities and save representation until an explicit migration lands.

## What we protect

The moats in `01-vision-and-pillars.md` are interconnected: a world that expands
weekly, creatures that become companions and build ingredients, genuinely
distinctive loot, skilled combat, and an ownership economy subordinate to play.
The artistic expression is **beauty beneath the dark**: the Gloom corrupts by
making the world more luminous. A bigger sprite alone does not deliver that.

The new direction retires the console-generation/"retro" target. We retain
pixel discipline, a flat authoritative 2D combat plane, the angled top-down
camera, and the 60 FPS client target. We do not restart the engine or abandon
the existing rigs, normal maps, LUTs, pooled VFX, or source content IDs.

## Audit: reuse what already works

| Existing system | Finding from the source | Response |
|---|---|---|
| `pipeline/providers.py`, `image_backend.py` | Useful provider seams; no implicit spending on the stub path | Keep the seams; add grounded release briefs and explicit candidate generation |
| `pipeline/model_provider.py` | Model output is one static full-body region; its prompt used a front view | Correct the style/camera; label concepts honestly; add animation-sheet ingest |
| `pipeline/assemble.py`, rigs and poses | Shared rigs already bake animation cheaply | Keep them for ordinary production; authored/3D-rendered sheets use the same new ingest contract |
| `pipeline/bestiary_gen.py` | Quantity comes largely from body/tint/stat combinations | Keep systemic variety, require a new silhouette, kit, history and ecology for named bosses |
| `registries/skill_trees.json`, `player.gd` | Five prototype trees, roughly 100 actives; reusable behavior executor; status bonuses/consumption and class charges | Consolidate into fewer recognizable skill families with behavioral forks; retain the executor vocabulary |
| `session.gd` rune sockets | Rune state is tied to named prototype slots | Move to stable skill-instance IDs when the C++ loadout port lands |
| `pet.gd`, systems map | Rolled pet skills are not yet a complete executed build axis | Pet setup/payoff/command execution is a priority; new item synergies alone cannot fix this |
| `dh-content` | Committed baseline has an ID interner, not a production pack loader | Do not pretend candidate JSON is already a hot-loadable server pack |

The branch starts at committed `b3d41e9`. The original workspace includes
additional uncommitted gameplay/training work; it was intentionally left intact.

## Art direction: rich pixels, clear action

The target keyframe is [Gloamfen](../art/modern-pixel/gloamfen-target.png).
It is generated concept art, **not an in-game capture**. The first creature
candidate is Orun, the Last Bellwether: a lean moss-armored cervid carrying a
cracked bronze bell between his antlers, with a visible Lumen heart. His
silhouette and story must survive a black silhouette test at actual game scale.

Art rules:

1. **Form before detail.** Hero/ordinary-creature targets remain within the
   canon 48–128px band. This pilot uses 128px cells. Three readable masses,
   directional pose, stable feet and deliberate negative space beat noisy texture.
2. **Materials have different cluster shapes.** Broad cloth folds, angular
   bronze highlights, broken moss clusters, restrained bone highlights. Never
   "add detail" by scattering isolated bright pixels over the whole body.
3. **Light belongs to the renderer.** Albedo and emission are separate. Never
   bake bloom into a sprite's alpha silhouette. Existing normal approximations
   remain identified as approximations; this pipeline does not invent a true
   normal map from a painting.
4. **Animate intent.** Required production clips: idle, movement, anticipation,
   attack, hit, death. Each attack needs a readable tell, a precise contact
   moment and a recovery opportunity. Secondary motion follows the body.
5. **Keep one camera, anchor and scale.** The pilot accepts a declared grid,
   applies a shared scale across cells, registers their bottom centers to the
   recipe anchor and packs padded atlas rects. Foot registration helps review;
   it cannot repair changing anatomy or replace an artist's contact poses.
6. **Build for a busy frame.** Quiet floors, controlled emissive accents,
   outlined danger boundaries, distinct ally/hostile shapes. A Divine item may
   receive a richer motif; it may not cover the next attack's warning.

The automated gates measure palette adherence, alpha, nonempty cells, unique
frames, silhouette area variation, required clips and decoded atlas memory.
They cannot grade composition, taste, anatomical continuity or a "100×" gain.
The human comparison uses native-scale stills, looping animation and a crowded
combat capture at identical display size, scene, exposure and VFX settings.

## Rarity becomes a promise

Candidate ladder: **Common → Uncommon → Rare → Epic → Legendary → Relic →
Mythic → Divine**. The new format covers the four story-bearing tiers.
Creature tiers remain Normal / Elite / Legendary; they are a separate axis.
The existing `relic` equipment-slot token also remains separate from rarity.

| Rarity | Build identity | Story promise | Visual promise | Pilot effect facets |
|---|---|---|---|---:|
| Legendary | One signature change to an action | A named maker or bearer, an origin, a discovery hook | Recognizable impact and weapon motif | 1 |
| Relic | Signature plus a situational utility interaction | A surviving historical object connected to another story | Secondary rune/sigil and restrained idle identity | 2 |
| Mythic | A cross-system combination, such as field + class skill | A creature, place and artifact tell one legend | Bespoke setup/payoff motif and richer secondary motion | 3 |
| Divine | A complete, demanding build vow | An exceptional event in the Lumen/Gloom history | Distinct awakening/impact motif within the same scene cap | 4 |

**Every tier has the same 100-point candidate slot ceiling.** Conditional
effects consume points that would otherwise buy ordinary affixes. The draft
includes a conservative effect-throughput floor, but this is a lint, not a
balance model. Encounter testing must include uptime, target density,
survivability, resource loops and realistic player execution.

The sample illustrates the progression:

- **Widow's Refrain / Legendary:** a 35% melee echo; 1.5s internal cooldown;
  18 effect points, 82 ordinary-affix points.
- **Pilgrim's Bell / Relic:** adds a resource request on dodge, once per 3s;
  30 effect points, 70 affix points.
- **Canticle of the Drowned Storm / Mythic:** adds a storm hit that consumes
  Wet for up to three 25% chain requests; 54 effect points, 46 affix points.
- **Crown of the First Return / Divine:** adds a ward request on a bonded
  creature hit, once per 5s; 74 effect points, 26 affix points.

These magnitudes are draft command operands, not installed combat numbers.
The host still needs to define resource/ward units and apply the commands.
The sample's cumulative facets are a teaching example, not a rule that every
future Divine item must inherit every lower-tier mechanic.

Lore is connected data: origin, story, discoverable evidence and typed links.
Players receive usable signatures with the item; reading lore should explain
the build and unlock optional presentation or sidegrade recipes, not hide a
mandatory stat ladder. Stories never auto-promote themselves into the world
bible. A curator appends accepted events; old places and published history
are not silently rewritten by the next weekly generation.

## Skill-system proposal: prepare, exploit, relocate

Retain six active slots plus three passive slots as the canonical target;
the current prototype controls remain unchanged on this branch. Keep basic
attack and dodge immediately accessible. Organize the six-slot build around
four class/flex skills, one Bestial Skill and one companion command. A flex
slot can replace its default role; the UI teaches a recommended opening kit
instead of enforcing one rotation. Prototype-to-final input mapping needs a
separate pass because LMB/E/1–4 already carry different responsibilities.

For each recognizable skill family, offer a small number of meaningful forks:
delivery (arc, projectile, field), resource tradeoff, and interaction. Avoid
twenty differently named buttons that mostly multiply damage. Runes modify
one supported behavior; artifacts connect behaviors; Spirit Essences tune
the result; pets supply a second actor. Each layer needs a distinct job.

| Canon class | Resource/decision proposal | Example play pattern | Creature contribution |
|---|---|---|---|
| Warden | Guard earned through timed blocks/positioning | Intercept → expose → shield breach | Companion pins an exposed target |
| Reaver | Tempo earned by alternating deliberate attacks | Mark/bleed → crossing strike → finish → disengage | Pack setup creates a safe punish window |
| Hunter | Focus earned by movement and precision | Mark → reposition → piercing payoff | Command flushes enemies into the firing lane |
| Occultist | Pact capacity traded between curse and summon | Curse → pet detonation → recover a pact | Bond identity changes curse propagation |
| Elementalist | Attunement encourages complementary casts | Wet field → storm conduct → movement reset | Mireborn setup enables a different spell loadout |
| Ritualist | Resolve earned through timely support | Mark danger → protect bond → countercast | Pet pressure creates a support payoff window |

These are the six canon roles. Emberkin, Frostbinder, Gloam Mage and Veilblade
are existing prototype kits, not silently renamed or removed classes.
Attunement and Combo mechanisms already present should inform migration.

One server-side event vocabulary should serve class skills, artifacts, pets
and fields. The pilot executes trigger/tag/status conditions and emits bounded
commands. A production executor must additionally own geometry, team checks,
damage and resistance math, resource units, interruptions, scheduled echoes,
target selection, shared tick animation events and replicated presentation cues.
Effects are sorted by stable ID within a content version. Status consumption
occurs once in that order; child proc events never recursively trigger artifacts.

### Combat-feel targets for the integration playtest

All values here are proposals, not measured shipped changes:

- First meaningful enemy decision within 10 seconds of entering a Hunt;
  first build choice within 60–90 seconds. Route openings should show both a
  basic attack and a setup/payoff opportunity without a tutorial wall.
- A roughly 100ms input buffer; responsive locomotion; explicit dodge/cancel
  windows; no animation speed tricks that move authoritative contact frames.
- Distinct anticipation/contact/recovery. Start ordinary threats around
  200–350ms tells and major boss attacks around 450–800ms, then tune by video
  review and real failure patterns rather than applying one number everywhere.
- Frequent consequential decisions, not permanent screen saturation. Use
  short encounter arcs with recovery pockets and optional risk escalation.
- Small, temporary run boons alter behavior every few encounters. Carry
  forward knowledge and collected items; remove temporary run modifiers at
  extraction. No escalating permanent power ceiling or paid rerolls.
- Pet commands must execute the rolled kit with readable cooldowns. All
  species should remain bondable under the existing demand; ordinary kits
  have at least three skills, Elite/Legendary kits at least five, Legendary
  kits at most ten. Learnable combos matter more than ability count alone.

## Weekly production: one coherent chapter

Choose a relationship: a creature changed a place, a maker responded, a
technique survived, an artifact remembers. Deliver a small connected chapter
instead of a bag of disconnected generated names. The Bell Beneath the Fen
does this through Orun, Ilyra's blade, the ferryman's bell and the keeper vow.

| Day | Work | Evidence |
|---|---|---|
| 1 | Select an established season/family and a combat gap; draft lore graph | Brief references the bible and season; no new rules hidden in prose |
| 2 | Direct silhouettes/keyframes; select an art candidate | Native-size silhouette comparison and provenance |
| 3 | Complete animation and material layers; author kit/loot data | Atlas/timeline/hitbox review, typed references, budgets |
| 4 | Run simulation scenarios, capture crowded fights, revise | No proc loops; counterplay; actual CPU/GPU percentiles on reference hardware |
| 5 | Curate lore, publish patch notes, stage signed data-only packs | Content hash parity, rollout/canary and rollback to previous version |

The first three days now have reusable authoring tools, and the bounded effect
probe contributes to day four. Signing, live pack loading, game integration,
complete animation, mobile profiling and deployment remain separate gates.
The browser review's JavaScript is an offline tool and never enters mobile PCKs.

## Performance and acceptance

The sample's two decoded atlases use **1,115,136 bytes** total (about 1.064 MiB),
with eight unique 128px frames and 48 allowed colors. Its measured silhouette
area variation is 2.07%; that does not establish an anatomically clean loop.
The initial C++ fixture run measured about 3.2ns/evaluation over one million
events on this developer machine. It measures only the small command evaluator.

Proposed incremental live budgets: authoring assets up to 4 MiB decoded for
this chapter, artifact effects up to 192 requested particles/4 requested
lights in the sample loadout, and at most 0.5ms CPU + 1.0ms GPU added at the
target crowded scene. These are caps to validate, not frame-time evidence.
The existing global pool and light registry must arbitrate all characters;
per-item maxima must never be multiplied into unbounded scene allocations.

Acceptance is an actual comparison: identical Hunt seed, current sprites
beside candidates, eight-direction/contact review where required, 100 enemies
and co-op effects, and frame-time captures on the named desktop and mid-range
mobile reference devices. Until that exists, no locked-60-FPS or numerical
art-quality claim follows from this branch.

## Discoverable lairs and boss memories (Ricardo, 2026-09-12)

The generated world should hide entrances to authored boss spaces. A place,
its guardian and its artifact stories form one discoverable chapter: the bell
arch leads beneath the fen to Orun's vigil. A lair victory unlocks that guardian
in repeatable boss rush, so exploration grows a personal roster to revisit for
items. Weekly chapters expand both the world and that roster through stable IDs.

The Codex slice implements one guardian, native earned progression and a saved
local artifact collection (tech/35). Rush cycles earned bosses with short
intermissions, bounded HP pressure and partial recovery. Practice is freely
available for comparing builds. Reward cycles are intentionally generous preview
tuning; production rarity/economy balancing is a separate gate. No paid entry,
keys, random purchases or permanent power inflation are introduced.

## UI identity: the hunter's field kit (2026-09-12)

Ricardo requested more personality in the UI and approved landing the reviewed
Codex work on `master`. The first presentation pass uses obsidian reading
surfaces, clipped bronze edges, ivory text and restrained Lumen accents. The
approved shrine plate is shared by the title screen, Haven and lair collection;
a single cached CanvasItem draws the engraving. Existing class colors keep
their meaning. The Pixel Operator 8/16px doctrine (§12.31) remains authoritative
for this prototype; design/17's native-resolution typography is a future target.

`ProtoTheme` owns reusable colors, buttons, cut-metal panels, keyboard focus
and the rune-shaped volume grip. `world_frame.gd` adds decoration behind inputs;
it has no processing loop and redraws on resize. Collection cards read authored
artifact names, rarity, signature and lore; labels supplement color, and bounded
hover excerpts point toward the full stories in the encounter's Lore view.
These are saved local collection counts, not a migration of ordinary equipment.
New chapters reuse the same presentation components and authoring fields.

This is the first UI identity pass, not the final interface. Next: unique class
and Bestial Skill sigils; a connected hunter's bestiary; production gear cards
with clearly separated skill effects and story; coherent HUD ornaments, focus
navigation and touch/controller layouts. Preserve attack visibility, the six
active/three passive target, and the 60 FPS budget as those systems migrate.
Actual frames and reproduction instructions: [UI captures](../art/ui-identity/README.md).
