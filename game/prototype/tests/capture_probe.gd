# CAPTURE PROBE — the R57 bond as a gate. Ricardo: "Every captured mob turns
# into a gloamfen stalker. Wanted: maximum variety — every species keeps its own
# chassis, AND bosses are capturable as mini-pets with their signature skills,
# levelling alongside the player."
#
# Every assertion has teeth: reverting the matching R57 line makes exactly one
# of these fail.
#   (a) a generated species bonds as ITSELF — species id, name, hue, scale,
#       element and archetype all survive the capture (pre-R57: always the
#       founding stalker, whatever was snared),
#   (b) its skills roll from its OWN element/archetype pools, one signature
#       guaranteed, and the same body rolls different kits on different nights,
#   (c) a wisp chassis walks home on the wisp rig, not the stalker's,
#   (d) a bonded legendary keeps the kit it fought with,
#   (e) a boss bonds on hard terms (15% gate, x0.35 roll) as a MINI-pet: a
#       quarter of the PRE-level HP, half the damage, 55% size,
#   (f) the bond levels with the hunter and keeps its wound fraction, while a
#       record saved before R57 is still exactly the 120/14 stalker,
#   (g) the Spirit Essence faucet is byte-identical to pre-R57,
#   (h) the real F path: the HP gate refuses for free, a bond spends one snare
#       and yields a pet of the captured species, and a captured boss/duo half
#       leaves the hunt state clean — no legendary ghost on the HUD, no kill
#       credit, and the surviving half of a Duologue learns its mate was TAKEN.
#   godot --headless --path game res://prototype/tests/capture_probe.tscn
extends Node

const CreatureScene := preload("res://prototype/creature.gd")
const WispScene := preload("res://prototype/wisp.gd")
const BossScene := preload("res://prototype/boss.gd")
const HagScene := preload("res://prototype/hag.gd")
const PyreScene := preload("res://prototype/pyre_sovereign.gd")
const ColossusScene := preload("res://prototype/terravore_colossus.gd")
const PetScene := preload("res://prototype/pet.gd")

# A generated bestiary normal that exists in no hand-written row: exactly the
# case pre-R57 could not express — its signature has to come from the pools.
const DRAKE := {
	"id": "core.creature.probe_emberling", "name": "Probe Emberling",
	"archetype": "brute", "element": "fire", "tint": "#ff6a1e", "scale": 1.4,
}
const LEG := {
	"id": "core.creature.probe_wyrm", "name": "Probe Wyrm", "base": "dragon",
	"tint": "#c060ff", "scale": 1.2, "hp_mult": 3.0, "dmg_mult": 1.6,
	"kit": ["core.skill.meteor_call", "core.skill.wing_gust"],
}
const ROLLS := 40          # rolls of one body: pool legality + variety
const TRIES := 200         # snare attempts per bond (odds as low as 0.13)
const FAR := Vector2(0, 320)   # well outside the snare's 3-tile reach

var failures: Array[String] = []
var _hunt: Node
var _fam: Dictionary = {}

func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func frames(n: int = 2) -> void:
	for i in n: await get_tree().process_frame

# The bond re-levels inside pet.gd::_physics_process, and headless runs process
# frames far faster than the fixed 60 Hz physics clock — three PROCESS frames can
# contain zero physics ticks, which flaked this gate about 1 run in 4 with
# "the bond did not level with the hunter". Wait on the clock that does the work.
func physics_frames(n: int = 3) -> void:
	for i in n: await get_tree().physics_frame

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ProtoLang.set_lang("en")
	Session.login("capture_probe")
	_hunt = preload("res://prototype/main.tscn").instantiate()
	add_child(_hunt)
	_hunt.set_physics_process(false)      # the probe owns the clock
	_hunt.world._streaming = false
	_hunt.world.set_process(false)
	_hunt._residency.set_process(false)
	var waited := 0.0
	while waited < 30.0 and _hunt.player == null:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if _hunt.player == null:
		push_error("CAPTURE FAIL: the hunt never produced a player")
		get_tree().quit(1)
		return
	await frames(3)
	_fam = Session.load_content("abyssal")
	check(not _fam.is_empty(), "abyssal.json did not load — no pools to roll from")
	_clear_creatures()

	_check_species_chassis()
	_check_skill_pools()
	_check_rigs()
	_check_legendary_kit()
	_check_boss_terms()
	await _check_pet_body()
	_check_essence_faucet()
	await _check_capture_path()

	if failures.is_empty():
		print("CAPTURE OK — %d rolls legal; species/kit/rig/level/essence/F-path all held" % ROLLS)
	else:
		for f in failures: push_error("CAPTURE FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

# ---- helpers ----------------------------------------------------------------

func _clear_creatures() -> void:
	for c in get_tree().get_nodes_in_group("creatures"):
		c.get_parent().remove_child(c)
		c.queue_free()

# A body spawned the way main spawns one, then frozen: the probe, not the AI,
# decides where it stands and how hurt it is.
func _body(node: Variant, at := Vector2.ZERO) -> Variant:
	_hunt.add_child(node)
	node.set_physics_process(false)
	node.global_position = _hunt.player.global_position + at
	return node

func _normal(entry: Dictionary, at := Vector2.ZERO) -> Variant:
	var c: ProtoCreature = CreatureScene.new()
	c.setup_from_entry(entry)
	return _body(c, at)

func _pool(which: String, key: String) -> Array:
	return (_fam.get(which, {}) as Dictionary).get(key, []) as Array

func _script_name(node: Variant) -> String:
	return str(node.get_script().resource_path.get_file())

# ---- (a) the species bonds as itself ----------------------------------------

func _check_species_chassis() -> void:
	var drake: ProtoCreature = _normal(DRAKE)
	var prof := drake.capture_profile()
	check(str(prof.get("species", "")) == DRAKE["id"],
			"the bond forgot which species it came from")
	check(str(prof.get("species_name", "")) == DRAKE["name"], "the species name is lost")
	check(str(prof.get("element", "")) == "fire", "the element is lost")
	check(str(prof.get("archetype", "")) == "brute", "the archetype is lost")
	check(float(prof.get("scale", 0.0)) > 1.4, "the species scale never reached the bond")
	var tint: Array = prof.get("tint", [])
	check(tint.size() == 3 and float(tint[0]) > float(tint[2]) * 2.0,
			"the species hue is lost — the bond would be drawn washed out")
	var rec: Dictionary = _hunt._roll_pet(drake)
	check(str(rec.get("species", "")) == DRAKE["id"],
			"R57 REGRESSION: every bond is a gloamfen stalker again")
	check(str(rec.get("name", "")).begins_with(DRAKE["name"]), "the pet wears the wrong name")
	check((rec.get("chassis", {}) as Dictionary).has("base_hp"),
			"the record carries no chassis — pet.gd has nothing to rebuild")
	drake.queue_free()

# ---- (b) skills roll from the species' own pools -----------------------------

func _check_skill_pools() -> void:
	var drake: ProtoCreature = _normal(DRAKE)
	var sig := _pool("element_signatures", "fire") + _pool("archetype_signatures", "brute")
	var legal := sig + (_fam.get("family_shared_skills", []) as Array)
	var kits := {}
	var elements := 0
	var archetypes := 0
	for i in ROLLS:
		var skills: Array = _hunt._roll_pet(drake).get("skills", [])
		kits[";".join(PackedStringArray(skills))] = true
		check(skills.size() >= 2 and skills.size() <= 3,
				"a normal rolled %d skills (roll_rules says 2-3)" % skills.size())
		check(sig.has(skills[0]),
				"the guaranteed signature did not come from the species' own pools")
		for s in skills:
			check(legal.has(s), "rolled %s — outside this species' pools" % s)
		if _pool("element_signatures", "fire").has(skills[0]): elements += 1
		if _pool("archetype_signatures", "brute").has(skills[0]): archetypes += 1
	check(kits.size() >= 3, "%d rolls produced %d kits — the roll is not rolling"
			% [ROLLS, kits.size()])
	check(elements > 0, "the element pool never led a roll")
	check(archetypes > 0, "the archetype pool never led a roll")
	drake.queue_free()

# ---- (c) a captured wisp does not walk home as a stalker ---------------------

func _check_rigs() -> void:
	var wisp: ProtoCreature = _body(WispScene.new())
	check(wisp.capture_archetype() == "wisp", "a wisp body names the wrong skill pool")
	var pet: ProtoPet = PetScene.new()
	pet.setup(_hunt._roll_pet(wisp))
	_hunt.add_child(pet)
	check(pet.sprite.sprite_frames == ProtoSprites.wisp_frames(),
			"a captured wisp walks home on the stalker rig")
	for anim in ["idle", "walk", "lunge"]:
		check(pet.sprite.sprite_frames.has_animation(anim),
				"the wisp rig has no %s — the pet would spam animation errors" % anim)
	pet.queue_free()
	wisp.queue_free()

# ---- (d) a bonded legendary keeps the kit it fought with ---------------------

func _check_legendary_kit() -> void:
	var leg: ProtoCreature = BossScene.new()
	leg.setup_legendary(LEG)
	_body(leg)
	var prof := leg.capture_profile()
	check((prof.get("kit", []) as Array) == LEG["kit"], "the legendary kit is lost")
	check(str(prof.get("archetype", "")) == "dragon", "the legendary rides the wrong pool")
	for i in ROLLS:
		var skills: Array = _hunt._roll_pet(leg).get("skills", [])
		check((LEG["kit"] as Array).has(skills[0]),
				"a bonded legendary did not lead with its own kit")
		check(skills.size() >= 3, "a bonded legendary rolled only %d skills" % skills.size())
	leg.queue_free()

# ---- (e) bosses bond on hard terms, as MINI-pets ------------------------------

func _check_boss_terms() -> void:
	Session.level = 11          # x1.6 hp / x1.3 damage on a boss chassis
	var boss: ProtoCreature = _body(BossScene.new())
	check(boss.capturable, "the boss is not capturable — R57's headline is reverted")
	check(not boss.drops_essence, "a boss now drops Spirit Essence (faucet opened)")
	check(is_equal_approx(boss.capture_hp_gate, 0.15), "the boss HP gate moved")
	check(is_equal_approx(boss.capture_chance_scale, 0.35), "the boss snare odds moved")
	check(is_equal_approx(boss.max_hp, 900.0 * 1.6), "the level curve is not on the body")
	var prof := boss.capture_profile()
	check(is_equal_approx(float(prof["base_hp"]), 225.0),
			"the mini-pet base HP is %s, not a quarter of the PRE-level 900"
			% str(prof["base_hp"]))
	check(is_equal_approx(float(prof["base_damage"]), 11.0),
			"the mini-pet base damage is %s, not half of the PRE-level 22"
			% str(prof["base_damage"]))
	check(is_equal_approx(float(prof["scale"]), 0.55), "the mini-pet is not 55% size")
	check(is_equal_approx(float(prof["hp_rate"]), 0.06), "the boss level rates are lost")
	boss.queue_free()

# ---- (f) the bond IS the captured body, and it levels with the hunter --------

func _check_pet_body() -> void:
	var boss: ProtoCreature = _body(BossScene.new())          # still level 11
	var rec: Dictionary = _hunt._roll_pet(boss)
	var roll := float(rec["roll_pct"]) / 100.0
	var pet: ProtoPet = PetScene.new()
	pet.setup(rec)
	_hunt.add_child(pet)
	check(is_equal_approx(pet.max_hp, 225.0 * 1.6 * roll),
			"the pet did not rebuild the chassis at the hunter's level")
	check(is_equal_approx(pet.damage, 11.0 * 1.3 * roll), "the pet damage is wrong")
	check(is_equal_approx(pet.sprite.scale.x, 0.55), "the pet is not drawn at mini size")
	check(not pet.chassis.is_empty(), "the pet kept no chassis")
	# hue rides the chassis tint, so a species with one is what proves it travels
	# (a stock boss carries its colors in its frames, not in a tint)
	var drake: ProtoCreature = _normal(DRAKE, FAR)
	var hued: ProtoPet = PetScene.new()
	hued.setup(_hunt._roll_pet(drake))
	_hunt.add_child(hued)
	check(hued.sprite.self_modulate != Color(1, 1, 1),
			"the pet lost its species hue — every bond is drawn in the stalker's colors")
	check(hued.sprite.self_modulate.r > hued.sprite.self_modulate.b * 2.0,
			"the ember hue did not survive the bond")
	hued.queue_free()
	drake.queue_free()
	pet.hp = pet.max_hp * 0.5                       # a wounded bond stays wounded
	Session.level = 21
	await physics_frames(3)
	check(is_equal_approx(pet.max_hp, 225.0 * 2.2 * roll),
			"the bond did not level with the hunter")
	check(is_equal_approx(pet.hp, pet.max_hp * 0.5), "levelling healed the pet for free")
	# a record saved before R57: byte-identical to the founding stalker
	var old: ProtoPet = PetScene.new()
	old.setup({"uid": 9, "name": "Gloam Stalker", "roll_pct": 100, "skills": []})
	_hunt.add_child(old)
	check(old.chassis.is_empty(), "a pre-R57 record grew a chassis")
	check(is_equal_approx(old.max_hp, 120.0) and is_equal_approx(old.damage, 14.0),
			"a pre-R57 record no longer stats as the 120/14 stalker")
	check(old.sprite.sprite_frames == ProtoSprites.stalker_frames(),
			"a pre-R57 record no longer draws as the stalker")
	check(old.sprite.scale == Vector2.ONE, "a pre-R57 record changed size")
	Session.level = 1
	pet.queue_free()
	old.queue_free()
	boss.queue_free()

# ---- (g) the Spirit Essence faucet never widened ------------------------------

func _check_essence_faucet() -> void:
	for kind in ["stalker", "lunger", "brute"]:
		var c: ProtoCreature = CreatureScene.new()
		c.setup_archetype(kind)
		_body(c, FAR)
		check(c.drops_essence, "%s stopped dropping Spirit Essence" % kind)
		check(c.capturable, "%s left the capture pool" % kind)
		c.queue_free()
	for node in [WispScene.new(), BossScene.new(), HagScene.new(),
			PyreScene.new(), ColossusScene.new()]:
		var c: ProtoCreature = _body(node, FAR)
		check(c.capturable, "%s is not capturable" % _script_name(c))
		check(not c.drops_essence, "%s opened the Spirit Essence faucet" % _script_name(c))
		c.queue_free()

# ---- (h) the real F path ------------------------------------------------------

func _check_capture_path() -> void:
	Session.pets.clear()
	_hunt.sync_pet_nodes()
	_hunt.snares = 4 * TRIES
	await frames()
	# the HP gate refuses, and refuses for FREE
	var strong: ProtoCreature = _normal(DRAKE)
	strong.hp = strong.max_hp * 0.5
	var before: int = _hunt.snares
	_hunt._try_capture()
	check(_hunt.snares == before, "a snare was spent on a body above its HP gate")
	check(Session.pets.is_empty(), "a body above its HP gate was bonded anyway")
	strong.queue_free()
	await frames()
	# below the gate it bonds — and the pet is the SPECIES, not a stalker
	check(await _bond(_normal(DRAKE)),
			"%d snares never bonded a frazzled normal (p < 1e-9)" % TRIES)
	check(Session.pets.size() == 1, "the bond did not reach the roster")
	if Session.pets.size() == 1:
		check(str(Session.pets[0].get("species", "")) == DRAKE["id"],
				"the roster entry is not the captured species")
	check(_hunt._pets.size() == 1 and is_instance_valid(_hunt._pets[0]),
			"no pet node walked out of the capture")
	await frames()
	# a captured hunt legendary leaves no ghost on the HUD and pays no kill credit
	var kills: int = _hunt.kills
	var leg: ProtoCreature = BossScene.new()
	leg.setup_legendary(LEG)
	_body(leg)
	_hunt.legendary_boss = leg
	_hunt._legendary_name = "PROBE WYRM"
	check(await _bond(leg), "%d snares never bonded a frazzled legendary (p < 1e-5)" % TRIES)
	check(_hunt.legendary_boss == null, "the hunt still points at a legendary that walked home")
	check(_hunt._legendary_name == "", "the HUD still hunts a bonded legendary")
	check(_hunt.kills == kills, "a capture paid kill credit — the bond IS the trophy")
	check(_hunt._hud.hint.text == ProtoLang.t("msg_bonded_leg"),
			"the hunt printed a death line for a capture")
	await frames()
	# the surviving half of a Duologue learns its mate was TAKEN, not killed
	Session.pets.clear()            # a full roster would open the replace window
	_hunt.sync_pet_nodes()
	var pyre: Variant = _body(PyreScene.new())
	var terra: Variant = _body(ColossusScene.new(), FAR)
	pyre.partner = terra
	terra.partner = pyre
	check(await _bond(pyre), "%d snares never bonded a frazzled duo half (p < 1e-6)" % TRIES)
	check(terra._enraged, "the survivor never learned its mate was taken")
	check(_hunt._hud.hint.text == ProtoLang.t("msg_duo_taken"),
			"the Duologue capture printed the wrong line")
	terra.queue_free()

# Frazzles a body to 1% and snares it until it bonds (the roll is deliberately
# unkind on a boss chassis — 0.13 for a Duologue half — so this is a loop, not a
# single attempt; every failure costs a snare and enrages the body, as in play).
func _bond(body: Variant) -> bool:
	var before: int = Session.pets.size()
	for i in TRIES:
		if not is_instance_valid(body) or body.dead:
			return Session.pets.size() > before
		body.hp = body.max_hp * 0.01
		body.global_position = _hunt.player.global_position + Vector2(10, 0)
		_hunt._try_capture()
		if Session.pets.size() > before:
			return true
	return false
