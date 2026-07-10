# PROTOTYPE HARNESS — derived StatBlock. Computes the hero's real numbers from
# base + allocated attributes + equipped item affixes + enchants. The shipping
# stat pipeline is dh-sim's (server-authoritative, canon hard rule); this exists
# so gear and attribute allocation REALLY matter in the slice today.
#
# Attribute effects per allocated point above base 10 (all proposals):
#   Might     +2% melee damage
#   Agility   +1% move speed, +2% dodge-charge recharge rate
#   Intellect +2% skill damage (Shadow Rend + rune effects)
#   Vitality  +6 max HP
#   Willpower +1% elemental resist, +2% status resist (fields/DoTs)
#
# Gear stat semantics (proposal): damage=flat melee, hp=flat max HP,
# armor=physical mitigation armor/(armor+150), move_speed=+%, crit_chance=+pts,
# fire_damage_pct=+% melee (fire), umbral_damage_pct=+% skill (umbral),
# *_res=+% elemental resist.
class_name ProtoStats

const BASE_HP := 100.0
const BASE_MELEE := 25.0
const BASE_REND := 40.0
const BASE_MOVE := 5.0          # m/s (canon)
const BASE_DODGE_RECHARGE := 1.5
const BASE_CRIT := 5.0          # % (proposal)
const CRIT_MULT := 1.5          # (proposal)

# sess = the Session autoload (passed in: statics can't assume autoload scope).
# equipment: optional override (hypothetical loadout) for equip-diff previews;
# empty = the session's real equipment.
static func compute(sess: Node, equipment: Dictionary = {}) -> Dictionary:
	var eq: Dictionary = equipment if not equipment.is_empty() else sess.equipment
	var pts := {}
	for a in sess.ATTRIBUTES:
		pts[a] = maxi(int(sess.attributes[a]) - sess.BASE_ATTRIBUTE, 0)
	var totals := {}   # stat -> summed value across equipped gear (+ enchants)
	for slot in eq:
		var item_totals := ProtoItems.stat_totals(eq[slot])
		for stat in item_totals:
			totals[stat] = float(totals.get(stat, 0.0)) + float(item_totals[stat])
	var res_pct := 0.01 * float(pts.willpower)
	for stat in totals:
		if str(stat).ends_with("_res"):
			res_pct += float(totals[stat]) / 100.0
	# learned Reaver tree nodes (reaver.json): passive stat_mods stack in.
	# blood_price's -15 armor is a REAL tradeoff — armor may go negative.
	var node_mods := {}
	var tree: Array = (sess.load_content("reaver") as Dictionary).get("skill_tree", [])
	for n in tree:
		if not sess.learned_nodes.has(str(n.get("node", ""))):
			continue
		for m in n.get("stat_mods", []):
			var st := str(m.get("stat", ""))
			node_mods[st] = float(node_mods.get(st, 0.0)) + float(m.get("value", 0.0))
	var armor := float(totals.get("armor", 0.0)) + float(node_mods.get("armor", 0.0))
	# class-lite modifiers (proposal): Emberkin trades HP for fire + Ignite-on-hit;
	# Frostbinder trades damage for bulk + Chill-on-hit. Full kits: docs/design/10.
	var class_hp := 1.0
	var class_dmg := 1.0
	var class_fire := 0.0
	var class_fx := ""
	match str(sess.class_id):
		"core.class.emberkin":
			class_hp = 0.9
			class_fire = 12.0
			class_fx = "ignite"
		"core.class.frostbinder":
			class_hp = 1.15
			class_dmg = 0.92
			class_fx = "chill"
	return {
		"max_hp": (BASE_HP + 6.0 * pts.vitality + float(totals.get("hp", 0.0))) \
				* class_hp,
		"class_fx": class_fx,
		"melee_damage": (BASE_MELEE + float(totals.get("damage", 0.0))) \
				* (1.0 + 0.02 * pts.might) * class_dmg \
				* (1.0 + (float(totals.get("fire_damage_pct", 0.0)) + class_fire) / 100.0),
		"rend_damage": BASE_REND * (1.0 + 0.02 * pts.intellect) \
				* (1.0 + float(totals.get("umbral_damage_pct", 0.0)) / 100.0),
		"skill_damage_mult": 1.0 + 0.02 * pts.intellect,
		"move_speed_mult": 1.0 + 0.01 * pts.agility \
				+ float(totals.get("move_speed", 0.0)) / 100.0,
		"dodge_recharge_s": BASE_DODGE_RECHARGE / (1.0 + 0.02 * pts.agility),
		"crit_chance": (BASE_CRIT + float(totals.get("crit_chance", 0.0)) \
				+ float(node_mods.get("crit_chance", 0.0))) / 100.0,
		"crit_mult": CRIT_MULT,
		"attack_speed_mult": 1.0 + float(node_mods.get("attack_speed", 0.0)) / 100.0,
		"leech_pct": float(node_mods.get("blood_leech_pct", 0.0)) / 100.0,
		"armor": armor,
		"phys_reduction": armor / (armor + 150.0),
		"resist_pct": minf(res_pct, 0.75),
		"status_resist_pct": minf(0.02 * pts.willpower, 0.75),
		"totals": totals,
	}

# Compact lines for the character panel / Haven.
static func summary_lines(s: Dictionary) -> Array:
	var lines := [
		"Max HP %d" % int(s.max_hp),
		"Melee damage %.1f  ·  crit %d%% (x%.1f)  ·  attack speed x%.2f" % [
				s.melee_damage, int(s.crit_chance * 100.0), s.crit_mult,
				s.attack_speed_mult],
		"Shadow Rend damage %.1f" % s.rend_damage,
		"Move speed x%.2f  ·  dodge recharge %.2f s" % [s.move_speed_mult,
				s.dodge_recharge_s],
		"Armor %d (%d%% physical mitigation)  ·  resist %d%%  ·  status resist %d%%" % [
				int(s.armor), int(s.phys_reduction * 100.0),
				int(s.resist_pct * 100.0), int(s.status_resist_pct * 100.0)],
	]
	if s.leech_pct > 0.0:
		lines.append("Blood leech %d%% of melee damage dealt" % int(s.leech_pct * 100.0))
	return lines
