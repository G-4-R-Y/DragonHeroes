# PROTOTYPE HARNESS — spectacle-VFX budget gate (docs/design/18 §4). Drives the
# engine pools at the HIGH-intensity worst case (Whirlwind ~20 orbital ribbons +
# Fan-of-Knives 5 pinned bolt trails + a boss converging-beam/ring telegraph +
# a 60-strong damage-number storm + shockwaves) over a fixed FRAME window, then
# asserts every pool stayed within its cap, that NO node was created after warmup
# (the whole point of the pooling pass), and that the draw-call / frame-time
# budgets hold. Prints ONE gate line; exits nonzero on any breach. Run:
#   godot --headless --path game res://prototype/tests/fx_stress.tscn --quit-after 260
#
# Drives the fx / telegraph / damage APIs DIRECTLY: a deterministic, framerate-
# robust pool-invariant check (the real player/creature/boss fx call sites are
# exercised by the hunt-boot + click_test gates). Additive fill-rate on mid-range
# mobile is the separate manual `--print-fps` run required by §6 — headless has no
# GPU-fill measurement, so draws/frame_ms here are reported but trivially pass.
extends Node2D

var fx            # ProtoFx         — satisfies the main.fx contract
var telegraphs    # ProtoTelegraphs — main.telegraphs
var post          # ProtoPost       — main.post
var _dmg          # ProtoDamage     — main._dmg

const WARMUP := 8       # frames: pools allocated + settled; baseline node snapshot
const LOAD_END := 200   # frames: sustained worst-case spawn window
const EVAL := 210       # frames: assert + quit

var _frame := 0
var _baseline_nodes := 0
var _peak_nodes := 0
var _peak_draws := 0
var _peak_ms := 0.0
var _knives: Array[Node2D] = []
var _done := false

func _ready() -> void:
	add_to_group("main")            # fx.aura / ProtoDamage crit path look us up here
	ProtoFx.intensity = 1.0         # HIGH ceiling — caps are at max (40/48/24)
	fx = ProtoFx.new(); add_child(fx)
	telegraphs = ProtoTelegraphs.new(); add_child(telegraphs)
	post = ProtoPost.new(); add_child(post)
	_dmg = ProtoDamage.new(); add_child(_dmg)
	# Fan-of-Knives owners: created DURING warmup so they never count as
	# "nodes created after warmup"; repositioned and reused every load frame.
	for i in 5:
		var k := Node2D.new()
		add_child(k)
		_knives.append(k)

func _process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame == WARMUP:
		_baseline_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if _frame >= WARMUP and _frame < LOAD_END:
		_drive_load()
	if _frame >= WARMUP:
		_sample()
	if _frame >= EVAL:
		_evaluate()

func _drive_load() -> void:
	var c := global_position + Vector2(320, 180)
	# Whirlwind vortex — 20 orbital ribbons/frame; one-shots steal the oldest
	# one-shot slot past the cap, so this must clamp at 40, never exceed.
	fx.orbital(c, {"count": 20, "turns": 2.5, "radius": 26.0, "radius_jitter": 8.0,
			"life": 0.5, "color": Color(0.7, 0.5, 1.0), "owner": self})
	fx.shockwave(c, Color(0.6, 0.9, 1.0), 60.0, {"rings": 3})
	fx.ribbon_radial(c, {"count": 12, "radius": 50.0, "color": Color(0.6, 0.9, 1.0)})
	# Fan of Knives — 5 pinned STREAK_FOLLOW trails (attached once, never stolen)
	if _frame == WARMUP:
		for k in _knives:
			fx.trail_attach(k, {"color": Color(0.85, 0.9, 1.0), "width": 5.0, "life": 5.0})
	for i in _knives.size():
		_knives[i].global_position = c + Vector2.from_angle(TAU * float(i) / 5.0
				+ float(_frame) * 0.12) * 40.0
	# Boss telegraph — fill most of the 24-slot pool ONCE (proves capacity without
	# over-claiming; telegraphs are gameplay info and not intensity-scaled).
	if _frame == WARMUP + 2:
		for i in 10:
			telegraphs.beams(c, Vector2.from_angle(TAU * float(i) / 10.0),
					{"count": 6, "spread": 1.2, "dur": 3.0})
		for i in 10:
			telegraphs.ring(c + Vector2(float(i) * 4.0, 0.0), 40.0, 3.0)
	# Damage-number storm — 12/frame, ~0.8 s life → far over the 48 pool concurrently,
	# so the round-robin recycle must hold peak at 48.
	for i in 12:
		_dmg.number(c + Vector2(randf_range(-70, 70), randf_range(-45, 45)),
				randf_range(10, 999999), Color(1, 1, 1), "", i % 4 == 0)
	if _frame % 20 == 0:
		post.pulse(0.8)

func _sample() -> void:
	_peak_nodes = maxi(_peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_peak_draws = maxi(_peak_draws,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_peak_ms = maxf(_peak_ms, (Performance.get_monitor(Performance.TIME_PROCESS)
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)

func _evaluate() -> void:
	_done = true
	var rb := int((fx._pool_debug().get("ribbons", {}) as Dictionary).get("peak_in_use", 0))
	var tg := int(telegraphs._pool_debug().get("peak_in_use", 0))
	var dm := int(_dmg._pool_debug().get("peak_in_use", 0))
	var nodes_after: int = _peak_nodes - _baseline_nodes
	var fail: Array[String] = []
	if rb > 40:
		fail.append("ribbons_peak=%d>40" % rb)
	if tg > 24:
		fail.append("telegraphs_peak=%d>24" % tg)
	if dm > 48:
		fail.append("labels_peak=%d>48" % dm)
	if nodes_after > 0:
		fail.append("nodes_created_after_warmup=%d" % nodes_after)
	if _peak_draws >= 120:
		fail.append("draws=%d>=120" % _peak_draws)
	if _peak_ms >= 16.6:
		fail.append("frame_ms=%.2f>=16.6" % _peak_ms)
	if fail.is_empty():
		print(("FXSTRESS OK ribbons_peak<=40(%d) telegraphs_peak<=24(%d) " +
				"labels_peak<=48(%d) nodes_created_after_warmup=0 draws<120(%d) " +
				"frame_ms<16.6(%.2f)") % [rb, tg, dm, _peak_draws, _peak_ms])
		get_tree().quit(0)
	else:
		print("FXSTRESS FAIL " + ", ".join(fail))
		get_tree().quit(1)
