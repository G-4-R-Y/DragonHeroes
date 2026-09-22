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
	max_hp = _base_hp * (1.0 + _hp_rate * lvl) * roll_pct / 100.0
	damage = _base_damage * (1.0 + _dmg_rate * lvl) * roll_pct / 100.0
	hp = max_hp if fresh else max_hp * frac

# Pets reset WITH the hunter: on player respawn every pet returns at full HP
# beside the player (they never die — downed pets only rest).
func reset_at(pos: Vector2) -> void:
	global_position = pos
	hp = max_hp
	_rest = 0.0
	_windup = 0.0
	_target = null

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
		if to_t.length() <= attack_reach + _target.body_radius and _cd <= 0.0:
			_windup = 0.22
			_attack_dir = to_t.normalized()
			_flash = 0.5
			sprite.flip_h = _attack_dir.x < 0.0
			sprite.play("lunge")
			sprite.frame = 0
		else:
			step = to_t.normalized() * move_speed * delta
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

func _strike() -> void:
	_cd = attack_cd
	if _target == null or not is_instance_valid(_target) or _target.dead:
		return
	var to_t: Vector2 = _target.global_position - global_position
	if to_t.length() <= attack_reach + _target.body_radius + 4.0:
		_target.take_damage(damage, to_t.normalized(), Color("7fe7ff"))

func take_damage(dmg: float, _from_dir: Vector2) -> void:
	if _rest > 0.0:
		return
	hp -= dmg
	_flash = 1.0
	if hp <= 0.0:
		hp = 0.0
		_rest = REST_TIME
		_windup = 0.0
		_target = null
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
