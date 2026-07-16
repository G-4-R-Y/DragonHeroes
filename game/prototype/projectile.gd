# PROTOTYPE HARNESS — projectiles. The real path is swept-circle CCD in dh-sim
# (sim/libs/dh-math geom.hpp); this frame-stepped version is close enough at 60 FPS
# for prototype speeds.
class_name ProtoProjectile
extends Node2D

var velocity := Vector2.ZERO
var damage := 12.0
var dmg_type := "fire"   # resist-mitigated on the player (stats.gd)
var radius := 4.0
var lifetime := 3.0
var friendly := false    # player-cast (Mage bolts, Rogue knives): hits creatures
# Class-tree skill bolts: the hit routes through the caster's synergy pipeline
# (applies/bonus_vs/consumes — player.gd projectile_hit) instead of raw damage.
var skill_def := {}
var shooter: Node2D = null
# color parameters — ember by default; the wisp's umbral bolt sets violet
var body_col := Color("ff7a33")
var core_col := Color("ffd9a0")
var edge_col := Color("8a3a12")
var trail_a := Color(1.0, 0.72, 0.35, 0.9)
var trail_b := Color(0.6, 0.15, 0.05, 0.0)
# in-flight juice (transforms only — no new frames, no per-frame allocation):
# knives spin, energy bolts breathe; impacts pop a tiny pooled ring.
var spin := 0.0          # rad/s sprite spin (steel knives)
var pulse_amp := 0.08    # sine scale pulse for energy bolts (0 disables)
var impact_ring := true  # steel opts out — the knife fan would starve the pool
var _spr: Sprite2D
var _t := 0.0
var _trail_id := -1       # pooled ribbon trail (fx.trail_attach), -1 = none

func set_violet() -> void:
	dmg_type = "umbral"
	body_col = Color("9a6cff")
	core_col = Color("e6d9ff")
	edge_col = Color("4a2a8a")
	trail_a = Color(0.68, 0.5, 1.0, 0.9)
	trail_b = Color(0.25, 0.1, 0.45, 0.0)
	pulse_amp = 0.11

func set_frost() -> void:
	dmg_type = "frost"
	body_col = Color("7fd8ff")
	core_col = Color("e8fbff")
	edge_col = Color("2a5a8a")
	trail_a = Color(0.6, 0.9, 1.0, 0.9)
	trail_b = Color(0.15, 0.3, 0.5, 0.0)
	pulse_amp = 0.11

func set_arcane() -> void:   # Gloam Mage bolt
	dmg_type = "umbral"
	body_col = Color("b48cff")
	core_col = Color("f2eaff")
	edge_col = Color("5a3aa8")
	trail_a = Color(0.75, 0.6, 1.0, 0.95)
	trail_b = Color(0.3, 0.5, 0.9, 0.0)
	pulse_amp = 0.11

func set_steel() -> void:    # Veilblade knife
	dmg_type = "physical"
	radius = 3.0
	body_col = Color("cdd6dd")
	core_col = Color("ffffff")
	edge_col = Color("5a6570")
	trail_a = Color(0.8, 0.85, 0.9, 0.6)
	trail_b = Color(0.4, 0.45, 0.5, 0.0)
	spin = 24.0          # thrown steel whirls
	pulse_amp = 0.0
	impact_ring = false

func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = ProtoSprites.circle_tex(10, body_col, core_col, edge_col)
	add_child(_spr)
	_t = randf() * TAU   # desync pulses across a volley
	# Pooled ribbon trail (§2.8): one STREAK_FOLLOW ribbon per bolt, replacing the
	# per-bolt CPUParticles2D. The `life` fallback self-releases the ribbon if the
	# bolt frees without an explicit detach — no leak. P/C/B deliberately do NOT
	# attach here (would double the trail + burn a second pinned slot).
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.get("fx") != null:
		_trail_id = main.fx.trail_attach(self, {
				"color": trail_a, "width": maxf(radius * 1.1, 3.5),
				"life": lifetime + 0.3})

func _physics_process(delta: float) -> void:
	# in-flight juice: pure transform math, zero allocation (60 FPS hard rule)
	_t += delta
	if spin != 0.0:
		_spr.rotation += spin * delta
	elif pulse_amp > 0.0:
		_spr.scale = Vector2.ONE * (1.0 + sin(_t * 12.0) * pulse_amp)
	var from := global_position
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_release_trail()
		queue_free()
		return
	if friendly:   # player-cast: swept check against every living creature
		var seg_f := global_position - from
		for c in get_tree().get_nodes_in_group("creatures"):
			if c.dead:
				continue
			var t_f := 0.0
			if seg_f.length_squared() > 0.0:
				t_f = clampf((c.global_position - from).dot(seg_f) \
						/ seg_f.length_squared(), 0.0, 1.0)
			if (from + seg_f * t_f).distance_to(c.global_position) \
					<= radius + c.body_radius:
				if not skill_def.is_empty() and is_instance_valid(shooter):
					shooter.projectile_hit(c, damage, velocity.normalized(),
							skill_def, body_col)
				else:
					c.take_damage(damage, velocity.normalized(), body_col)
				_impact()
				return
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.dead:
		# Segment-vs-circle check (poor man's CCD for one frame of travel).
		var seg := global_position - from
		var t := 0.0
		if seg.length_squared() > 0.0:
			t = clampf((player.global_position - from).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest := from + seg * t
		if closest.distance_to(player.global_position) <= radius + player.body_radius:
			player.take_damage(damage, velocity.normalized(), dmg_type)
			if dmg_type == "frost":
				player.apply_slow(1.2)   # Chill: -35% move (effects registry)
			_impact()

func _impact() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.hit_spark(global_position, body_col)
		if impact_ring:   # squash-flash pop (tiny pooled ring, fx.gd)
			main.fx.impact_pop(global_position, body_col)
	_release_trail()
	queue_free()

# Detach the pooled ribbon trail on either exit path. Cheap idempotent no-op if
# never attached; the ribbon's own `life` fallback covers any path we miss.
func _release_trail() -> void:
	if _trail_id == -1:
		return
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.get("fx") != null:
		main.fx.trail_detach(_trail_id)
	_trail_id = -1
