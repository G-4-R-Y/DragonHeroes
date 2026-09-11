# Dragon Heroes — Project Guidelines

**Canon first:** `docs/00-canon.md` is the single source of truth for every name,
number, and decision. Read it before designing or implementing anything. If work
requires deviating from it, update the canon (with a note) in the same change.

## Standing directives (Ricardo)

1. **C++ with maximized performance.** All performance-critical/runtime systems —
   simulation core, netcode, procgen, content loading, servers — are C++20 in the
   `sim/` CMake workspace. Godot integration via godot-cpp GDExtension; RL training
   exposure via a C API + nanobind. GDScript is presentation-only glue. No Rust, no C#.
   (Sole carve-out pending confirmation: the Go economy core — money code.)
2. **60 FPS, always.** The client holds a locked 60 FPS on all platforms including
   mid-range mobile; animations must never hitch. The sim runs at fixed 30 Hz and the
   client interpolates. Every visual feature lands with a measured frame-time budget;
   profile before and after performance-relevant changes.
3. **Beautiful AND optimized.** Rich GPU-driven particles, dynamic 2D lighting,
   palette-LUT recolors — via MultiMesh/RenderingServer paths and explicit budgets,
   never node-per-entity. Gen-AI is a first-class art production tool behind a curated
   pipeline (style-locked, palette-enforced, human-directed).
4. **Extensibility is the product.** Weekly content must never require engine work:
   items, skills, creatures, classes, biomes, AI profiles are pure data with stable
   `pack.type.name` IDs, validated against `content/schemas/` in CI.

## Hard rules (legal/architectural — never violate)

- **No paid randomness, ever** (no purchasable loot boxes/keys/gacha/rerolls). Items
  are cashable; paid RNG = unlicensed gambling exposure in Brazil.
- **Server-authoritative everything.** The client is untrusted by design. All combat,
  loot, inventory, and trade state lives server-side.
- **The economy core is the sole writer** of real-money item/money tables. Game
  servers and Nakama call it via RPC; nothing else touches those tables.
- **The marketplace is web-only** — never inside the mobile apps.
- `sim/` never imports Godot (except `dh-godot`) and never does I/O (except
  `dh-server`/`dh-net`); `game/` contains zero gameplay rules.

## Claude session hygiene (Ricardo)

Longer sessions cost more even when cached. Auto-compact fires at 50% context
(user settings `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50`). On top of that: run
`/compact` at natural checkpoints mid-task, and start fresh with `/clear` when
switching to an unrelated task instead of dragging dead context along. Do NOT spawn
background agents/workflows unless Ricardo asks for them in the moment: two
workflows exhausted the session quota on 2026-09-11 and their work was lost
mid-flight (canon §12.39). Work inline; keep context lean with `/compact`.

## Layout

Monorepo layout and coupling rules: canon §10. Document set index: `docs/README.md`.

## Resuming work (any harness)

Start at **`docs/harness/README.md`** — the durable harness memory (invariants,
gates, doctrine, environment), then `docs/harness/10-systems-map.md` (every
system's status/files/gate) and `docs/harness/20-roadmap.md` (the one roadmap).
`HANDOFF.md` is the volatile delta from the last session. Update all three in
the same change as the work they describe.
