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
	# R57: even the Duologue can be bonded — but it is the hardest capture in
	# the game (10% HP gate, a roll scaled to 0.15) and the smallest share of
	# the parent's power. design/13 §7.1's "Legendary tier never" is overridden
	# by Ricardo's demand; the tier gate there is updated in the same change.
	# capturable = false # pre-R57: legendaries were out of the capture pool
	drops_essence = false      # essence drop set unchanged (see creature.gd)
	capture_hp_gate = 0.10
	capture_chance_scale = 0.15
	capture_hp_share = 0.2
	capture_dmg_share = 0.45
	capture_scale = 0.5
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
	_pose_pulse(1.3, 0.45)   # grief becomes fury — the body swells with it
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.telegraphs.beams(global_position, Vector2.RIGHT,
				{"count": 12, "spread": TAU, "converge_dist": 6.0 * TILE, "dur": 0.6})
		main.fx.aura(self, Color(1.0, 0.28, 0.16), {"radius": body_radius + 10.0, "dur": 3.0})
		main.damage_number(global_position + Vector2(0, -34), 0, Color("ff6a4a"),
				"VENGEANCE!")
		main.play_sfx("boss_screech", global_position, -4.0)
		main.shake(3.0)
		main.post.pulse(0.7)

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
	_anticipate(_attack_dir, windup)   # legendary tells read in the body too

func _telegraph_circle(at: Vector2, radius: float, dur: float,
		col := Color(1.0, 0.55, 0.15, 0.35)) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.telegraphs.ring(at, radius, dur, Color(col.r, col.g, col.b, 1.0))

func _telegraph_line(to: Vector2, width: float, dur: float,
		col := Color(1.0, 0.55, 0.15, 0.35)) -> void:
	# Dramatic line tells (Cinder Breath, Stone Spikes) escalate to red converging
	# BEAMS (spec §3): wedges advance inward along the corridor onto the strike point.
	# width/col kept for caller compatibility; BEAMS render in the red danger family.
	var main := get_tree().get_first_node_in_group("main")
	if main == null:
		return
	var path := to - global_position
	main.telegraphs.beams(to, (-path).normalized(), {"count": 5, "spread": 1.0,
			"converge_dist": clampf(path.length() * 0.55, 90.0, 220.0), "dur": dur})

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
