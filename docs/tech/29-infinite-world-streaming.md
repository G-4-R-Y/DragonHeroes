# 29 — Infinite World Streaming (prototype v0.2.0)

**Status:** design locked, landing in v0.2.0 (2026-07-17). Owner: prototype.
**Relation:** realizes docs/tech/24 §"infinite, seeded, deterministic" in the
playable slice. The C++ generator was born infinite (`generate_chunk(seed, cx,
cy)` is stateless coordinate hashing — constant-time random access to any
chunk); everything finite lives in the *consumers*: the dump CLI emits an
origin-radius block, and the Godot prototype loads it once and builds
world-sized artifacts. v0.2.0 turns that finite dump into a moving window.

## 1. The two finite layers and their fixes

| layer | finite today | v0.2.0 |
|---|---|---|
| dh-server CLI | `--dump-chunks R` (origin radius only) | `--dump-window cx0,cy0,cx1,cy1` (any inclusive chunk rect, same JSON schema) |
| world_gen.gd | one-shot build: whole-world tilemap, transition scan, prop scatter, water MultiMesh, SDF bake | per-chunk load/unload around the player, per-frame apply budgets |
| minimap.gd | one baked world texture | window-following composite of per-chunk 64×64 blocks |
| main.gd | 14 packs seeded at boot, nothing despawns | frontier repopulation per newly-loaded chunk + distance despawn |

The sim/net story is untouched: streaming is a *presentation* concern. The
shipping path replaces the subprocess dump with in-process dh-godot calls —
the window/apply architecture stays identical (only the transport changes),
which is why this lands prototype-side without violating "no worldgen logic
engine-side": the engine still only *renders* chunks the C++ generator emits.

## 2. Streaming contract (world_gen.gd = ProtoWorld)

Constants: `LOAD_RADIUS := 2` (5×5 chunks live around the player's chunk,
320×320 tiles), `UNLOAD_RADIUS := 3` (hysteresis — unload only past 7×7).
One chunk = 64 tiles = 1024 px; the player can never outrun a 2-chunk apron.

Public surface (consumers key on these — minimap, main, future systems):

```gdscript
signal chunk_loaded(key: Vector2i)     # emitted AFTER the chunk is applied
signal chunk_unloaded(key: Vector2i)
func can_stream() -> bool              # dh-server binary present?
func loaded_bounds() -> Rect2i         # chunk-key rect, position + size
func chunk_map_image(key: Vector2i) -> Image   # 64×64 minimap block (cached)
```

Pipeline per player-chunk-crossing (checked in `_process`):
1. Compute `needed` = 5×5 keys around player chunk; `missing = needed - loaded`.
2. If missing and not already streaming: WorkerThread runs
   `dh-server --dump-window <bbox(missing)> --seed <hunt seed> --out user://stream_<n>.json`,
   parses JSON, pre-bakes per-chunk minimap Images + tile PackedByteArrays.
   ONE in-flight request at a time; results land in a queue.
3. Main thread applies AT MOST one pending chunk per frame, amortized:
   ≤16 tilemap rows per frame per chunk (4096 set_cell split across ~4 frames),
   then transitions (chunk rect grown by 1 — idempotent dual-grid repaint),
   props (one Node2D container per chunk; shroom statics register handles),
   water (one per-chunk MultiMeshInstance2D; neighbor chunks' water custom
   data refreshed so shore foam heals across seams), then `chunk_loaded`.
4. Unload pass: chunks beyond UNLOAD_RADIUS (chebyshev) — erase cells (same
   row budget), erase transition strip, free props container,
   `darkness.remove_static(handle)` per shroom, free water MMI, emit
   `chunk_unloaded`, drop from `chunks`.
5. SDF: on any load/unload batch settling, snapshot the loaded window's rock
   mask and re-run the two-pass chamfer IN A WORKER THREAD (pure
   PackedFloat32Array math, no engine access); main thread swaps the texture
   via `darkness.set_sdf` when done. Debounced: at most one rebake in flight.

Walkability outside loaded chunks stays `T_ROCK` (the stream fence: nothing
walks or spawns into unloaded space, and the fence retreats as chunks apply).

Determinism: the hunt seed is rolled once per hunt; every window dump reuses
it, so revisited coordinates are byte-identical (generator guarantee). Props/
variants/transitions all hash off world tile coords — no per-load state.

Fallback (no sim binary): load a shipped `worlds/world_N.json` island exactly
as today; `can_stream() == false`; no unload, no frontier spawns. The game is
identical to v0.1.x — graceful degradation, never a hard requirement.

## 3. Consumers

**darkness.gd** — `add_static(...) -> int` returns a handle;
`remove_static(handle)`. Registration stays unbounded (nearest-16 upload
unchanged); handles exist so unloading chunks can retract their glowshrooms.

**minimap.gd** — drops the one-shot world bake. Keeps a `key -> Image` block
cache fed by `chunk_map_image` on `chunk_loaded`; composites the 5×5 window
into one 320×320 texture on crossings (blit_rect, no per-pixel loops on the
main thread); `_origin_tile/_span_tiles` follow the window so `_map_pos`
stays valid. Dots logic unchanged. Unloaded space renders as the void color.

**main.gd** — hunts stay anchored: the 14 authored packs + bosses spawn near
origin exactly as today (the "quest layer" is finite ON PURPOSE — the
Matriarch nests where she nests). Two additions:
- *Frontier repopulation:* on first `chunk_loaded` of a virgin chunk beyond
  the origin window, a deterministic hash of (hunt seed, key) rolls 0–2
  wandering packs (reusing the pack builder; ~35% one pack, 10% two, wisps
  ride the existing i%2 cadence). Intended pack-level bias is +1 per four
  Chebyshev chunks, capped at +10. **Current implementation (audit 2026-09-12):**
  this increases non-leader elite-affix odds by four percentage points per
  distance step, capped at 40%; it does not add levels to individual monsters.
  Their base scaling reads hunter level once at spawn. See design/24's
  progression audit; an actual per-spawn level hook remains unimplemented.
- *Distance despawn:* creatures (never bosses/legendaries/pets) farther than
  ~1.5 windows from the player are silently recycled — the entity count is
  bounded by exploration speed, not session length.

## 4. Budgets (60 FPS contract, canon directive 2)

- chunk apply: ≤2 ms main-thread per frame (row-amortized set_cell; measured
  by stream_test with a worst-case sprint).
- SDF rebake: worker-thread only; 5×5 window (320×320) target <200 ms in the
  thread, zero main-thread stalls beyond the texture swap.
- streaming subprocess: one in flight, fire on crossing, ~25-chunk bbox worst
  case. Missing chunks while sprinting = fence holds, world fills in behind.
- pools: nothing new allocates at runtime — props/water/tilemap per chunk are
  the same objects the one-shot build made, just created per-window and freed.

## 5. Test gate

`tests/stream_test.tscn` (headless): boots the world with a fixed seed,
teleports a player proxy east 8 chunks in steps, pumps frames; asserts
(a) needed chunks load, (b) far chunks unload, (c) darkness statics count
returns to baseline after unload (no leak), (d) per-chunk water/prop nodes
are freed, (e) walkability fence holds at the stream edge, (f) prints
worst apply-step ms. Ends `STREAMTEST OK` (joins boot ×2 / click_test /
fx_stress as a standing gate).

## 6. Later (not v0.2.0)

- dh-godot GDExtension transport (kills the subprocess + JSON hop).
- Chunk deltas (docs/tech/24 §5 world-drop versioning) — virgin-space rule.
- Server-authoritative streaming for multiplayer (AOI = the same window).
- POI/feature layers when dh-procgen grows them (docs/tech/24 §3).


## Recovery repair (2026-09-12, roadmap R09)

Implemented in the prototype presentation streamer: reconciliation every 0.5 s
and after apply completion closes a hole caused by returning during an active
unload. Obsolete queued/worker loads are discarded; remaining loads prioritize
distance to the hunter. Active terrain stays within 49 chunks even when teleporting
between distant windows. Walkability stays closed during load AND unload phases.
Helper failures retry with bounded exponential backoff (0.5–8s) without needing
another boundary crossing. One per-world scratch dump is deleted after parsing.

The SDF now receives a copy-on-write chunk snapshot and builds its rock mask in
the worker. Its streaming extent is bounded to 7×7 around the hunter, including
when old and new chunks briefly coexist thousands of chunks apart. This avoids
allocating an enormous rectangle between those two windows. Frontier encounter
persistence and actual biome identities/art remain separate pending R08/R09 work.

Gate: `tests/stream_recovery.tscn` actually interrupts requests, travels through
far negative coordinates, reverses an active unload, fails the helper then
restores it while stationary, and returns to the byte-identical original chunk.
It asserts the unfinished-ground fence, 49-chunk peak, empty staging/unload state
and deleted scratch dump. Initial receipt: 1.07 ms worst apply; ordinary eight-step
stream test 1.10 ms. These desktop/headless samples are not a mobile guarantee.
