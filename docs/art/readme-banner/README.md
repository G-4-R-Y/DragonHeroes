# Dragon Heroes README banner

[Final banner](dragon-heroes-banner.png) — 2172 × 724 PNG (3:1). The root README
references this file directly with descriptive alt text. Promotional key art, not
a gameplay screenshot.

## How it is made

```sh
python3 -m genforge.pipeline.readme_banner \
        --out docs/art/readme-banner/dragon-heroes-banner.png   # rebuild
python3 -m genforge.pipeline.readme_banner --check              # verify committed == source
```

`--check` is the gate: it re-renders in memory and compares the hash against the
committed PNG. No network, no API key, fixed seeds — byte-identical on every run.

## Why a compositor and not a new generation

v1 (`plate-v1-genai.png`, built-in `image_gen`, 2026-09-12) got the world right
and one thing badly wrong: a monumental dragon head floating on the horizon,
which the v1 prompt had explicitly asked for. Ricardo's call on it (R76):

> I liked the vibe, but the giant dragon head in the horizon is bizarre and
> hallucinated lol / Perhaps use our new quests themes to represent stuff! The
> heroes party and spirit dog vibe was neat, tho, keep that. Reminds me of lord
> of the rings journeys - companionship and adventure

Re-rolling the whole prompt would have gambled the party, causeway, citadel and
moon that he asked to keep, and would have produced an image no later session
could reproduce. So the right third — and only the right third — is repainted in
code. **A banner only one session can reproduce is not an asset, it is a lucky
file.**

## What v2 changes

| | |
|---|---|
| **Kept** | the party of three + spectral wolf, the lantern causeway, the citadel and its waterfalls, the moon, the title and its rule, every ruin left of x ≈ 0.68 |
| **Removed** | the monumental dragon: wing, head, horns, neck and the waterfalls drooling off its jaw |
| **Added** | Orun's bell tower (lit belfry, broken crown, keepers' windows), Ilyra's ferry and its two lanterns, drifting Lumen motes, two *small* distant wyrms, three hazed terrain ridges with broken ruin towers |

The new imagery is the chapter's own, from
[`genforge/releases/bell_beneath_fen.json`](../../../genforge/releases/bell_beneath_fen.json)
— *The Bell That Refused the Gloom* and *The Second Stroke* — so the banner
advertises the living world rather than a mascot.

## What the repaint had to get right

Four lessons, each paid for by a bad render and each recorded in the module's
docstrings so the next session does not repeat them:

- **Flat fill is the tell, not the seam.** The plate's sky carries a
  high-frequency σ of 20–30 grey levels; the first clean repaint came back at
  0.9. Smooth fill beside painted texture reads as a hole however well its edges
  are feathered.
- **But σ is a diagnostic, not a target.** Tuning grain until the numbers matched
  produced visible burlap. The plate earns its σ from painted structure — rain,
  foliage, masonry — and noise buys the same number with none of the meaning.
- **Distance washes toward the sky; it does not darken.** Stacking ever-darker
  silhouettes measured 10–20 levels under the painting and dug a hole exactly
  where the composition wanted light. The fix was an aerial-perspective pass.
- **Silhouettes composite; fills do not.** An earlier bell modelled in three
  tones of bronze read as vector clipart on an oil painting. A dark shape with
  light coming through it has no fills to compare against — which is also how
  the plate's own ruins are lit.

Fog is laid *across* the old/new boundary rather than up to it: feathering only
converts a hard seam into a soft one, while atmosphere that ignores the boundary
leaves nothing to betray.

## Files

| File | What it is |
|---|---|
| `dragon-heroes-banner.png` | the shipped banner (generated; `--check` gates it) |
| `plate-v1-genai.png` | the v1 generation the composite is painted over |
| `prompt.txt` | v1 verbatim (with the offending line marked) **+** the corrected v2 prompt |
| `provenance.json` | hashes, pipeline path, reproduce/verify commands, plate lineage |

`prompt.txt`'s v2 section has not been run through any image model. It is carried
for the day the paid path runs behind the
[`ImageBackend`](../../../genforge/pipeline/image_backend.py) seam, so that
regeneration starts from the corrected brief instead of from v1's mistake.

Direction: [the living pixel world](../../design/26-living-pixel-world.md), with
the turquoise Lumen identity of the application icon. Existing repository art
licensing applies.
