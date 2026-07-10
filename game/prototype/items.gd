# PROTOTYPE HARNESS — item instance factory + loot roller. A dropped item =
# base + rolled affixes (PoE-style indirection, docs/design/14 §2): bases and
# affixes are hand-synced snapshots in prototype/data/ (mirrors content/core/,
# validated there by tools/validate_content.py). The shipping roller lives in
# dh-sim behind the economy core (client never mints items — canon hard rule).
# All drop/price/forge numbers here are (proposal) unless sourced from data/.
class_name ProtoItems

const INVENTORY_CAP := 40

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS := {
	"common": Color("a8a8a8"),     # grey
	"uncommon": Color("58d858"),   # green
	"rare": Color("4a9fff"),       # blue
	"epic": Color("b06cff"),       # purple
	"legendary": Color("ff9a3c"),  # orange
}
# Affix count per rarity (docs/design/14 §3 proposal: 0/1/2/3/4).
const RARITY_AFFIX_COUNT := {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4}

const GEAR_SLOTS := ["weapon", "chest", "helm", "boots", "amulet", "ring"]

# Base pools (data/ snapshots of content/core/items/). Emberfang is the
# Matriarch's signature drop — excluded from the generic pool.
const DROP_BASES := ["emberglass_staff", "gloamhide_vest", "fenwarden_helm",
		"mirebound_boots", "duskwarden_amulet", "palecrown_signet"]
const ALL_BASES := ["emberfang_blade", "emberglass_staff", "gloamhide_vest",
		"fenwarden_helm", "mirebound_boots", "duskwarden_amulet", "palecrown_signet"]
const AFFIX_IDS := ["of_embers", "stalwart", "brutal", "vigorous", "of_keenness"]

# (proposal) rarity weights per loot roll — normal kills vs Elite+ kills.
const RARITY_WEIGHTS_NORMAL := {
	"common": 55.0, "uncommon": 30.0, "rare": 11.0, "epic": 3.5, "legendary": 0.5}
const RARITY_WEIGHTS_ELITE := {
	"common": 0.0, "uncommon": 40.0, "rare": 35.0, "epic": 20.0, "legendary": 5.0}

# Forge (proposal — prototype-soft version of docs/design/14 §7 risk):
# upgrade cost = 50 * 2^tier gold; +10% to all affix values per tier, max 5;
# attempts INTO tiers 4/5 can fail (gold burned, item kept).
const FORGE_MAX_TIER := 5
const FORGE_FAIL := {4: 0.25, 5: 0.40}

# Vendor prices (proposal) — the real market is player-to-player (docs/design/15).
const SELL_BASE := {"common": 5, "uncommon": 12, "rare": 30, "epic": 75, "legendary": 180}

static var _data_cache: Dictionary = {}
static var _uid := 0

# ---- data loading (res://prototype/data/, hand-synced from content/core) -------

static func _data(data_name: String) -> Dictionary:
	if _data_cache.has(data_name):
		return _data_cache[data_name]
	var raw := FileAccess.get_file_as_string("res://prototype/data/%s.json" % data_name)
	var parsed: Variant = JSON.parse_string(raw) if raw != "" else null
	if not (parsed is Dictionary):
		push_warning("ProtoItems: missing/bad data file " + data_name)
		return {}
	_data_cache[data_name] = parsed
	return parsed

static func next_uid() -> int:
	_uid += 1
	return _uid

# Save-load support: fresh uids must never collide with persisted ones.
static func bump_uid(to: int) -> void:
	_uid = maxi(_uid, to)

static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

# ---- rolling -------------------------------------------------------------------

static func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return str(k)
	return str(weights.keys().back())

static func roll_rarity(elite: bool) -> String:
	return _weighted_pick(RARITY_WEIGHTS_ELITE if elite else RARITY_WEIGHTS_NORMAL)

# Affixes whose spawn_weights allow this slot (tag-based, PoE pattern).
static func _affix_pool(slot: String) -> Array:
	var pool: Array = []
	for aid in AFFIX_IDS:
		var a := _data(aid)
		if a.is_empty():
			continue
		var w := float((a.get("spawn_weights", {}) as Dictionary).get(slot, 0.0))
		if w <= 0.0:
			continue
		var t: Dictionary = (a.get("tiers", []) as Array)[0]   # prototype rolls tier 1
		pool.append({"id": str(a.get("id", aid)), "name": str(a.get("name", aid)),
				"kind": str(a.get("kind", "prefix")), "stat": str(t.get("stat", "?")),
				"min": float(t.get("min", 0)), "max": float(t.get("max", 0)), "weight": w})
	return pool

# Rolls a full item instance from a base snapshot. Affix count follows rarity
# (0/1/2/3/4), capped by the slot's available affix pool (prototype cap —
# shipping legendaries are hand-authored uniques, canon §4).
static func roll_item(base_key: String, rarity: String) -> Dictionary:
	var base := _data(base_key)
	var slot := str(base.get("slot", "weapon"))
	var affixes: Array = []
	for m in base.get("implicit_mods", []):
		affixes.append({"stat": str(m.get("stat", "?")),
				"value": float(randi_range(int(m.get("min", 0)), int(m.get("max", 0)))),
				"implicit": true})
	var pool := _affix_pool(slot)
	var prefix_name := ""
	var suffix_name := ""
	var count := int(RARITY_AFFIX_COUNT.get(rarity, 0))
	for i in mini(count, pool.size()):
		var weights := {}
		for j in pool.size():
			weights[j] = pool[j].weight
		var pick: Dictionary = pool[int(_weighted_pick(weights))]
		pool.erase(pick)
		affixes.append({"stat": pick.stat,
				"value": float(randi_range(int(pick.min), int(pick.max)))})
		if pick.kind == "prefix" and prefix_name == "":
			prefix_name = pick.name
		elif pick.kind == "suffix" and suffix_name == "":
			suffix_name = pick.name
	var item_name := str(base.get("name", base_key))
	if prefix_name != "":
		item_name = prefix_name + " " + item_name
	if suffix_name != "":
		item_name += " " + suffix_name
	var sprite_key := str(base.get("weapon_class", slot)) if slot == "weapon" else slot
	var item := {"uid": next_uid(), "base_id": str(base.get("id", "core.item." + base_key)),
			"name": item_name, "slot": slot, "rarity": rarity, "affixes": affixes,
			"power": 0, "upgrade_tier": 0, "enchant": null, "sprite_key": sprite_key}
	item.power = power(item)
	return item

# A creature-kill loot roll: random base + rarity from the tier's weights.
static func roll_loot(elite: bool) -> Dictionary:
	var bases := ALL_BASES if elite else DROP_BASES
	return roll_item(bases.pick_random(), roll_rarity(elite))

# Spirit Essence as an inventory material (data/abyssal_remnant.json snapshot).
static func make_essence() -> Dictionary:
	var d := _data("abyssal_remnant")
	return {"uid": next_uid(), "base_id": str(d.get("id", "core.spirit.abyssal_remnant")),
			"name": str(d.get("name", "Abyssal Remnant")), "slot": "material",
			"rarity": "rare", "affixes": [], "power": 0, "upgrade_tier": 0,
			"enchant": null, "sprite_key": "essence"}

# ---- runes (canon §4 proposal layer — prototype defs in data/runes.json) --------

static func rune_defs() -> Array:
	return _data("runes").get("runes", [])

static func rune_def(key: String) -> Dictionary:
	for r in rune_defs():
		if str(r.get("key", "")) == key:
			return r
	return {}

static func make_rune(key: String) -> Dictionary:
	var d := rune_def(key)
	return {"uid": next_uid(), "base_id": "proto.rune." + key,
			"name": str(d.get("name", key)), "slot": "rune", "rarity": "epic",
			"affixes": [], "power": 0, "upgrade_tier": 0, "enchant": null,
			"sprite_key": "rune", "rune_key": key}

# ---- derived views ---------------------------------------------------------------

# Affix values scaled by the forge tier (+10% per tier, proposal).
static func effective_affixes(item: Dictionary) -> Array:
	var scale := 1.0 + 0.1 * int(item.get("upgrade_tier", 0))
	var out: Array = []
	for a in item.get("affixes", []):
		out.append({"stat": str(a.get("stat", "?")),
				"value": float(a.get("value", 0)) * scale,
				"implicit": bool(a.get("implicit", false))})
	return out

# stat -> summed effective value (affixes at forge scale + enchant).
static func stat_totals(item: Dictionary) -> Dictionary:
	var totals := {}
	if item.is_empty():
		return totals
	for a in effective_affixes(item):
		totals[a.stat] = float(totals.get(a.stat, 0.0)) + a.value
	var en: Variant = item.get("enchant")
	if en is Dictionary and not (en as Dictionary).is_empty():
		var stat := str(en.get("stat", "?"))
		totals[stat] = float(totals.get(stat, 0.0)) + float(en.get("value", 0))
	return totals

# Display-only power score (proposal): affix weight + rarity + forge tier.
static func power(item: Dictionary) -> int:
	var p := 0.0
	for a in effective_affixes(item):
		p += absf(a.value)
	var en: Variant = item.get("enchant")
	if en is Dictionary and not (en as Dictionary).is_empty():
		p += absf(float(en.get("value", 0)))
	p += RARITIES.find(str(item.get("rarity", "common"))) * 8.0
	p += int(item.get("upgrade_tier", 0)) * 6.0
	return int(round(p))

static func sell_price(item: Dictionary) -> int:
	match str(item.get("slot", "")):
		"material":
			return 15
		"rune":
			return 60
	var base := int(SELL_BASE.get(str(item.get("rarity", "common")), 5))
	return int(base * (1.0 + 0.5 * int(item.get("upgrade_tier", 0))))

static func upgrade_cost(item: Dictionary) -> int:
	return 50 * int(pow(2.0, int(item.get("upgrade_tier", 0))))   # 50 * 2^tier (proposal)

# Fail chance of the NEXT upgrade attempt (into tier+1). 0 below tier 4.
static func upgrade_fail_chance(item: Dictionary) -> float:
	return float(FORGE_FAIL.get(int(item.get("upgrade_tier", 0)) + 1, 0.0))

# Rolls the forge attempt (the caller charges the gold either way — design/14
# taste). true = tier up (+10% affix values); false = failed, the item survives.
static func try_upgrade(item: Dictionary) -> bool:
	if int(item.get("upgrade_tier", 0)) >= FORGE_MAX_TIER:
		return false
	if randf() < upgrade_fail_chance(item):
		return false
	item.upgrade_tier = int(item.get("upgrade_tier", 0)) + 1
	item.power = power(item)
	return true

# ---- enchanting (Spirit Essences, docs/design/14 §9.1) ---------------------------

static func essence_info() -> Dictionary:
	return _data("abyssal_remnant").get("enchant", {})

static func can_enchant(item: Dictionary) -> bool:
	var slots: Array = essence_info().get("applicable_slots", [])
	return str(item.get("slot", "")) in slots

# Destroy risk (docs/design/14 §7 mirror): only attempts on tier>=4 items risk it.
# Ricardo 2026-07-10: enchanting NEVER destroys gear — the essence is the only
# cost. Kept for API compatibility; always 0.
static func enchant_destroy_risk(_item: Dictionary) -> float:
	return 0.0

static func roll_enchant() -> Dictionary:
	var mods: Array = essence_info().get("stat_mods", [])
	if mods.is_empty():
		return {"stat": "umbral_damage_pct", "value": 4.0}
	var m: Dictionary = mods[0]
	return {"stat": str(m.get("stat", "umbral_damage_pct")),
			"value": float(randi_range(int(m.get("min", 4)), int(m.get("max", 10))))}

# ---- pretty printing --------------------------------------------------------------

const STAT_NAMES := {
	"damage": "Damage", "hp": "Max HP", "armor": "Armor", "move_speed": "Move Speed %",
	"crit_chance": "Crit %", "fire_damage_pct": "Fire Dmg %",
	"umbral_damage_pct": "Umbral Dmg %", "frost_res": "Frost Res %",
}

static func stat_name(stat: String) -> String:
	return STAT_NAMES.get(stat, stat.capitalize())

static func describe(item: Dictionary) -> Array:
	var lines: Array = []
	if str(item.get("slot", "")) == "rune":
		lines.append(str(rune_def(str(item.get("rune_key", ""))).get("desc", "")))
		return lines
	if str(item.get("slot", "")) == "material":
		lines.append("Spirit Essence — enchant weapons/amulets at the Haven (umbral +4-10).")
		return lines
	for a in effective_affixes(item):
		lines.append("%s+%.0f %s" % ["implicit: " if a.implicit else "", a.value,
				stat_name(a.stat)])
	var en: Variant = item.get("enchant")
	if en is Dictionary and not (en as Dictionary).is_empty():
		lines.append("enchant: +%.0f %s" % [float(en.get("value", 0)),
				stat_name(str(en.get("stat", "?")))])
	return lines
