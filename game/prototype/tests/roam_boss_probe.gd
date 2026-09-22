# ROAM BOSS PROBE — the roaming-boss slot as a gate (R44/R61; Ricardo: "Bosses
# are not spawning randomly among new hordes while exploring... I expect to meet
# them out in the map, not only at lairs", and then "Bosses spawning together
# and fighting multiple at once is actually a pretty fun mechanic, with
# unexpected crossovers").
#
# Asserts the whole contract, and every assertion has teeth — reverting the
# matching line in main.gd makes exactly one of these fail:
#   (a) at the ORIGIN (danger 0) the pressure roll never spawns a warlord —
#       the authored 5x5 keeps its authored bosses,
#   (b) out in the danger band warlords DO ride the hordes in,
#   (c) several are alive at once (the crossover Ricardo asked for),
#   (d) never more than ROAM_BOSS_MAX_ALIVE — the frame budget holds,
#   (e) the cooldown blocks the roll right after a spawn,
#   (f) a warlord is on the boss bar's list but is NOT the hunt's legendary,
#   (g) killing a warlord leaves the hunt's legendary state untouched,
#   (h) a warlord wears its CATALOG name, not the chassis default.
#   godot --headless --path game res://prototype/tests/roam_boss_probe.tscn
extends Node

const CHUNK_PX := 64 * 16          # world_gen: 64 tiles of 16 px
const ORIGIN_WAVES := 200          # rolls at danger 0 that must all come up empty
const FIELD_WAVES := 400           # rolls out in the band (odds ~0.09/roll)

var _hunt: Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_hunt = preload("res://prototype/main.tscn").instantiate()
	add_child(_hunt)
	var waited := 0.0
	while waited < 60.0 and _hunt.player == null:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if _hunt.player == null:
		_verdict(false, "hunt never booted")
		return
	if _hunt._ground_species.is_empty():
		_verdict(false, "no ground roster — the repop pass early-returns")
		return

	# (a) the authored window is sacred: danger 0 must never roll a warlord
	for i in ORIGIN_WAVES:
		_hunt._roam_boss_cd = 0.0
		await _wave()
	if not _hunt._roam_bosses.is_empty():
		_verdict(false, "a warlord spawned INSIDE the authored 5x5 (danger 0)")
		return

	# walk out into the danger band (danger = chunks-from-origin / 4)
	var home: Vector2 = _hunt.player.global_position
	for step in 9:
		_hunt.player.global_position = home + Vector2((step + 1) * CHUNK_PX, 0)
		await get_tree().process_frame
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout        # let the streamer settle

	# (b)+(c)+(d) the slot fires, stacks, and stays under the ceiling
	var peak := 0
	var spawns := 0
	var waves := 0
	var seen := {}
	for i in FIELD_WAVES:
		_hunt._roam_boss_cd = 0.0                     # the probe owns the clock
		await _wave()
		for b in _hunt._roam_bosses:
			if not seen.has(b.get_instance_id()):
				seen[b.get_instance_id()] = true
				spawns += 1
		peak = maxi(peak, _hunt._roam_bosses.size())
		if peak > _hunt.ROAM_BOSS_MAX_ALIVE:
			_verdict(false, "%d warlords alive at once, cap is %d" % [
					peak, _hunt.ROAM_BOSS_MAX_ALIVE])
			return
		waves = i + 1
		if peak >= 2 and spawns >= 3:
			break
	if spawns == 0:
		_verdict(false, "%d waves out in the danger band and no warlord ever rode in"
				% FIELD_WAVES)
		return
	if peak < 2:
		_verdict(false, "warlords spawn (%d) but never overlap — no crossover" % spawns)
		return

	# (e) the cooldown: a fresh spawn stamps it, and a roll under it is refused
	var alive_before: int = _hunt._roam_bosses.size()
	if _hunt._roam_boss_cd <= 0.0:
		_verdict(false, "a warlord spawned without stamping the cooldown")
		return
	for m in get_tree().get_nodes_in_group("creatures"):
		if is_instance_valid(m) and not _hunt._roam_bosses.has(m):
			m.queue_free()
	await get_tree().process_frame
	for i in 40:
		_hunt._repopulate()                           # cooldown NOT cleared this time
	await get_tree().process_frame
	if _hunt._roam_bosses.size() != alive_before:
		_verdict(false, "the cooldown did not hold: %d -> %d warlords" % [
				alive_before, _hunt._roam_bosses.size()])
		return

	# (f) on the bar's list, never wearing the hunt's crown
	var warlord = _hunt._roam_bosses[0]
	if not _hunt._bosses.has(warlord):
		_verdict(false, "a warlord is missing from _bosses — it gets no boss bar")
		return
	if warlord == _hunt.boss or warlord == _hunt.legendary_boss:
		_verdict(false, "a warlord took over the hunt's own boss slot")
		return

	# (h) every warlord wears its catalog name, not the chassis default — the
	# duo chassis stamp theirs in _ready(), which runs after main names them
	var tail: String = (ProtoLang.t("warlord_suffix") % "").strip_edges()
	for b in _hunt._roam_bosses:
		if not str(b.display_name).ends_with(tail):
			_verdict(false, "warlord shows the chassis name '%s' (want '... %s')" % [
					str(b.display_name), tail])
			return

	# (g) its death leaves the hunt's legendary state alone
	var leg_before = _hunt.legendary_boss
	var name_before: String = _hunt._legendary_name
	_hunt.on_legendary_died(warlord)
	if _hunt.legendary_boss != leg_before or _hunt._legendary_name != name_before:
		_verdict(false, "a warlord's death cleared the HUNT's legendary (%s -> %s)" % [
				name_before, _hunt._legendary_name])
		return

	_verdict(true, ("%d warlords over %d waves, %d alive at the peak (cap %d); "
			+ "none in %d waves at danger 0; %s kept its catalog name") % [
			spawns, waves, peak, _hunt.ROAM_BOSS_MAX_ALIVE, ORIGIN_WAVES,
			str(warlord.display_name)])

# One pressure wave with a clear field: the repop pass early-returns while ten
# foes stand near the hunter, so the probe clears everything but the warlords.
func _wave() -> void:
	for m in get_tree().get_nodes_in_group("creatures"):
		if is_instance_valid(m) and not _hunt._roam_bosses.has(m):
			m.queue_free()
	await get_tree().process_frame
	_hunt._repopulate()
	await get_tree().process_frame

func _verdict(ok: bool, msg: String) -> void:
	if ok:
		print("ROAM BOSS OK — ", msg)
	else:
		push_error("ROAM BOSS FAIL — " + msg)
	get_tree().quit(0 if ok else 1)
