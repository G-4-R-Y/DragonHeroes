# PROTOTYPE HARNESS — the Emberwing Matriarch: the boss canon made playable.
# Elite tier = >=5 signature skills composing one learnable strategy (canon §4):
#   ranged pokes (Ember Bolt) into dive commitment (Talon Dive) you punish,
#   Wing Gust to break melee pressure, Ember Screech enrage at 60%,
#   Magma Breath fire fields at 30% (the elemental field system's first taste).
# Kit mirrors content/core/creatures/emberwing_matriarch.json + boss_emberwing AI.
class_name ProtoBoss
extends ProtoCreature

const EmberProjectile := preload("res://prototype/projectile.gd")
const Telegraph := preload("res://prototype/telegraph.gd")

var display_name := "EMBERWING MATRIARCH — Elite"   # boss bar (main._update_boss_bar)
var bar_color := Color("ff7a33")

var _skill_cd := {"bolt": 0.0, "dive": 0.0, "gust": 0.0, "screech": 0.0, "breath": 0.0}
var _enraged := false
var _cd_scale := 1.0
var _dive_target := Vector2.ZERO
var _pending := ""
var _aggro_cried := false

func _ready() -> void:
	max_hp = 900.0
	damage = 22.0
	move_speed = 5.5 * TILE
	body_radius = 20.0
	aggro_range = 12.0 * TILE
	attack_reach = 2.4 * TILE
	windup_time = 0.4
	attack_cd = 1.6
	gold_min = 80
	gold_max = 260
	snare_chance = 0.0
	capturable = false   # Elites are not in the pet capture pool
	elite = true         # Elite tier: boosted loot rarity + the rune drop pool
	item_chance = 1.0    # an Elite kill always rolls real items (proposal)
	super._ready()

func _make_frames() -> SpriteFrames:
	return _bundle_or(ProtoSprites.boss_frames())

# All bosses scale power with the player (task 3, Ricardo, proposal):
# hp x(1 + 0.06*(level-1)), damage x(1 + 0.03*(level-1)), read at spawn.
func _power_rates() -> Vector2:
	return Vector2(0.06, 0.03)

func _sprite_lift() -> float:
	return 14.0  # the Matriarch hovers a little above her shadow

func _shadow_dims() -> Vector2i:
	return Vector2i(30, 9)

func _physics_process(delta: float) -> void:
	for k in _skill_cd:
		_skill_cd[k] = maxf(_skill_cd[k] - delta, 0.0)
	super._physics_process(delta)
	if not _aggro_cried and not dead and _state != "idle":
		_aggro_cried = true
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.play_sfx("boss_screech", global_position, -6.0)

func _chase(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	# Utility-style selection, mirroring core.ai.boss_emberwing's scorers.
	if hp <= max_hp * 0.6 and not _enraged and _skill_cd["screech"] <= 0.0:
		_cast("screech", player)
	elif hp <= max_hp * 0.3 and _skill_cd["breath"] <= 0.0:
		_cast("breath", player)
	elif dist < 3.0 * TILE and _skill_cd["gust"] <= 0.0:
		_cast("gust", player)
	elif dist > 3.0 * TILE and dist < 8.0 * TILE and _skill_cd["dive"] <= 0.0:
		_cast("dive", player)
	elif dist > 3.5 * TILE and _skill_cd["bolt"] <= 0.0:
		_cast("bolt", player)
	else:
		# Keep mid-range: the Matriarch is a skirmisher, not a shover.
		var ideal := 5.0 * TILE
		var dir := (player.global_position - global_position).normalized()
		if dist > ideal + TILE:
			_move(dir * move_speed * delta)
		elif dist < ideal - TILE:
			_move(-dir * move_speed * 0.7 * delta)
		else:
			_move(dir.orthogonal() * move_speed * 0.5 * delta)
	if dist <= attack_reach * 0.9 and _cd <= 0.0:
		_begin_windup((player.global_position - global_position).normalized())

func _cast(skill: String, player: Node2D) -> void:
	_pending = skill
	_state = "windup"
	threat = true
	_attack_dir = (player.global_position - global_position).normalized()
	_dive_target = player.global_position
	_flash = 0.6
	sprite.flip_h = _attack_dir.x < 0.0
	sprite.play("lunge")
	sprite.frame = 0
	match skill:
		"bolt":
			_timer = 0.17
			_skill_cd["bolt"] = 1.5 * _cd_scale
		"dive":
			_timer = 0.4
			_skill_cd["dive"] = 8.0 * _cd_scale
			_telegraph_line(_dive_target)
		"gust":
			_timer = 0.5
			_skill_cd["gust"] = 10.0 * _cd_scale
			_telegraph_circle(global_position, 5.0 * TILE, 0.5)
		"screech":
			_timer = 0.33
			_skill_cd["screech"] = 20.0
		"breath":
			_timer = 0.66
			_skill_cd["breath"] = 12.0 * _cd_scale
			_telegraph_circle(_dive_target, 4.0 * TILE, 0.66)

func _strike(player: Node2D) -> void:
	if _pending == "":
		super._strike(player)  # basic talon swipe
		return
	var skill := _pending
	_pending = ""
	_state = "recover"
	_timer = 0.35
	var main := get_tree().get_first_node_in_group("main")
	match skill:
		"bolt":
			var p := EmberProjectile.new()
			p.global_position = global_position
			p.velocity = _attack_dir * 18.0 * TILE
			p.damage = 12.0 * dmg_scale
			get_parent().add_child(p)
			if main:
				main.play_sfx("bolt", global_position, -8.0)
		"dive":
			var path := _dive_target - global_position
			if player and not player.dead:
				var seg := path
				var t := clampf((player.global_position - global_position).dot(seg) / seg.length_squared(), 0.0, 1.0)
				if (global_position + seg * t).distance_to(player.global_position) < 20.0 + player.body_radius:
					player.take_damage(20.0 * dmg_scale, path.normalized())
			global_position += path
			if main:
				main.hit_spark(global_position, Color("ff7a33"))
		"gust":
			if player and not player.dead \
					and global_position.distance_to(player.global_position) <= 5.0 * TILE:
				player.take_damage(8.0 * dmg_scale, (player.global_position - global_position).normalized())
				player.knockback((player.global_position - global_position).normalized() * 4.0 * TILE)
		"screech":
			_enraged = true
			_cd_scale = 0.7
			sprite.self_modulate = Color(1.5, 0.75, 0.75)
			if main:
				main.damage_number(global_position + Vector2(0, -30), 0, Color("ff6a4a"), "ENRAGED!")
				main.play_sfx("boss_screech", global_position, -4.0)
		"breath":
			if main:
				main.spawn_fire_field(_dive_target, 4.0 * TILE, 6.0, 6.0 * dmg_scale)

func _telegraph_circle(at: Vector2, radius: float, dur: float) -> void:
	var t := Telegraph.new()
	t.kind = Telegraph.Kind.CIRCLE
	t.radius = radius
	t.duration = dur
	t.global_position = at
	get_parent().add_child(t)

func _telegraph_line(to: Vector2) -> void:
	var t := Telegraph.new()
	t.kind = Telegraph.Kind.LINE
	t.direction = to - global_position
	t.length = (to - global_position).length()
	t.width = 44.0
	t.duration = 0.4
	t.global_position = global_position
	get_parent().add_child(t)

func _die() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		# A hunt legendary riding the dragon chassis has its own spoils
		# (main.on_legendary_died) — the Matriarch's blade/mount stay hers.
		if legendary_entry.is_empty():
			main.on_boss_died(self)
		else:
			main.on_legendary_died(self)
	super._die()
