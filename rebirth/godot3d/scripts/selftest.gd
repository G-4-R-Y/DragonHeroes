# REBIRTH / Godot 3D — headless gate. Runs the slice with the autopilot at
# --fixed-fps 60 and asserts OUTCOMES (never "it booted"): the valley exists,
# the hunter walks, i-frames ate a hit, a 3-hit combo landed, the dragon used
# all 5 signature skills and enraged, died, dropped, and the rematch reset it —
# with zero VFX pool overflow and no node growth after warmup.
# Run: godot --headless --fixed-fps 60 --path rebirth/godot3d  (REBIRTH_SELFTEST=1)
class_name RbSelftest
extends Node

const LIMIT_S := 300.0
var slice: Node
var sim_t := 0.0
var nodes_warm := -1
var enraged_seen := false
var rematch_seen := false
var kills_at_rematch := 0
var early_ok := false
var _last_kills := 0
var _wall_start := 0

func _ready() -> void:
	slice = get_parent()
	_wall_start = Time.get_ticks_msec()
	var dragon: RbDragon = slice.get("dragon")
	dragon.enraged_now.connect(func() -> void: enraged_seen = true)

func _fail(reason: String) -> void:
	print("REBIRTH3D FAIL — ", reason)
	get_tree().quit(1)

func _physics_process(delta: float) -> void:
	sim_t += delta
	var hunter: RbHunter = slice.get("hunter")
	var dragon: RbDragon = slice.get("dragon")
	var valley: RbValley = slice.get("valley")
	var fx: RbFx = slice.get("fx")
	var hud: RbHud = slice.get("hud")
	var kills: int = slice.get("kills")
	if not early_ok and sim_t >= 0.5:
		early_ok = true
		if valley.tri_count <= 0:
			_fail("valley has no triangles")
			return
		if not is_finite(hunter.position.y) or absf(hunter.position.y - valley.height_at(hunter.position.x, hunter.position.z)) > 0.01:
			_fail("hunter not grounded: %s" % hunter.position)
			return
	if sim_t >= 3.0 and sim_t < 3.02 and hunter.stats["distance"] < 5.0:
		_fail("hunter did not walk (%.1f m in 3 s)" % hunter.stats["distance"])
		return
	if sim_t >= 10.0 and nodes_warm < 0:
		nodes_warm = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	if not is_finite(hunter.position.x) or not is_finite(dragon.position.x):
		_fail("NaN position")
		return
	if kills > _last_kills:
		_last_kills = kills
		kills_at_rematch = kills
	if kills_at_rematch > 0 and slice.get("state") == "fight" and dragon.hp == dragon.HP_MAX and dragon.state != "dead":
		rematch_seen = true
	var missing: Array[String] = []
	if dragon.used.size() < 5:
		missing.append("skills %d/5 %s" % [dragon.used.size(), dragon.used.keys()])
	if not enraged_seen:
		missing.append("enrage")
	if hunter.stats["iframe_avoids"] < 1:
		missing.append("iframe_avoid")
	if hunter.stats["max_combo"] < 3:
		missing.append("combo3 (max %d)" % hunter.stats["max_combo"])
	if kills < 1:
		missing.append("kill")
	if hud.toasts < 1:
		missing.append("toast")
	if not rematch_seen:
		missing.append("rematch")
	if missing.is_empty():
		var nodes_now := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		if fx.overflow != 0:
			_fail("fx pool overflow x%d" % fx.overflow)
			return
		if nodes_warm >= 0 and nodes_now > nodes_warm:
			_fail("node growth after warmup %d -> %d" % [nodes_warm, nodes_now])
			return
		var wall := (Time.get_ticks_msec() - _wall_start) / 1000.0
		print("REBIRTH3D OK — sim %.0fs in %.1fs wall · skills %s · enrage · iframe avoids %d · max combo %d · hits %d · dmg taken %.0f · kills %d · toast '%s' · rematch · fx overflow 0 · nodes %d" % [
			sim_t, wall, dragon.used, hunter.stats["iframe_avoids"], hunter.stats["max_combo"], hunter.stats["hits"], hunter.stats["dmg_taken"], kills, hud.last_toast, nodes_now])
		get_tree().quit(0)
		return
	if sim_t >= LIMIT_S:
		_fail("time limit (%.1fs wall); missing: %s · hunter hp %.0f dragon hp %.0f state %s · stats %s" % [(Time.get_ticks_msec() - _wall_start) / 1000.0, ", ".join(missing), hunter.hp, dragon.hp, slice.get("state"), hunter.stats])
