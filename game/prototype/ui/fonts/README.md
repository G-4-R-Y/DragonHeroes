# Pixel Operator — UI pixel fonts (asset provenance)

- **Author:** Jayvee Enaguas (HarvettFox96)
- **License:** CC0 1.0 Universal (public domain) — see `LICENSE.txt`
- **Source:** https://fontlibrary.org/en/font/pixel-operator (zip fetched 2026-07-17)
- **Files:**
  - `PixelOperator8.ttf` — native **8 px** grid (ascent 7 / descent 1). Small UI
    text: buttons, chips, tooltips, HUD stat/hint lines.
  - `PixelOperator.ttf` — native **16 px** grid (ascent 13 / descent 3). Display
    text: panel titles, damage numbers.

Both files were verified headless (Godot 4.6 `FontFile.has_char`) to carry the
full PT-BR diacritic set (á à â ã ç é ê í ó ô õ ú ü + uppercase). Decorative
glyphs the prototype uses (◆ ◇ ◈ ← → ▸ ⟡ §) are NOT covered — `ProtoTheme`
chains the engine font as a scripted fallback so they keep rendering.

**Doctrine (see `ui/theme.gd`):** render only at integer multiples of the native
grid, antialiasing off, hinting none, subpixel positioning off, oversampling
pinned to 1x — font pixels must equal 640x360 canvas pixels.
