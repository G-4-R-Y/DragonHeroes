# PROTOTYPE HARNESS — cross-scene session state (autoload "Session"). This is a
# stand-in for the server-authoritative account/character state that will live
# behind Nakama + the economy core (docs/tech/26); the client never owns real
# state in the shipping architecture (canon hard rule). Dies when dh-sim lands.
extends Node

const ATTRIBUTES := ["might", "agility", "intellect", "vitality", "willpower"]
const BASE_ATTRIBUTE := 10
const MAX_PETS := 3            # (proposal) all bonded pets hunt together

var player_name := "Hunter"
var class_id := "core.class.reaver"
const CLASS_NAMES := {"core.class.reaver": "Reaver",
		"core.class.emberkin": "Emberkin", "core.class.frostbinder": "Frostbinder",
		"core.class.mage": "Gloam Mage", "core.class.rogue": "Veilblade"}

func class_display() -> String:
	return str(CLASS_NAMES.get(class_id, "Reaver"))
var level := 1
var gold := 0
var stones := 0
var snares := 0            # Soul Snares — pet capture charges (design/13 §7.1)
var kills := 0
var has_blade := false     # Emberfang obtained at least once (display flavor)
var rune_granted := false  # first Elite kill guarantees a rune drop (proposal)
# Bonded pets (up to MAX_PETS; all spawn and fight together). Each entry:
# {uid, name, species, roll_pct, skills} — instance-rolled at capture from
# prototype/data/abyssal.json (canon §3).
var pets: Array = []
var attribute_points := 5  # +5 per level-up (proposal: 1 level / 20 kills)
var attributes := {
	"might": BASE_ATTRIBUTE, "agility": BASE_ATTRIBUTE, "intellect": BASE_ATTRIBUTE,
	"vitality": BASE_ATTRIBUTE, "willpower": BASE_ATTRIBUTE,
}

# Item instances (ProtoItems dictionaries). Inventory caps at 40 (proposal);
# equipment holds one item (or {}) per gear slot; skill_runes holds the rune
# item socketed per skill (canon §4 runes proposal) — {} when empty.
var inventory: Array = []
# Haven chest (Ricardo): big stash at town; bag <-> chest moves are free.
const STASH_CAP := 120
var stash: Array = []
var equipment := {"weapon": {}, "chest": {}, "helm": {}, "boots": {},
		"amulet": {}, "ring": {}}
var skill_runes := {"cleave": {}, "rend": {}, "dodge": {}}
# Stabled pets (Ricardo: pets are NEVER abandoned) — overflow captures move the
# oldest ACTIVE bond here; manage active/stabled in CHARACTER → Pets.
var stables: Array = []
# Skill progression (proposal): 1 point per level; class-tree nodes
# (skill_trees.json — 20 actives + 8 passives per class) are learned here and
# feed the StatBlock (stats.gd). Roots are free (cost 0). skill_loadout maps
# hotbar slots 1-4 to learned ACTIVE node ids ("" = empty).
var skill_points := 0
var learned_nodes: Array = ["root_cleave"]
var skill_loadout: Array = ["", "", "", ""]
# Mounts (Ricardo 2026-07-10, proposals): walking + flying. Owned instances:
# {uid, key, name, kind: walk|fly, speed_mult, rarity, tint}. M rides the active.
var mounts: Array = []
var active_mount := -1

var _content_cache := {}
var _logged_in := false    # saving starts at login — keeps tests/menu hermetic
var _save_dirty := false
var _save_t := 0.0

func _ready() -> void:
	# Cap the interactive client, while headless arena search keeps its explicit
	# uncapped fixed-step clock. A cap alone does not establish a frame budget.
	if DisplayServer.get_name() != "headless": Engine.max_fps = 60
	setup_input()   # actions exist from frame one, in EVERY scene (menu/haven/hunt)

# Throttled autosave: mutations mark dirty; at most one disk write per 2 s.
func _process(delta: float) -> void:
	_save_t += delta
	if _save_dirty and _save_t >= 2.0:
		save()

func _exit_tree() -> void:
	if _save_dirty:
		save()

# All gameplay/UI input actions — registered at autoload time so the character
# panel closes at the Haven too, not only in the hunt (was a v4 bug).
func setup_input() -> void:
	if InputMap.has_action("toggle_character"):
		return
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE], "dodge": [KEY_SHIFT],
		"capture": [KEY_F], "bestial": [KEY_Q], "skill2": [KEY_E],
		"mount": [KEY_Z],   # Z: reachable without leaving WASD (was M — Ricardo)
		"flask": [KEY_R],   # Ember Flask (heal): kill-fed charges, haven-refilled
		"toggle_character": [KEY_C, KEY_TAB], "toggle_keybinds": [KEY_K],
		"toggle_debug": [KEY_F3],   # fps/mem/VRAM readout (roadmap 3c)
		# skill bar: 1-4 cast the assigned class-tree actives (skill_loadout)
		"slot1": [KEY_1], "slot2": [KEY_2], "slot3": [KEY_3], "slot4": [KEY_4],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", lmb)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("dodge", rmb)

# ---- character persistence (user://saves/<name>.json) -------------------------
# Stand-in for the server-authoritative character store (docs/tech/26): the
# shipping game NEVER trusts a client-side save. One JSON per hunter name.

func login(pname: String) -> void:
	if _logged_in and _save_dirty:
		save()
	_reset_character()
	player_name = pname
	_logged_in = true
	if FileAccess.file_exists(save_path()):
		_load_state()
	else:
		# A fresh hunter starts with points to spend: 2-3 actives learnable at
		# the character screen, not one lonely root skill (Ricardo 2026-07-12).
		skill_points = 3
		save()   # claim the slot right away

func leave_character() -> void:
	save()
	_logged_in = false

func _reset_character() -> void:
	# A return to the title screen must not clone the old hunter into a new
	# save. Keep the menu's class selection, reset all per-character state.
	level = 1
	gold = 0
	stones = 0
	snares = 0
	kills = 0
	has_blade = false
	rune_granted = false
	attribute_points = 5
	for k in ATTRIBUTES:
		attributes[k] = BASE_ATTRIBUTE
	inventory = []
	stash = []
	pets = []
	stables = []
	mounts = []
	active_mount = -1
	for slot in equipment:
		equipment[slot] = {}
	for skill in skill_runes:
		skill_runes[skill] = {}
	skill_points = 3
	learned_nodes = ["root_cleave"]
	skill_loadout = ["", "", "", ""]
	_save_dirty = false
	_save_t = 0.0

func companion_name(data: Dictionary) -> String:
	var nickname := str(data.get("nickname", "")).strip_edges()
	return nickname if not nickname.is_empty() else str(data.get("name", "?"))

func rename_companion(uid: int, nickname: String) -> bool:
	var cleaned := ""
	for ch in nickname.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			cleaned += ch
	cleaned = cleaned.left(24)
	for collection in [pets, stables, mounts]:
		for pet in collection:
			if int(pet.get("uid", -1)) == uid:
				pet["nickname"] = cleaned
				for body in get_tree().get_nodes_in_group("pet"):
					if body.uid == uid:
						body.pet_name = companion_name(pet)
				request_save()
				return true
	return false

func save_path() -> String:
	var safe := player_name.to_lower().replace(" ", "_").validate_filename()
	return "user://saves/%s.json" % safe

func request_save() -> void:
	if _logged_in:
		_save_dirty = true

func save() -> void:
	if not _logged_in:
		return
	_save_dirty = false
	_save_t = 0.0
	DirAccess.make_dir_recursive_absolute("user://saves")
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		push_warning("Session.save: cannot write " + save_path())
		return
	f.store_string(JSON.stringify({"version": 1, "player_name": player_name,
			"class_id": class_id,
			"level": level, "gold": gold, "stones": stones, "snares": snares,
			"kills": kills, "has_blade": has_blade, "rune_granted": rune_granted,
			"attribute_points": attribute_points, "attributes": attributes,
			"inventory": inventory, "equipment": equipment,
			"skill_runes": skill_runes, "pets": pets, "stables": stables,
			"skill_points": skill_points, "learned_nodes": learned_nodes,
			"skill_loadout": skill_loadout,
			"mounts": mounts, "active_mount": active_mount,
			"stash": stash}, "\t"))

func _load_state() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not (parsed is Dictionary):
		push_warning("Session: corrupt save " + save_path() + " — starting fresh")
		return
	var d: Dictionary = parsed
	class_id = str(d.get("class_id", class_id))
	level = int(d.get("level", 1))
	gold = int(d.get("gold", 0))
	stones = int(d.get("stones", 0))
	snares = int(d.get("snares", 0))
	kills = int(d.get("kills", 0))
	has_blade = bool(d.get("has_blade", false))
	rune_granted = bool(d.get("rune_granted", false))
	attribute_points = int(d.get("attribute_points", 0))
	var attrs: Dictionary = d.get("attributes", {})
	for k in ATTRIBUTES:
		attributes[k] = int(attrs.get(k, BASE_ATTRIBUTE))
	inventory = d.get("inventory", [])
	var eq: Dictionary = d.get("equipment", {})
	for slot in equipment:
		equipment[slot] = eq.get(slot, {}) if eq.get(slot, {}) is Dictionary else {}
	var sr: Dictionary = d.get("skill_runes", {})
	for skill in skill_runes:
		skill_runes[skill] = sr.get(skill, {}) if sr.get(skill, {}) is Dictionary else {}
	pets = d.get("pets", [])
	stables = d.get("stables", [])
	skill_points = int(d.get("skill_points", 0))
	learned_nodes = d.get("learned_nodes", ["root_cleave"])
	# skill bar loadout: missing in old saves — default to 4 empty slots
	var lo: Array = d.get("skill_loadout", []) if d.get("skill_loadout", []) is Array else []
	for i in 4:
		skill_loadout[i] = str(lo[i]) if i < lo.size() else ""
	mounts = d.get("mounts", [])
	active_mount = int(d.get("active_mount", -1))
	stash = d.get("stash", [])
	# JSON round-trips numbers as floats — normalize the int fields and make
	# sure freshly rolled uids never collide with loaded ones.
	var top := 0
	for it in _all_item_dicts():
		for key in ["uid", "upgrade_tier", "power", "roll_pct"]:
			if it.has(key):
				it[key] = int(it[key])
		top = maxi(top, int(it.get("uid", 0)))
	ProtoItems.bump_uid(top)

func _all_item_dicts() -> Array:
	var out: Array = []
	out.append_array(inventory)
	for slot in equipment:
		if not (equipment[slot] as Dictionary).is_empty():
			out.append(equipment[slot])
	for skill in skill_runes:
		if not (skill_runes[skill] as Dictionary).is_empty():
			out.append(skill_runes[skill])
	out.append_array(pets)
	out.append_array(stables)
	out.append_array(mounts)
	out.append_array(stash)
	return out

# Menu helper: every saved hunter as {name, level} (newest login continues it).
func list_saves() -> Array:
	var out: Array = []
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string("user://saves/" + f))
		if parsed is Dictionary:
			out.append({"name": str(parsed.get("player_name", f.get_basename())),
					"level": int(parsed.get("level", 1))})
	return out

# ---- inventory / equipment ------------------------------------------------------

func add_item(item: Dictionary) -> bool:
	# repetitive stuff STACKS (Ricardo): materials merge into a qty on one slot
	if str(item.get("slot", "")) == "material":
		for it in inventory:
			if str(it.get("slot", "")) == "material" \
					and str(it.get("name", "")) == str(item.get("name", "")):
				it.qty = int(it.get("qty", 1)) + int(item.get("qty", 1))
				request_save()
				return true
	if inventory.size() >= ProtoItems.INVENTORY_CAP:
		return false
	inventory.append(item)
	if str(item.get("base_id", "")) == "core.item.emberfang_blade":
		has_blade = true
	request_save()
	return true

func find_item(uid: int) -> Dictionary:
	for it in inventory:
		if int(it.get("uid", -1)) == uid:
			return it
	return {}

func remove_item(uid: int) -> void:
	for it in inventory:
		if int(it.get("uid", -1)) == uid:
			inventory.erase(it)
			request_save()
			return

# Equips an inventory item into its slot; the previous piece returns to the bag.
func equip(uid: int) -> bool:
	var it := find_item(uid)
	if it.is_empty() or not equipment.has(str(it.get("slot", ""))):
		return false
	var slot := str(it.slot)
	inventory.erase(it)
	var prev: Dictionary = equipment[slot]
	if not prev.is_empty():
		inventory.append(prev)
	equipment[slot] = it
	request_save()
	return true

func unequip(slot: String) -> bool:
	var it: Dictionary = equipment.get(slot, {})
	if it.is_empty() or inventory.size() >= ProtoItems.INVENTORY_CAP:
		return false
	equipment[slot] = {}
	inventory.append(it)
	request_save()
	return true

# Removes an item wherever it lives (bag, equipment, or a rune socket) —
# used by enchant destruction (docs/design/14 §7 mirror).
func destroy_item(uid: int) -> void:
	remove_item(uid)
	for slot in equipment:
		if int((equipment[slot] as Dictionary).get("uid", -1)) == uid:
			equipment[slot] = {}
	for skill in skill_runes:
		if int((skill_runes[skill] as Dictionary).get("uid", -1)) == uid:
			skill_runes[skill] = {}
	request_save()

# ---- Haven chest (stash) -----------------------------------------------------------

func stash_item(uid: int) -> bool:
	if stash.size() >= STASH_CAP:
		return false
	var it := find_item(uid)
	if it.is_empty():
		return false
	inventory.erase(it)
	stash.append(it)
	request_save()
	return true

func unstash_item(uid: int) -> bool:
	if inventory.size() >= ProtoItems.INVENTORY_CAP:
		return false
	for it in stash:
		if int(it.get("uid", -1)) == uid:
			stash.erase(it)
			inventory.append(it)
			request_save()
			return true
	return false

# ---- rune sockets (one per skill, canon §4 proposal) ------------------------------

func socket_rune(skill: String, uid: int) -> bool:
	var it := find_item(uid)
	if it.is_empty() or str(it.get("slot", "")) != "rune" or not skill_runes.has(skill):
		return false
	inventory.erase(it)
	var prev: Dictionary = skill_runes[skill]
	if not prev.is_empty():
		inventory.append(prev)
	skill_runes[skill] = it
	request_save()
	return true

func unsocket_rune(skill: String) -> bool:
	var it: Dictionary = skill_runes.get(skill, {})
	if it.is_empty() or inventory.size() >= ProtoItems.INVENTORY_CAP:
		return false
	skill_runes[skill] = {}
	inventory.append(it)
	request_save()
	return true

func rune_effect(skill: String) -> String:
	return str((skill_runes.get(skill, {}) as Dictionary).get("rune_key", ""))

# ---- mounts (walking + flying — Ricardo 2026-07-10, proposals) --------------------

func owns_mount(key: String) -> bool:
	for m in mounts:
		if str(m.get("key", "")) == key:
			return true
	return false

func grant_mount(m: Dictionary) -> void:
	mounts.append(m)
	if active_mount < 0:
		active_mount = int(m.get("uid", -1))
	request_save()

func active_mount_data() -> Dictionary:
	for m in mounts:
		if int(m.get("uid", -1)) == active_mount:
			return m
	return {}

# ---- class skill trees (skill_trees.json; 1 point per level-up, proposal) ----------
# 20 actives + 8 passives per class, executed generically by player.use_skill.
# The tree for the CURRENT class is flattened + indexed once and cached.

var _tree_cache := {}      # class_id -> {branches, flat, by_id, charge}

func _class_tree_data() -> Dictionary:
	if _tree_cache.has(class_id):
		return _tree_cache[class_id]
	var reg := load_content("skill_trees")
	var cls: Dictionary = (reg.get("classes", {}) as Dictionary).get(class_id, {})
	var branches: Array = cls.get("branches", [])
	var flat: Array = []
	var by_id := {}
	for b in branches:
		for n in b.get("nodes", []):
			flat.append(n)
			by_id[str(n.get("id", ""))] = n
	var data := {"branches": branches, "flat": flat, "by_id": by_id,
			"charge": cls.get("charge", {})}
	_tree_cache[class_id] = data
	return data

func class_branches() -> Array:
	return _class_tree_data().branches

func class_tree() -> Array:
	return _class_tree_data().flat

func skill_def(node: String) -> Dictionary:
	return _class_tree_data().by_id.get(node, {})

# Class charge mechanic (Gloam Mage Attunement, Veilblade Combo) — {} for none.
func class_charge() -> Dictionary:
	return _class_tree_data().charge

func node_learned(node: String) -> bool:
	return learned_nodes.has(node)

# Roots cost 0 and are always "learned" — old saves only carry root_cleave.
func def_learned(def: Dictionary) -> bool:
	return int(def.get("cost", 1)) <= 0 or learned_nodes.has(str(def.get("id", "")))

func learn_node(node: String, cost := 1) -> bool:
	if skill_points < cost or cost <= 0 or learned_nodes.has(node):
		return false
	learned_nodes.append(node)
	skill_points -= cost
	request_save()
	return true

# Assign a learned active to hotbar slot 0-3 ("" clears; one skill per slot).
func assign_skill(slot: int, node: String) -> void:
	if slot < 0 or slot >= skill_loadout.size():
		return
	for i in skill_loadout.size():   # a skill lives in at most one slot
		if str(skill_loadout[i]) == node and node != "":
			skill_loadout[i] = ""
	skill_loadout[slot] = node
	request_save()

# Every rune key the player owns (bag + sockets) — drops prefer unowned runes.
func owned_rune_keys() -> Array:
	var keys: Array = []
	for it in inventory:
		if str(it.get("slot", "")) == "rune":
			keys.append(str(it.get("rune_key", "")))
	for skill in skill_runes:
		var r: Dictionary = skill_runes[skill]
		if not r.is_empty():
			keys.append(str(r.get("rune_key", "")))
	return keys

# ---- content loading ---------------------------------------------------------------

# Reads res://prototype/data/<name>.json (hand-synced from content/core).
# The shipping loader is dh-content with schema validation (docs/tech/23).
func load_content(content_name: String) -> Dictionary:
	if _content_cache.has(content_name):
		return _content_cache[content_name]
	var path := "res://prototype/data/%s.json" % content_name
	var raw := FileAccess.get_file_as_string(path)
	if raw.is_empty():
		push_warning("Session.load_content: missing " + path)
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("Session.load_content: bad JSON in " + path)
		return {}
	_content_cache[content_name] = parsed
	return parsed
