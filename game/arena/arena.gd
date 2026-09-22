# ARENA — the self-play match runner and spectator (docs/design/23).
#
# Creatures, bosses and geared player builds face off in a bounded ring so we
# can WATCH policies learn: scripted baselines today, per-species and global
# neural nets (ml/) as training produces them. Episodes log obs+action pairs
# (recorder.gd) for behavioral cloning — the R0 dataset from canon §9.
#
# Headless / training:
#   godot --headless --path game res://arena/arena.tscn -- \
#       --a core.arena.dusk_revenant --b core.arena.fen_boar_alpha \
#       --policy-a scripted --policy-b native --episodes 4 --seed 7 --fast \
#       --record-dir /abs/ml/data/episodes --out /abs/result.json
#   --selftest runs the built-in gate (must end "ARENA SELFTEST OK", exit 0);
#   it runs the spectator stack headless. --spectate forces that stack on
#   for ad-hoc fast/headless runs.
# Spectate (windowed, no args): cycles the roster rotation; [N]ext, [R]ematch,
# [1/2/3] speed, [Q]uit.
extends Node2D

const TILE := 16.0
const INTRO_S := 1.0
const END_S := 1.4
const SELFTEST_MATCHES := [
	["core.arena.dusk_revenant", "core.arena.fen_boar_alpha", "scripted", "native"],
	["core.arena.fen_boar_alpha", "core.arena.gloamfen_stalker", "scripted", "scripted"],
	["core.arena.pyre_justiciar", "core.arena.fenwitch_hag", "scripted", "native"],
	# duo: a member falls MID-FIGHT (freed body while the fighter lives on) —
	# the crash class of 2026-09-11; keeps alive_body()/living_proxies() honest
	["core.arena.the_duologue", "core.arena.bloodwarrant", "native", "scripted"],
]

# Elemental fields (main.gd parity, trimmed): fire/earth fuse into LAVA here
# regardless of duo context — emergent field combos are on-brand (canon open
# question 7 leans "enable"); mire slows.
const FIELD_KINDS := {
	"fire": {"edge": Color("ff9a3c"), "glow": Color(1.0, 0.55, 0.2), "slow": 0.0},
	"earth": {"edge": Color("c9a25e"), "glow": Color(0.75, 0.6, 0.35), "slow": 0.0},
	"mire": {"edge": Color("7ce7a2"), "glow": Color(0.35, 0.8, 0.5), "slow": 1.0},
	"lava": {"edge": Color("ff5a2e"), "glow": Color(1.0, 0.42, 0.1), "slow": 0.0},
}

# main-contract services (entities look this node up via group "main")
var fx: ProtoFx
var telegraphs: ProtoTelegraphs
var post: ProtoPost
var _dmg: ProtoDamage
var stones := 1                    # unlocks the bestial slot for bot builds

var _world: ArenaWorld
var _cam: Camera2D
var _hud: ArenaHud
var _fighters: Array = []
var _cfg := {}
var _spectate := true
var _hud_frames := 0          # selftest asserts the spectator path ran
var _fast := false
var _selftest := false
var _selftest_stage := 0
var _selftest_damage := 0.0
var _selftest_player_damage := 0.0
var _state := "boot"               # intro | fight | end | done | idle (serve)
var _serve := false                # --serve: stay alive, take matchups on stdin
var _stdin_buf := ""               # stdin is a byte stream, not a line reader
var _episode := 0
var _episodes := 1
var _timer := 0.0
var _time_limit := 90.0
var _wins := [0, 0, 0]             # side A, side B, draws
var _results: Array = []
var _recorder := ArenaRecorder.new()
var _rec_dir := ""
var _rec_t := 0.0
var _fields: Array = []
var _field_clock := 0.0   # sim seconds; fields expire on THIS clock (see spawn_field)
var _rotation: Array = []
var _rotation_idx := 0
var _rng := RandomNumberGenerator.new()
var _ended := false

func _ready() -> void:
	add_to_group("main")
	_parse_cli()
	_serve = bool(_cfg.get("serve", false))
	_fast = bool(_cfg.get("fast", false)) or _selftest or _serve
	ProtoFx.intensity = 0.3 if _fast else 1.0
	# the selftest runs the spectator stack too: the camera/HUD _process path
	# is where freed-body dereferences bite (2026-09-11) — gate it, don't skip it
	_spectate = _selftest or _cfg.has("spectate") or (not _fast and not _cfg.has("a"))
	ProtoTheme.apply_doctrine()
	_world = ArenaWorld.new()
	add_child(_world)
	fx = ProtoFx.new(); add_child(fx)
	telegraphs = ProtoTelegraphs.new(); add_child(telegraphs)
	post = ProtoPost.new(); add_child(post)
	_dmg = ProtoDamage.new(); add_child(_dmg)
	if _spectate:
		_cam = Camera2D.new()
		add_child(_cam)
		_cam.make_current()
		var dark := ProtoDarkness.new()
		add_child(dark)
		for i in 8:   # arena rim lights: the ring reads as a lit stage in the dark
			var ang := TAU * i / 8.0
			dark.add_static(Vector2.from_angle(ang) * _world.radius * 0.92,
					40.0, 0.5, 0.35)
		_hud = ArenaHud.new()
		add_child(_hud)
	if _fast:
		_apply_speed(str(_cfg.get("speed", "4")))
	if _selftest:
		_rotation = SELFTEST_MATCHES.map(func(m: Array) -> Array: return m)
	elif _cfg.has("a"):
		_rotation = [[str(_cfg.a), str(_cfg.get("b", _cfg.a)),
				str(_cfg.get("policy_a", "")), str(_cfg.get("policy_b", ""))]]
	else:
		_rotation = _spectate_rotation()
	_episodes = int(_cfg.get("episodes", 2 if _selftest else 4))
	_time_limit = float(_cfg.get("time_limit", 60.0 if _selftest else 90.0))
	_rec_dir = str(_cfg.get("record_dir", ""))
	_rng.seed = int(_cfg.get("seed", 2026))
	Session.level = int(_cfg.get("level", 20))
	if _serve:
		# The engine is the expensive part (measured 4.01 s of boot per match,
		# 2.53 s for the release export). A sweep pays it 20 times per
		# generation for nothing: the project, the scene and every art bundle
		# are identical every time. In serve mode we boot ONCE and then take
		# matchups on stdin, so that cost is paid once per worker per run.
		_state = "idle"
		print(SERVE_READY)
		return
	if _rotation.is_empty():
		push_error("arena: no matchups (builds.json missing or empty)")
		get_tree().quit(1)
		return
	_start_match()

# ---- CLI -----------------------------------------------------------------------------

# --speed: how fast a --fast match runs relative to real time (training's lever).
#   N (default 4, the original fast mode): WALL-LOCKED at N x. 60*N Hz ticks x
#     time_scale N keeps the 1/60 s per-tick sim resolution (more ticks alone would
#     only add resolution, not speed); max_physics_steps_per_frame follows N so
#     the engine never drops sim time when a frame falls behind. Never faster
#     than N x however idle the CPU is — this is why --jobs alone plateaued.
#   max: CPU-BOUND and deterministic. 60 Hz ticks, time_scale 1, no frame sleep;
#     needs the ENGINE flag `--fixed-fps 60` (before `--`; league.py passes it),
#     which advances every frame by exactly 1/60 s of sim regardless of wall
#     time — one tick per frame, so a match runs as fast as one core can step it
#     and the frame/tick relationship is identical on every machine and load.
#     Without the flag there is no in-script way to unlock the clock: warn and
#     run the wall-locked 4x.
func _apply_speed(spec: String) -> void:
	if spec == "max":
		if OS.get_cmdline_args().has("--fixed-fps"):
			OS.low_processor_usage_mode_sleep_usec = 0   # headless sleeps 6.9 ms/frame otherwise
			Engine.max_fps = 0
			return
		push_warning("arena: --speed max needs the engine flag `--fixed-fps 60` before `--` (see README §2) — running the wall-locked 4x")
		spec = "4"
	var n := clampf(float(spec), 1.0, 64.0)
	Engine.physics_ticks_per_second = int(roundf(60.0 * n))
	Engine.max_physics_steps_per_frame = maxi(8, int(roundf(60.0 * n)))
	Engine.time_scale = n

func _parse_cli() -> void:
	const FLAGS := ["--selftest", "--fast", "--spectate", "--serve"]
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := str(args[i])
		if a == "--selftest":
			_selftest = true
		elif a in FLAGS:
			_cfg[a.trim_prefix("--").replace("-", "_")] = true
		elif a.begins_with("--") and i + 1 < args.size():
			_cfg[a.trim_prefix("--").replace("-", "_")] = args[i + 1]
			i += 1
		i += 1

func _spectate_rotation() -> Array:
	var cat := ProtoBuild.catalog()
	var pairs: Array = []
	for p in cat.get("rotation", []):
		pairs.append([str(p[0]), str(p[1]), "", ""])
	if pairs.is_empty():   # fallback: mirror of the first two builds
		var ids: Array = (cat.builds as Dictionary).keys()
		if ids.size() >= 2:
			pairs.append([str(ids[0]), str(ids[1]), "", ""])
	return pairs

# ---- match / episode lifecycle ---------------------------------------------------------

func _start_match() -> void:
	_episode = 0
	_wins = [0, 0, 0]
	_results.clear()
	_ended = false
	_start_episode()

func _current_match() -> Array:
	return _rotation[_rotation_idx % _rotation.size()]

func _start_episode() -> void:
	# DETERMINISM — training fitness must be a signal, not a lottery.
	# Godot randomizes the GLOBAL random stream at startup, and gameplay draws
	# from it: creature.gd's wander target, hag.gd's retreat destination,
	# projectile.gd's volley desync. The arena seeded its OWN _rng and never
	# that one, so the same --seed produced different damage and durations on
	# every run — measured 2026-09-13: dusk_revenant vs gloam_wisp on seed 77
	# gave dmg_b [0,0,0], [0,88.6,0] and [0,112,0] across three identical runs.
	# Winners were stable, so it hid from the win-rate checks, but fitness is
	# win_rate + 0.1*(own_hp - foe_hp): the hp term was partly luck, and ES was
	# ranking candidates on it. Seeded per EPISODE (not per match) so episodes
	# still differ from one another while reproducing exactly across runs.
	seed(int(_cfg.get("seed", 2026)) * 1000003 + _rotation_idx * 9176 + _episode * 7919)
	for f in _fighters:
		if is_instance_valid(f):
			f.free_body()
	_fighters.clear()
	for n in get_tree().get_nodes_in_group("creatures"):   # leftover summons
		if not (n is ArenaProxy):
			n.queue_free()
	for n in get_tree().get_nodes_in_group("arena_projectiles"):
		n.queue_free()
	for fd in _fields:
		if is_instance_valid(fd.get("glow")):
			fd.glow.queue_free()
	_fields.clear()
	var m := _current_match()
	var defs := [ProtoBuild.build_def(m[0]), ProtoBuild.build_def(m[1])]
	if defs[0].is_empty() or defs[1].is_empty():
		push_error("arena: unknown build(s) %s" % str(m))
		_advance_or_quit(1)
		return
	var side := 1 if _episode % 2 == 0 else -1   # alternate spawn sides per episode
	for i in 2:
		var f := ArenaFighter.new()
		var spec := str(m[2 + i])
		if spec == "":
			spec = str(defs[i].get("policy", "scripted" if defs[i].get("kind") == "player" else "native"))
		f.setup(defs[i], self, Vector2(-150.0 * side * (1 if i == 0 else -1), 0),
				spec, _rng.randi())
		_fighters.append(f)
		add_child(f)
	_fighters[0].enemy = _fighters[1]
	_fighters[1].enemy = _fighters[0]
	for i in 2:
		_fighters[i].policy.setup(_fighters[i], _fighters[i].enemy, _rng.randi())
	if _rec_dir != "":
		_recorder.open_episode(_rec_dir, "%s_vs_%s" % [
				_fighters[0].build_id.get_slice(".", 2), _fighters[1].build_id.get_slice(".", 2)],
				_episode, {"a": _fighters[0].build_id, "b": _fighters[1].build_id,
				"policy_a": _fighters[0].policy.policy_id(),
				"policy_b": _fighters[1].policy.policy_id(),
				"level": Session.level, "seed": int(_cfg.get("seed", 2026))})
	_timer = 0.0
	_rec_t = 0.0
	_state = "intro"
	if _fast:
		_state = "fight"

func _end_episode(winner: ArenaFighter) -> void:
	if _state != "fight":
		return
	var duration := _timer
	_state = "end"
	_timer = 0.0
	var loser: ArenaFighter = _fighters[1] if winner == _fighters[0] else _fighters[0]
	var draw := winner == null
	var result := {"episode": _episode,
			"a": _fighters[0].build_id, "b": _fighters[1].build_id,
			"winner": "draw" if draw else winner.build_id,
			# WHICH SIDE won, not which build. In a mirror matchup — and every
			# self-play suite is one — `winner` alone is ambiguous because both
			# fighters carry the same build_id, so anything reading it scores
			# both sides as the winner (found 2026-09-14 via a net that lost
			# every episode and still scored 0.607).
			"winner_side": "draw" if draw else ("a" if winner == _fighters[0] else "b"),
			"duration_s": snappedf(duration, 0.01),
			"hp_a": snappedf(_fighters[0].hp_frac(), 0.001),
			"hp_b": snappedf(_fighters[1].hp_frac(), 0.001),
			"dmg_taken_a": snappedf(_fighters[0].damage_taken, 0.1),
			"dmg_taken_b": snappedf(_fighters[1].damage_taken, 0.1),
			"max_hp_a": snappedf(_fighters[0].max_hp_total(), 0.1),
			"max_hp_b": snappedf(_fighters[1].max_hp_total(), 0.1)}
	# damage TAKEN by source (R55): contact / bolt / field, per side — the
	# columns ml/eval/env_parity.py compares against dh_env_damage_by_source
	for side in 2:
		var tag := "a" if side == 0 else "b"
		for src in ["contact", "bolt", "field"]:
			result["dmg_%s_%s" % [src, tag]] = snappedf(
					float(_fighters[side].damage_by_source.get(src, 0.0)), 0.1)
	_results.append(result)
	_selftest_damage += _fighters[0].damage_taken + _fighters[1].damage_taken
	if _selftest_stage == 0:   # player-vs-creature: the BUILD must deal damage
		_selftest_player_damage += _fighters[1].damage_taken
	if draw:
		_wins[2] += 1
	elif winner == _fighters[0]:
		_wins[0] += 1
	else:
		_wins[1] += 1
	_recorder.log_result(result)
	_recorder.close()
	if not draw and is_instance_valid(loser.body):
		fx.explosion(loser.body.global_position, Color(1.0, 0.6, 0.3), true)

func _finish_match() -> void:
	_state = "done"
	var m := _current_match()
	print("ARENA RESULT a=%s b=%s wins_a=%d wins_b=%d draws=%d" % [
			m[0], m[1], _wins[0], _wins[1], _wins[2]])
	var out := str(_cfg.get("out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"a": m[0], "b": m[1],
					"wins_a": _wins[0], "wins_b": _wins[1], "draws": _wins[2],
					"episodes": _results}, "  "))
			f.close()
	if _serve:
		print(SERVE_DONE, out)   # the pool waits for exactly this line
		_state = "idle"
		return
	if _selftest:
		_selftest_stage += 1
		if _selftest_stage < _rotation.size():
			_rotation_idx += 1
			_start_match()
		else:
			_selftest_verdict()
	elif _fast:
		get_tree().quit(0)
	else:
		_rotation_idx += 1   # spectate: rotate to the next matchup forever
		_start_match()

func _selftest_verdict() -> void:
	var ok := true
	if _results.size() < 2:
		ok = false
		push_error("ARENA SELFTEST: episodes missing")
	if _selftest_damage <= 0.0:
		ok = false
		push_error("ARENA SELFTEST: no damage flowed")
	if _selftest_player_damage <= 0.0:
		ok = false
		push_error("ARENA SELFTEST: player build dealt no damage (proxy wiring?)")
	if _hud_frames == 0:
		ok = false
		push_error("ARENA SELFTEST: spectator camera/HUD path never ran")
	for f in _fighters:
		if is_instance_valid(f):
			f.free_body()
	_fighters.clear()
	# queue_free is deferred: let a frame pass, then count what actually leaked
	await get_tree().process_frame
	await get_tree().process_frame
	var orphans := 0
	for n in get_tree().get_nodes_in_group("creatures"):
		if n is ArenaProxy:
			orphans += 1
	if orphans > 0:
		ok = false
		push_error("ARENA SELFTEST: %d orphan proxies" % orphans)
	if ok:
		print("ARENA SELFTEST OK — %d matchups, damage flowed, no orphan proxies, HUD %d frames" \
				% [_rotation.size(), _hud_frames])
	get_tree().quit(0 if ok else 1)

func _advance_or_quit(code: int) -> void:
	if _spectate and not _selftest:
		_rotation_idx += 1
		_start_match()
	else:
		get_tree().quit(code)

# ---- per-frame --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	# tag fresh projectiles for the observation vector's nearest-hostile slots —
	# per TICK, not per frame: at --speed max (one tick per frame) or a wall-locked
	# N x (many ticks per frame) a per-frame tag would land a variable number of
	# ticks late, so the obs would depend on the speed setting
	for c in get_children():
		if c is ProtoProjectile and not c.is_in_group("arena_projectiles"):
			c.add_to_group("arena_projectiles")
	# storm bolt x mire field = CONDUCT (canon §12.41): the bolt detonates the
	# field — 2x bolt damage over 1.5x radius on the field owner's enemy
	for c in get_children():
		if not (c is ProtoProjectile) or c.dmg_type != "storm":
			continue
		for fd in _fields:
			if fd.kind != "mire":
				continue
			if c.global_position.distance_to(fd.pos) > fd.radius:
				continue
			for f in _fighters:
				if not is_instance_valid(f) or f == fd.owner or f.is_dead():
					continue
				for pr in f.living_proxies():
					if pr.global_position.distance_to(fd.pos) <= fd.radius * 1.5 \
							+ pr.body_radius:
						pr.take_damage(c.damage * 2.0,
								(pr.global_position - fd.pos).normalized())
			fx.shockwave(fd.pos, Color("7fd8ff"), fd.radius * 1.5)
			fd.until = 0.0   # consumed
			c.queue_free()
			break
	if _state == "intro":
		_timer += delta
		if _timer >= INTRO_S:
			_timer = 0.0
			_state = "fight"
		return
	if _state == "end":
		_timer += delta
		if _timer >= (0.05 if _fast and not _selftest else END_S):
			_episode += 1
			if _episode >= _episodes:
				_finish_match()
			else:
				_start_episode()
		return
	if _state != "fight":
		return
	_timer += delta
	for f in _fighters:
		if is_instance_valid(f):
			f.pre_tick(delta, f.enemy)
	_tick_fields(delta)
	_tick_summon_wiring(delta)
	# obs+action logging at 30 Hz (every 2nd physics frame at 60, 8th at 240)
	_rec_t += delta
	if _recorder.is_open() and _rec_t >= 1.0 / 30.0:
		_rec_t = 0.0
		for f in _fighters:
			if is_instance_valid(f) and not f.is_dead():
				_recorder.log_step(_timer, f, f.enemy)
	# outcome checks
	for f in _fighters:
		if is_instance_valid(f) and f.is_dead():
			_end_episode(f.enemy)
			return
	if _timer >= _time_limit:
		var a: float = _fighters[0].hp_frac()
		var b: float = _fighters[1].hp_frac()
		_end_episode(null if absf(a - b) < 0.001 \
				else (_fighters[0] if a > b else _fighters[1]))

# ---- serve mode ----------------------------------------------------------------------
# Protocol, one JSON object per line each way:
#   in   {"a":.., "b":.., "policy_a":.., "policy_b":.., "episodes":N, "time_limit":..,
#         "seed":N, "out":"/abs/path.json"}   -> runs it, writes the SAME result file
#                                                a one-shot run writes
#        {"quit":true}                        -> exit
#   out  "ARENA SERVE READY"                  -> boot finished, send work
#        "ARENA SERVE DONE <out path>"        -> that matchup is written and closed
# The result still goes to a FILE rather than stdout, so the reader is unchanged
# and Godot's own prints (art bundles, warnings) cannot corrupt a result.

const SERVE_READY := "ARENA SERVE READY"
const SERVE_DONE := "ARENA SERVE DONE "

func _serve_read_request() -> Variant:
	# OS.read_string_from_stdin() is LINE oriented and returns the line with the
	# newline ALREADY STRIPPED (verified on 4.6 — an earlier version of this
	# waited for a "\n" that never arrives and hung on the first request). A
	# request is ~250 bytes, far under the buffer, so one call is one request;
	# the accumulator exists only so a line that ever did exceed the buffer gets
	# assembled rather than silently truncated. Completeness is decided by
	# "does it parse as JSON yet", not by counting bytes.
	# GDScript's analyser does not treat `while true` as exhaustive, so the loop
	# condition is explicit and EOF is the single other exit.
	var eof := false
	while not eof:
		var chunk := OS.read_string_from_stdin(4096)
		if chunk.is_empty():
			eof = true           # the pool closed our stdin
			continue
		_stdin_buf += chunk
		var parsed: Variant = JSON.parse_string(_stdin_buf.strip_edges())
		if parsed != null:
			_stdin_buf = ""
			return parsed
	return null

func _serve_accept() -> void:
	var req: Variant = _serve_read_request()
	if req == null:
		get_tree().quit(0)       # stdin closed: the pool is done with us
		return
	if not (req is Dictionary):
		printerr("arena serve: not a JSON object")
		return
	if bool((req as Dictionary).get("quit", false)):
		get_tree().quit(0)
		return
	for k in (req as Dictionary):
		_cfg[k] = (req as Dictionary)[k]
	# EVERY per-match field is re-read here. A worker that kept a stale episode
	# count or time limit from the previous request would produce results that
	# silently disagree with a one-shot run.
	_rotation = [[str(_cfg.get("a", "")), str(_cfg.get("b", _cfg.get("a", ""))),
			str(_cfg.get("policy_a", "")), str(_cfg.get("policy_b", ""))]]
	_rotation_idx = 0
	_episodes = int(_cfg.get("episodes", 4))
	_time_limit = float(_cfg.get("time_limit", 90.0))
	_rec_dir = str(_cfg.get("record_dir", ""))
	_rng.seed = int(_cfg.get("seed", 2026))
	Session.level = int(_cfg.get("level", 20))
	_apply_speed(str(_cfg.get("speed", "max")))
	_state = "boot"
	_start_match()

func _process(delta: float) -> void:
	if _serve and _state == "idle":
		_serve_accept()          # blocks on stdin: an idle worker burns no CPU
		return
	if not _spectate or _fighters.size() < 2:
		return
	var fa: ArenaFighter = _fighters[0]
	var fb: ArenaFighter = _fighters[1]
	if not (is_instance_valid(fa) and is_instance_valid(fb)):
		return
	# A dead body frees ITSELF after its death tween (creature._die) — squarely
	# inside the END pause, while the fighter still references it. Binding a
	# freed instance to a typed var is the error, so validate BEFORE binding.
	_hud_frames += 1
	var a: Node2D = fa.alive_body() if is_instance_valid(fa.alive_body()) else null
	var b: Node2D = fb.alive_body() if is_instance_valid(fb.alive_body()) else null
	if a != null and b != null:
		var mid := (a.global_position + b.global_position) * 0.5
		_cam.global_position = _cam.global_position.lerp(mid, delta * 4.0)
		var dist := a.global_position.distance_to(b.global_position)
		var z := clampf(230.0 / maxf(dist, 120.0), 0.75, 1.5)
		_cam.zoom = _cam.zoom.lerp(Vector2(z, z), delta * 2.0)
	_hud.set_bars([
		{"name": fa.build_name, "policy": fa.policy.policy_id(),
			"frac": fa.hp_frac(), "tint": Color("7fd8ff"), "side": 0},
		{"name": fb.build_name, "policy": fb.policy.policy_id(),
			"frac": fb.hp_frac(), "tint": Color("ff9a3c"), "side": 1}])
	_hud.set_center("ARENA  ep %d/%d   %d : %d (%d draws)   %s" % [
			_episode + 1, _episodes, _wins[0], _wins[1], _wins[2],
			"" if _state == "fight" else _state.to_upper()])

func _unhandled_input(event: InputEvent) -> void:
	if not _spectate or not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_Q:
			get_tree().quit(0)
		KEY_N:
			_rotation_idx += 1
			_start_match()
		KEY_R:
			_start_match()
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 2.0
		KEY_3:
			Engine.time_scale = 4.0

# ---- summons + fields --------------------------------------------------------------------

func _tick_summon_wiring(delta: float) -> void:
	# Summons (hag wisplings et al.) are loose ProtoCreatures; point them at the
	# proxy of the fighter that did NOT summon them.
	if _fighters.size() < 2:
		return
	# same-frame death: a body can be freed while summons still need wiring —
	# never pass a freed body into a typed Node parameter
	if not (is_instance_valid(_fighters[0].body) and is_instance_valid(_fighters[1].body)):
		return
	for n in get_tree().get_nodes_in_group("creatures"):
		if n is ArenaProxy or not (n is ProtoCreature):
			continue
		if is_instance_valid(n.target_override):
			continue
		var owned_by_a := _is_descendant_of(n, _fighters[0].body)
		n.target_override = _fighters[1].proxy if owned_by_a else _fighters[0].proxy

func _is_descendant_of(n: Node, ancestor: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p == ancestor:
			return true
		p = p.get_parent()
	return false

func spawn_fire_field(at: Vector2, radius: float, duration: float, dps: float) -> void:
	spawn_field(at, radius, duration, dps, "fire")

# kind: fire | earth | mire | lava. owner: the casting fighter (exempt).
func spawn_field(at: Vector2, radius: float, duration: float, dps: float,
		kind := "fire", friendly := false, owner: ArenaFighter = null) -> void:
	# fire + earth -> LAVA (registries/fields.json Duologue, arena-generalized)
	var counter: String = {"fire": "earth", "earth": "fire"}.get(kind, "")
	if counter != "":
		for fd in _fields:
			if fd.kind == counter and fd.pos.distance_to(at) < (fd.radius + radius) * 0.75:
				var mid: Vector2 = (fd.pos + at) * 0.5
				fd.until = 0.0
				if is_instance_valid(fd.get("glow")):
					fd.glow.queue_free()
				fx.explosion(mid, Color(1.0, 0.4, 0.08), true)
				damage_number(mid + Vector2(0, -20), 0, Color("ff5a2e"), "LAVA!")
				spawn_field(mid, maxf(fd.radius, radius) * 1.05,
						duration * 1.5, dps * 2.0, "lava", friendly, owner)
				return
	var k: Dictionary = FIELD_KINDS[kind]
	var glow := ProtoGlow.make(k.glow, radius * 0.9, 0.35, 2.5, 0.35)
	glow.position = at
	glow.z_index = 2
	add_child(glow)
	telegraphs.ring(at, radius, 0.45, k.edge)
	fx.orbital(at, {"count": 5, "radius": radius * 0.45, "life": 0.3, "color": k.edge})
	if kind == "fire" or kind == "lava":
		fx.shader_burst("firestorm", at + Vector2(0, -radius * 0.55),
				{"size": radius * 2.4, "life": duration, "persist": true,
				"uniforms": {"hold": 0.88, "flash_amt": 0.0}})
		fx.light_at(at, {"radius": radius * 1.9, "color": k.glow,
				"alpha": 0.4, "life": duration, "flicker": 0.4})
	_fields.append({"pos": at, "radius": radius, "dps": dps, "kind": kind,
			"slow": float(k.slow), "owner": owner, "glow": glow,
			# SIM time, not wall time (R55, 2026-09-19). This read
			# Time.get_ticks_msec(), and under --speed max (`--fixed-fps 60`:
			# one 1/60 s tick per frame, as fast as a core steps it) a frame is
			# ~1-3 ms of wall clock, so a "6 s" field outlived the whole
			# episode — every field a caster ever dropped stayed lit until the
			# end. dh-env expires its fields in sim seconds; the gate and every
			# env_parity run graded field casters against permanent fields.
			# "until": Time.get_ticks_msec() / 1000.0 + duration, "tick": 0.25})
			"until": _field_clock + duration, "tick": 0.25})

func _tick_fields(delta: float) -> void:
	# var now := Time.get_ticks_msec() / 1000.0   # wall clock: wrong at any speed but 1x
	_field_clock += delta
	var now := _field_clock
	var dirty := false
	for fd in _fields:
		if now > fd.until:
			dirty = true
			continue
		fd.tick -= delta
		if fd.tick > 0.0:
			continue
		fd.tick = 0.25
		for f in _fighters:
			if not is_instance_valid(f) or f.is_dead() or f == fd.owner:
				continue
			for pr in f.living_proxies():   # duo: each member takes its own field hit
				if pr.global_position.distance_to(fd.pos) < fd.radius + pr.body_radius:
					if fd.dps > 0.0:
						pr.dot_damage(fd.dps * 0.25, FIELD_KINDS[fd.kind].edge)
					if fd.slow > 0.0:
						pr.apply_slow(fd.slow)
	if dirty:
		for fd in _fields:
			if now > fd.until and is_instance_valid(fd.get("glow")):
				fd.glow.queue_free()
		_fields = _fields.filter(func(fd: Dictionary) -> bool: return now <= fd.until)

func spawn_scorch(at: Vector2) -> void:
	fx.burst(at, {"amount": 6, "lifetime": 0.3, "v_min": 20.0, "v_max": 60.0,
			"s_min": 0.5, "s_max": 1.0, "color": Color(0.4, 0.25, 0.15, 0.7)})

# ---- main-contract plumbing -----------------------------------------------------------

func shake(amount: float) -> void:
	if _spectate and _cam != null:
		_cam.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))

func hitstop(_scale := 0.15, _dur := 0.045) -> void:
	pass   # training fidelity: never distort sim time for juice in the arena

func hit_spark(at: Vector2, color: Color) -> void:
	fx.burst(at, {"amount": 6, "lifetime": 0.22, "v_min": 40.0, "v_max": 120.0,
			"s_min": 0.6, "s_max": 1.2, "color": color})

func damage_number(at: Vector2, amount: float, color: Color, text := "", crit := false) -> void:
	_dmg.number(at, amount, color, text, crit)

func play_sfx(_n: String, _at: Vector2, _v := -8.0) -> void:
	pass   # the arena is silent (headless training); the hunt owns audio

func play_ui(_n: String, _v := -8.0) -> void:
	pass

func refresh_hud() -> void:
	pass   # the arena HUD polls every frame already

# Death routing from the prototype combat code (no signals — direct calls).
func on_creature_died(c: ProtoCreature) -> void:
	_route_death(c)

func on_boss_died(b: ProtoBoss) -> void:
	_route_death(b)

func on_hag_died(h: Node2D) -> void:
	_route_death(h)

func on_duo_boss_died(b: ProtoDuoBoss) -> void:
	_route_death(b)

func on_legendary_died(b) -> void:
	_route_death(b)

func on_player_death() -> void:
	for f in _fighters:
		if is_instance_valid(f) and f.is_dead():
			_end_episode(f.enemy)
			return

func _route_death(body: Node2D) -> void:
	for f in _fighters:
		if is_instance_valid(f) and f.owns_body(body):
			# duo bodies die one at a time — the FIGHTER falls when both do
			if f.is_dead():
				_end_episode(f.enemy)
			return
	# a summon died: a small pop, no match impact
	fx.impact_pop(body.global_position, Color("9a6cff"))

# Arena floor: a dark disc stage with a pale rim (the boundary IS walkability).
func _draw() -> void:
	if _world == null:
		return
	draw_circle(Vector2.ZERO, _world.radius, Color(0.055, 0.06, 0.09))
	draw_arc(Vector2.ZERO, _world.radius, 0, TAU, 96, Color(0.35, 0.45, 0.6, 0.8), 2.0)
	draw_arc(Vector2.ZERO, _world.radius * 0.35, 0, TAU, 64, Color(0.2, 0.26, 0.36, 0.5), 1.0)
