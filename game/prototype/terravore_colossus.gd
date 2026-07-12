# PROTOTYPE HARNESS — the Terravore Colossus: earth half of the Legendary duo
# (canon §4). A slow ZONER that OWNS THE GROUND: Earthshatter is a huge
# telegraphed radial quake (dodge OUT), Stone Spikes rip a telegraphed line,
# Stone Upheaval drops earth fields under the hunter, Boulder Hurl punishes
# range. Its earth fields are Duologue fuel — under the Sovereign's fire they
# fuse into LAVA (main.gd spawn_field).
# Kit mirrors content/core/creatures/terravore_colossus.json (prototype scale).
class_name ProtoTerravoreColossus
extends ProtoDuoBoss

const BoulderProjectile := preload("res://prototype/projectile.gd")

const EARTH_TELE := Color(0.85, 0.6, 0.3, 0.35)

func _ready() -> void:
	max_hp = 2300.0            # (proposal) the duo's anchor: biggest HP in the slice
	damage = 34.0
	move_speed = 2.8 * TILE
	body_radius = 26.0
	aggro_range = 13.0 * TILE
	attack_reach = 2.8 * TILE
	windup_time = 0.6
	attack_cd = 2.2
	gold_min = 150
	gold_max = 450
	display_name = "TERRAVORE COLOSSUS — Legendary"
	bar_color = Color("c9a05a")
	_base_tint = Color(0.85, 0.78, 0.62)   # stone cast over the quadruped rig
	_scale = 2.3
	_skill_cd = {"quake": 5.0, "spikes": 3.0, "upheaval": 7.0, "boulder": 2.0}
	super._ready()

func _make_frames() -> SpriteFrames:
	# giant rig stand-in, scaled 2.3x (legendary bundles override)
	return _bundle_or(ProtoSprites.stalker_frames())

func _sprite_lift() -> float:
	return 8.0

func _shadow_dims() -> Vector2i:
	return Vector2i(36, 11)

# Selection: quake when you hug it, upheaval to zone your feet, spikes at mid
# range, boulders at long range — otherwise it just lumbers at you.
func _chase(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < 4.0 * TILE and _skill_cd["quake"] <= 0.0:
		_begin_cast("quake", player, 0.9)
		_skill_cd["quake"] = 12.0 * _cd_scale
		_telegraph_circle(global_position, 4.5 * TILE, 0.9, EARTH_TELE)
	elif dist < 9.0 * TILE and _skill_cd["upheaval"] <= 0.0:
		_begin_cast("upheaval", player, 0.6)
		_skill_cd["upheaval"] = 10.0 * _cd_scale
		_telegraph_circle(player.global_position, 3.0 * TILE, 0.6, EARTH_TELE)
	elif dist >= 2.5 * TILE and dist < 9.0 * TILE and _skill_cd["spikes"] <= 0.0:
		_begin_cast("spikes", player, 0.65)
		_skill_cd["spikes"] = 8.0 * _cd_scale
		_telegraph_line(player.global_position, 40.0, 0.65, EARTH_TELE)
	elif dist >= 5.0 * TILE and _skill_cd["boulder"] <= 0.0:
		_begin_cast("boulder", player, 0.45)
		_skill_cd["boulder"] = 6.0 * _cd_scale
	else:
		_move((player.global_position - global_position).normalized()
				* _speed() * delta)
		_separate(delta)
	if dist <= attack_reach * 0.9 and _cd <= 0.0:
		_begin_windup((player.global_position - global_position).normalized())

func _strike(player: Node2D) -> void:
	if _pending == "":
		super._strike(player)   # crushing swipe up close
		return
	var skill := _pending
	_pending = ""
	_state = "recover"
	_timer = 0.55
	var main := get_tree().get_first_node_in_group("main")
	match skill:
		"quake":
			_pose_punch(Vector2(1.34, 0.68), 0.0, 0.4)   # full-body ground slam
			_quake(player, main)
		"spikes":
			_strike_recoil(_attack_dir, 1.2)   # rips the line open toward you
			_spikes(player, main)
		"upheaval":
			_pose_punch(Vector2(1.18, 0.84), 0.0, 0.3)   # stomps the earth awake
			if main:
				main.spawn_field(_cast_target, 3.0 * TILE, 8.0, 5.0 * dmg_scale, "earth")
		"boulder":
			var p := BoulderProjectile.new()
			p.dmg_type = "physical"
			p.body_col = Color("a8845a")
			p.core_col = Color("e8d9b0")
			p.edge_col = Color("5a4028")
			p.trail_a = Color(0.6, 0.5, 0.35, 0.8)
			p.trail_b = Color(0.3, 0.22, 0.12, 0.0)
			p.radius = 7.0
			p.global_position = global_position
			p.velocity = _attack_dir * 10.0 * TILE
			p.damage = 22.0 * dmg_scale
			get_parent().add_child(p)
			_strike_recoil(-_attack_dir, 0.9)   # the hurl rocks it backward
			if main:
				main.play_sfx("bolt", global_position, -6.0)

# Earthshatter: radial quake — shake, debris, big radial hit, an earth field
# ring left underfoot. The 0.9 s circle telegraph says: get OUT.
func _quake(player: Node2D, main: Node) -> void:
	if main:
		main.shake(9.0)
		main.play_sfx("hit", global_position, -4.0)
		for off in [Vector2.ZERO, Vector2(28, -10), Vector2(-30, 8)]:
			main.fx.debris(global_position + off)
		main.fx.dust(global_position, 2.0)   # the quake kicks a dirt curtain up
	if player and not player.dead and global_position.distance_to(
			player.global_position) <= 4.5 * TILE + player.body_radius:
		player.take_damage(30.0 * dmg_scale, (player.global_position
				- global_position).normalized())
	if main:
		main.spawn_field(global_position, 3.5 * TILE, 7.0, 5.0 * dmg_scale, "earth")

# Stone Spikes: an 8-tile spike line — debris erupts along the corridor.
func _spikes(player: Node2D, main: Node) -> void:
	var dir := _attack_dir
	if main:
		main.shake(4.0)
		for d in [2.0, 4.0, 6.0, 8.0]:
			main.fx.debris(global_position + dir * d * TILE, Color(0.55, 0.45, 0.3))
		main.play_sfx("hit", global_position, -7.0)
	if _hits_corridor(player, dir, 8.0 * TILE, 40.0):
		player.take_damage(26.0 * dmg_scale, dir)
