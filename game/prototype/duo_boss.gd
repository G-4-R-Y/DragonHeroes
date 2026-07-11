# PROTOTYPE HARNESS — Legendary duo base (canon §4): Legendary creatures may
# hunt in coordinated duos whose kits combine into FIELD COMBOS — here the Pyre
# Sovereign's fire fields fusing with the Terravore Colossus's earth fields into
# lava (the Duologue, main.gd spawn_field + registries/fields.json combo table).
# This base owns the shared plumbing: skill cooldowns, cast state, telegraph
# helpers, the duo aggro link (wake one, wake both) and the survivor's
# VENGEANCE enrage when its partner falls. Numbers prototype-scale (proposal);
# content truth: content/core/creatures/{pyre_sovereign,terravore_colossus}.json.
class_name ProtoDuoBoss
extends ProtoCreature

const Telegraph := preload("res://prototype/telegraph.gd")

var partner: ProtoDuoBoss = null
var display_name := "LEGENDARY"
var bar_color := Color("ff7a33")

var _skill_cd := {}
var _cd_scale := 1.0
var _enraged := false
var _pending := ""
var _cast_target := Vector2.ZERO
var _aggro_cried := false

func _ready() -> void:
	snare_chance = 0.0
	stone_chance = 0.0
	capturable = false   # Legendaries are certainly not in the capture pool
	elite = true         # Elite+ loot path: rarity boost + rune pool
	item_chance = 1.0
	super._ready()

# Boss power scaling (task 3, proposal): hp 6%/level, damage 3%/level at spawn.
func _power_rates() -> Vector2:
	return Vector2(0.06, 0.03)

func _physics_process(delta: float) -> void:
	for k in _skill_cd:
		_skill_cd[k] = maxf(_skill_cd[k] - delta, 0.0)
	super._physics_process(delta)
	if dead:
		return
	# Duo aggro link: they hunt as one — waking either wakes both (canon §4).
	if _state != "idle" and partner != null and is_instance_valid(partner) \
			and not partner.dead and partner._state == "idle":
		partner._state = "chase"
	if not _aggro_cried and _state != "idle":
		_aggro_cried = true
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.play_sfx("boss_screech", global_position, -6.0)

# The survivor avenges its partner: faster casts, harder hits (proposal).
func avenge() -> void:
	if dead or _enraged:
		return
	_enraged = true
	_cd_scale = 0.7
	move_speed *= 1.15
	damage *= 1.2
	sprite.self_modulate = _base_tint * Color(1.5, 0.72, 0.72)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.damage_number(global_position + Vector2(0, -34), 0, Color("ff6a4a"),
				"VENGEANCE!")
		main.play_sfx("boss_screech", global_position, -4.0)

func _begin_cast(skill: String, player: Node2D, windup: float) -> void:
	_pending = skill
	_state = "windup"
	_timer = windup
	threat = true
	_attack_dir = (player.global_position - global_position).normalized()
	_cast_target = player.global_position
	_flash = 0.6
	sprite.flip_h = _attack_dir.x < 0.0
	sprite.play("lunge")
	sprite.frame = 0

func _telegraph_circle(at: Vector2, radius: float, dur: float,
		col := Color(1.0, 0.55, 0.15, 0.35)) -> void:
	var t := Telegraph.new()
	t.kind = Telegraph.Kind.CIRCLE
	t.radius = radius
	t.duration = dur
	t.color = col
	t.global_position = at
	get_parent().add_child(t)

func _telegraph_line(to: Vector2, width: float, dur: float,
		col := Color(1.0, 0.55, 0.15, 0.35)) -> void:
	var t := Telegraph.new()
	t.kind = Telegraph.Kind.LINE
	t.direction = to - global_position
	t.length = (to - global_position).length()
	t.width = width
	t.duration = dur
	t.color = col
	t.global_position = global_position
	get_parent().add_child(t)

# Corridor check shared by every line skill (dive-style segment-vs-circle).
func _hits_corridor(player: Node2D, dir: Vector2, length: float, width: float) -> bool:
	if player == null or player.dead:
		return false
	var seg := dir.normalized() * length
	var t := clampf((player.global_position - global_position).dot(seg)
			/ seg.length_squared(), 0.0, 1.0)
	return (global_position + seg * t).distance_to(player.global_position) \
			<= width * 0.5 + player.body_radius

func _die() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		# a solo hunt legendary riding a duo chassis has no partner to avenge —
		# it takes the legendary spoils path instead of the duo one
		if legendary_entry.is_empty():
			main.on_duo_boss_died(self)
		else:
			main.on_legendary_died(self)
	super._die()
