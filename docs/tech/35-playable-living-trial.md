# 35 — Play the living-content candidates

Ricardo, 2026-09-12: “where do I review what's up for review before being
playable? generate a binary with them so I can test it out.” This promotes
the first chapter into a playable **trial**, with a C++ simulation and
Godot presentation. Law: canon §12.45, design/26, tech/34.

## Explore, unlock and farm

Run the Linux or Windows executable with `dh-server(.exe)` beside it.
Choose **PLAY NEW CONTENT: LAIRS & LEGENDS**, then **EXPLORE SHRINE ENTRANCES**.
This guided Hunt uses seed 42 and starts beside the first generated doorway.
Normal solo Hunts also contain seeded lair entrances. Follow the bell bearing
and press **G** near the arch to enter its guardian's arena.

The first guardian is **Orun, the Last Bellwether**. Defeat him in his lair to
unlock him in **BOSS RUSH** and earn an artifact. ESC returns you to the exact
paused Hunt: position, seed, enemies and loaded chunks are preserved. Solo lairs
currently pause the local Hunt; P2P parties cannot enter this preview flow.

The **LAIRS & LEGENDS** menu displays saved lair/rush victories and your earned
collection. Start rush with an unlocked guardian; each victory earns another
artifact. ENTER continues through the unlocked roster, wrapping into another
round. This chapter contains one guardian, so the roster currently repeats Orun.
HP rises 10% per completed round to a 150% cap; between rounds, restore 35% of
maximum hunter HP and refill Lumen. These are data-authored preview values.
Defeat/retry resets the current run; already earned artifacts remain saved.

Every fourth clear completes a visible Legendary → Relic → Mythic → Divine
reward cycle, then repeats. These generous, deterministic review rewards let
you test each behavior; they are not production rarity odds. The initial
Legendary blade is available as a starter; the other presets become equippable
when earned. Higher tiers retain the common 100-point power ceiling.

**PRACTICE THE BELL SHRINE** keeps all four presets available and grants no
items or unlocks. No online account is needed. The native host saves the local
trial collection to `user://lair-collection-v1.txt`, separately from regular
Hunt equipment and all cashable economy state.

| Input | Trial action |
|---|---|
| WASD / mouse | Move / aim |
| LMB or Space | Melee cut; Legendary+ can echo it after nine simulation ticks |
| Shift or RMB | Reed Step: dash with eight ticks of invulnerability |
| Q | Mire Chime: spend Lumen to mark enemies Wet |
| E | Storm Toll: aimed lightning; Mythic/Divine consumes Wet for chain damage |
| R | Command the companion: hit + Wet setup; Divine grants a ward |
| 1–4 or artifact buttons | Equip owned presets; all four are available in practice |
| L / mouse wheel | Pause and read artifact/Orun lore / scroll |
| Enter | Continue after victory; retry after defeat or restart the active fight |
| F after victory | Bond Orun; move around and watch him follow |
| Esc | Return to the retained Hunt, or to the collection menu |

Try all four artifacts. Widow's Refrain repeats a deliberate melee strike;
Pilgrim's Bell adds a dodge resource refund; the Canticle adds Wet-consuming
chains; the Crown adds a companion-triggered ward. Counters below the artifact
buttons count procs across the current attempt. Cooldowns and existing effects
survive swapping; changing rarity cannot reset internal cooldowns. Higher
tiers spend more of the shared 100-point slot budget on mechanics and leave
less for ordinary damage. These are **preview tuning values**, not ranked balance.

Orun cycles through all five authored skills: pools, a targeted storm,
telegraphed lateral leap, a double sweep, and a ward with an exposed recovery.
Bellbound wisps provide additional chain targets. Orange rings warn before
damage; turquoise pools apply Wet. Dodge the tell, set up Wet, then strike
during recovery. Win/lose/retry and the temporary bond happen in the C++ host.

[Actual trial capture](../art/playable-shrine/trial-capture.png).
The new backdrop's [source prompt/provenance](../art/playable-shrine/README.md)
are preserved. The online-looking world is entirely local in this trial.

## Review definitions without playing

Every archive also contains **`content-review/index.html`**. Open it directly
to inspect the atlas animation, emissive layer, artifact facets, connected lore
and remaining content blockers. In the checkout, run:

```bash
python3 tools/review_living.py
```

That command prints the current immutable review directory. It is separate
from the playable trial; neither interface marks assets approved for live release.

## Rebuild and verify

```bash
python3 tools/stage_living_preview.py
python3 tools/package_build.py all
python3 tools/check_living_preview.py --package builds/linux
python3 tools/check_living_preview.py --capture
python3 tools/check_lair_journey.py --package builds/linux
python3 tools/check_lair_journey.py --capture
```

The packager stages content **before** C++ compilation and Godot import. It
exports fresh clients/helpers, verifies file hashes and native icons, tests
the exported normal Hunt, practice trial and complete lair/unlock/rush journey, then writes the ZIP. No
image service or other paid call runs during rebuilding. `--capture` uses
windowed OpenGL; test/capture files live under `genforge/candidates/playable/`.

Native gates: `ctest --test-dir sim/build --output-on-failure`. Python gates:
`python3 -m pytest genforge/tests/test_playable.py genforge/tests/test_living_transport.py -q`.
The transport test requires the native build; the CI simulation job runs it.

## Weekly authoring seam

`genforge/releases/bell_beneath_fen.json` remains the source for the creature,
skills, artifact facets, rarity budgets, VFX colors/timing and lore. Trial
tuning and phase verbs are in `genforge/playable/fen_bells.json`, validated by
`content/schemas/living-preview.schema.json`. The v2 catalog supports one to eight
lairs with stable `pack.lair.name` IDs. Each references an authored creature,
one to eight phase verbs, boss HP, placement salt/region size and a reward
cycle of authored artifact IDs. Distinct guardians use their own generated
atlases; the bounded five-verb interpreter, shrine presentation, hunter,
companion and three wisps are shared. Four artifact presets and up to eight
effect definitions remain the pilot's bounds. New rooms/verbs need corresponding
presentation/behavior primitives; changes within the supported catalog are data.
Duplicate IDs, missing rewards and out-of-bounds tuning fail staging.

Effect roots currently cover melee/storm hits, dodge and companion hits, with
Wet as the supported status condition. Non-chain effects target one actor.
The stager rejects unsupported trigger/tag/status combinations,
unknown/unimplemented actions, missing creature references,
missing authored phases, unsafe numbers and schema drift. It emits:

- `sim/libs/dh-content/include/dh/content/lairs.generated.hpp`: shared native
  lair/phase/reward catalog, stable artifact IDs and rush tuning.
- `sim/libs/dh-sim/include/dh/sim/living_content.generated.hpp`: compiled
  effect definitions, artifact masks/affix budgets, phase tuning and parity stamp.
- `game/living/generated/`: atlas albedo/emission/rects and display-only chapter
  metadata. No duplicated combat rules in GDScript.

Changing lore, existing effect combinations, their colors/timings, phase order
or tuning requires data edits and the same staging command. New combat verbs
require a versioned implementation; the stager fails instead of advertising
an unsupported effect as playable. Exact image bytes remain dependent on the
recorded Pillow toolchain; simulation parity hashes authoring data independently.
CI checks that the committed C++ tables match current authoring data.

## Host and budgets

`LivingTrial` is a pure C++ fixed-30-Hz state machine with bounded arrays:
four enemies, twelve hazards, thirty-two visual cues and sixteen delayed echoes.
It resolves targets, applies damage/resources/wards, consumes Wet once, retains
owner cooldowns and never routes child damage back through root triggers.
The helper's `--living-preview` mode runs it; normal world-generation commands
remain available in the same executable.

The presenter binds an ephemeral loopback UDP port and launches the helper
with that port and a random session token. Only that loopback endpoint/token
can supply bounded, finite, monotonically sequenced input. Packets use explicit
little-endian fields, a version magic and a simulation-data stamp; mixed
client/helper definitions are refused. Snapshots carry 452 floats (1,828 bytes
including their header). Godot interpolates the authoritative positions and
renders the limited cue arrays, with no node-per-particle or gameplay solver.

Discrete retry/bond/continue commands remain pending until acknowledged; the
host retains impulses across packet batching, pause and save retries.
Input silence pauses the host after 250 ms; twelve seconds without valid
input exits it. Leaving the scene sends stop, closes the socket and terminates
the owned child if it is still running. Losing application focus or opening
lore pauses simulation. This is a **local preview transport**, not the planned
public multiplayer/netcode or secure production server deployment.

The staged trial textures occupy **7,573,376 decoded RGBA bytes** against an
8 MiB cap (shrine, Orun albedo/emission, hunter and wisps). The inspected
1280×720 OpenGL journey capture measured **60 FPS**, **2.033 ms** process-frame
CPU and **89 draw calls** on this desktop; peak doorway draw CPU was 277µs.
The final practice capture measured 60 FPS, 1.52ms process CPU, 85 draws and
745µs peak presentation draw CPU. Actual frames and metrics:
[the lair journey](../art/lair-journey/README.md). These separate short samples
are not sustained worst-case or mobile performance claims.

## World placement and saved outcomes

`dh-procgen/lairs.hpp` emits at most eight entrances per chunk, choosing one
chunk per lair per seeded region and a clear 5×5 walkable pad. Central regions
use chunk (0,0) for discoverability; regions with no valid pad omit the entrance.
Negative coordinates use floor division. Terrain tiles and generator version
are unchanged; POI metadata has its own version. Godot follows the chunk
load/unload lifecycle, clears visual props around pads and renders the arch
and bearing. Later placement changes need a POI-version migration for persistent
worlds. The current procedural world has no full persistent POI-delta store.

`LairCampaign` owns earned eligibility, reward rotation, equipment availability,
once-per-victory grants and rush progression. It only observes `LivingTrial`
outcomes; controller packets have no grant/unlock operation. The host validates
that a lair-mode entry exists in the supplied seed/chunk; rush checks saved
victories. Hunt movement and proximity remain the existing prototype harness,
so this local bridge is not public-server anti-cheat or multiplayer deployment.

Windows helpers accept UTF-16 command lines, convert explicitly to UTF-8 and
open native Unicode paths for both world dumps and the collection.
Only `dh-server` reads/writes the collection. Records use stable lair/artifact
IDs rather than array indices; appended catalog entries start empty. Writes
hold an OS-exclusive profile lock and use flushed temporary files followed by
atomic replacement. Duplicate, unknown, oversized, truncated or invalid records
fail closed and preserve the file. Unknown IDs require migration before loading
an older executable. Save failure pauses advancement and retries while the fight
is open. This local file is user-editable and has no online/cashable value.

Gates include actual ordinary-input fights, no grants from practice/death or
locked rush, single grants across repeated victory ticks, bounded difficulty,
clear deterministic entrance pads, exclusive save writer/reopen/corrupt records,
invalid/stale input and nonexistent entry rejection. The exported journey drives
G at a doorway, wins, verifies saved loot/unlock, returns to the same Hunt,
restarts the helper for rush, earns the next item and advances to round two.

## Remaining production work

The new Orun sprite currently has the eight-frame idle loop. Movement and
attack intent are demonstrated with authoritative footwork, sprite translation,
hazards and VFX; authored directional/attack/hit/death clips are still pending.
The companion, class-like abilities and bond in this trial are a review slice,
not a migration of all existing classes, pet saves or skill trees. Regular Hunt gear/class/pet migration, multiplayer/authority deployment, full action
animation, final balance and mobile profiling remain tracked in the roadmap.
