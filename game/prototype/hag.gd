# PROTOTYPE HARNESS — the Fenwitch Hag: Elite mid-boss (canon §4, >=5 signature
# skills forming one learnable strategy). She is a KITING WITCH: Hex Bolt volleys
# from range, Void Step blink when you close (the blink recovery is your punish
# window), Wisplings to screen her, Creeping Mire slow-fields under your feet,
# and a Shrieking Curse enrage below 40% — faster casts, same tells.
# Kit mirrors content/core/creatures/fenwitch_hag.json (data snapshot in
# prototype/data/fenwitch_hag.json); all numbers prototype-scale (proposal).
class_name ProtoHag
extends ProtoCreature

const HexProjectile := preload("res://prototype/projectile.gd")
const Telegraph := preload("res://prototype/telegraph.gd")

const MIRE_COLOR := Color(0.5, 0.85, 0.3, 0.35)

var display_name := "FENWITCH HAG — Elite"
var bar_color := Color("a06ce0")

var _skill_cd := {"hex": 2.0, "blink": 3.0, "summon": 4.0, "mire": 6.0}
var _cursed := false
var _cd_scale := 1.0
var _pending := ""
var _cast_target := Vector2.ZERO
var _wisplings: Array = []
var _aggro_cried := false

func _ready() -> void:
	max_hp = 520.0             # (proposal) mid boss: harder than pack elites,
	damage = 14.0              # softer than the Matriarch (900) at pack 13
	move_speed = 4.2 * TILE
	body_radius = 12.0
	aggro_range = 11.0 * TILE
	attack_reach = 1.8 * TILE  # claw scratch — she'd rather blink away
	windup_time = 0.4
	attack_cd = 1.8
	gold_min = 50
	gold_max = 160
	snare_chance = 0.0
	stone_chance = 0.0
	capturable = false         # Elites are not in the pet capture pool
	elite = true               # Elite tier: boosted loot rarity + rune pool
	item_chance = 1.0          # an Elite kill always rolls real items (proposal)
	_base_tint = Color(0.72, 1.0, 0.78)   # swamp-green cast over the wisp rig
	_scale = 1.5
	super._ready()

func _make_frames() -> SpriteFrames:
	return ProtoSprites.wisp_frames()   # spirit rig stand-in until the hag rig lands

func _sprite_lift() -> float:
	return 12.0

func _shadow_dims() -> Vector2i:
	return Vector2i(14, 5)

func _physics_process(delta: float) -> void:
	for k in _skill_cd:
		_skill_cd[k] = maxf(_skill_cd[k] - delta, 0.0)
	_wisplings = _wisplings.filter(
			func(w): return is_instance_valid(w) and not w.dead)
	super._physics_process(delta)
	if not _aggro_cried and not dead and _state != "idle":
		_aggro_cried = true
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.play_sfx("boss_screech", global_position, -10.0)

# Utility-style selection, mirroring core.ai.boss_emberwing's scorer shape:
# curse (once, <40%) > blink (pressured) > wisplings > mire > hex volley > kite.
func _chase(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	if hp <= max_hp * 0.4 and not _cursed:
		_cast("curse", player)
	elif dist < 2.6 * TILE and _skill_cd["blink"] <= 0.0:
		_cast("blink", player)
	elif _wisplings.size() < 2 and _skill_cd["summon"] <= 0.0:
		_cast("summon", player)
	elif dist < 8.5 * TILE and _skill_cd["mire"] <= 0.0:
		_cast("mire", player)
	elif dist >= 2.5 * TILE and dist <= 9.5 * TILE and _skill_cd["hex"] <= 0.0:
		_cast("hex", player)
	else:
		# Kite the pocket like her wisps do: 5.5 tiles is home.
		var ideal := 5.5 * TILE
		var dir := (player.global_position - global_position).normalized()
		if dist > ideal + TILE:
			_move(dir * _speed() * delta)
		elif dist < ideal - TILE:
			_move(-dir * _speed() * 0.85 * delta)
		else:
			_move(dir.orthogonal() * _speed() * 0.5 * delta)
	if dist <= attack_reach * 0.9 and _cd <= 0.0:
		_begin_windup((player.global_position - global_position).normalized())

func _cast(skill: String, player: Node2D) -> void:
	_pending = skill
	_state = "windup"
	threat = true
	_attack_dir = (player.global_position - global_position).normalized()
	_cast_target = player.global_position
	_flash = 0.6
	sprite.flip_h = _attack_dir.x < 0.0
	sprite.play("lunge")
	sprite.frame = 0
	match skill:
		"hex":
			_timer = 0.35
			_skill_cd["hex"] = 4.0 * _cd_scale
		"blink":
			_timer = 0.25
			_skill_cd["blink"] = 7.0 * _cd_scale
		"summon":
			_timer = 0.6
			_skill_cd["summon"] = 12.0 * _cd_scale
		"mire":
			_timer = 0.5
			_skill_cd["mire"] = 10.0 * _cd_scale
			var tg := Telegraph.new()
			tg.kind = Telegraph.Kind.CIRCLE
			tg.radius = 3.5 * TILE
			tg.duration = 0.5
			tg.color = MIRE_COLOR
			tg.global_position = _cast_target
			get_parent().add_child(tg)
		"curse":
			_timer = 0.4

func _strike(player: Node2D) -> void:
	if _pending == "":
		super._strike(player)   # claw scratch when cornered
		return
	var skill := _pending
	_pending = ""
	_state = "recover"
	_timer = 0.5
	var main := get_tree().get_first_node_in_group("main")
	match skill:
		"hex":
			_timer = 0.9   # the volley's recovery IS the punish window
			for i in 3:
				var p := HexProjectile.new()
				p.set_violet()
				p.global_position = global_position
				p.velocity = _attack_dir.rotated(deg_to_rad(-14.0 + 14.0 * i)) \
						* 13.0 * TILE
				p.damage = 9.0
				get_parent().add_child(p)
			if main:
				main.play_sfx("bolt", global_position, -8.0)
		"blink":
			_blink(player, main)
		"summon":
			_summon(main)
		"mire":
			if main:
				main.spawn_field(_cast_target, 3.5 * TILE, 7.0, 3.0, "mire")
		"curse":
			_cursed = true
			_cd_scale = 0.65
			attack_cd *= 0.75
			sprite.self_modulate = _base_tint * Color(1.4, 0.75, 1.1)
			if main:
				main.damage_number(global_position + Vector2(0, -30), 0,
						Color("cf9dff"), "CURSED SHRIEK!")
				main.play_sfx("boss_screech", global_position, -4.0)

# Void Step, hag-flavored: 4 m hop away from the hunter (walkability-checked),
# violet bursts at both ends. The landing recovery is punishable.
func _blink(player: Node2D, main: Node) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var away := -_attack_dir if player != null else Vector2.from_angle(randf() * TAU)
	var dest := global_position + away.rotated(randf_range(-0.5, 0.5)) * 4.0 * TILE
	if world and not world.is_walkable(dest):
		dest = world.random_walkable_in_ring(global_position, 3.0 * TILE, 4.5 * TILE)
	if main:
		main.fx.burst(global_position, {"amount": 10, "lifetime": 0.3, "v_min": 40.0,
				"v_max": 120.0, "s_min": 0.8, "s_max": 1.8,
				"color": Color(0.65, 0.45, 1.0, 0.8)})
	global_position = dest
	if main:
		main.fx.burst(global_position, {"amount": 10, "lifetime": 0.3, "v_min": 40.0,
				"v_max": 120.0, "s_min": 0.8, "s_max": 1.8,
				"color": Color(0.65, 0.45, 1.0, 0.8)})
		main.play_sfx("swing", global_position, -10.0)

func _summon(main: Node) -> void:
	var world := get_tree().get_first_node_in_group("world")
	while _wisplings.size() < 2:
		var w := Wispling.new()
		w.global_position = world.random_walkable_in_ring(
				global_position, 1.0 * TILE, 2.0 * TILE) if world \
				else global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
		w.pack_anchor = pack_anchor
		get_parent().add_child(w)
		_wisplings.append(w)
		if main:
			main.fx.burst(w.global_position, {"amount": 8, "lifetime": 0.35,
					"v_min": 30.0, "v_max": 90.0, "s_min": 0.7, "s_max": 1.4,
					"color": Color(0.55, 0.95, 0.6, 0.75)})
	if main:
		main.play_sfx("boss_screech", global_position, -14.0)

func _die() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.on_hag_died(self)
	super._die()

# --- Wispling: weak, short-lived summon (wispling_call.json). Expires without
# loot or kill credit; killing one pays a token of gold at most.
class Wispling:
	extends ProtoWisp

	var _life := 12.0   # summon_lifetime_s (proposal)

	func _ready() -> void:
		element = "umbral"
		_base_tint = Color(0.7, 1.0, 0.75)
		_scale = 0.7
		super._ready()
		max_hp = 26.0
		hp = max_hp
		damage = 5.0
		move_speed = 4.2 * TILE
		attack_cd = 2.8
		aggro_range = 14.0 * TILE   # summons engage immediately
		gold_min = 1
		gold_max = 3
		stone_chance = 0.0
		item_chance = 0.0
		_state = "chase"

	func _physics_process(delta: float) -> void:
		if not dead:
			_life -= delta
			if _life <= 0.0:
				dead = true   # expire quietly: no loot, no kill credit
				var main := get_tree().get_first_node_in_group("main")
				if main:
					main.fx.burst(global_position, {"amount": 6, "lifetime": 0.3,
							"v_min": 20.0, "v_max": 70.0, "s_min": 0.6, "s_max": 1.2,
							"color": Color(0.55, 0.95, 0.6, 0.6)})
				queue_free()
				return
		super._physics_process(delta)
