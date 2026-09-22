# PROTOTYPE HARNESS — the bonded pet (pet capture vision, canon §3 / design/13 §7.1).
# A cyan-washed copy of THE BODY IT WAS CAPTURED FROM that follows the hunter, hunts
# creatures that fought the player (threat-marked), and RESTS for 15 s when its HP
# hits 0 — pets never die. Its skills/attribute roll were INSTANCE-ROLLED at capture
# (see main._roll_pet) and live in the Session autoload; the shipping pet sim is a
# dh-sim concern.
#
# R57: before this, every bond came home a Gloamfen Stalker — the sprite, the tint
# and the 120/14 stat block were hardcoded here. The capture now carries the whole
# chassis (creature.capture_profile): bundle art, species tint, scale, reach, and
# PRE-LEVEL bases plus the level rates, so the pet keeps its species AND levels with
# the hunter instead of freezing at capture-time power. Records saved before R57 have
# no `chassis` key and keep the founding stalker exactly as it was.
#
# R65: the OTHER half. Until now the `core.skill.*` ids a capture rolled were
# stored, printed on the companion card and never cast — every bond, whatever it
# had been, only bit things. The roll is now a real kit, executed here by
# BEHAVIOR (content/core/skills/*.json), and the bond has its own track: bond
# level unlocks the rolled skills one at a time and adds a little potency on top
# of the chassis curve (Session.bond_* — the track is a design call, flagged).
class_name ProtoPet
extends Node2D

const TILE := 16.0
const FOLLOW_DIST := 2.5 * TILE
const TELEPORT_DIST := 12.0 * TILE
const LEASH_DIST := 11.0 * TILE      # won't hunt targets farther than this from the hunter
const REST_TIME := 15.0
const TINT := Color(0.6, 1.05, 1.3)  # friendly cyan over the stalker sprite
const REST_TINT := Color(0.42, 0.62, 0.72)
# R57: a species-coloured body would turn to mud under the full cyan wash, so a
# chassis pet gets it at half strength — enough that "bonded" still reads at a
# glance, little enough that an ember drake is still orange. The RESTING tint is
# NOT softened: a status read must win over species identity.
const CHASSIS_BOND_MIX := 0.5

# ---- the rolled kit (R65) ----------------------------------------------------
# Skill content is authored in SIM units — metres (one metre = one tile) and
# 30 Hz sim ticks — so every number crosses into prototype pixels/seconds here,
# once, and the JSON stays the shipping schema.
const SIM_HZ := 30.0
const SKILL_LEASH := 10.0 * TILE       # never casts at anything farther than this
# A skill that leaves a lingering field splits its coefficient: half lands as
# impact, half burns as field dps. The field share goes through the same
# main.spawn_field(friendly) the hunter's own field skills use, so the two
# calibrate against each other (player._exec_field: attack_damage * dps_mult).
const FIELD_DPS_SHARE := 0.5
const SUMMON_POWER := 0.35             # a wispling is a third of the pet that called it
# damage_type -> cast colour, and -> which of main.FIELD_KINDS it leaves behind.
const ELEMENT_COL := {
	"fire": Color(1.0, 0.55, 0.18),
	"umbral": Color(0.68, 0.45, 1.0),
	"physical": Color(0.85, 0.78, 0.6),
	"venom": Color(0.5, 0.88, 0.35),
	"storm": Color(0.6, 0.9, 1.0),
	"frost": Color(0.6, 0.9, 1.0),
	"blood": Color(1.0, 0.35, 0.4),
}
const FIELD_KIND := {"fire": "fire", "venom": "mire", "physical": "earth"}

var uid := 0                         # matches the Session.pets entry
var pet_name := "Gloam Stalker"
var roll_pct := 100
var max_hp := 120.0
var hp := 120.0
var damage := 14.0
var move_speed := 5.4 * TILE
var body_radius := 8.0
var attack_reach := 1.7 * TILE
var attack_cd := 1.1

# ---- the captured chassis (R57) ---------------------------------------------
var chassis: Dictionary = {}         # creature.capture_profile(), {} = pre-R57 save
var _bundle := ""                    # baked GenForge actor key ("" = procedural)
var _archetype := "stalker"          # picks the procedural fallback rig
var _species_tint := Color(1, 1, 1)
var _bond_tint := TINT
var _scale := 1.0
var _base_hp := 120.0                # PRE-level bases: the level curve is re-applied
var _base_damage := 14.0             # every time the hunter levels (see _apply_level)
var _hp_rate := 0.0
var _dmg_rate := 0.0
var _level_for := 0                  # the Session.level the stat block was built for

# ARENA HOOK (game/arena): in arena matches the pet follows a specific fighter
# body instead of the global "player" group (two builds may fight at once).
var owner_override: Node2D = null

var _cd := 0.0
var _windup := 0.0
var _rest := 0.0
var _flash := 0.0
var _attack_dir := Vector2.RIGHT
var _target: Node2D = null
var _step_accum := Vector2.ZERO

# ---- the rolled kit + the bond track (R65) -----------------------------------
var skill_ids: Array = []            # every rolled `core.skill.*` id, in roll order
var skills: Array = []               # the ones the bond level has unlocked, resolved
var bond_lvl := 1
var bond_slots := 1
var _record: Dictionary = {}         # the LIVE Session.pets entry (bond_xp lives there)
var _skill_cd: Array = []            # parallel to `skills`
var _cast: Dictionary = {}           # the skill mid-windup ({} = a plain bite)
var _cast_slot := -1
var _cast_at := Vector2.ZERO         # landing point, locked when the windup starts
var _cast_dir := Vector2.RIGHT
var _haste := 0.0                    # remaining buff time
var _haste_mult := 1.0               # attack/cast speed multiplier while it lasts
var _once: Dictionary = {}           # skill id -> spent (once_per_fight)
var _summons: Array = []
# A SUMMON is a ProtoPet with no save record: uid -1 (real uids start at 1, so it
# can never collide with the uid-matched HUD chips / rename / character panel), a
# lifetime instead of the stables, and no kit of its own.
var summon_life := 0.0

var sprite: AnimatedSprite2D
var _shadow: Sprite2D

# Rebuilds the captured body: chassis art/geometry first, then the capture-time
# instance roll (70-110%) and the hunter's level on top of the chassis bases.
func setup(data: Dictionary) -> void:
	uid = int(data.get("uid", 0))
	pet_name = Session.companion_name(data)
	roll_pct = int(data.get("roll_pct", 100))
	chassis = (data.get("chassis", {}) as Dictionary).duplicate(true)
	_bundle = str(chassis.get("bundle", str(data.get("bundle", ""))))
	_archetype = str(chassis.get("archetype", "stalker"))
	var rgb: Array = chassis.get("tint", [])
	_species_tint = Color(float(rgb[0]), float(rgb[1]), float(rgb[2])) \
			if rgb.size() == 3 else Color(1, 1, 1)
	_bond_tint = TINT.lerp(Color(1, 1, 1), CHASSIS_BOND_MIX) if not chassis.is_empty() \
			else TINT
	_scale = clampf(float(chassis.get("scale", 1.0)), 0.3, 2.5)
	body_radius = maxf(float(chassis.get("body_radius", 8.0)), 3.0)
	attack_reach = maxf(float(chassis.get("attack_reach", 1.7 * TILE)), 8.0)
	attack_cd = clampf(float(chassis.get("attack_cd", 1.1)), 0.4, 3.0)
	move_speed = clampf(float(chassis.get("base_speed", 5.4 * TILE)), 2.0 * TILE, 9.0 * TILE)
	_base_hp = maxf(float(chassis.get("base_hp", 120.0)), 1.0)
	_base_damage = maxf(float(chassis.get("base_damage", 14.0)), 0.5)
	_hp_rate = clampf(float(chassis.get("hp_rate", 0.0)), 0.0, 0.2)
	_dmg_rate = clampf(float(chassis.get("dmg_rate", 0.0)), 0.0, 0.2)
	_record = data          # the live entry, NOT a copy: bond_xp is credited in place
	skill_ids = (data.get("skills", []) as Array).duplicate()
	refresh_bond()
	_apply_level(true)
	if sprite != null:      # re-setup on a live pet (stables swap): redress it
		_dress()

# The bond levels WITH the hunter (R57): hp/damage are re-derived from the
# pre-level bases whenever Session.level moves, so a pet captured at level 3 is
# not a museum piece at level 40. Current HP keeps its fraction, never healing
# the pet for free; a resting pet still comes back at the new full.
func _apply_level(fresh: bool) -> void:
	_level_for = Session.level
	var lvl := float(maxi(Session.level - 1, 0))
	var frac := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	# R65: the hunter's level is the chassis curve; the BOND level is the pet's own
	# track and rides on top of it, so a veteran bond out-hits a fresh capture of
	# the same species at the same hunter level.
	var bond := 1.0 + Session.BOND_POWER_PER_LEVEL * float(maxi(bond_lvl, 1) - 1)
	max_hp = _base_hp * (1.0 + _hp_rate * lvl) * bond * roll_pct / 100.0
	damage = _base_damage * (1.0 + _dmg_rate * lvl) * bond * roll_pct / 100.0
	hp = max_hp if fresh else max_hp * frac

# Re-reads the bond track off the live Session record: how many of the rolled
# skills are unlocked (1 at capture, +1 every Session.BOND_SLOT_EVERY levels) and
# the potency the bond level is worth. main calls this again whenever a kill is
# credited, so a level-up lands mid-hunt instead of at the next load.
func refresh_bond() -> void:
	var was := bond_lvl
	bond_lvl = Session.bond_level(_record)
	bond_slots = Session.bond_skill_slots(bond_lvl)
	skills.clear()
	_skill_cd.clear()
	for id in skill_ids:
		if skills.size() >= bond_slots:
			break
		var def: Dictionary = Session.pet_skill_def(str(id))
		if def.is_empty():   # an id with no snapshot never eats a slot
			continue
		skills.append(def)
		_skill_cd.append(0.0)
	if bond_lvl != was and _level_for != 0:
		_apply_level(false)

# Pets reset WITH the hunter: on player respawn every pet returns at full HP
# beside the player (they never die — downed pets only rest).
func reset_at(pos: Vector2) -> void:
	global_position = pos
	hp = max_hp
	_rest = 0.0
	_windup = 0.0
	_target = null
	_clear_fight()

func _ready() -> void:
	add_to_group("pet")
	_shadow = Sprite2D.new()
	_shadow.position.y = -1.0
	add_child(_shadow)
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	_dress()   # R57: _dress plays "idle"; playing it before the frames exist
	           # only logged "There is no animation with name 'idle'" per spawn.

# Everything the chassis decides about how this pet LOOKS. Split out of _ready so
# setup() can run before or after the node enters the tree (main spawns pets both
# ways) and so a stables swap redresses a live pet.
func _dress() -> void:
	_shadow.texture = ProtoSprites.shadow_tex(maxi(roundi(16.0 * _scale), 6),
			maxi(roundi(5.0 * _scale), 2))
	sprite.sprite_frames = _frames()
	sprite.self_modulate = _species_tint   # species hue under the bond wash
	sprite.scale = Vector2.ONE * _scale
	sprite.position.y = -6.0 * _scale
	if not sprite.sprite_frames.has_animation(sprite.animation):
		sprite.play("idle")

# Baked GenForge bundle for the captured species when one exists, else the
# procedural rig its chassis rides (a captured wisp must not walk as a stalker).
func _frames() -> SpriteFrames:
	if _bundle != "":
		var sf := ProtoBundleArt.frames_for(_bundle)
		if sf != null:
			ProtoBundleArt.ensure_animations(sf, ["idle", "walk", "lunge"])
			return sf
	match _archetype:
		"wisp", "hag":
			return ProtoSprites.wisp_frames()
		"dragon", "colossus":
			return ProtoSprites.boss_frames()
	return ProtoSprites.stalker_frames()

func resting() -> bool:
	return _rest > 0.0

func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	for i in _skill_cd.size():
		_skill_cd[i] = maxf(_skill_cd[i] - delta, 0.0)
	if _haste > 0.0:
		_haste -= delta
		if _haste <= 0.0:
			_haste_mult = 1.0
	if summon_life > 0.0:   # a called wispling is on a clock, not a leash
		summon_life -= delta
		if summon_life <= 0.0:
			_unsummon()
			return
	if _level_for != Session.level:   # the hunter levelled: the bond levels too
		_apply_level(false)
	var tint := REST_TINT if _rest > 0.0 else _bond_tint
	sprite.modulate = tint.lerp(Color(2.5, 2.5, 2.5), _flash)
	var player: Node2D = owner_override if is_instance_valid(owner_override) \
			else get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if _rest > 0.0:
		_rest -= delta
		_target = null
		if _rest <= 0.0:
			hp = max_hp
			_clear_fight()   # a rest ends the fight: rescue buffs re-arm
			var main := get_tree().get_first_node_in_group("main")
			if main:
				main.damage_number(global_position + Vector2(0, -20), 0,
						Color("7fe7ff"), "%s is rested!" % pet_name)
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_strike()
		_update_anim()
		queue_redraw()
		return
	if _rest <= 0.0:
		_acquire(player)
	var step := Vector2.ZERO
	if _target != null:
		var to_t: Vector2 = _target.global_position - global_position
		var dir := to_t.normalized()
		# R65: the rolled kit gets first refusal every time the pet is off cooldown;
		# the bite is what it does when nothing in the kit is ready or in range.
		var slot := _pick_skill(to_t.length()) if _cd <= 0.0 else -1
		if slot >= 0:
			_begin_cast(slot, dir)
		elif to_t.length() <= attack_reach + _target.body_radius and _cd <= 0.0:
			_windup = 0.22 / _haste_mult
			_attack_dir = dir
			_flash = 0.5
			sprite.flip_h = _attack_dir.x < 0.0
			sprite.play("lunge")
			sprite.frame = 0
		else:
			step = dir * move_speed * delta
	else:
		var to_p: Vector2 = player.global_position - global_position
		if to_p.length() > TELEPORT_DIST:
			var world := get_tree().get_first_node_in_group("world")
			global_position = world.random_walkable_in_ring(
					player.global_position, TILE, FOLLOW_DIST) if world \
					else player.global_position
		elif to_p.length() > FOLLOW_DIST:
			step = to_p.normalized() * move_speed * delta
	_move(step)
	_update_anim()
	queue_redraw()

# Hunts the nearest threat-marked creature near the hunter.
func _acquire(player: Node2D) -> void:
	if _target != null and (not is_instance_valid(_target) or _target.dead \
			or _target.global_position.distance_to(player.global_position) > LEASH_DIST):
		_target = null
	if _target != null:
		return
	var best: Node2D = null
	var best_d := 9.0 * TILE
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead or not c.threat:
			continue
		if ("owner_fighter" in c) and c.owner_fighter == player:   # ARENA: own proxy
			continue
		if c.global_position.distance_to(player.global_position) > LEASH_DIST:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = c
	_target = best

# The windup landed. A queued cast fires its behavior and pays its own cooldown;
# everything else is the plain bite this pet has always had.
func _strike() -> void:
	if not _cast.is_empty():
		var def := _cast
		var slot := _cast_slot
		var n: Dictionary = def.get("numbers", {})
		_cast = {}
		_cast_slot = -1
		_cd = maxf(float(n.get("recovery_ticks", 6)) / SIM_HZ, 0.2) / _haste_mult
		if slot >= 0 and slot < _skill_cd.size():
			_skill_cd[slot] = maxf(float(n.get("cooldown_s", 8.0)), 0.5) / _haste_mult
		_execute(def)
		return
	_cd = attack_cd / _haste_mult
	if _target == null or not is_instance_valid(_target) or _target.dead:
		return
	var to_t: Vector2 = _target.global_position - global_position
	if to_t.length() <= attack_reach + _target.body_radius + 4.0:
		_target.take_damage(damage, to_t.normalized(), Color("7fe7ff"))

# ---- the kit (R65) -----------------------------------------------------------
# One executor keyed on `behavior`, NOT a hand-written branch per skill: adding a
# skill has to stay a JSON edit (canon §10 extensibility), which is exactly what
# the boss's hardcoded _cast does not do.

# First unlocked skill that is off cooldown AND makes sense right now. Slot order
# is roll order, so the signature skill (main._roll_pet guarantees it first) is
# the one the pet reaches for.
func _pick_skill(dist: float) -> int:
	if not _cast.is_empty() or skills.is_empty():
		return -1
	for i in skills.size():
		if _skill_cd[i] > 0.0:
			continue
		var def: Dictionary = skills[i]
		var n: Dictionary = def.get("numbers", {})
		match str(def.get("behavior", "")):
			"buff":
				if _haste > 0.0:
					continue
				# a rescue buff (shrieking_curse) waits for the hp trigger and is
				# spent for the rest of the fight once it fires
				if n.has("trigger_below_hp_pct"):
					if hp / maxf(max_hp, 1.0) * 100.0 > float(n.trigger_below_hp_pct):
						continue
					if _once.has(str(def.get("id", ""))):
						continue
			"summon":
				if _live_summons() >= maxi(int(n.get("summon_cap", 2)), 1):
					continue
			"melee_arc":
				if dist > float(n.get("reach_m", 1.8)) * TILE + _target_radius():
					continue
			"dash":
				# a dash that lands on top of the target is a wasted cooldown
				if dist < 2.0 * TILE or dist > float(n.get("dash_range_m", 6.0)) * TILE:
					continue
			_:
				var reach := float(n.get("line_length_m", 0.0)) * TILE
				if dist > (reach if reach > 0.0 else SKILL_LEASH):
					continue
		return i
	return -1

# Locks the aim and the landing point NOW, so a target that dies or runs during
# the windup still eats the cast it walked into.
func _begin_cast(slot: int, dir: Vector2) -> void:
	var def: Dictionary = skills[slot]
	var n: Dictionary = def.get("numbers", {})
	_cast = def
	_cast_slot = slot
	_cast_dir = dir
	_attack_dir = dir
	_cast_at = _target.global_position if is_instance_valid(_target) \
			else global_position + dir * 3.0 * TILE
	_windup = maxf(float(n.get("windup_ticks", 8)) / SIM_HZ, 0.1) / _haste_mult
	_flash = 0.5
	sprite.flip_h = dir.x < 0.0
	sprite.play("lunge")
	sprite.frame = 0
	_telegraph(def, _windup)

# The same pooled telegraph the bosses warn with, in the skill's own element and
# at half alpha: a FRIENDLY cast must never read as a red floor you should dodge.
func _telegraph(def: Dictionary, dur: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.get("telegraphs") == null:
		return
	var n: Dictionary = def.get("numbers", {})
	var col: Color = ELEMENT_COL.get(str(def.get("damage_type", "physical")),
			Color(0.7, 0.9, 1.0))
	col.a = 0.4
	match str((def.get("telegraph", {}) as Dictionary).get("shape", "")):
		"line":
			main.telegraphs.line(global_position, _cast_dir,
					float(n.get("line_length_m", n.get("dash_range_m", 6.0))) * TILE,
					maxf(float(n.get("line_width_m", 1.5)), 1.0) * TILE, dur, col)
		"circle", "ring":
			main.telegraphs.ring(_cast_at, _impact_radius(n), dur, col)
		"arc":
			main.telegraphs.ring(global_position,
					float(n.get("reach_m", 1.8)) * TILE, dur, col)

func _impact_radius(n: Dictionary) -> float:
	return maxf(float(n.get("impact_radius_m", n.get("quake_radius_m",
			n.get("field_radius_m", 2.5)))) * TILE, 8.0)

func _target_radius() -> float:
	return _target.body_radius if is_instance_valid(_target) else 0.0

# ARENA: a pet must not shoot its own side's proxy (the fighter body it follows).
func _hostile(c: Node) -> bool:
	return not (("owner_fighter" in c) and is_instance_valid(owner_override) \
			and c.owner_fighter == owner_override)

func _execute(def: Dictionary) -> void:
	var main := get_tree().get_first_node_in_group("main")
	var n: Dictionary = def.get("numbers", {})
	var elem := str(def.get("damage_type", "physical"))
	var col: Color = ELEMENT_COL.get(elem, Color(0.7, 0.9, 1.0))
	# no damage_coeff at all means the skill does no damage (void_step is pure
	# mobility, the buffs are pure buff) — a 1.0 default would invent a hit.
	var dmg := damage * float(n.get("damage_coeff", 0.0))
	var impact := dmg * (FIELD_DPS_SHARE if n.has("field_duration_s") else 1.0)
	match str(def.get("behavior", "")):
		"melee_arc":
			_cast_arc(n, impact, col, main)
		"projectile":
			_cast_projectile(n, elem, impact, col, main)
		"aoe_field", "channel":
			_cast_field(n, elem, impact, dmg * FIELD_DPS_SHARE, col, main)
		"dash":
			_cast_dash(n, impact, col, main)
		"buff":
			_cast_buff(def, n, col, main)
		"summon":
			_cast_summon(n, col, main)
	if main:
		main.damage_number(global_position + Vector2(0, -26), 0, col,
				str(def.get("name", "?")))

func _cast_arc(n: Dictionary, dmg: float, col: Color, main: Node) -> void:
	var reach := float(n.get("reach_m", 1.8)) * TILE
	var cos_half := cos(deg_to_rad(float(n.get("arc_deg", 90.0))) * 0.5)
	var hit := false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead or not _hostile(c):
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= reach + c.body_radius \
				and to_c.normalized().dot(_cast_dir) >= cos_half:
			c.take_damage(dmg, _cast_dir, col)
			hit = true
	if hit:
		var leech := float(n.get("blood_leech_pct", 0.0)) / 100.0
		if leech > 0.0:   # Abyssal Maw feeds the bond that swung it
			hp = minf(hp + dmg * leech, max_hp)
	if main:
		main.play_sfx("swing", global_position, -10.0)
		main.fx.shader_burst("slash", global_position,
				{"size": reach * 2.8, "dir": _cast_dir, "color": col,
				"uniforms": {"arc_radius": 0.71,
				"arc_span": deg_to_rad(float(n.get("arc_deg", 90.0))), "arc_thick": 0.11}})

func _cast_projectile(n: Dictionary, elem: String, dmg: float, col: Color,
		main: Node) -> void:
	var count := maxi(int(n.get("projectile_count", 1)), 1)
	var spread := deg_to_rad(float(n.get("spread_deg", 0.0)))
	var muzzle := global_position + Vector2(0, -8) + _cast_dir * 8.0
	for i in count:
		var ang := 0.0
		if count > 1:
			ang = -spread * 0.5 + spread * float(i) / float(count - 1)
		var b := ProtoProjectile.new()
		b.friendly = true
		match elem:
			"umbral":
				b.set_violet()
			"frost":
				b.set_frost()
			"storm":
				b.set_arcane()
			"physical":
				b.set_steel()
		b.damage = dmg
		# skill_def stays EMPTY on purpose: everything behind projectile_hit is the
		# HUNTER's synergy pipeline (applies / bonus_vs / consumes) and the pet
		# content schema carries none of it — the plain damage path is the right one.
		b.shooter = owner_override if is_instance_valid(owner_override) else self
		b.lifetime = 2.0
		b.global_position = muzzle
		b.velocity = _cast_dir.rotated(ang) \
				* float(n.get("projectile_speed_mps", 14.0)) * TILE
		get_parent().add_child(b)
	if main:
		main.play_sfx("bolt", global_position, -10.0)
		main.fx.orbital(muzzle, {"count": 4, "radius": 4.0, "life": 0.2, "color": col})

# aoe_field and channel share this: an impact at one or more spots, then the
# lingering field (when the skill leaves one) through main.spawn_field FRIENDLY —
# the same system the hunter's field skills use, so it burns creatures, not us.
func _cast_field(n: Dictionary, elem: String, impact: float, dps: float,
		col: Color, main: Node) -> void:
	if main == null:
		return
	var spots: Array = []
	var line_len := float(n.get("line_length_m", 0.0)) * TILE
	if line_len > 0.0:
		# stone_spikes / cinder_breath: the shape is a LINE, so the effect is laid
		# down as overlapping spots along the aim instead of one fat circle.
		var step := maxf(float(n.get("field_radius_m",
				n.get("line_width_m", 2.0))) * TILE, 8.0)
		for i in maxi(int(line_len / step), 1):
			spots.append(global_position + _cast_dir * (step * (float(i) + 0.5)))
	elif int(n.get("meteor_count", 0)) > 0:
		for _i in int(n.meteor_count):
			spots.append(_cast_at + Vector2(randf_range(-1.6, 1.6),
					randf_range(-1.6, 1.6)) * TILE)
	else:
		spots.append(_cast_at)
	var radius := _impact_radius(n)
	var kind: String = FIELD_KIND.get(elem, "fire")
	var dur := float(n.get("field_duration_s", 0.0))
	var kb := float(n.get("knockback_m", 0.0))
	var slow := float(n.get("slow_pct", 0.0))
	var per := impact / float(spots.size())   # full overlap still totals one cast
	for at in spots:
		for c in get_tree().get_nodes_in_group("creatures"):
			if c.dead or not _hostile(c):
				continue
			if c.global_position.distance_to(at) > radius + c.body_radius:
				continue
			var away: Vector2 = (c.global_position - at).normalized()
			if per > 0.0:
				c.take_damage(per, away, col)
			if kb > 0.0:
				c.shove(away, kb * TILE)
			if slow > 0.0:
				c.apply_slow(1.0)
		if dur > 0.0:
			main.spawn_field(at, maxf(float(n.get("field_radius_m", 2.2)) * TILE, 8.0),
					dur, dps / float(spots.size()), kind, true)
		main.fx.shockwave(at, col, radius)
		main.fx.orbital(at, {"count": 5, "radius": 12.0, "life": 0.35, "color": col})
	main.play_sfx("bolt", global_position, -8.0)
	main.shake(2.0)

func _cast_dash(n: Dictionary, dmg: float, col: Color, main: Node) -> void:
	var start := global_position
	var dist := float(n.get("dash_range_m", 6.0)) * TILE
	var world := get_tree().get_first_node_in_group("world")
	for _i in 8:   # stepped, so walls still gate the dash
		var nxt := global_position + _cast_dir * dist / 8.0
		if world != null and not world.is_walkable(nxt):
			break
		global_position = nxt
	var seg := global_position - start
	if dmg > 0.0:
		for c in get_tree().get_nodes_in_group("creatures"):
			if c.dead or not _hostile(c):
				continue
			var t := 0.0
			if seg.length_squared() > 0.0:
				t = clampf((c.global_position - start).dot(seg) / seg.length_squared(),
						0.0, 1.0)
			if (start + seg * t).distance_to(c.global_position) \
					<= 1.2 * TILE + c.body_radius:
				c.take_damage(dmg, _cast_dir, col)
	if main:
		main.play_sfx("swing", global_position, -10.0)
		main.fx.ribbon_streak(start, global_position,
				{"color": col, "width": 6, "life": 0.25})
		main.fx.shockwave(global_position, col, 26.0)

func _cast_buff(def: Dictionary, n: Dictionary, col: Color, main: Node) -> void:
	_haste = maxf(float(n.get("duration_s", 10.0)), 1.0)
	_haste_mult = 1.0 + maxf(float(n.get("attack_speed_pct", 0.0)),
			float(n.get("cast_speed_pct", 0.0))) / 100.0
	if int(n.get("once_per_fight", 0)) > 0:
		_once[str(def.get("id", ""))] = true
	if main:
		main.play_ui("capture", -16.0)
		main.fx.aura(self, col, {"radius": 18.0, "dur": _haste, "orbit_ribbons": 2})

func _cast_summon(n: Dictionary, col: Color, main: Node) -> void:
	var cap := maxi(int(n.get("summon_cap", 2)), 1)
	var want := mini(maxi(int(n.get("summon_count", 1)), 1), cap - _live_summons())
	var life := maxf(float(n.get("summon_lifetime_s", 10.0)), 1.0)
	for _i in want:
		var s := ProtoPet.new()
		# no save record, no kit, uid -1: see `summon_life` above.
		s.setup({"uid": -1, "name": pet_name, "skills": [], "chassis": chassis,
				"roll_pct": maxi(roundi(float(roll_pct) * SUMMON_POWER), 10)})
		s.summon_life = life
		s.owner_override = owner_override
		s.global_position = global_position \
				+ Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * TILE
		get_parent().add_child(s)
		_summons.append(s)
		if main:
			main.fx.ring(s.global_position, Color(col.r, col.g, col.b, 0.9), 14.0)

func _live_summons() -> int:
	var live: Array = []
	for s in _summons:
		if is_instance_valid(s):
			live.append(s)
	_summons = live
	return live.size()

func _unsummon() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.fx.burst(global_position, {"amount": 10, "lifetime": 0.35,
				"v_min": 20.0, "v_max": 70.0, "gravity": Vector2.ZERO,
				"color": ELEMENT_COL.umbral})
	queue_free()

# Everything that is scoped to ONE fight: cooldowns, the buff, the once-per-fight
# ledger, and any wisplings still standing.
func _clear_fight() -> void:
	_cast = {}
	_cast_slot = -1
	_haste = 0.0
	_haste_mult = 1.0
	_once.clear()
	for i in _skill_cd.size():
		_skill_cd[i] = 0.0

func take_damage(dmg: float, _from_dir: Vector2) -> void:
	if _rest > 0.0:
		return
	hp -= dmg
	_flash = 1.0
	if hp <= 0.0:
		hp = 0.0
		if summon_life > 0.0:
			_unsummon()   # a wispling has no stables to rest in
			return
		_rest = REST_TIME
		_windup = 0.0
		_target = null
		_clear_fight()
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.damage_number(global_position + Vector2(0, -20), 0,
					Color("7fe7ff"), "%s rests..." % pet_name)
	queue_redraw()

func _move(step: Vector2) -> void:
	if step == Vector2.ZERO:
		_step_accum = Vector2.ZERO
		return
	var world := get_tree().get_first_node_in_group("world")
	var target := global_position + step
	if world == null or world.is_walkable(target):
		global_position = target
		_step_accum = step

func _update_anim() -> void:
	if _windup > 0.0:
		if sprite.animation != "lunge":
			sprite.play("lunge")
	elif _step_accum.length() > 0.15:
		if absf(_step_accum.x) > 0.02:
			sprite.flip_h = _step_accum.x < 0.0
		if sprite.animation != "walk":
			sprite.play("walk")
	elif sprite.animation != "idle":
		sprite.play("idle")

func _draw() -> void:
	if hp >= max_hp and _rest <= 0.0:
		return
	var w := body_radius * 2.4
	var y := -body_radius * 2.0 - 6.0
	draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.6))
	var frac := clampf(hp / max_hp, 0, 1) if _rest <= 0.0 \
			else 1.0 - clampf(_rest / REST_TIME, 0, 1)   # resting: shows the recovery fill
	draw_rect(Rect2(-w / 2, y, w * frac, 3), Color("59d6e6"))
