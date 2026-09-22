# BOND PROBE — the R65 kit as a gate. R57 gave a bond the captured body; R65 gives
# it the kit that body fought with, plus a track of its own: rolled skills come
# online one at a time as the bond hunts at your side.
#
# Every assertion has teeth: reverting the matching R65 line makes exactly one of
# these fail.
#   (a) every id the roll can produce RESOLVES to real content, and the flat
#       snapshot directory cannot hand back the wrong file (core.skill.abyssal is
#       the pet FAMILY, not a skill),
#   (b) the bond curve is the one the card prints: 8 kills to bond 2, 144 to the
#       cap, a slot every 3 levels, bond_slot_level its exact inverse,
#   (c) a fresh capture banks bond_xp 0 and casts ONE of its rolled skills — the
#       rest are rolled, shown, and locked,
#   (d) a kill pays the bonds that were THERE: not the one across the map, not the
#       one resting, not the stabled record, not a called wispling,
#   (e) the level-up lands mid-hunt — the second skill is castable on the next
#       swing, not after a reload,
#   (f) bond potency rides ON TOP of the chassis curve (+3%/level, not instead of
#       the hunter's level),
#   (g) the executor fires, one check per behavior: melee_arc damages in a cone and
#       leeches, projectile leaves a FRIENDLY bolt with a real shooter, aoe_field
#       and channel lay a FRIENDLY field, dash moves the body, buff sets the haste,
#       summon calls uid -1 wisplings that never reach the roster,
#   (h) a skill with no damage_coeff does NO damage (void_step is pure mobility —
#       a 1.0 default would invent a hit),
#   (i) a wispling dies on its own clock.
#   godot --headless --path game res://prototype/tests/bond_probe.tscn
extends Node

const CreatureScene := preload("res://prototype/creature.gd")
const PetScene := preload("res://prototype/pet.gd")

const DUMMY := {"id": "core.creature.probe_dummy", "name": "Probe Dummy",
		"archetype": "brute", "element": "fire", "tint": "#ff6a1e", "scale": 1.0}
const BEHAVIORS := ["melee_arc", "projectile", "aoe_field", "channel", "dash",
		"buff", "summon"]
const FAR := Vector2(0, 640)      # far outside the 11-tile bond leash
const CAST_FRAMES := 240          # 4 s at 60 Hz; the longest windup here is 21 ticks
const TILE := 16.0

var failures: Array[String] = []
var _hunt: Node
var _fam: Dictionary = {}
var _chassis: Dictionary = {}

func check(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func frames(n: int = 2) -> void:
	for i in n: await get_tree().process_frame

# The kit runs inside pet.gd::_physics_process, and headless PROCESS frames can
# contain zero physics ticks (the same flake that bit capture_probe). Everything
# the pet does is waited on the clock that actually does the work.
func physics_frames(n: int = 3) -> void:
	for i in n: await get_tree().physics_frame

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ProtoLang.set_lang("en")
	Session.login("bond_probe")
	Session.level = 1
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
		push_error("BOND FAIL: the hunt never produced a player")
		get_tree().quit(1)
		return
	await frames(3)
	_fam = Session.load_content("abyssal")
	check(not _fam.is_empty(), "abyssal.json did not load — no pools to roll from")
	_clear_creatures()
	var proto: ProtoCreature = CreatureScene.new()
	_hunt.add_child(proto)          # in-tree: setup_from_entry reaches for the world
	proto.set_physics_process(false)
	proto.setup_from_entry(DUMMY)
	_chassis = proto.capture_profile()
	proto.get_parent().remove_child(proto)
	proto.queue_free()

	_check_content()
	_check_curve()
	_check_fresh_capture()
	await _check_credit()
	await _check_unlock()
	_check_potency()
	await _check_kit()
	await _check_summon_clock()

	if failures.is_empty():
		print("BOND OK — %d skills resolve; curve/credit/unlock/potency and all %d behaviors held"
				% [_all_ids().size(), BEHAVIORS.size()])
	else:
		for f in failures: push_error("BOND FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

# ---- helpers ----------------------------------------------------------------

func _clear_creatures() -> void:
	for c in get_tree().get_nodes_in_group("creatures"):
		c.get_parent().remove_child(c)
		c.queue_free()

func _clear_pets() -> void:
	for p in get_tree().get_nodes_in_group("pet"):
		p.get_parent().remove_child(p)
		p.queue_free()
	_hunt._pets.clear()

# Every id the roll can ever produce, from the family's own pools.
func _all_ids() -> Array:
	var ids: Array = (_fam.get("family_shared_skills", []) as Array).duplicate()
	for group in ["element_signatures", "archetype_signatures"]:
		for key in (_fam.get(group, {}) as Dictionary).keys():
			for id in (_fam[group][key] as Array):
				if not ids.has(id):
					ids.append(id)
	return ids

# A frozen punching bag with more HP than the probe can chew through, marked as a
# threat so the pet's own acquisition (not the probe) picks it up.
func _dummy(at: Vector2, hp := 90000.0) -> ProtoCreature:
	var c: ProtoCreature = CreatureScene.new()
	_hunt.add_child(c)              # in-tree BEFORE setup: the art path reads the world
	c.set_physics_process(false)
	c.setup_from_entry(DUMMY)
	c.global_position = _hunt.player.global_position + at
	c.max_hp = hp
	c.hp = hp
	c.threat = true
	return c

# A bond with an EXPLICIT kit, so each behavior is tested on its own skill instead
# of whatever the roll happened to hand out.
func _pet(ids: Array, xp := 0, at := Vector2.ZERO, uid := 0) -> ProtoPet:
	var rec := {"uid": uid, "name": "Probe Bond", "roll_pct": 100, "bond_xp": xp,
			"skills": ids, "chassis": _chassis}
	var p: ProtoPet = PetScene.new()
	p.setup(rec)
	_hunt.add_child(p)
	p.global_position = _hunt.player.global_position + at
	return p

# Runs the clock until the pet has paid a skill cooldown — the one signal that
# says "_strike went down the cast branch", whatever the behavior was.
func _await_cast(pet: ProtoPet, limit := CAST_FRAMES) -> bool:
	for i in limit:
		await get_tree().physics_frame
		if pet._skill_cd.size() > 0 and pet._skill_cd[0] > 0.0:
			return true
	return false

func _projectiles() -> Array:
	var out: Array = []
	for n in _hunt.get_children():
		if n is ProtoProjectile:
			out.append(n)
	return out

# ---- (a) the rolled ids resolve to real content ------------------------------

func _check_content() -> void:
	var ids := _all_ids()
	check(ids.size() >= 15, "the family pools only offer %d skills" % ids.size())
	for id in ids:
		var def: Dictionary = Session.pet_skill_def(str(id))
		if def.is_empty():
			failures.append("%s has no snapshot in prototype/data — the bond rolls a skill it cannot cast" % id)
			continue
		check(str(def.get("id", "")) == str(id),
				"%s resolved to content carrying a different id" % id)
		check(BEHAVIORS.has(str(def.get("behavior", ""))),
				"%s has behavior '%s' — the executor dispatches on behavior and would drop it"
				% [id, str(def.get("behavior", ""))])
		check(not (def.get("numbers", {}) as Dictionary).is_empty(),
				"%s carries no numbers" % id)
		check(not str(def.get("name", "")).is_empty(), "%s has no display name" % id)
	# the snapshot directory is FLAT: an id that collides with a non-skill file
	# must resolve to nothing, not to the pet family it happens to be named after
	check(Session.pet_skill_def("core.skill.abyssal").is_empty(),
			"a pet FAMILY resolved as a skill — the flat-directory guard is gone")
	check(Session.pet_skill_def("core.skill.not_a_real_skill").is_empty(),
			"an unknown id resolved to something")
	check(Session.pet_skill_name("core.skill.not_a_real_skill") == "Not A Real Skill",
			"an unresolvable id does not fall back to a readable name on the card")
	check(Session.pet_skill_name("core.skill.ember_bolt") == "Ember Bolt",
			"the card prints the raw id instead of the skill name")

# ---- (b) the bond curve the card prints --------------------------------------

func _check_curve() -> void:
	check(Session.bond_level({}) == 1, "a record with no bond_xp is not bond 1")
	check(Session.bond_level({"bond_xp": 7}) == 1, "bond 2 arrived before 8 kills")
	check(Session.bond_level({"bond_xp": 8}) == 2, "8 kills did not reach bond 2")
	var total := 0
	for lvl in range(1, Session.BOND_LEVEL_CAP):
		total += Session.bond_kills_for_level(lvl)
	check(total == 144, "the cap costs %d kills, not 144" % total)
	check(Session.bond_level({"bond_xp": total - 1}) == Session.BOND_LEVEL_CAP - 1,
			"the last level came free")
	check(Session.bond_level({"bond_xp": total}) == Session.BOND_LEVEL_CAP,
			"144 kills did not reach the cap")
	check(Session.bond_level({"bond_xp": total * 10}) == Session.BOND_LEVEL_CAP,
			"the bond levelled past its own cap")
	check(is_equal_approx(Session.bond_progress({}), 0.0), "a fresh bond is not at 0")
	check(is_equal_approx(Session.bond_progress({"bond_xp": 4}), 0.5),
			"half of the first level does not read as half")
	check(is_equal_approx(Session.bond_progress({"bond_xp": total}), 1.0),
			"a capped bond does not read as full")
	for pair in [[1, 1], [3, 1], [4, 2], [6, 2], [7, 3], [10, 4]]:
		check(Session.bond_skill_slots(pair[0]) == pair[1],
				"bond %d unlocks %d skills, not %d"
				% [pair[0], Session.bond_skill_slots(pair[0]), pair[1]])
	for idx in 4:
		check(Session.bond_skill_slots(Session.bond_slot_level(idx)) == idx + 1,
				"bond_slot_level(%d) is not the inverse of bond_skill_slots" % idx)
		if Session.bond_slot_level(idx) > 1:
			check(Session.bond_skill_slots(Session.bond_slot_level(idx) - 1) == idx,
					"slot %d unlocks one level early" % idx)

# ---- (c) a fresh capture: one skill live, the rest locked --------------------

func _check_fresh_capture() -> void:
	var body := _dummy(FAR)
	var rec: Dictionary = _hunt._roll_pet(body)
	check(rec.has("bond_xp") and int(rec.bond_xp) == 0,
			"a fresh capture does not start its own track at 0")
	var pet: ProtoPet = PetScene.new()
	pet.setup(rec)
	_hunt.add_child(pet)
	check(pet.bond_lvl == 1, "a fresh capture is not bond 1")
	check(pet.skill_ids.size() == (rec.skills as Array).size(),
			"the pet forgot part of its roll")
	check(pet.skills.size() == 1,
			"a fresh capture casts %d of its %d rolled skills — the whole roll came free"
			% [pet.skills.size(), pet.skill_ids.size()])
	check(pet._skill_cd.size() == pet.skills.size(),
			"the cooldown array is not parallel to the unlocked kit")
	# a record saved before R65 has no bond_xp at all and must still work
	var old: ProtoPet = PetScene.new()
	old.setup({"uid": 9, "name": "Gloam Stalker", "roll_pct": 100,
			"skills": ["core.skill.ember_bolt", "core.skill.wing_gust"]})
	_hunt.add_child(old)
	check(old.bond_lvl == 1 and old.skills.size() == 1,
			"a pre-R65 record does not read as a bond 1 with one live skill")
	# an id with no snapshot must not eat the slot the bond paid for
	var ghost: ProtoPet = PetScene.new()
	ghost.setup({"uid": 8, "name": "Ghost Kit", "roll_pct": 100,
			"skills": ["core.skill.not_a_real_skill", "core.skill.ember_bolt"]})
	_hunt.add_child(ghost)
	check(ghost.skills.size() == 1 and str(ghost.skills[0].get("id", "")) == "core.skill.ember_bolt",
			"an unresolvable id ate the bond's only slot")
	pet.queue_free()
	old.queue_free()
	ghost.queue_free()
	body.queue_free()

# ---- (d) a kill pays the bonds that were THERE -------------------------------

func _check_credit() -> void:
	_clear_creatures()
	_clear_pets()
	Session.pets.clear()
	Session.stables.clear()
	var near := {"uid": 101, "name": "Near", "roll_pct": 100, "bond_xp": 0,
			"skills": [], "chassis": _chassis}
	var away := {"uid": 102, "name": "Away", "roll_pct": 100, "bond_xp": 0,
			"skills": [], "chassis": _chassis}
	var tired := {"uid": 103, "name": "Tired", "roll_pct": 100, "bond_xp": 0,
			"skills": [], "chassis": _chassis}
	Session.pets.append_array([near, away, tired])
	Session.stables.append({"uid": 104, "name": "Stabled", "roll_pct": 100,
			"bond_xp": 0, "skills": [], "chassis": _chassis})
	_hunt.sync_pet_nodes()
	await frames()
	check(_hunt._pets.size() == 3, "the roster did not produce three pet nodes")
	var at: Vector2 = _hunt.player.global_position + Vector2(24, 0)
	for p in _hunt._pets:
		match p.uid:
			101: p.global_position = at + Vector2(8, 0)
			102: p.global_position = at + FAR
			103:
				p.global_position = at + Vector2(-8, 0)
				p._rest = p.REST_TIME       # downed: resting, not hunting
	_hunt._credit_bonds(at)
	check(int(near.bond_xp) == 1, "the bond standing on the kill banked nothing")
	check(int(away.bond_xp) == 0, "a bond across the map banked a kill it never saw")
	check(int(tired.bond_xp) == 0, "a resting bond banked a kill")
	check(not Session.credit_bond_kill(104),
			"a STABLED pet earned bond xp — the stables are a rest, not a career")
	check(int(Session.stables[0].bond_xp) == 0, "the stabled record was credited anyway")
	check(not Session.credit_bond_kill(-1), "a called wispling banked a kill")
	# the real path: a creature dying next to the bond, through on_creature_died
	var victim := _dummy(Vector2(24, 0), 40.0)
	victim.take_damage(999.0, Vector2.RIGHT)
	await frames(2)
	check(victim.dead, "the victim did not die")
	check(int(near.bond_xp) == 2,
			"a real kill did not credit the bond — the death handler never calls _credit_bonds")
	_clear_creatures()

# ---- (e) the level-up lands mid-hunt -----------------------------------------

func _check_unlock() -> void:
	_clear_pets()
	Session.pets.clear()
	var need := 0
	for lvl in range(1, 4):
		need += Session.bond_kills_for_level(lvl)   # 30: one kill short of bond 4
	var rec := {"uid": 201, "name": "Veteran", "roll_pct": 100, "bond_xp": need - 1,
			"skills": ["core.skill.ember_bolt", "core.skill.abyssal_maw",
			"core.skill.magma_breath"], "chassis": _chassis}
	Session.pets.append(rec)
	_hunt.sync_pet_nodes()
	await frames()
	var pet: ProtoPet = _hunt._pets[0]
	check(pet.bond_lvl == 3 and pet.skills.size() == 1,
			"a bond 3 does not carry exactly one live skill")
	var at: Vector2 = pet.global_position
	_hunt._credit_bonds(at)
	check(int(rec.bond_xp) == need, "the kill was not banked")
	check(pet.bond_lvl == 4,
			"the pet is still bond %d after the level-up — refresh_bond never ran" % pet.bond_lvl)
	check(pet.skills.size() == 2,
			"the second skill is not castable until the next load (%d live)" % pet.skills.size())
	check(pet._skill_cd.size() == 2, "the new slot has no cooldown of its own")
	check(str(pet.skills[0].get("id", "")) == "core.skill.ember_bolt"
			and str(pet.skills[1].get("id", "")) == "core.skill.abyssal_maw",
			"the slots do not unlock in roll order — the signature is not first")
	_clear_pets()
	Session.pets.clear()

# ---- (f) bond potency rides ON TOP of the hunter's level ---------------------

func _check_potency() -> void:
	Session.level = 11
	var fresh := _pet([], 0, FAR)
	var capped := _pet([], 999, FAR)
	check(capped.bond_lvl == Session.BOND_LEVEL_CAP, "the capped record did not read as the cap")
	var want := 1.0 + Session.BOND_POWER_PER_LEVEL * float(Session.BOND_LEVEL_CAP - 1)
	check(is_equal_approx(capped.damage / fresh.damage, want),
			"a capped bond hits %.3fx a fresh one, not %.3fx"
			% [capped.damage / fresh.damage, want])
	check(is_equal_approx(capped.max_hp / fresh.max_hp, want),
			"the bond level does not carry into HP")
	var base: float = float(_chassis.get("base_damage", 14.0))
	var rate: float = float(_chassis.get("dmg_rate", 0.0))
	check(is_equal_approx(fresh.damage, base * (1.0 + rate * 10.0)),
			"the chassis curve moved — the bond track replaced the hunter's level instead of riding it")
	fresh.queue_free()
	capped.queue_free()
	Session.level = 1

# ---- (g)/(h) the executor, one check per behavior ----------------------------

func _check_kit() -> void:
	Session.level = 1
	# melee_arc: a cone hit at 1.5x, and the Maw feeds the bond that swung it
	_clear_creatures()
	_clear_pets()
	var target := _dummy(Vector2(22, 0))
	var arc := _pet(["core.skill.abyssal_maw"], 0, Vector2(-2, 0))
	arc.hp = arc.max_hp * 0.5
	var hp_before: float = arc.hp
	var t_before: float = target.hp
	check(await _await_cast(arc), "melee_arc never fired")
	check(is_equal_approx(t_before - target.hp, arc.damage * 1.5),
			"the arc dealt %.1f, not the coefficient's %.1f"
			% [t_before - target.hp, arc.damage * 1.5])
	check(arc.hp > hp_before, "blood_leech_pct never healed the bond that swung")
	# and a body BEHIND the pet is outside the 60-degree cone
	var behind := _dummy(Vector2(-22, 0))
	var b_before: float = behind.hp
	arc._skill_cd[0] = 0.0
	arc._cd = 0.0
	check(await _await_cast(arc), "melee_arc did not fire a second time")
	check(is_equal_approx(behind.hp, b_before) or behind.hp > b_before - arc.damage,
			"the arc hit a body behind the pet — the cone test is gone")
	_clear_creatures()
	_clear_pets()

	# projectile: a FRIENDLY bolt with a real shooter and no skill_def
	var bolt_target := _dummy(Vector2(80, 0))
	var shooter := _pet(["core.skill.ember_bolt"], 0, Vector2(-2, 0))
	check(await _await_cast(shooter), "projectile never fired")
	var bolts := _projectiles()
	check(bolts.size() >= 1, "the cast left no projectile")
	if bolts.size() >= 1:
		var b: ProtoProjectile = bolts[0]
		check(b.friendly, "a pet bolt is HOSTILE — it would shoot the hunter")
		check(b.shooter != null and is_instance_valid(b.shooter),
				"a pet bolt has no shooter — the friendly sweep would crash on it")
		check((b.skill_def as Dictionary).is_empty(),
				"a pet bolt carries a skill_def — it would run the hunter's synergy pipeline")
		check(is_equal_approx(b.damage, shooter.damage * 0.9),
				"the bolt carries %.1f, not the coefficient's %.1f"
				% [b.damage, shooter.damage * 0.9])
	for b in bolts:
		b.queue_free()
	bolt_target.queue_free()
	_clear_creatures()
	_clear_pets()

	# aoe_field: impact at half, and a FRIENDLY lingering field
	_hunt._fields.clear()
	var burned := _dummy(Vector2(40, 0))
	var caster := _pet(["core.skill.magma_breath"], 0, Vector2(-2, 0))
	var burn_before: float = burned.hp
	check(await _await_cast(caster), "aoe_field never fired")
	check(burn_before - burned.hp > 0.0, "the field impact did no damage")
	check(is_equal_approx(burn_before - burned.hp, caster.damage * 0.6 * 0.5),
			"the impact is %.1f — the impact/field split moved"
			% (burn_before - burned.hp))
	check(_hunt._fields.size() >= 1, "the cast left no lingering field")
	if _hunt._fields.size() >= 1:
		var f: Dictionary = _hunt._fields[0]
		check(bool(f.get("friendly", false)),
				"a pet-cast field is HOSTILE — it would burn the hunter who called it")
		check(is_equal_approx(float(f.get("dps", 0.0)), caster.damage * 0.6 * 0.5),
				"the field carries the wrong dps")
	_hunt._fields.clear()
	_clear_creatures()
	_clear_pets()

	# channel: the line shape lays overlapping spots, not one fat circle
	var lined := _dummy(Vector2(56, 0))
	var breather := _pet(["core.skill.cinder_breath"], 0, Vector2(-2, 0))
	check(await _await_cast(breather), "channel never fired")
	check(_hunt._fields.size() >= 2,
			"a line-shaped channel laid %d field(s) — it collapsed to one circle"
			% _hunt._fields.size())
	var friendly_all := true
	for f in _hunt._fields:
		if not bool(f.get("friendly", false)):
			friendly_all = false
	check(friendly_all, "part of the channel is hostile ground")
	_hunt._fields.clear()
	lined.queue_free()
	_clear_creatures()
	_clear_pets()

	# dash: the body actually moves, and hits what it passes through
	var dived := _dummy(Vector2(70, 0))
	var diver := _pet(["core.skill.talon_dive"], 0, Vector2(-2, 0))
	var from: Vector2 = diver.global_position
	var d_before: float = dived.hp
	check(await _await_cast(diver), "dash never fired")
	check(diver.global_position.distance_to(from) > 3.0 * TILE,
			"the dash moved the pet %.0f px — it never left the ground"
			% diver.global_position.distance_to(from))
	check(d_before - dived.hp > 0.0, "the dash passed through a body without hitting it")
	_clear_creatures()
	_clear_pets()

	# (h) no damage_coeff at all means NO damage — void_step is pure mobility
	var passed := _dummy(Vector2(64, 0))
	var stepper := _pet(["core.skill.void_step"], 0, Vector2(-2, 0))
	var v_from: Vector2 = stepper.global_position
	var v_before: float = passed.hp
	check(await _await_cast(stepper), "void_step never fired")
	check(stepper.global_position.distance_to(v_from) > 2.0 * TILE,
			"void_step did not move the pet")
	check(is_equal_approx(passed.hp, v_before),
			"void_step dealt %.1f damage — damage_coeff defaults to 1.0 again"
			% (v_before - passed.hp))
	_clear_creatures()
	_clear_pets()

	# buff: the haste is real and multiplies the pet's own clock
	var watched := _dummy(Vector2(48, 0))
	var screecher := _pet(["core.skill.ember_screech"], 0, Vector2(-2, 0))
	check(await _await_cast(screecher), "buff never fired")
	check(screecher._haste > 0.0, "the buff left no haste on the pet")
	check(is_equal_approx(screecher._haste_mult, 1.25),
			"the buff multiplier is %.2f, not the content's 1.25" % screecher._haste_mult)
	watched.queue_free()
	_clear_creatures()
	_clear_pets()

	# summon: uid -1 wisplings that never touch the roster
	Session.pets.clear()
	var haunted := _dummy(Vector2(48, 0))
	var caller := _pet(["core.skill.wispling_call"], 0, Vector2(-2, 0))
	check(await _await_cast(caller), "summon never fired")
	check(caller._live_summons() == 2, "the call produced %d wisplings, not 2"
			% caller._live_summons())
	check(Session.pets.is_empty(), "a called wispling was written into the roster")
	if caller._live_summons() > 0:
		var w: ProtoPet = caller._summons[0]
		check(w.uid == -1, "a wispling carries uid %d — it would collide with a real bond" % w.uid)
		check(w.summon_life > 0.0, "a wispling has no clock — it would never leave")
		check(w.skills.is_empty(), "a wispling rolled a kit of its own")
		check(w.damage < caller.damage, "a wispling hits as hard as the bond that called it")
	# a full cap does not re-cast
	caller._skill_cd[0] = 0.0
	caller._cd = 0.0
	check(caller._pick_skill(3.0 * TILE) == -1,
			"the summon re-cast at its cap — the field would fill with wisplings")
	haunted.queue_free()
	_clear_creatures()
	_clear_pets()

# ---- (i) a wispling dies on its own clock ------------------------------------

func _check_summon_clock() -> void:
	_clear_pets()
	Session.pets.clear()
	var w := _pet([], 0, Vector2(20, 0))
	w.summon_life = 0.05
	await physics_frames(12)
	check(not is_instance_valid(w) or w.is_queued_for_deletion(),
			"a wispling outlived its clock")
	check(Session.pets.is_empty(), "an expiring wispling touched the roster")
