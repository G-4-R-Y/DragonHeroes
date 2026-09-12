# 27 — Permanent heroes, weekly builds and community worlds

Status: approved direction, staged implementation. Canon §12.47. Demand ledger:
[R01–R26](../harness/20-roadmap.md); [full prompts](../harness/requests/2026-09-12-recovery.md).
This spec extends existing classes/items/PvP/modding contracts, without claiming
that the prototype already runs an official marketplace or public server.

## Sequence and acceptance

1. Finish the playable 2D foundation: action animation, readable HUD/options,
   companion cards, streaming/hibernation, varied biomes, player and Orun-style
   creature art. Gate: real Hunt journeys, identity-preserving revisits, GL
   frames and bounded per-frame/pool budgets.
2. Deliver a weekly enchantment pack and permanent XP/cosmetic loop. Equip an
   item, demonstrate actual native trigger effects and class/pet setup/payoff,
   save/reload ownership, and acquire cosmetics through multiple play routes.
   Haven adds NPC services, salvage and earned-material fixed-rarity crafting.
3. Add community submission/promotion and character-provenance tooling. A
   sample pack must survive schema, rights/credit, compatibility, art and
   balance checks; invalid or unsigned packs cannot become official awards.
4. Prototype deliberate PvP, rating/bot eligibility and guild objectives in
   native testable modules. Measure capacity in steps; official production
   service deployment needs the existing backend/security gates.
5. After the 2D gates, improve Rebirth's actual fight and local 3D asset path
   for CPU/6 GB GPU use. Generate, import and render real assets; distinguish
   tested Godot/native builds from any Unreal installation limitation.

## Enchantments are behaviors

One data definition describes `id`, version, story, rarity eligibility, trigger,
conditions, chance, cooldown, effect primitives, stat budget, VFX/SFX/animation
reference and PvP tuning. An item instance stores rolled enchantment IDs and
rolls, not executable scripts. Refer to stable learned skill tags for synergies,
not translated names. C++ interprets a finite, validated command vocabulary.

First pack vocabulary: verified hit → ignite, lifesteal, bounded chain lightning,
delayed meteor/meteor shower, impact thunder, short-lived AI clone; skill cast
→ echoed or granted active; Wet + Storm → chain, Bleed + harvest → sustain,
Exposed + heavy strike → payoff. These are explicit effects, not tooltip claims.

Every proc carries its source cast/owner/target and a lineage ID. Defaults:
procs cannot proc other procs, misses grant nothing, one target cannot be hit
twice by one chain, leech uses damage actually dealt, clone output is budgeted
and cannot create recursive clones or drops. A bounded event queue, fixed
targets, internal cooldown and one damage budget cover simultaneous triggers.
Effect invalidation, unequip, death, pause, save/load and multiplayer authority
are outcome gates. Clone AI uses the existing policy seam; it never invents
input authority or a second item owner.

Common→Epic establish an understandable core behavior. Legendary/Relic/Mythic/
Divine combine more authored facets, history and visual motifs within the same
slot ceiling. Rare does not mean mandatory for viability. Balance older item
combinations against new packs; retain versioned migration notes and replays.

## Endless experience without disposable equipment

The capped hunter continues earning a mastery counter and cosmetic caches.
Each cache is earned exclusively from play, has visible contents/odds and
duplicate protection; exhausted collections award cosmetic crafting materials.
No cash value, tradability, paid keys, paid XP boost into random caches, or
conversion to combat materials. A deterministic choice reward is a compatible
alternative for players who dislike random reveals. Cosmetics include auras,
wings, trails and weapon motifs with clear combat readability constraints.

Separate ordinary hunter-level rarity progression from lifetime mastery luck.
Candidate luck curve: `1 + b * xp/(xp + k)`, never an unbounded multiplier.
Starting experimental ceiling `b=0.15` is a maximum relative shift of selected
rarity weights, not +15 percentage points of Legendary chance. Normalize once;
never override encounter-specific exclusions or guaranteed reward identity.
Simulate 100/1,000/10,000-hour accounts, new-player value, total item supply,
bot farming and weekly-content demand before enabling mastery luck officially.
Infinite XP does not imply infinite finite-width numbers: store a rolling
remainder plus decimal-text lifetime milestones, validate on load, and avoid
float precision loss or overflow. No UI promise of an infinite stat ceiling.

## Deliberate fast PvP

Keep movement and short basic attacks responsive. Powerful effects announce
their direction/area, commit their user for a defined interval and provide a
punishable recovery. Separate PvP data tuning from PvE spectacle. Pilot ranges:
0.35–0.6 s hostile heavy/meteor tells, 0.15 s input buffer, short defense/parry
window, and bounded resource/cooldown spending. These numbers are proposals,
not blanket latency guarantees. Test at realistic RTT and mobile readability.

Elemental combinations must expose both a setup and a response: Wet conducts
Storm but can be cleansed, stationary fields can be left or displaced, a clone
has a distinguishable silhouette and limited lifetime, reflects/wards counter
predictable projectiles. Never hide lethal PvP effects in cosmetic particles.
Team contribution includes control, protection and objectives, not just DPS.

## Community content and official continuity

Open code + content tooling → mod sandbox → voted nominations → reviewed,
signed official pack → official compatible servers. Community votes are a
discovery signal; preserve authorship, licensing consent, moderation and
balance/security review. Do not silently relicense the existing proprietary
art as part of the open-source code promise.

An official character can be forked into a local/modded save at any time.
The fork keeps its story/name/appearance where rights permit; it does not
rewrite the verified official character. Returning resumes the official branch.
Untrusted local XP, gear, luck, cosmetics and trade claims cannot be imported
merely because their item IDs match official content. A conversion preview
shows retained identity and quarantined local progression without deleting it.
Verified online solo play can progress the official branch normally.

## Guilds, bots and ranking

Territories create scheduled objectives, supply routes and defense windows.
Alliances support raids; contested bosses use explicit ownership and reward
rules. Raid contribution includes mechanics, control/support and survival;
pure damage ranking encourages neglecting the encounter. 100v100 requires
measured 20v20 then 50v50 then 100v100 simulation/AOI/client-crowd gates.

AI competitors have stable identities such as `DarkLord [AI]`, authored build
themes, a frozen policy/content hash per match and public AI labels. Weekly
meta exploration can propose builds; promotion needs replay and balance gates.
The player knows when matchmaking offers AI. Start with a separate exhibition
ladder; bots cannot take cash prizes or generate official tradable loot.
They may occupy visible exhibition ranks without displacing human awards.

Skill rating is an estimate, not XP. Use the existing Glicko-2 direction with
rating deviation/volatility, adequate distinct opponents and uncertainty-aware
placement. Equal-skill 100-match and 10,000-match populations should converge
to similar skill estimates; more play improves confidence, not an unlimited
score. Test repeated opponents, win trading, easy-bot farming and intentional
deranking. A separate activity badge can honor dedication without inflating
MMR. Seasons retain character progress and may refresh presentation/confidence;
bounties reward objectives/cosmetics, not raw rank accumulation or paid stakes.
Algorithm context: [Microsoft's skill-and-uncertainty explanation](https://www.microsoft.com/en-us/research/project/trueskill-ranking-system/).
