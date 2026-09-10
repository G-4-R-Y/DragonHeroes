# ARENA — build loading + instantiation (docs/design/23).
#
# A BUILD is one combatant definition: a player build (class + attributes +
# rolled gear + runes + skill loadout + pet + cosmetics — the bounty-hunter /
# Champion-Ghost shape) or a creature build (bestiary entry / boss chassis).
# Canonical data: content/core/arena/builds.json; the game reads the synced
# snapshot at res://arena/data/builds.json (same hand-sync pattern as
# prototype/data).
#
# ProtoBuild mimics the Session autoload surface that ProtoStats.compute and
# ProtoPlayer.apply_stats read (ATTRIBUTES, BASE_ATTRIBUTE, attributes,
# equipment, class_id, class_tree(), def_learned(), class_charge(),
# rune_effect()), so a geared build exists WITHOUT the global Session — that's
# what lets two differently-built player models share one arena.
class_name ProtoBuild
extends RefCounted

const ATTRIBUTES := ["might", "agility", "intellect", "vitality", "willpower"]
const BASE_ATTRIBUTE := 10
const EQUIP_SLOTS := ["weapon", "chest", "helm", "boots", "amulet", "ring"]

var class_id := "core.class.reaver"
var level := 20
var attributes := {"might": BASE_ATTRIBUTE, "agility": BASE_ATTRIBUTE,
	"intellect": BASE_ATTRIBUTE, "vitality": BASE_ATTRIBUTE,
	"willpower": BASE_ATTRIBUTE}
var equipment := {}
var skill_runes := {"cleave": {}, "rend": {}, "dodge": {}}
var learned_nodes: Array = []
var skill_loadout: Array = ["", "", "", ""]
var _tree := {}

# ---- Session-compatible surface ---------------------------------------------------

func _tree_data() -> Dictionary:
	if not _tree.is_empty():
		return _tree
	var raw := FileAccess.get_file_as_string("res://prototype/data/skill_trees.json")
	var reg: Dictionary = JSON.parse_string(raw) if not raw.is_empty() else {}
	var cls: Dictionary = (reg.get("classes", {}) as Dictionary).get(class_id, {})
	var flat: Array = []
	var by_id := {}
	for b in cls.get("branches", []):
		for n in b.get("nodes", []):
			flat.append(n)
			by_id[str(n.get("id", ""))] = n
	_tree = {"flat": flat, "by_id": by_id, "charge": cls.get("charge", {})}
	return _tree

func class_tree() -> Array:
	return _tree_data().flat

func skill_def(node_id: String) -> Dictionary:
	return _tree_data().by_id.get(node_id, {})

func class_charge() -> Dictionary:
	return _tree_data().charge

func def_learned(def: Dictionary) -> bool:
	return int(def.get("cost", 1)) <= 0 or learned_nodes.has(str(def.get("id", "")))

func node_learned(node_id: String) -> bool:
	return learned_nodes.has(node_id)

func rune_effect(skill: String) -> String:
	return str((skill_runes.get(skill, {}) as Dictionary).get("rune_key", ""))

# ---- loading -----------------------------------------------------------------------

# The full build catalog, cached once per process:
# {"builds": {id: def}, "rotation": [[a, b], ...]}.
static func catalog() -> Dictionary:
	const KEY := "__arena_builds"
	var reg := Engine.get_meta(KEY, {}) as Dictionary
	if not reg.is_empty():
		return reg
	reg = {"builds": {}, "rotation": []}
	var raw := FileAccess.get_file_as_string("res://arena/data/builds.json")
	var parsed: Variant = JSON.parse_string(raw) if not raw.is_empty() else null
	if parsed is Dictionary:
		for b in parsed.get("builds", []):
			reg.builds[str(b.get("id", ""))] = b
		reg.rotation = parsed.get("rotation", [])
	Engine.set_meta(KEY, reg)
	return reg

static func build_def(build_id: String) -> Dictionary:
	return (catalog().builds as Dictionary).get(build_id, {})

# Deterministic roll stream per build instance (training matches must be
# reproducible from seed alone).
static func make_player_build(def: Dictionary, rng: RandomNumberGenerator) -> ProtoBuild:
	var b := ProtoBuild.new()
	b.class_id = str(def.get("class_id", "core.class.reaver"))
	b.level = int(def.get("level", 20))
	for a in ATTRIBUTES:
		b.attributes[a] = int((def.get("attributes", {}) as Dictionary).get(a, BASE_ATTRIBUTE))
	for slot in EQUIP_SLOTS:
		b.equipment[slot] = {}
	for it in def.get("equipment", []):
		var slot := str(it.get("slot", ""))
		if slot == "" or not b.equipment.has(slot):
			continue
		b.equipment[slot] = ProtoItems.roll_item(str(it.get("base", "emberfang_blade")),
				str(it.get("rarity", "rare")), b.level, float(it.get("quality", 0.5)))
	# Rune sockets: {cleave|rend|dodge: rune_key} -> rune item dicts
	for skill in def.get("runes", {}):
		var key := str(def.runes[skill])
		for r in ProtoItems._data("runes").get("runes", []):
			if str(r.get("key", "")) == key:
				b.skill_runes[skill] = {"rune_key": key, "name": r.get("name", key)}
				break
	b.learned_nodes.assign(def.get("learned", []))
	var lo: Array = def.get("loadout", [])
	for i in 4:
		b.skill_loadout[i] = str(lo[i]) if i < lo.size() else ""
	return b
