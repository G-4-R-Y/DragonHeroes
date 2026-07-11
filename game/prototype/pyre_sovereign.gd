# PROTOTYPE HARNESS — the Pyre Sovereign: fire half of the Legendary duo
# (canon §4). A mobile skirmisher that OWNS THE SKY: Meteor Call rains delayed
# telegraphed impacts that leave fire fields, Cinder Breath burns a line, Wing
# Gust breaks melee pressure, Ember Bolt pokes. Every fire field it lays is
# Duologue fuel — over the Colossus's earth it fuses into LAVA (main.gd).
# Kit mirrors content/core/creatures/pyre_sovereign.json (prototype scale).
class_name ProtoPyreSovereign
extends ProtoDuoBoss

const EmberProjectile := preload("res://prototype/projectile.gd")

var _meteors: Array = []   # {pos, t} — scheduled impacts ticked here

func _ready() -> void:
	max_hp = 1700.0            # (proposal) endgame-hard: ~2x the Matriarch
	damage = 30.0
	move_speed = 5.8 * TILE
	body_radius = 22.0
	aggro_range = 13.0 * TILE
	attack_reach = 2.6 * TILE
	windup_time = 0.42
	attack_cd = 1.7
	gold_min = 150
	gold_max = 450
	display_name = "PYRE SOVEREIGN — Legendary"
	bar_color = Color("ff5a2e")
	_base_tint = Color(1.3, 0.78, 0.62)   # hotter cast over the winged rig
	_scale = 1.35
	_skill_cd = {"bolt": 2.0, "meteor": 4.0, "breath": 6.0, "gust": 3.0}
	super._ready()

func _make_frames() -> SpriteFrames:
	return ProtoSprites.boss_frames()

func _sprite_lift() -> float:
	return 16.0

func _shadow_dims() -> Vector2i:
	return Vector2i(34, 10)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	var impacted := false
	for m in _meteors:
		m.t -= delta
		if m.t <= 0.0:
			_meteor_impact(m.pos)
			impacted = true
	if impacted:
		_meteors = _meteors.filter(func(m): return m.t > 0.0)

# Selection: meteors on cooldown tempo, gust when crowded, breath at mid range,
# bolts as filler — then skirmish the 5.5-tile pocket like the Matriarch.
func _chase(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < 11.0 * TILE and _skill_cd["meteor"] <= 0.0:
		_begin_cast("meteor", player, 0.5)
		_skill_cd["meteor"] = 11.0 * _cd_scale
	elif dist < 3.0 * TILE and _skill_cd["gust"] <= 0.0:
		_begin_cast("gust", player, 0.5)
		_skill_cd["gust"] = 10.0 * _cd_scale
		_telegraph_circle(global_position, 4.5 * TILE, 0.5)
	elif dist >= 2.5 * TILE and dist < 7.0 * TILE and _skill_cd["breath"] <= 0.0:
		_begin_cast("breath", player, 0.7)
		_skill_cd["breath"] = 9.0 * _cd_scale
		_telegraph_line(player.global_position, 52.0, 0.7)
	elif dist > 4.0 * TILE and _skill_cd["bolt"] <= 0.0:
		_begin_cast("bolt", player, 0.17)
		_skill_cd["bolt"] = 2.2 * _cd_scale
	else:
		var ideal := 5.5 * TILE
		var dir := (player.global_position - global_position).normalized()
		if dist > ideal + TILE:
			_move(dir * _speed() * delta)
		elif dist < ideal - TILE:
			_move(-dir * _speed() * 0.7 * delta)
		else:
			_move(dir.orthogonal() * _speed() * 0.5 * delta)
	if dist <= attack_reach * 0.9 and _cd <= 0.0:
		_begin_windup((player.global_position - global_position).normalized())

func _strike(player: Node2D) -> void:
	if _pending == "":
		super._strike(player)   # talon rake up close
		return
	var skill := _pending
	_pending = ""
	_state = "recover"
	_timer = 0.4
	var main := get_tree().get_first_node_in_group("main")
	match skill:
		"meteor":
			_call_meteors(player)
		"breath":
			_breath(player, main)
		"gust":
			if player and not player.dead and global_position.distance_to(
					player.global_position) <= 4.5 * TILE:
				player.take_damage(10.0, (player.global_position
						- global_position).normalized())
				player.knockback((player.global_position
						- global_position).normalized() * 4.5 * TILE)
			if main:
				main.fx.tornado(global_position)
		"bolt":
			var p := EmberProjectile.new()
			p.global_position = global_position
			p.velocity = _attack_dir * 18.0 * TILE
			p.damage = 16.0
			get_parent().add_child(p)
			if main:
				main.play_sfx("bolt", global_position, -8.0)

# Meteor Call: 3 telegraphed points around the hunter, impacts land 0.9 s later
# (meteor_call.json impact_delay_ticks 27 @ 30 Hz) and leave fire fields.
func _call_meteors(player: Node2D) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var center: Vector2 = player.global_position if player else _cast_target
	for i in 3:
		var at := center
		if i > 0:
			at = world.random_walkable_in_ring(center, 1.5 * TILE, 3.5 * TILE) \
					if world else center + Vector2(randf_range(-56, 56), randf_range(-56, 56))
		_telegraph_circle(at, 2.2 * TILE, 0.9)
		_meteors.append({"pos": at, "t": 0.9})
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.play_sfx("boss_screech", global_position, -12.0)

func _meteor_impact(at: Vector2) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	main.fx.explosion(at, Color(1.0, 0.5, 0.15), true)
	main.shake(5.0)
	main.play_sfx("hit", at, -6.0)
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.dead \
			and at.distance_to(player.global_position) <= 2.2 * TILE + player.body_radius:
		player.take_damage(26.0, (player.global_position - at).normalized(), "fire")
	main.spawn_field(at, 2.2 * TILE, 6.0, 7.0, "fire")

# Cinder Breath: a 7-tile burning corridor; small fire fields smolder along it.
func _breath(player: Node2D, main: Node) -> void:
	var dir := _attack_dir
	if main:
		main.fx.flame_cone(global_position + dir * 0.8 * TILE, dir)
		main.fx.flame_cone(global_position + dir * 3.2 * TILE, dir)
		main.play_sfx("hit", global_position, -8.0)
	if _hits_corridor(player, dir, 7.0 * TILE, 52.0):
		player.take_damage(24.0, dir, "fire")
	if main:
		for d in [2.5, 4.5, 6.5]:
			main.spawn_field(global_position + dir * d * TILE,
					1.6 * TILE, 5.0, 6.0, "fire")
