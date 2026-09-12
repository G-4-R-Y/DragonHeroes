# PROTOTYPE HARNESS — the bonded pet (pet capture vision, canon §3 / design/13 §7.1).
# A cyan-tinted Gloamfen Stalker that follows the hunter, hunts creatures that fought
# the player (threat-marked), and RESTS for 15 s when its HP hits 0 — pets never die.
# Its skills/attribute roll were INSTANCE-ROLLED at capture (see main._roll_pet) and
# live in the Session autoload; the shipping pet sim is a dh-sim concern.
class_name ProtoPet
extends Node2D

const TILE := 16.0
const FOLLOW_DIST := 2.5 * TILE
const TELEPORT_DIST := 12.0 * TILE
const LEASH_DIST := 11.0 * TILE      # won't hunt targets farther than this from the hunter
const REST_TIME := 15.0
const TINT := Color(0.6, 1.05, 1.3)  # friendly cyan over the stalker sprite
const REST_TINT := Color(0.42, 0.62, 0.72)

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

# Applies the capture-time instance roll (70-110%) to hp/damage.
func setup(data: Dictionary) -> void:
	uid = int(data.get("uid", 0))
	pet_name = Session.companion_name(data)
	roll_pct = int(data.get("roll_pct", 100))
	max_hp = 120.0 * roll_pct / 100.0
	hp = max_hp
	damage = 14.0 * roll_pct / 100.0

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
	_shadow.texture = ProtoSprites.shadow_tex(16, 5)
	_shadow.position.y = -1.0
	add_child(_shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ProtoSprites.stalker_frames()
	sprite.position.y = -6.0
	sprite.play("idle")
	add_child(sprite)

func resting() -> bool:
	return _rest > 0.0

func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	var tint := REST_TINT if _rest > 0.0 else TINT
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
