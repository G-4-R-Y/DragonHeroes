# PROTOTYPE HARNESS — Gloamfen Wisp: the second creature, spirit archetype.
# A floating cyan-violet orb that KITES: it holds 5-7 m from the hunter and fires
# violet umbral bolts (0.3 s windup flash, 2.5 s cooldown) while the stalkers rush —
# pack composition creates the ranged/melee split emergently. Shipping path is a
# data-driven AI profile in dh-sim (docs/tech/25), same as every creature here.
class_name ProtoWisp
extends ProtoCreature

const Bolt := preload("res://prototype/projectile.gd")

var element := "umbral"          # umbral | ember | frost — set by the spawner
var _bob := 0.0

func _ready() -> void:
	max_hp = 60.0
	damage = 10.0                 # umbral bolt damage
	match element:                # elemental variants (effects registry)
		"ember":
			damage = 12.0
			_base_tint *= Color(1.25, 0.85, 0.6)   # x= so catalog species tint survives
		"frost":
			damage = 8.0          # weaker hit, but bolts Chill (-35% move 1.2 s)
			_base_tint *= Color(0.75, 1.0, 1.2)
	move_speed = 3.5 * TILE
	body_radius = 7.0
	aggro_range = 9.0 * TILE
	windup_time = 0.3             # windup flash before the bolt
	attack_cd = 2.5
	gold_min = 6
	gold_max = 24
	stone_chance = 0.12
	snare_chance = 0.0
	capturable = false            # not in the Abyssal capture pool (abyssal.json)
	super._ready()

func _make_frames() -> SpriteFrames:
	return _bundle_or(ProtoSprites.wisp_frames())

func _sprite_lift() -> float:
	return 10.0                   # floats well above its tiny shadow

func _shadow_dims() -> Vector2i:
	return Vector2i(8, 3)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	_bob += delta
	sprite.position.y = -_sprite_lift() + sin(_bob * 4.0) * 1.6   # float bob

# Kite: back off inside 5 m, close outside 7 m, strafe in the pocket; fire when able.
func _chase(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var dir := to_player.normalized()
	if _cd <= 0.0 and dist >= 3.0 * TILE and dist <= 8.5 * TILE:
		_begin_windup(dir)
		return
	if dist < 5.0 * TILE:
		_move(-dir * _speed() * delta)
	elif dist > 7.0 * TILE:
		_move(dir * _speed() * delta)
	else:
		_move(dir.orthogonal() * _speed() * 0.5 * delta)
	_separate(delta)
	if dist > aggro_range * 2.2:
		_state = "idle"

func _strike(player: Node2D) -> void:
	_state = "recover"
	_timer = 0.5
	_cd = attack_cd
	if player == null or player.dead:
		_pose_punch(Vector2.ONE, 0.0, 0.2)   # dry fire: release the windup lean
		return
	var dir := (player.global_position - global_position).normalized()
	var p := Bolt.new()
	p.shooter = self   # ARENA: lets the bolt hunt target_override
	match element:
		"ember":
			pass          # projectile default IS the ember bolt (fire)
		"frost":
			p.set_frost()
		_:
			p.set_violet()
	p.global_position = global_position
	p.velocity = dir * 14.0 * TILE
	p.damage = damage
	get_parent().add_child(p)
	_strike_recoil(-dir, 0.7)   # the orb kicks back as the bolt leaves it
	var main := get_tree().get_first_node_in_group("main")
	if main:
		# Muzzle swirl as the bolt leaves the orb (spec §3), element-tinted. The
		# short danger ring is fired by the base _begin_windup; the bolt's ribbon
		# trail is owned by projectile.gd (self-attaches) — no trail_attach here,
		# or the bolt would carry two trails.
		var muzzle_col := Color(0.68, 0.5, 1.0)   # umbral violet (default)
		match element:
			"ember":
				muzzle_col = Color(1.0, 0.55, 0.25)
			"frost":
				muzzle_col = Color(0.6, 0.9, 1.0)
		main.fx.orbital(global_position + dir * 6.0,
				{"count": 4, "radius": 4.0, "life": 0.2, "color": muzzle_col})
		main.play_sfx("bolt", global_position, -10.0)
