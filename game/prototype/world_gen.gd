# PROTOTYPE HARNESS — renders the REAL dh-procgen world (dumped by `dh-server
# --dump-window cx0,cy0,cx1,cy1`, docs/tech/24 + 29). No worldgen logic lives
# engine-side. Tile variants + prop scatter are deterministic coordinate hashes —
# pure dressing, never gameplay (props are visual only and do not affect
# walkability). The same rule covers the anti-procgen-look layers: macro variant
# patches, the macro tint quad and the dual-grid boundary layer are ALL
# visual-only — walkability always reads the raw world grid.
#
# v0.2.0 STREAMING (docs/tech/29): the finite one-shot build became a moving
# window. A radius-2 block boots synchronously (parity with the old feel); after
# that the world loads/unloads per-chunk around the player on a WORKER THREAD
# (subprocess dump + JSON parse + PackedByteArray/minimap/SDF baking off-main),
# with a per-frame apply budget on the main thread. The C++ generator is
# stateless coordinate hashing, so the same hunt seed makes revisited chunks
# byte-identical — nothing here is per-load state. can_stream()==false falls back
# to a shipped island exactly as v0.1.x (graceful degradation, no unload).
class_name ProtoWorld
extends Node2D

# Streaming contract (docs/tech/29 §2): consumers snapshot `chunks.keys()` at
# ready, then follow these deltas. Emitted AFTER a chunk is fully applied; the
# one-shot fallback path emits chunk_loaded once per dumped chunk after build.
signal chunk_loaded(key: Vector2i)
signal chunk_unloaded(key: Vector2i)

const TILE := 16          # 16 px = 1 m (prototype scale)
const CHUNK := 64
# 1 px per tile minimap block colors (water/grass/forest/rock) — owned here so
# chunk map blocks bake WITH the chunk (worker thread), not in the minimap.
const MAP_COLS: Array[Color] = [Color("16303b"), Color("2c4a33"), Color("223a2b"), Color("3a3f49")]
const T_WATER := 0
const T_GRASS := 1
const T_FOREST := 2
const T_ROCK := 3

# Streaming radii (docs/tech/29 §2). LOAD keeps a 5×5 apron live around the
# player's chunk; UNLOAD only retires past 7×7 (hysteresis — the player can't
# outrun a 2-chunk apron, and a chunk near the boundary won't thrash).
const LOAD_RADIUS := 2
const UNLOAD_RADIUS := 3
const ORIGIN_KEEP := 2    # bosses nest in the origin 5×5 — never unload it while inside

# Main-thread apply budget (docs/tech/29 §4, target ≤2 ms/frame): every heavy
# phase — base tiles, prop scatter, AND the dual-grid transition scan — is row-
# budgeted to this many rows per frame (the doc's ≤16 ceiling; 6 measures ~1.7 ms
# worst per step with headroom for worker-thread contention spikes).
const APPLY_ROWS := 6
# Water is budgeted by instances, not rows: a chunk's own quads (transform + shore
# mask) and neighbours' re-masks drain through a job queue at this many per frame,
# so even a full-water lake chunk never stalls a frame.
const WATER_FILL := 512

# Dual-grid boundary dressing (Oskar Stålberg corners) — flip off to fall back
# to hard tile edges for A/B comparison captures.
const DUAL_GRID := true

var chunks := {}          # Vector2i(cx,cy) -> PackedByteArray (tiles) — LOADED only
var _layer: TileMapLayer          # base floor (z=-10)
var _trans_layer: TileMapLayer    # dual-grid transition dressing (z=-9)
var _sway_mat: ShaderMaterial     # shared wind/walk-through material for foliage
var _spawn_cache := Vector2.ZERO
var _spawn_valid := false
var _streaming := false           # true once the async pipeline is armed at boot
var _hunt_seed := 0               # rolled ONCE; every window dump reuses it
# MP HOOK (docs/tech/33): in P2P co-op the host chooses the hunt seed in the
# lobby and every peer builds the SAME world from it (dh-procgen is
# deterministic) — the world itself never crosses the wire, only entities do.
var forced_seed := 0
var _bin_path := ""

# Per-chunk scene artifacts (created on apply, freed on unload — no runtime pool
# growth: the same object kinds the one-shot build made, just per-window).
var _props := {}          # Vector2i -> Node2D container ("Props_cx_cy")
var _water := {}          # Vector2i -> MultiMeshInstance2D ("Water_cx_cy")
var _water_tiles := {}    # Vector2i -> Array[Vector2i] world-tile coords of its water quads
var _shroom_handles := {} # Vector2i -> Array[int] darkness static handles
var _map_blocks := {}     # Vector2i -> Image (64x64, 1px/tile) — minimap cache

# --- streaming worker pipeline (docs/tech/29 §2 steps 2-4) ----------------
# The worker does subprocess + FileAccess + JSON + PackedByteArray/Image baking
# and NOTHING scene-tree. Results cross to the main thread through a mutex queue.
var _thread: Thread = null
var _mutex := Mutex.new()
var _ready_chunks := []            # [ {key, tiles, img} ] — filled by the worker
var _stream_done := false          # worker set: request finished (join + clear inflight)
var _req_inflight := false
var _inflight_needed := {}         # keys the in-flight request will satisfy (dedup)
var _staged := {}                  # Vector2i -> {tiles, img} parsed, awaiting apply
var _jobs := []                    # [ {key, mode:"load"|"unload"} ] apply queue
var _pending_unload := {}          # dedup set for queued unloads

# Amortized apply state machine — ONE chunk in flight at a time.
var _apply_active := false
var _apply_key := Vector2i.ZERO
var _apply_mode := ""              # "load" | "unload"
var _apply_phase := 0             # per-mode phase index (see _step_load / _step_unload)
var _apply_row := 0
var _wjobs := []                  # [ {key, self, cur, mmi?} ] budgeted water fill/refresh
var _worst_apply_ms := 0.0        # stream_test reads this (§5 budget gate)

# SDF rebake (docs/tech/29 §2 step 5): pure chamfer math on a snapshot, worker
# thread, debounced (one in flight; re-arm if the chunk set changed while baking).
var _sdf_thread: Thread = null
var _sdf_mutex := Mutex.new()
var _sdf_result = null             # {img, origin, size} handed back by the worker
var _sdf_inflight := false
var _sdf_dirty := false

const _CHUNK_NONE := Vector2i(1 << 30, 1 << 30)
var _player_chunk := _CHUNK_NONE   # last observed player chunk (crossing trigger)
var _pending_shrooms := []         # [ [key,pos] ] deferred until darkness exists (boot)

func _ready() -> void:
	y_sort_enabled = true
	_bin_path = _find_dh_server()
	_setup_layers()
	if can_stream():
		# A NEW map every hunt (Ricardo): roll the seed ONCE and reuse it for every
		# window dump so revisited coordinates stay byte-identical.
		_hunt_seed = forced_seed if forced_seed != 0 else randi()
		print("world seed: ", _hunt_seed)
		_streaming = true
		_boot_sync()
		if not _streaming:   # binary present but the boot dump failed — degrade
			_boot_fallback()
	else:
		_boot_fallback()

# Locate the worldgen binary. Exported builds (friends' installs) carry it NEXT
# TO the game executable; the dev repo carries it in sim/build. Co-op world
# parity depends on every peer having it (docs/tech/33 §architecture).
func _find_dh_server() -> String:
	if not OS.has_feature("editor"):
		var exe := "dh-server.exe" if OS.has_feature("windows") else "dh-server"
		var beside: String = OS.get_executable_path().get_base_dir().path_join(exe)
		if FileAccess.file_exists(beside):
			return beside
	return ProjectSettings.globalize_path("res://../sim/build/libs/dh-server/dh-server")

func can_stream() -> bool:
	var resolved := _bin_path if not _bin_path.is_empty() else _find_dh_server()
	return not resolved.is_empty() and FileAccess.file_exists(resolved)

# --- boot ------------------------------------------------------------------

# Base floor + dual-grid transition TileMapLayers, both empty. Cells are painted
# per-chunk (boot: all at once; streaming: row-amortized), erased on unload.
func _setup_layers() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ProtoSprites.make_tile_atlas()
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for i in 16:              # 4 types x 4 variants (column = type*4+variant)
		atlas.create_tile(Vector2i(i, 0))
	ts.add_source(atlas, 0)
	_layer = TileMapLayer.new()
	_layer.tile_set = ts
	_layer.z_index = -10
	add_child(_layer)
	if DUAL_GRID:
		var tts := TileSet.new()
		tts.tile_size = Vector2i(TILE, TILE)
		var tatlas := TileSetAtlasSource.new()
		tatlas.texture = ProtoSprites.make_transition_atlas(
				[[T_FOREST, T_GRASS], [T_ROCK, T_GRASS]])
		tatlas.texture_region_size = Vector2i(TILE, TILE)
		for i in 32:          # 2 pairs x 16 corner masks (column = pair*16+mask)
			tatlas.create_tile(Vector2i(i, 0))
		tts.add_source(tatlas, 0)
		_trans_layer = TileMapLayer.new()
		_trans_layer.name = "Transitions"
		_trans_layer.tile_set = tts
		_trans_layer.position = Vector2(TILE, TILE) * 0.5   # the dual-grid half-tile shift
		_trans_layer.z_index = -9        # over the base floor (-10), under macro tint (-8)
		add_child(_trans_layer)

# Synchronous radius-2 window around origin — parity with the old boot feel; the
# whole 5×5 lands this frame (unamortized), everything after streams. On dump
# failure clears _streaming so _ready degrades to the shipped island.
func _boot_sync() -> void:
	var out := ProjectSettings.globalize_path("user://stream_boot.json")
	var arg := "%d,%d,%d,%d" % [-LOAD_RADIUS, -LOAD_RADIUS, LOAD_RADIUS, LOAD_RADIUS]
	var code := OS.execute(_bin_path, ["--dump-window", arg, "--seed", str(_hunt_seed), "--out", out])
	var data = null
	if code == 0:
		var raw := FileAccess.get_file_as_string(out)
		if raw != "":
			data = JSON.parse_string(raw)
	if data == null or not data.has("chunks"):
		_streaming = false
		return
	_prewarm_tilemap()
	for c in data["chunks"]:
		var key := Vector2i(int(c["cx"]), int(c["cy"]))
		chunks[key] = _pack_tiles(c["tiles"])
	_build_all_loaded()
	_arm_boot_deferred()
	set_process(true)

# Pre-grow the base TileMapLayer's internal storage to the streaming peak (the
# 7×7 = UNLOAD-diameter window) by painting then clearing it. Boot is unbudgeted,
# so paying the HashMap growth here means a mid-gameplay rehash never hitches an
# apply frame (canon directive 2: animations must never hitch). Streaming keeps
# the live cell count within this window, so the map never rehashes again.
func _prewarm_tilemap() -> void:
	var r := UNLOAD_RADIUS
	var lo := -r * CHUNK
	var hi := (r + 1) * CHUNK
	for gy in range(lo, hi):
		for gx in range(lo, hi):
			_layer.set_cell(Vector2i(gx, gy), 0, Vector2i(0, 0))
	for gy in range(lo, hi):
		for gx in range(lo, hi):
			_layer.erase_cell(Vector2i(gx, gy))

# Fallback (no sim binary, or a failed boot dump): load a shipped island exactly
# as v0.1.x — one-shot, no streaming, no unload. Graceful degradation.
func _boot_fallback() -> void:
	var raw := _load_fallback_json()
	assert(raw != "", "no world dump — run: dh-server --dump-window \"-4,-4,4,4\" --out game/prototype/chunks.json")
	var data: Dictionary = JSON.parse_string(raw)
	print("world seed: ", data.get("seed", "?"))
	for c in data["chunks"]:
		var key := Vector2i(int(c["cx"]), int(c["cy"]))
		chunks[key] = _pack_tiles(c["tiles"])
	_streaming = false
	_build_all_loaded()
	_arm_boot_deferred()
	set_process(true)   # _process still drives foliage sway + the one SDF swap

# Shared one-shot build over EVERY currently loaded chunk (boot + fallback):
# paint tiles, one transition scan over the whole bounds, then per-chunk props +
# water. Reuses the streaming helpers so both paths produce identical artifacts.
func _build_all_loaded() -> void:
	for key in chunks:
		_paint_chunk_rows(key, 0, CHUNK)
	var b := _chunk_bounds()
	_repaint_transitions(b[0] * CHUNK, (b[1] + Vector2i.ONE) * CHUNK - Vector2i.ONE)
	for key in chunks:
		_scatter_chunk_props(key, 0, CHUNK)
	for key in chunks:
		_build_chunk_water(key)
	var tint := ProtoMacroTint.new()   # macro brightness/hue drift over the floor
	tint.name = "MacroTint"
	add_child(tint)

# Shrooms + SDF are deferred: main assembles its darkness node AFTER world gen, so
# neither exists during our _ready. chunk_loaded replay covers listeners already
# connected during the one-shot build (late listeners use snapshot-then-connect).
func _arm_boot_deferred() -> void:
	call_deferred("_register_pending_shrooms")
	call_deferred("_kick_sdf")
	for key in chunks:
		chunk_loaded.emit(key)

func _load_fallback_json() -> String:
	var variants: Array[String] = []
	for i in 6:
		var p := "res://prototype/worlds/world_%d.json" % i
		if FileAccess.file_exists(p):
			variants.append(p)
	if not variants.is_empty():
		return FileAccess.get_file_as_string(variants.pick_random())
	return FileAccess.get_file_as_string("res://prototype/chunks.json")

func _pack_tiles(tiles: Array) -> PackedByteArray:
	var packed := PackedByteArray()
	packed.resize(CHUNK * CHUNK)
	for i in tiles.size():
		packed[i] = int(tiles[i])
	return packed

# --- per-frame driver ------------------------------------------------------

func _process(_dt: float) -> void:
	# Foliage sway needs the hero's position once per frame (walk-through push).
	if _sway_mat != null:
		var p := _get_player()
		if p != null:
			_sway_mat.set_shader_parameter("player_pos", p.global_position)
	_drain_sdf()                 # both modes bake the SDF once (fallback) or per crossing
	if not _streaming:
		return
	_drain_stream()
	var pl := _get_player()
	if pl != null:
		var pc := _world_to_chunk(pl.global_position)
		if pc != _player_chunk:
			_player_chunk = pc
			_on_crossing()
	_process_apply()

# Player crossed a chunk boundary: request the missing apron, retire what fell
# out of range, and re-arm the SDF. Also re-runs after a request settles so a
# sprint that outran one dump keeps filling in.
func _on_crossing() -> void:
	var pc := _player_chunk
	# queued unloads that came back into range are cancelled (hysteresis)
	for i in range(_jobs.size() - 1, -1, -1):
		var j: Dictionary = _jobs[i]
		if j["mode"] == "unload":
			var k: Vector2i = j["key"]
			if _chebyshev(k, pc) <= UNLOAD_RADIUS or _in_origin_keep(k, pc):
				_jobs.remove_at(i)
				_pending_unload.erase(k)
	# missing = the 5×5 apron not already present anywhere in the pipeline
	var missing: Array = []
	for dy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var k := pc + Vector2i(dx, dy)
			if not _present(k):
				missing.append(k)
	if not missing.is_empty() and not _req_inflight:
		_kick_stream(missing)
	# unload past UNLOAD_RADIUS (chebyshev) — but never the origin 5×5 while inside
	for key in chunks.keys():
		if _apply_active and key == _apply_key:
			continue
		if _chebyshev(key, pc) <= UNLOAD_RADIUS or _in_origin_keep(key, pc):
			continue
		if _pending_unload.has(key):
			continue
		_jobs.append({"key": key, "mode": "unload"})
		_pending_unload[key] = true
	_kick_sdf()

# A chunk is "present" if it is loaded, staged, queued/active for load, or covered
# by the in-flight request — so it is never fetched twice.
func _present(key: Vector2i) -> bool:
	if chunks.has(key) or _staged.has(key):
		return true
	if _req_inflight and _inflight_needed.has(key):
		return true
	if _apply_active and _apply_mode == "load" and _apply_key == key:
		return true
	for j in _jobs:
		if j["mode"] == "load" and j["key"] == key:
			return true
	return false

func _in_origin_keep(key: Vector2i, pc: Vector2i) -> bool:
	if maxi(absi(pc.x), absi(pc.y)) > ORIGIN_KEEP:
		return false   # player left the origin apron — it may retire normally
	return maxi(absi(key.x), absi(key.y)) <= ORIGIN_KEEP

# --- streaming worker (subprocess dump -> parsed chunks) -------------------

func _kick_stream(missing: Array) -> void:
	var bmin := Vector2i(1 << 20, 1 << 20)
	var bmax := Vector2i(-(1 << 20), -(1 << 20))
	_inflight_needed = {}
	for k in missing:
		bmin = Vector2i(mini(bmin.x, k.x), mini(bmin.y, k.y))
		bmax = Vector2i(maxi(bmax.x, k.x), maxi(bmax.y, k.y))
		_inflight_needed[k] = true
	_req_inflight = true
	var out := ProjectSettings.globalize_path("user://stream_%d_%d.json" % [_player_chunk.x, _player_chunk.y])
	var job := {"bbox": "%d,%d,%d,%d" % [bmin.x, bmin.y, bmax.x, bmax.y],
			"out": out, "needed": _inflight_needed.keys()}
	_thread = Thread.new()
	# LOW priority: the main thread's per-frame apply budget wins any CPU contest
	# (the dump subprocess + parse must never starve a 60 FPS frame).
	_thread.start(_stream_worker.bind(job), Thread.PRIORITY_LOW)

# WORKER THREAD — no scene tree / RenderingServer. Only the missing chunks in the
# bbox are packed + minimap-baked (the dump's rect can include already-loaded
# ones). Results and the done flag cross under the mutex.
func _stream_worker(job: Dictionary) -> void:
	var results := []
	var code := OS.execute(_bin_path,
			["--dump-window", job["bbox"], "--seed", str(_hunt_seed), "--out", job["out"]])
	if code == 0:
		var raw := FileAccess.get_file_as_string(job["out"])
		if raw != "":
			var data = JSON.parse_string(raw)
			if data != null and typeof(data) == TYPE_DICTIONARY and data.has("chunks"):
				var wanted := {}
				for k in job["needed"]:
					wanted[k] = true
				for c in data["chunks"]:
					var key := Vector2i(int(c["cx"]), int(c["cy"]))
					if not wanted.has(key):
						continue
					var tiles: Array = c["tiles"]
					var packed := PackedByteArray()
					packed.resize(CHUNK * CHUNK)
					var img := Image.create_empty(CHUNK, CHUNK, false, Image.FORMAT_RGBA8)
					for i in tiles.size():
						var t := int(tiles[i])
						packed[i] = t
						@warning_ignore("integer_division")
						img.set_pixel(i % CHUNK, i / CHUNK, MAP_COLS[t])
					results.append({"key": key, "tiles": packed, "img": img})
	_mutex.lock()
	for r in results:
		_ready_chunks.append(r)
	_stream_done = true
	_mutex.unlock()

func _drain_stream() -> void:
	var newly := []
	var done := false
	_mutex.lock()
	if not _ready_chunks.is_empty():
		newly = _ready_chunks
		_ready_chunks = []
	if _stream_done:
		done = true
		_stream_done = false
	_mutex.unlock()
	if done and _thread != null:
		_thread.wait_to_finish()
		_thread = null
	for r in newly:
		var key: Vector2i = r["key"]
		if chunks.has(key) or _staged.has(key):
			continue
		_staged[key] = r
		_jobs.append({"key": key, "mode": "load"})
	if done:
		_req_inflight = false
		_inflight_needed = {}
		# a crossing may have happened mid-dump — re-evaluate to keep filling in
		if _player_chunk != _CHUNK_NONE:
			_on_crossing()

# --- amortized apply (main thread, ≤ budget per frame) ---------------------

func _process_apply() -> void:
	if not _apply_active and _jobs.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	if not _apply_active:
		_begin_next_job()
	if _apply_active:
		if _apply_mode == "load":
			_step_load()
		else:
			_step_unload()
	_worst_apply_ms = maxf(_worst_apply_ms, (Time.get_ticks_usec() - t0) / 1000.0)

func _begin_next_job() -> void:
	# Prefer loads (retreat the walkability fence) over unloads.
	var idx := -1
	for i in _jobs.size():
		if _jobs[i]["mode"] == "load":
			idx = i
			break
	if idx == -1:
		if _jobs.is_empty():
			return
		idx = 0
	var job: Dictionary = _jobs.pop_at(idx)
	var key: Vector2i = job["key"]
	var mode: String = job["mode"]
	if mode == "load":
		if chunks.has(key) or not _staged.has(key):
			return   # already loaded / lost its staging — skip silently
		# publish tile DATA at apply-start so this chunk's own transitions/water
		# read it; the fence (is_walkable) only opens once data is in `chunks`.
		var st: Dictionary = _staged[key]
		chunks[key] = st["tiles"]
		_map_blocks[key] = st["img"]
		_staged.erase(key)
	elif not chunks.has(key):
		_pending_unload.erase(key)
		return   # nothing to unload
	_apply_active = true
	_apply_key = key
	_apply_mode = mode
	_apply_phase = 0
	_apply_row = 0

# Load: tiles -> props -> transitions -> water. Rows 0/1/2 are row-budgeted so no
# single frame does more than APPLY_ROWS rows of work; water is one build frame.
func _step_load() -> void:
	var key := _apply_key
	var tmin := key * CHUNK
	var tmax := tmin + Vector2i(CHUNK - 1, CHUNK - 1)
	match _apply_phase:
		0:   # base tiles
			var r1 := mini(_apply_row + APPLY_ROWS, CHUNK)
			_paint_chunk_rows(key, _apply_row, r1)
			_apply_row = r1
			if _apply_row >= CHUNK:
				_apply_phase = 1
				_apply_row = 0
		1:   # props (node creation is the heavy part — ride the same row budget)
			var pr1 := mini(_apply_row + APPLY_ROWS, CHUNK)
			_scatter_chunk_props(key, _apply_row, pr1)
			_apply_row = pr1
			if _apply_row >= CHUNK:
				_apply_phase = 2
				_apply_row = 0
		2:   # dual-grid transitions over the chunk rect grown by 1 (idempotent)
			if _repaint_transition_rows(tmin, tmax):
				_apply_phase = 3
		3:   # queue our own water quads + the 4 neighbours' seam re-masks
			_queue_chunk_water(key)
			_apply_phase = 4
		4:   # drain the water job queue, WATER_FILL instances/frame
			if _step_water_jobs():
				_apply_active = false
				chunk_loaded.emit(key)

# Unload: erase tiles -> drop data + free artifacts -> repaint the seam (now vs
# rock) -> emit. Data is dropped BEFORE the transition repaint so the seam heals.
func _step_unload() -> void:
	var key := _apply_key
	var tmin := key * CHUNK
	var tmax := tmin + Vector2i(CHUNK - 1, CHUNK - 1)
	match _apply_phase:
		0:   # erase base cells — same row budget as load
			var r1 := mini(_apply_row + APPLY_ROWS, CHUNK)
			_erase_chunk_rows(key, _apply_row, r1)
			_apply_row = r1
			if _apply_row >= CHUNK:
				_apply_phase = 1
				_apply_row = 0
		1:   # drop data + free every per-chunk artifact
			chunks.erase(key)
			_map_blocks.erase(key)
			if _props.has(key):
				_props[key].queue_free()
				_props.erase(key)
			if _shroom_handles.has(key):
				var d := _darkness()
				if d != null:
					for h in _shroom_handles[key]:
						d.remove_static(h)
				_shroom_handles.erase(key)
			if _water.has(key):
				_water[key].queue_free()
				_water.erase(key)
				_water_tiles.erase(key)
			_apply_phase = 2
			_apply_row = 0
		2:   # erase the transition strip (reads rock for the dropped chunk now)
			if _repaint_transition_rows(tmin, tmax):
				_apply_phase = 3
		3:   # our land is gone — queue the 4 neighbours' foam to re-form
			for nb in _neighbours4(key):
				if _water.has(nb):
					_wjobs.append({"key": nb, "self": false, "cur": 0})
			_apply_phase = 4
		4:   # drain the neighbour re-mask queue, WATER_FILL instances/frame
			if _step_water_jobs():
				_pending_unload.erase(key)
				_apply_active = false
				chunk_unloaded.emit(key)

func _paint_chunk_rows(key: Vector2i, r0: int, r1: int) -> void:
	var tiles: PackedByteArray = chunks[key]
	for ly in range(r0, r1):
		var gy := key.y * CHUNK + ly
		for lx in CHUNK:
			var gx := key.x * CHUNK + lx
			var t := tiles[ly * CHUNK + lx]
			_layer.set_cell(Vector2i(gx, gy), 0, Vector2i(t * 4 + _pick_variant(gx, gy), 0))

func _erase_chunk_rows(key: Vector2i, r0: int, r1: int) -> void:
	for ly in range(r0, r1):
		var gy := key.y * CHUNK + ly
		for lx in CHUNK:
			_layer.erase_cell(Vector2i(key.x * CHUNK + lx, gy))

# --- visual dressing (deterministic — hashes off world tile coords) --------

# Macro variation: a ~50-tile value noise picks each region's DOMINANT atlas
# variant and the per-tile hash only jitters around it — texture repetition
# breaks into organic patches (mossy vs worn regions) instead of the uniform
# 4-variant confetti that screams procgen.
func _pick_variant(gx: int, gy: int) -> int:
	var n := clampf((ProtoSprites.macro_noise(gx, gy, 131) - 0.5) * 1.9 + 0.5, 0.0, 1.0)
	var jitter := (ProtoSprites._speck(gx, gy, 91) - 0.5) * 1.6
	return clampi(int(n * 3.999 + jitter), 0, 3)

# Dual-grid autotiling (Oskar Stålberg corners) over a WORLD-TILE rect [tmin,tmax]
# (inclusive). Rect-parameterized so a single chunk can repaint its own strip on
# load/unload; the -1/+1 growth is the display grid's half-tile straddle, so a
# chunk heals its seam with already-loaded neighbours. IDEMPOTENT: non-matching
# cells are erased, so re-scanning (or a neighbour applying) reproduces the same
# result. Pure dressing — is_walkable still reads the world grid.
func _repaint_transitions(tmin: Vector2i, tmax: Vector2i) -> void:
	_repaint_transitions_span(tmin, tmax, tmin.y - 1, tmax.y + 1)   # whole strip (boot/fallback)

# Row-budgeted repaint driven by the apply state machine's _apply_row cursor:
# APPLY_ROWS display-rows of the grown rect per call. Returns true when the strip
# is complete (the whole grown-rect height [tmin.y-1, tmax.y+1) has been scanned).
func _repaint_transition_rows(tmin: Vector2i, tmax: Vector2i) -> bool:
	var gy0 := tmin.y - 1 + _apply_row
	var gy_end := tmax.y + 1
	var gy1 := mini(gy0 + APPLY_ROWS, gy_end)
	_repaint_transitions_span(tmin, tmax, gy0, gy1)
	_apply_row += gy1 - gy0
	return gy1 >= gy_end

func _repaint_transitions_span(tmin: Vector2i, tmax: Vector2i, gy0: int, gy1: int) -> void:
	if not DUAL_GRID:
		return
	const PAIR_FG := (1 << T_FOREST) | (1 << T_GRASS)
	const PAIR_RG := (1 << T_ROCK) | (1 << T_GRASS)
	var x0 := tmin.x - 1
	var x1 := tmax.x + 1
	for gy in range(gy0, gy1):
		var tl := _data_tile(x0, gy)              # display cell corners = the
		var bl := _data_tile(x0, gy + 1)          # 4 world tiles it straddles
		for gx in range(x0, x1):
			var tr := _data_tile(gx + 1, gy)
			var br := _data_tile(gx + 1, gy + 1)
			var bits := (1 << tl) | (1 << tr) | (1 << bl) | (1 << br)
			# exactly {forest,grass} or {rock,grass} — anything else (uniform,
			# touches water, forest meets rock) keeps the hard edge
			if bits == PAIR_FG or bits == PAIR_RG:
				var pair := 0 if bits == PAIR_FG else 1
				var a := T_FOREST if pair == 0 else T_ROCK
				var mask := (1 if tl == a else 0) | (2 if tr == a else 0) \
						| (4 if bl == a else 0) | (8 if br == a else 0)
				_trans_layer.set_cell(Vector2i(gx, gy), 0, Vector2i(pair * 16 + mask, 0))
			else:
				_trans_layer.erase_cell(Vector2i(gx, gy))
			tl = tr
			bl = br

# Deterministic prop dressing for one chunk (rows [r0,r1)): trees on forest,
# rocks on rock-adjacent grass, glowshrooms on grass/forest. One Y-sorted
# container per chunk so unload frees the lot; every position/kind is a world-
# coord hash, so revisits are identical. Glowshrooms register darkness statics
# and keep their handles for unload retraction.
func _scatter_chunk_props(key: Vector2i, r0: int, r1: int) -> void:
	var props: Node2D
	if _props.has(key):
		props = _props[key]
	else:
		props = Node2D.new()
		props.name = "Props_%d_%d" % [key.x, key.y]
		props.y_sort_enabled = true
		add_child(props)
		_props[key] = props
	var spawn := spawn_point()
	var skip_r := 3.0 * TILE
	var tiles: PackedByteArray = chunks[key]
	for ly in range(r0, r1):
		for lx in CHUNK:
			var t := tiles[ly * CHUNK + lx]
			if t == T_WATER or t == T_ROCK:
				continue
			var gx := key.x * CHUNK + lx
			var gy := key.y * CHUNK + ly
			var h := ProtoSprites._speck(gx, gy, 4177)
			var tex: Texture2D = null
			var shroom := false
			var foliage := false
			if t == T_FOREST and h < 0.06:
				tex = ProtoSprites.prop_tex(
						"tree_a" if ProtoSprites._speck(gx, gy, 5501) < 0.5 else "tree_b")
				foliage = true
			elif t == T_GRASS and h < 0.04 and _near_rock(gx, gy):
				tex = ProtoSprites.prop_tex("rock")
			elif h > 0.985:
				tex = ProtoSprites.prop_tex("glowshroom")
				shroom = true
				foliage = true
			if tex == null:
				continue
			var pos := Vector2((gx + 0.5) * TILE, (gy + 0.5) * TILE)
			pos.x += (ProtoSprites._speck(gx, gy, 616) - 0.5) * 10.0
			pos.y += (ProtoSprites._speck(gx, gy, 717) - 0.5) * 6.0
			if pos.distance_to(spawn) < skip_r:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.offset = Vector2(0.0, -tex.get_height() / 2.0 + 1.0)  # base sits on origin
			s.position = pos
			if foliage:   # trees + shrooms sway in the wind / bend from the hero;
				s.material = _sway_material()   # rocks obviously don't
			props.add_child(s)
			if shroom:
				# Glowshrooms are environment LIGHT SOURCES in the darkness model
				# (darkness statics only — a pool light per shroom would flood the
				# 32-slot gameplay pool). The hole reveals ground, the sprite the cyan.
				_add_shroom_light(key, pos)

func _add_shroom_light(key: Vector2i, pos: Vector2) -> void:
	var d := _darkness()
	if d == null:
		_pending_shrooms.append([key, pos])   # boot: darkness not assembled yet
		return
	if not _shroom_handles.has(key):
		_shroom_handles[key] = []
	_shroom_handles[key].append(d.add_static(pos, 34.0, 0.55, 0.5, 2.2))

func _register_pending_shrooms() -> void:
	var pend := _pending_shrooms
	_pending_shrooms = []
	for e in pend:
		if chunks.has(e[0]):   # skip any chunk unloaded before darkness came up
			_add_shroom_light(e[0], e[1])

func _sway_material() -> ShaderMaterial:
	if _sway_mat == null:
		_sway_mat = ShaderMaterial.new()
		_sway_mat.shader = preload("res://prototype/shaders/prop_sway.gdshader")
	return _sway_mat

# Animated water: ONE MultiMesh quad per water tile over the static tile art (one
# draw call per chunk's water). INSTANCE_CUSTOM carries the shore mask (land
# N/E/S/W) so the shader's foam hugs real coastlines. z=-6: above the tile floor,
# below field decals (-5) and everything alive.
func _make_water_mmi(key: Vector2i, count: int) -> MultiMeshInstance2D:
	var mmi := MultiMeshInstance2D.new()
	mmi.name = "Water_%d_%d" % [key.x, key.y]
	mmi.z_as_relative = false
	mmi.z_index = -6
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
	mmi.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://prototype/shaders/water.gdshader")
	mmi.material = mat
	return mmi

func _water_tiles_of(key: Vector2i) -> Array:
	var tiles: PackedByteArray = chunks[key]
	var water: Array = []
	for i in CHUNK * CHUNK:
		if tiles[i] == T_WATER:
			@warning_ignore("integer_division")
			water.append(Vector2i(key.x * CHUNK + (i % CHUNK), key.y * CHUNK + (i / CHUNK)))
	return water

# Boot/fallback one-shot: build a chunk's water fully in one call (the boot block
# is not on the frame budget). Each chunk reads real neighbours (all loaded), so
# no seam heal is needed.
func _build_chunk_water(key: Vector2i) -> void:
	var water := _water_tiles_of(key)
	if water.is_empty():
		return
	var mmi := _make_water_mmi(key, water.size())
	add_child(mmi)
	_water[key] = mmi
	_water_tiles[key] = water
	var mm := mmi.multimesh
	for k in water.size():
		var t: Vector2i = water[k]
		mm.set_instance_transform_2d(k, Transform2D(Vector2(TILE, 0), Vector2(0, TILE),
				Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)))
	_refresh_water_masks(key)

# Streaming: register the chunk's water MMI (kept OFF-TREE until fully filled so
# half-transformed quads never flash at the origin) and queue its fill plus the 4
# neighbours' seam re-masks onto the budgeted drain (_step_water_jobs).
func _queue_chunk_water(key: Vector2i) -> void:
	var water := _water_tiles_of(key)
	if not water.is_empty():
		var mmi := _make_water_mmi(key, water.size())
		_water[key] = mmi
		_water_tiles[key] = water
		_wjobs.append({"key": key, "self": true, "cur": 0})
	for nb in _neighbours4(key):
		if _water.has(nb):
			_wjobs.append({"key": nb, "self": false, "cur": 0})

# Drain WATER_FILL instance-ops per frame across queued jobs. Self jobs set each
# quad's transform + shore mask and reveal (add_child) the MMI only once every
# quad is placed; neighbour jobs re-mask in place. Returns true when drained.
func _step_water_jobs() -> bool:
	var budget := WATER_FILL
	while budget > 0 and not _wjobs.is_empty():
		var job: Dictionary = _wjobs[0]
		var key: Vector2i = job["key"]
		if not _water.has(key) or not chunks.has(key):
			_wjobs.pop_front()
			continue
		var mm: MultiMesh = _water[key].multimesh
		var wt: Array = _water_tiles[key]
		var src: PackedByteArray = chunks[key]
		var is_self: bool = job["self"]
		var bx := key.x * CHUNK
		var by := key.y * CHUNK
		var cur: int = job["cur"]
		var n := wt.size()
		while cur < n and budget > 0:
			var t: Vector2i = wt[cur]
			var lx := t.x - bx
			var ly := t.y - by
			var li := ly * CHUNK + lx
			if is_self:
				mm.set_instance_transform_2d(cur, Transform2D(Vector2(TILE, 0),
						Vector2(0, TILE), Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)))
			var up := int(src[li - CHUNK]) if ly > 0 else _data_tile(t.x, t.y - 1)
			var ri := int(src[li + 1]) if lx < CHUNK - 1 else _data_tile(t.x + 1, t.y)
			var dn := int(src[li + CHUNK]) if ly < CHUNK - 1 else _data_tile(t.x, t.y + 1)
			var lf := int(src[li - 1]) if lx > 0 else _data_tile(t.x - 1, t.y)
			mm.set_instance_custom_data(cur, Color(
					1.0 if up != T_WATER else 0.0,
					1.0 if ri != T_WATER else 0.0,
					1.0 if dn != T_WATER else 0.0,
					1.0 if lf != T_WATER else 0.0))
			cur += 1
			budget -= 1
		job["cur"] = cur
		if cur >= n:
			if is_self and not _water[key].is_inside_tree():
				add_child(_water[key])   # reveal only now that every quad is placed
			_wjobs.pop_front()
	return _wjobs.is_empty()

# Recompute a loaded chunk's shore masks against the CURRENT neighbourhood — used
# on build and whenever an adjacent chunk loads/unloads (foam heals both ways).
# Interior neighbours read the chunk's own PackedByteArray directly (no per-tile
# dict lookup — that was the apply-budget killer); only the 1-tile border falls
# back to _data_tile for cross-chunk reads.
func _refresh_water_masks(key: Vector2i) -> void:
	if not _water.has(key):
		return
	var mm: MultiMesh = _water[key].multimesh
	var wt: Array = _water_tiles[key]
	var src: PackedByteArray = chunks[key]
	var bx := key.x * CHUNK
	var by := key.y * CHUNK
	for k in wt.size():
		var t: Vector2i = wt[k]
		var lx := t.x - bx
		var ly := t.y - by
		var li := ly * CHUNK + lx
		var up := int(src[li - CHUNK]) if ly > 0 else _data_tile(t.x, t.y - 1)
		var ri := int(src[li + 1]) if lx < CHUNK - 1 else _data_tile(t.x + 1, t.y)
		var dn := int(src[li + CHUNK]) if ly < CHUNK - 1 else _data_tile(t.x, t.y + 1)
		var lf := int(src[li - 1]) if lx > 0 else _data_tile(t.x - 1, t.y)
		mm.set_instance_custom_data(k, Color(
				1.0 if up != T_WATER else 0.0,
				1.0 if ri != T_WATER else 0.0,
				1.0 if dn != T_WATER else 0.0,
				1.0 if lf != T_WATER else 0.0))

# --- SDF (worker chamfer over the loaded window, main only swaps texture) ---

# Static world occlusion SDF for shadow-caster lights (canon §12.30): a
# tile-resolution distance field over the impassable T_ROCK cells of the CURRENT
# loaded window. The two-pass chamfer runs in a worker off a rock-mask snapshot;
# main only turns the finished Image into a texture and hands it to darkness.
# Debounced: one rebake in flight, re-armed if the chunk set changed meanwhile.
func _kick_sdf() -> void:
	if _sdf_inflight:
		_sdf_dirty = true
		return
	if chunks.is_empty():
		return
	_sdf_inflight = true
	_sdf_thread = Thread.new()
	# LOW priority: the chamfer is pure background math — it must yield to apply.
	_sdf_thread.start(_sdf_worker.bind(_snapshot_rock()), Thread.PRIORITY_LOW)

# Main-thread snapshot: copy each loaded chunk's rock bits into a window-sized
# byte mask (per-chunk memcpy-style loop, no per-tile dict lookups).
func _snapshot_rock() -> Dictionary:
	var b := _chunk_bounds()
	var kmin: Vector2i = b[0]
	var kmax: Vector2i = b[1]
	var tw := (kmax.x - kmin.x + 1) * CHUNK
	var th := (kmax.y - kmin.y + 1) * CHUNK
	var rock := PackedByteArray()
	rock.resize(tw * th)   # zero = not rock (holes in a non-rect window stay open)
	for key: Vector2i in chunks:
		var tiles: PackedByteArray = chunks[key]
		var ox := (key.x - kmin.x) * CHUNK
		var oy := (key.y - kmin.y) * CHUNK
		for ly in CHUNK:
			var row := (oy + ly) * tw + ox
			var src := ly * CHUNK
			for lx in CHUNK:
				if tiles[src + lx] == T_ROCK:
					rock[row + lx] = 1
	return {"kmin": kmin, "tw": tw, "th": th, "rock": rock}

# WORKER THREAD — pure PackedFloat32Array chamfer (3-4 mask ~ 1 / 1.4 tile units),
# two passes, then bakes the R8 Image. No engine/scene access.
func _sdf_worker(snap: Dictionary) -> void:
	var tw: int = snap["tw"]
	var th: int = snap["th"]
	var rock: PackedByteArray = snap["rock"]
	var kmin: Vector2i = snap["kmin"]
	const BIG := 1e9
	var dist := PackedFloat32Array()
	dist.resize(tw * th)
	for i in tw * th:
		dist[i] = 0.0 if rock[i] == 1 else BIG
	for ty in th:
		for tx in tw:
			var i := ty * tw + tx
			if dist[i] == 0.0:
				continue
			var d: float = dist[i]
			if tx > 0:
				d = minf(d, dist[i - 1] + 1.0)
			if ty > 0:
				d = minf(d, dist[i - tw] + 1.0)
				if tx > 0:
					d = minf(d, dist[i - tw - 1] + 1.4)
				if tx < tw - 1:
					d = minf(d, dist[i - tw + 1] + 1.4)
			dist[i] = d
	for ty in range(th - 1, -1, -1):
		for tx in range(tw - 1, -1, -1):
			var i := ty * tw + tx
			var d: float = dist[i]
			if tx < tw - 1:
				d = minf(d, dist[i + 1] + 1.0)
			if ty < th - 1:
				d = minf(d, dist[i + tw] + 1.0)
				if tx < tw - 1:
					d = minf(d, dist[i + tw + 1] + 1.4)
				if tx > 0:
					d = minf(d, dist[i + tw - 1] + 1.4)
			dist[i] = d
	var img := Image.create(tw, th, false, Image.FORMAT_R8)
	for ty in th:
		for tx in tw:
			var px := clampf(dist[ty * tw + tx] * TILE, 0.0, 500.0) / 500.0
			img.set_pixel(tx, ty, Color(px, 0, 0))
	_sdf_mutex.lock()
	_sdf_result = {"img": img, "origin": Vector2(kmin.x * CHUNK, kmin.y * CHUNK) * TILE,
			"size": Vector2(tw, th) * TILE}
	_sdf_mutex.unlock()

func _drain_sdf() -> void:
	_sdf_mutex.lock()
	var res = _sdf_result
	_sdf_result = null
	_sdf_mutex.unlock()
	if res == null:
		return
	if _sdf_thread != null:
		_sdf_thread.wait_to_finish()
		_sdf_thread = null
	var d := _darkness()
	if d != null:
		d.set_sdf(ImageTexture.create_from_image(res["img"]), res["origin"], res["size"])
	_sdf_inflight = false
	if _sdf_dirty:
		_sdf_dirty = false
		_kick_sdf()

# --- lifetime --------------------------------------------------------------

# No leaked threads at exit (stream_test must quit clean): join whatever runs.
func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _sdf_thread != null:
		_sdf_thread.wait_to_finish()
		_sdf_thread = null

# --- streaming contract surface (docs/tech/29 §2) --------------------------

# Chunk-key rect of currently loaded chunks (position + size, inclusive keys).
func loaded_bounds() -> Rect2i:
	if chunks.is_empty():
		return Rect2i()
	var b := _chunk_bounds()
	return Rect2i(b[0], b[1] - b[0] + Vector2i.ONE)

# 64x64 minimap block for a loaded chunk (1 px per tile), cached. Streaming bakes
# it in the worker; boot/fallback chunks bake lazily here on first request.
func chunk_map_image(key: Vector2i) -> Image:
	if _map_blocks.has(key):
		return _map_blocks[key]
	if not chunks.has(key):
		return null
	var tiles: PackedByteArray = chunks[key]
	var img := Image.create_empty(CHUNK, CHUNK, false, Image.FORMAT_RGBA8)
	for i in CHUNK * CHUNK:
		@warning_ignore("integer_division")
		img.set_pixel(i % CHUNK, i / CHUNK, MAP_COLS[tiles[i]])
	_map_blocks[key] = img
	return img

# --- helpers ---------------------------------------------------------------

# Chunk-key bounding box of the loaded window: [kmin, kmax], inclusive.
func _chunk_bounds() -> Array:
	var kmin := Vector2i(1 << 20, 1 << 20)
	var kmax := Vector2i(-(1 << 20), -(1 << 20))
	for key in chunks:
		kmin = Vector2i(mini(kmin.x, key.x), mini(kmin.y, key.y))
		kmax = Vector2i(maxi(kmax.x, key.x), maxi(kmax.y, key.y))
	return [kmin, kmax]

func _near_rock(tx: int, ty: int) -> bool:
	return _data_tile(tx + 1, ty) == T_ROCK or _data_tile(tx - 1, ty) == T_ROCK \
			or _data_tile(tx, ty + 1) == T_ROCK or _data_tile(tx, ty - 1) == T_ROCK

# WALKABILITY grid (the stream fence): reads LOADED chunks only. Outside them
# every tile is T_ROCK, so nothing walks or spawns into unloaded space and the
# fence retreats only as chunks apply.
func _tile_grid(tx: int, ty: int) -> int:
	var key := Vector2i(floori(float(tx) / CHUNK), floori(float(ty) / CHUNK))
	if not chunks.has(key):
		return T_ROCK
	return chunks[key][(ty - key.y * CHUNK) * CHUNK + (tx - key.x * CHUNK)]

# DRESSING grid: like _tile_grid but also sees staged-not-yet-applied chunks, so
# transitions/props/water at a seam use real neighbour data the instant the dump
# lands (and heal to rock if the neighbour is truly beyond the fetched window).
# Never used for gameplay — the fence stays on _tile_grid.
func _data_tile(tx: int, ty: int) -> int:
	var key := Vector2i(floori(float(tx) / CHUNK), floori(float(ty) / CHUNK))
	var local := (ty - key.y * CHUNK) * CHUNK + (tx - key.x * CHUNK)
	if chunks.has(key):
		return chunks[key][local]
	if _staged.has(key):
		return (_staged[key]["tiles"] as PackedByteArray)[local]
	return T_ROCK

func tile_at(world_pos: Vector2) -> int:
	return _tile_grid(floori(world_pos.x / TILE), floori(world_pos.y / TILE))

func is_walkable(world_pos: Vector2) -> bool:
	var t := tile_at(world_pos)
	return t == T_GRASS or t == T_FOREST

# Finds a walkable point in a ring around `center` (meters converted by caller).
func random_walkable_in_ring(center: Vector2, r_min_px: float, r_max_px: float) -> Vector2:
	for _i in 200:
		var ang := randf() * TAU
		var dist := randf_range(r_min_px, r_max_px)
		var p := center + Vector2.from_angle(ang) * dist
		if is_walkable(p):
			return p
	return center

func spawn_point() -> Vector2:
	if not _spawn_valid:
		_spawn_valid = true
		_spawn_cache = Vector2.ZERO if is_walkable(Vector2.ZERO) \
				else random_walkable_in_ring(Vector2.ZERO, 0.0, 40.0 * TILE)
	return _spawn_cache

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _darkness() -> Node:
	var m := get_tree().get_first_node_in_group("main")
	if m == null:
		return null
	return m.get("darkness")

func _world_to_chunk(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / float(CHUNK * TILE)), floori(pos.y / float(CHUNK * TILE)))

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _neighbours4(key: Vector2i) -> Array:
	return [key + Vector2i.LEFT, key + Vector2i.RIGHT, key + Vector2i.UP, key + Vector2i.DOWN]
