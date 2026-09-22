# The world remembers — exploration and weekly narrative

Law: canon §§4, 7, 12.47–48. Requests R27–R32 in the single
[roadmap](../harness/20-roadmap.md); exact wording in the request archive.
This supplements [world and biomes](12-world-and-biomes.md),
[living pixel art](26-living-pixel-world.md) and [continuity](27-continuity-and-community.md).

Every release should answer: who lived here, what changed, why this creature
looks and fights this way, which old story it complicates, and what the hunter
can discover or influence. A weekly set contains connected lore, named material
and silhouette archetypes, a small cast/factions, a continuing thread and one
playable consequence. Not every release must introduce a war or a new faction.

## Authoring contract

The candidate manifest binds creature/skill/item IDs to lore and art, and adds a
narrative graph. Threads connect the set's creatures and artifacts. Archetypes
identify anatomy, materials and the remembered magical motif; sharing a rig must
not erase species identity. Dependencies pin earlier release JSON by SHA-256,
and meaningful typed links explain the connection: continuation, consequence,
dispute, inheritance or revelation. Missing references, duplicate IDs, dependency
cycles, changing pinned history and ungrounded content fail local validation.

An origin chapter can ground itself directly in the world bible. Subsequent
chapters must connect to prior content. Copying a template creates an explicitly
unreviewed draft with lineage, never an original story by assertion. Local build
briefs include the actual linked stories as well as the current bible and season;
build hashes include those dependencies. No network call is needed to validate,
prepare briefs or bake existing source art.

Example continuity: Orun's bell remembers Ilyra's rescues. A later caravan arrives
carrying bronze cast from the submerged ferry rail; one Haven calls it theft,
another calls it reconstruction. Hunters recover the missing ledger, escort
survivors or defend a mooring. Later chapters can introduce a faction's guardian
or an enchantment that remembers the outcome. Each new story adds context to the
old bell and its artifacts instead of replacing their power or erasing history.
This is an authoring example, not a claim that these quests are already playable.

## Roaming experience and implementation order

1. Native generation provides persistent biome identity independently of floor
   collision type. Everbloom, Gloamfen, Cinderwastes, Palecrown and Umbral regions
   use distinct floor clusters, edges, silhouettes, atmosphere and landmarks.
   Difficulty remains separate from biome identity.
2. Versioned POI templates add visible dungeon mouths, lairs, ruined shrines,
   villages and camps. Placement checks traversable approach, clear interaction
   space and separation. Existing Orun lair/rush functionality remains usable.
3. An encounter director selects data-defined quest/event templates with pacing
   budgets and cooldowns: quiet discoveries, travelers, rescues, ambushes and
   telegraphed rare bosses. Deterministic placement plus recorded outcomes stops
   reload farming. Surprises need readable invitations, not unavoidable punishment.
4. NPCs and Haven stations consume the same item/material/story references.
   Discoveries can unlock forging/enchanting recipes and earned cosmetics;
   cashable awards remain behind official server/economy authority.
5. Reviewed world-outcome branches feed the next content drop. Track actual
   encounters, not merely decorative quest markers, in acceptance receipts.

## Player and guild agency — future official-server seam

Store an append-only outcome record: event instance and definition version,
verified contributors, guild/faction attribution, chosen action, objective result,
zone and tick range, award transaction IDs and replay evidence. Idempotency keys
prevent reconnect/replay from voting or paying twice. Contribution caps and
eligibility rules need abuse simulations before a live political system.

Separate personal discovery, local zone consequence and shared season consequence.
Personal choices persist in the character journal; zone outcomes can change an
NPC's allegiance, a patrol route or a settlement service. Shared outcomes are
aggregated transparently at a published cutoff and used to select reviewed story
branches. Display what changed and why, including minority contributions and
meaningful follow-up opportunities. No season reset of characters or equipment.

Never overwrite explored base geography to force a new story. Apply versioned
deltas and reversible presentation dressing where appropriate; generate new
landmarks in virgin space. A country's conflict can bring a guardian/creature
lineage, a displaced NPC or new enchantment into the next release with explicit
causal links. Keep this world's politics fictional and grounded in its factions.

## Persistence and documentation gates

Ground loot restores the original item instance/affixes/rarity/amount after travel,
even at the creature cap or with a full bag. Collection commits once. Projectiles
continue to move and collide offscreen until their normal lifetime ends; traveling
away must not give immunity by unloading a potential target. Detailed current
prototype semantics and limits: [tech/29](../tech/29-infinite-world-streaming.md).

Every changed source file needs a continuation note describing responsibility,
inputs/outputs, invariants, callers, tests and limits. The [file notes](../reference/files/README.md)
index begins with this recovery slice; coverage must be reported honestly rather
than inventing documentation for the entire repository. Central docs own policy;
file notes point to them and explain implementation. Full catalog art completion
requires an explicit coverage report and inspected animation frames, not a count
of successfully generated JSON definitions.
