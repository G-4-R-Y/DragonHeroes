# 35 — Play the living-content candidates

Ricardo, 2026-09-12: “where do I review what's up for review before being
playable? generate a binary with them so I can test it out.” This promotes
the first chapter into a playable **Codex trial**, with a C++ simulation and
Godot presentation. Law: canon §12.45, design/26, tech/34.

## Open the trial

Unzip the new Codex Linux or Windows package, keep `dh-server(.exe)` beside
the client, run `dragon-heroes-codex`, and click:

**PLAY NEW CONTENT: THE BELL BENEATH THE FEN**

No character creation or account is needed for this button. Trial state is
temporary; it does not add candidate items to existing saves or the economy.
The main menu still leads to the normal Hunt separately.

| Input | Trial action |
|---|---|
| WASD / mouse | Move / aim |
| LMB or Space | Melee cut; Legendary+ can echo it after nine simulation ticks |
| Shift or RMB | Reed Step: dash with eight ticks of invulnerability |
| Q | Mire Chime: spend Lumen to mark enemies Wet |
| E | Storm Toll: aimed lightning; Mythic/Divine consumes Wet for chain damage |
| R | Command the companion: hit + Wet setup; Divine grants a ward |
| 1–4 or artifact buttons | Equip Legendary, Relic, Mythic, Divine presets |
| L / mouse wheel | Pause and read artifact/Orun lore / scroll |
| Enter | Restart the trial |
| F after victory | Bond Orun; move around and watch him follow |
| Esc | Return to the main menu |

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
python3 tools/package_codex.py all
python3 tools/check_living_preview.py --package builds/codex/linux
python3 tools/check_living_preview.py --capture
```

The packager stages content **before** C++ compilation and Godot import. It
exports fresh clients/helpers, verifies file hashes and native icons, tests
the exported normal Hunt and the exported trial, then writes the ZIP. No
image service or other paid call runs during rebuilding. `--capture` uses
windowed OpenGL; test/capture files live under `genforge/candidates/playable/`.

Native gates: `ctest --test-dir sim/build --output-on-failure`. Python gates:
`python3 -m pytest genforge/tests/test_playable.py genforge/tests/test_living_transport.py -q`.
The transport test requires the native build; the CI simulation job runs it.

## Weekly authoring seam

`genforge/releases/bell_beneath_fen.json` remains the source for the creature,
skills, artifact facets, rarity budgets, VFX colors/timing and lore. Trial
tuning and phase verbs are in `genforge/playable/fen_bells.json`, validated by
`content/schemas/living-preview.schema.json`. This v1 host supports one
five-verb boss kit, one hunter, one companion, three wisps, four artifact
presets and up to eight effect definitions. Configurations can use one to eight
phases; this chapter uses all five authored skills in order.

Effect roots currently cover melee/storm hits, dodge and companion hits, with
Wet as the supported status condition. Non-chain effects target one actor.
The stager rejects unsupported trigger/tag/status combinations,
unknown/unimplemented actions, missing creature references,
missing authored phases, unsafe numbers and schema drift. It emits:

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
client/helper definitions are refused. Snapshots carry 439 floats (1,776 bytes
including their header). Godot interpolates the authoritative positions and
renders the limited cue arrays, with no node-per-particle or gameplay solver.

Input silence pauses the host after 250 ms; twelve seconds without valid
input exits it. Leaving the scene sends stop, closes the socket and terminates
the owned child if it is still running. Losing application focus or opening
lore pauses simulation. This is a **local preview transport**, not the planned
public multiplayer/netcode or secure production server deployment.

The staged trial textures occupy **7,573,376 decoded RGBA bytes** against an
8 MiB cap (shrine, Orun albedo/emission, hunter and wisps). The inspected
1280×720 OpenGL capture measured **60 FPS**, about **2.09 ms** process-frame
CPU time and **85 draw calls** on this desktop. Peak presentation `_draw()`
CPU in that short run was 3.08 ms; the C++ fixture was approximately 105 ns
per simulation step. These are separate measurements, not a mobile or
sustained worst-case performance claim.

## Remaining production work

The new Orun sprite currently has the eight-frame idle loop. Movement and
attack intent are demonstrated with authoritative footwork, sprite translation,
hazards and VFX; authored directional/attack/hit/death clips are still pending.
The companion, class-like abilities and bond in this trial are a review slice,
not a migration of all existing classes, pet saves or skill trees. Full Hunt
integration, save/loot migration, multiplayer/authority deployment, full action
animation, final balance and mobile profiling remain tracked in the roadmap.
