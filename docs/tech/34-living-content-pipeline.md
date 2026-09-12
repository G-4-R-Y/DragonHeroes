# 34 — Living content authoring pipeline

Law: [design/26](../design/26-living-pixel-world.md), canon §12.45.
This is an offline candidate format and review tool. The existing authoritative
production architecture and `content/` pack format remain in place.

## Run the review

From the isolated worktree (or any checkout of this branch):

The shortcut is `python3 tools/review_living.py`: validate, build C++, run
CTest, bake the review, run the compiled effect probe and print the HTML path.
The individual commands are:

```bash
python3 -m pip install -r genforge/requirements.txt
python3 tools/validate_content.py
python3 -m genforge.living.build genforge/releases/bell_beneath_fen.json
cmake -S sim -B sim/build -DCMAKE_BUILD_TYPE=Release
cmake --build sim/build -j 4
python3 -m pytest genforge/tests/test_living.py -q
ctest --test-dir sim/build --output-on-failure
```

The build prints `genforge/candidates/living/fen_bells-<hash>/index.html`.
Open that file directly in a browser. It works without a server or network:
pause the creature, compare 1×/2×, toggle emission/silhouette, inspect the four
rarities and linked lore, and preview data-defined effect anatomy. VFX preview
is presentation only, not a second combat implementation.

Run the compiled content through C++ using the **actual directory printed**:

```bash
sim/build/libs/dh-server/dh-effect-lab genforge/candidates/living/fen_bells-<hash>/effects.bin
```

Output is JSON: each dense effect handle, emitted action, bounded magnitude
and target count, cooldown and recursion outcomes, then an informational
one-million-event microbenchmark. An invalid/truncated/oversized binary fails.

## Files and boundaries

| Source | Responsibility |
|---|---|
| `content/schemas/expansion.schema.json` | Strict v1 authoring contract; no arbitrary scripts/unknown fields |
| `genforge/releases/*.json` | Weekly chapters: style, lore graph, skills, creature kits, artifacts, recipes |
| `genforge/living/validation.py` | IDs, typed refs, lore, kits, rarity facets, budgets, safe source paths |
| `genforge/living/draft.py` | New namespace and references from a template; never masquerades as authored content |
| `genforge/living/generate.py` | Explicit ImageBackend call; raw image + prompt/model/source provenance |
| `genforge/living/atlas.py` | Shared-scale animation ingest, OKLab palette, emission, atlas/tick timeline |
| `genforge/living/build.py` | Reproducible immutable candidate directory and hash manifest |
| `genforge/living/review.html` | Portable offline review; content inserted as text, escaped JS payload |
| `sim/libs/dh-sim/include/dh/sim/effects.hpp` | Pure C++ event conditions → bounded effect commands |
| `sim/libs/dh-server/src/effect_lab.cpp` | File I/O boundary and real C++ outcome probe |

`tools/validate_content.py` now validates these authoring drafts in addition
to legacy content. Missing `jsonschema` is a failure, never a skipped green
check. A valid candidate is **not** a shippable live pack. CI uploads a review
artifact and runs the Python/C++ integration gate separately.

## Start the next weekly chapter

```bash
python3 -m genforge.living.draft \
  --from genforge/releases/bell_beneath_fen.json \
  --pack fen_second_bell --title "The Second Bell" \
  --out genforge/releases/fen_second_bell.json
python3 -m genforge.living.build genforge/releases/fen_second_bell.json --brief-only
```

Edit the inherited lore, subject, mechanics, sources and season. Namespace
remapping is automation, not original authorship. The draft marks itself as
template material. Existing source art may be reused deliberately; a named
boss should not pass art review as a recolor of its predecessor.

For an explicitly configured generation provider, `generate.py` exposes the
existing `ImageBackend` protocol. It is never invoked by the build or CI.
Callers can pass any implementation programmatically; CLI `--backend` is
required and resolves through the existing provider registry. Provider calls
may incur its configured costs; missing providers/keys fail instead of falling
back to another provider. The current branch's actual artwork was generated
with the built-in image tool, not the CLI/API path.

Generated sources remain quarantined. Inspect alpha, layout and continuity,
then update the recipe's `source`, `prompt`, grid and provider provenance.
The same ingest stage accepts a coherent rig bake, edited pixel sheet or
3D-to-sprite render. It does not require any one model, vendor or mesh method.

## Asset contract

Each source has a declared cell grid. Providers sometimes return dimensions
that do not divide evenly; rational grid boundaries assign each input pixel
to exactly one cell. No hidden stretching to a requested image resolution.
One common scale preserves relative cell size; bottom-center registration
uses the declared normalized anchor. This is appropriate for the pilot's
planted idle, not a substitute for authored root motion or flight anchors.

The quantizer selects nearest palette colors in OKLab after binary-alpha
thresholding. It emits albedo and a separate selected-color emissive mask,
with two transparent pixels around atlas cells. Normal maps are optional
future inputs; the pipeline does not advertise image-derived approximations
as physically correct normals. Requested emission colors must exist in the
palette and remain inside the albedo silhouette.

Clips preserve source frame indices and expose rects, FPS, loop flags and
30Hz frame durations. Timeline rounding distributes ticks at frame rates
that do not divide 30 evenly. A later combat integration must attach reviewed
contact/hitbox events to this same timeline, never derive hitboxes from sprite
size or infer contact from generated art.

Hard errors: malformed schema, duplicate/incorrect IDs, missing or mistyped
references, paths outside the repo (including symlinks), impossible frames,
empty/opaque rectangular sources, unsafe budgets. Missing production clips
and silhouette variation become explicit review blockers. Every build always
retains human review, target-device capture and integration/balance blockers.
There is deliberately no `--approve` shortcut or publication endpoint.

The identity hashes canonical release JSON, source files, pipeline sources,
schema and Pillow version. Output uses no timestamps or absolute source
paths. Repeated builds on the same toolchain are byte-reproducible; use the
same Python/Pillow toolchain for exact cross-machine comparison. Images from
a generative model are not claimed reproducible; the accepted source bytes
are the reproducibility boundary. Existing output corruption is detected,
and completed bundles are published by atomic directory rename.

Hashes detect content changes/corruption. They are not an authenticity
signature and do not replace signed manifests for eventual public release.
The browser review includes JavaScript; the future production exporter must
export only game data/assets, never copy the whole review directory into a PCK.

## Effect program DHE1

Wire layout, explicitly little-endian:

- Magic `DHE1` (4 bytes), count `u32` (1–64).
- Each effect: nine `u32` operands: trigger, tag mask, required-status mask,
  consumed-status mask, action, magnitude in permille, cooldown ticks,
  max targets, candidate budget.
- No trailing bytes. String IDs sorted into `effects.index.json` provide
  deterministic handles for this particular content version.

v1 trigger order: hit, dodge, pet_hit, field_combo. Action order: echo,
chain, burst, resource, ward. Tag/status bit order is in `validation.py` and
must remain append-only within a format version. IDs survive releases;
dense numeric handles must never be persisted across different content hashes.

The host owns cooldown state per owner and effect ID, and must preserve it
across re-equipping until it expires. An authoritative root event supplies
tags, statuses and tick. Matching consumes the named status, advances the
internal cooldown, and emits at most one command per evaluation. Any event
with nonzero proc depth is refused, so procs cannot recursively generate procs.
Integer tick overflow exhausts the state rather than making it fire endlessly.

**Integration boundary:** the evaluator does not select targets, schedule an
echo, subtract HP, grant real resources, spawn a field or mint an item. The
server must apply those commands to its world and emit presentation cues.
The probe tests the implemented boundary, not an imaginary complete ARPG.

## Production integrations still required

1. Resolve approved definitions into `dh-content` typed tables; wire root
   events from skills/pets/fields and execute bounded commands in `dh-sim`.
2. Add gameplay tests for timing, team/target validation, resource units,
   status ownership, loadout caps, interruptions and replay hashes.
3. Complete directional/attack animation and contact-event authoring. Review
   actual Hunt captures with the existing lighting, LUT and pool system.
4. Migrate item rarity/save/UI/loot schemas deliberately; existing item IDs
   and the `relic` slot cannot change meaning. Candidate rarity never changes
   drop odds or economy tables on its own.
5. Compile signed data-only client/server packs, enforce version parity,
   stage/canary/rollback, then accept lore into the world bible.

These are tracked in the single roadmap, not silently treated as complete.
