## PROTOTYPE HARNESS presentation lifetime adapter. Official entity/award state
## belongs to dh-sim/dh-server. These local Hunt snapshots confer no server trust.
## Dormant creatures occupy files, never retained scene nodes or a world-sized
## in-memory dictionary. Work drains one creature/file per rendered frame.
class_name ProtoEncounterResidency
extends Node

const SLEEP_DISTANCE := 640.0
const WAKE_DISTANCE := 512.0
const SCRIPTS := {
	"res://prototype/creature.gd": preload("res://prototype/creature.gd"),
	"res://prototype/wisp.gd": preload("res://prototype/wisp.gd"),
	"res://prototype/boss.gd": preload("res://prototype/boss.gd"),
	"res://prototype/hag.gd": preload("res://prototype/hag.gd"),
	"res://prototype/pyre_sovereign.gd": preload("res://prototype/pyre_sovereign.gd"),
	"res://prototype/terravore_colossus.gd": preload("res://prototype/terravore_colossus.gd"),
	"res://prototype/pickup.gd": preload("res://prototype/pickup.gd"),
}
const LOOT_STATE := ["kind", "amount", "item", "_t", "_base_y", "_warned"]
const STATE := ["max_hp", "hp", "damage", "move_speed", "body_radius", "aggro_range",
	"attack_reach", "attack_arc_deg", "windup_time", "attack_cd", "gold_min", "gold_max",
	"stone_chance", "snare_chance", "capturable", "guaranteed_stone", "elite", "item_chance",
	"archetype", "elite_affix", "fiery", "name_tag", "species_name", "dmg_scale",
	"legendary_entry", "_entry", "_bundle", "_base_tint", "_scale", "pack_anchor", "threat",
	"_cd", "_enrage_t", "_slow_t", "_burn_t", "_burn_tick", "_burn_dps", "_bleed_t",
	"_bleed_tick", "_bleed_dps", "_bleed_stacks", "_expose_t", "_stagger_t",
	"display_name", "bar_color", "_skill_cd", "_cd_scale", "_enraged", "_cursed",
	"_aggro_cried", "element"]

var hunt: Node
var root := ""
var _next_id := 1
var _sleep_queue: Array[WeakRef] = []
var _scan_keys: Array[Vector2i] = []
var _scan: DirAccess
var _scan_path := ""
var _scan_centers: Array[Vector2i] = []
var _boss_records := {}  # only dormant authored bosses, bounded by this Hunt's roster
var asleep_count := 0
var restored_count := 0
var asleep_loot := 0
var worst_step_ms := 0.0

func _ready() -> void:
	hunt = get_parent()
	root = "user://hunt-residency-%d-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
	DirAccess.make_dir_recursive_absolute(root)

func identity(c: Node2D) -> int:
	if not c.has_meta("encounter_id"):
		c.set_meta("encounter_id", _next_id)
		_next_id += 1
	return int(c.get_meta("encounter_id"))

func _folder(key: Vector2i) -> String:
	return root.path_join("%d_%d" % [key.x, key.y])

func was_rolled(key: Vector2i) -> bool:
	return FileAccess.file_exists(_folder(key).path_join("rolled"))

func mark_rolled(key: Vector2i) -> bool:
	DirAccess.make_dir_recursive_absolute(_folder(key))
	var file := FileAccess.open(_folder(key).path_join("rolled"), FileAccess.WRITE)
	return file != null

func nearest_hunter(pos: Vector2) -> float:
	var distance := INF
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p): distance = minf(distance, p.global_position.distance_to(pos))
	return distance

func wake_distance() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return WAKE_DISTANCE
	# Keep the full visible diagonal plus approach time, also when zoomed out.
	return maxf(WAKE_DISTANCE, (get_viewport().get_visible_rect().size / camera.zoom).length() * 0.5 + 128.0)

func sleep_distance() -> float:
	return wake_distance() + (SLEEP_DISTANCE - WAKE_DISTANCE)

func active_count() -> int:
	return get_tree().get_nodes_in_group("creatures").size()

func sweep() -> void:
	# Replacing the bounded weak queue also drops obsolete requests after a turn.
	_sleep_queue.clear()
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is ProtoCreature and not c.dead:
			identity(c)
			if _can_sleep(c): _sleep_queue.append(weakref(c))
	for loot in get_tree().get_nodes_in_group("ground_loot"):
		if _can_sleep(loot): _sleep_queue.append(weakref(loot))
	var centers: Array[Vector2i] = []
	for p in get_tree().get_nodes_in_group("player"):
		centers.append(hunt._chunk_of(p.global_position))
	if centers != _scan_centers:
		if _scan != null: _scan.list_dir_end()
		_scan = null
		_scan_keys.clear()
		_scan_centers = centers
	if _scan == null and _scan_keys.is_empty():
		for p in get_tree().get_nodes_in_group("player"):
			var center: Vector2i = hunt._chunk_of(p.global_position)
			for y in range(-1, 2):
				for x in range(-1, 2):
					var key := center + Vector2i(x, y)
					if not _scan_keys.has(key): _scan_keys.append(key)
		_scan_keys.sort_custom(func(a, b): return nearest_hunter(Vector2(a * 1024 + Vector2i(512, 512))) < nearest_hunter(Vector2(b * 1024 + Vector2i(512, 512))))

func _can_sleep(c: Node2D) -> bool:
	if c is ProtoPickup:
		return not c._collected and not c.is_queued_for_deletion() and nearest_hunter(c.global_position) > sleep_distance()
	if not c is ProtoCreature: return false
	if c.dead or c.is_queued_for_deletion() or c.is_in_group("pet"):
		return false
	if not SCRIPTS.has(c.get_script().resource_path): return false
	if nearest_hunter(c.global_position) <= sleep_distance(): return false
	# A hunter can teleport while a shot is still in flight. Keep possible targets
	# simulating until that finite shot resolves; unloading must not cancel hits.
	for bolt in get_tree().get_nodes_in_group("projectiles"):
		if bolt._finished or bolt.is_queued_for_deletion(): continue
		var reach: float = bolt.velocity.length() * bolt.lifetime + c.move_speed * bolt.lifetime + c.body_radius + bolt.radius
		if bolt.global_position.distance_to(c.global_position) <= reach: return false
	if c is ProtoDuoBoss and is_instance_valid(c.partner) and not c.partner.dead:
		if nearest_hunter(c.partner.global_position) <= sleep_distance(): return false
	return true

func _process(_dt: float) -> void:
	var start := Time.get_ticks_usec()
	if not _sleep_queue.is_empty():
		var c = _sleep_queue.pop_front().get_ref()
		if is_instance_valid(c) and _can_sleep(c): _sleep(c)
	elif not _wake_near_boss():
		_scan_one()
	worst_step_ms = maxf(worst_step_ms, (Time.get_ticks_usec() - start) / 1000.0)

func _sleep(c: Node2D) -> bool:
	var id := identity(c)
	var is_loot := c is ProtoPickup
	var state := {}
	for property in LOOT_STATE if is_loot else STATE:
		var value = c.get(property)
		if value != null: state[property] = value
	var partner_id := int(c.get_meta("encounter_partner_id", 0))
	if c is ProtoDuoBoss and is_instance_valid(c.partner) and not c.partner.dead:
		partner_id = identity(c.partner)
		# The partner may drain on a later frame after this body has been freed.
		# Keep symmetric identity links independently of scene-node references.
		c.set_meta("encounter_partner_id", partner_id)
		c.partner.set_meta("encounter_partner_id", id)
	var role := ""
	if not is_loot and c == hunt.boss: role = "matriarch"
	elif c == hunt.legendary_boss: role = "legendary"
	elif hunt._bosses.has(c): role = "boss"
	var record := {"version": 1, "id": id, "script": c.get_script().resource_path,
		"position": c.global_position, "state": state, "role": role, "partner": partner_id,
		"entity_kind": "loot" if is_loot else "creature",
		"sprite_tint": Color.WHITE if is_loot else c.sprite.self_modulate,
		"flip": false if is_loot else c.sprite.flip_h}
	var folder := _folder(hunt._chunk_of(c.global_position))
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("%d.bin" % id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false  # leave the creature alive if persistence failed
	file.store_var(record, false)  # primitives only; never serialize objects/scripts
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if role != "":
		_boss_records[id] = {"path": path, "position": c.global_position, "partner": partner_id}
		hunt._bosses.erase(c)
		if role == "matriarch": hunt.boss = null
		if role == "legendary": hunt.legendary_boss = null
	c.remove_from_group("ground_loot" if is_loot else "creatures")
	c.set_physics_process(false)
	c.queue_free()
	if is_loot: asleep_loot += 1
	else: asleep_count += 1
	return true

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() > 65536: return {}
	var data = file.get_var(false)
	if typeof(data) != TYPE_DICTIONARY or data.get("version") != 1: return {}
	if not SCRIPTS.has(data.get("script", "")): return {}
	return data

func _wake_near_boss() -> bool:
	for id in _boss_records.keys():
		var r: Dictionary = _boss_records[id]
		if nearest_hunter(r.position) <= wake_distance() and hunt.world.is_ready_at(r.position):
			return _wake(_read(r.path), r.path)
	return false

func _live(id: int) -> Node2D:
	for c in get_tree().get_nodes_in_group("creatures") + get_tree().get_nodes_in_group("ground_loot"):
		if int(c.get_meta("encounter_id", 0)) == id: return c
	return null

func _wake(record: Dictionary, path: String, pair := true) -> bool:
	if record.is_empty() or _live(int(record.id)) != null: return false
	if record.get("entity_kind", "creature") == "loot":
		return _wake_loot(record, path)
	var mate_path := ""
	if pair and _boss_records.has(int(record.partner)):
		mate_path = _boss_records[int(record.partner)].path
	var needed := 2 if mate_path != "" else 1
	if active_count() + needed > hunt.REPOP_CAP: return false
	# A paired wake is one operation. Wait for both pieces of terrain to draw.
	var mate := _read(mate_path) if mate_path != "" else {}
	if mate_path != "" and (mate.is_empty() or not hunt.world.is_ready_at(mate.position)):
		return false
	# Claim before constructing a live body. A failed deletion can leave an
	# ignored .active tombstone, but never a second restorable copy after death.
	if DirAccess.rename_absolute(path, path + ".active") != OK: return false
	var c: ProtoCreature = SCRIPTS[record.script].new()
	var state: Dictionary = record.state
	if not state.get("legendary_entry", {}).is_empty(): c.setup_legendary(state.legendary_entry)
	elif not state.get("_entry", {}).is_empty(): c.setup_from_entry(state._entry, str(state.get("elite_affix", "")))
	elif record.script == "res://prototype/creature.gd": c.setup_archetype(str(state.archetype), str(state.elite_affix))
	c.global_position = record.position
	c.pack_anchor = state.pack_anchor
	if state.has("element"): c.set("element", state.element)
	c.set_meta("encounter_id", int(record.id))
	c.set_meta("encounter_partner_id", int(record.partner))
	hunt.add_child(c)
	# _ready applies the original species visuals. Restore FINAL spawn-time
	# numbers afterwards so leveling while away cannot reroll or heal this foe.
	for property in STATE:
		if state.has(property): c.set(property, state[property])
	c.sprite.scale = Vector2.ONE * c._scale
	c.sprite.self_modulate = record.sprite_tint
	c.sprite.flip_h = record.flip
	c._state = "recover"
	c._timer = 0.5
	c._flash = 0.0
	c.sprite.play("idle")
	if record.role != "":
		hunt._bosses.append(c)
		if record.role == "matriarch": hunt.boss = c
		if record.role == "legendary": hunt.legendary_boss = c
	_boss_records.erase(int(record.id))
	DirAccess.remove_absolute(path + ".active")
	asleep_count -= 1
	restored_count += 1
	if not mate.is_empty(): _wake(mate, mate_path, false)
	if c is ProtoDuoBoss:
		var partner := _live(int(record.partner))
		if partner is ProtoDuoBoss:
			c.partner = partner
			partner.partner = c
	return true

func _wake_loot(record: Dictionary, path: String) -> bool:
	if record.script != "res://prototype/pickup.gd": return false
	if DirAccess.rename_absolute(path, path + ".active") != OK: return false
	var loot := ProtoPickup.new()
	loot.position = record.position
	loot.set_meta("encounter_id", int(record.id))
	# Item ID, affixes, rarity and amount are the original roll, never regenerated.
	for property in LOOT_STATE:
		if record.state.has(property): loot.set(property, record.state[property])
	hunt.add_child(loot)
	# _ready initializes the bobbing anchor; restore it to avoid creeping positions.
	loot._base_y = record.state._base_y
	DirAccess.remove_absolute(path + ".active")
	asleep_loot -= 1
	return true

func _scan_one() -> void:
	# Loot wakes even when the creature cap is full. Creature records enforce the
	# cap inside _wake; refusing the whole scan would hide a full bag's ground loot.
	if _scan == null:
		if _scan_keys.is_empty(): return
		_scan_path = _folder(_scan_keys.pop_front())
		_scan = DirAccess.open(_scan_path)
		if _scan == null: return
		_scan.list_dir_begin()
	var name := _scan.get_next()
	if name == "":
		_scan.list_dir_end()
		_scan = null
		return
	if not name.ends_with(".bin") or _scan.current_is_dir(): return
	var path := _scan_path.path_join(name)
	var r := _read(path)
	if not r.is_empty() and nearest_hunter(r.position) <= wake_distance() and hunt.world.is_ready_at(r.position):
		_wake(r, path)

func _exit_tree() -> void:
	if _scan != null: _scan.list_dir_end()
	# This Hunt is over; character saves and other Hunt directories are untouched.
	var directory := DirAccess.open(root)
	if directory == null: return
	for name in directory.get_directories():
		var path := root.path_join(name)
		var chunk := DirAccess.open(path)
		if chunk != null:
			for file in chunk.get_files(): DirAccess.remove_absolute(path.path_join(file))
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(root)
