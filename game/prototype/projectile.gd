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
# color parameters — ember by default; the wisp's umbral bolt sets violet
var body_col := Color("ff7a33")
var core_col := Color("ffd9a0")
var edge_col := Color("8a3a12")
var trail_a := Color(1.0, 0.72, 0.35, 0.9)
var trail_b := Color(0.6, 0.15, 0.05, 0.0)

func set_violet() -> void:
	dmg_type = "umbral"
	body_col = Color("9a6cff")
	core_col = Color("e6d9ff")
	edge_col = Color("4a2a8a")
	trail_a = Color(0.68, 0.5, 1.0, 0.9)
	trail_b = Color(0.25, 0.1, 0.45, 0.0)

func set_frost() -> void:
	dmg_type = "frost"
	body_col = Color("7fd8ff")
	core_col = Color("e8fbff")
	edge_col = Color("2a5a8a")
	trail_a = Color(0.6, 0.9, 1.0, 0.9)
	trail_b = Color(0.15, 0.3, 0.5, 0.0)

func _ready() -> void:
	var s := Sprite2D.new()
	s.texture = ProtoSprites.circle_tex(10, body_col, core_col, edge_col)
	add_child(s)
	# small ember trail left behind as the bolt travels
	var trail := CPUParticles2D.new()
	trail.amount = 8
	trail.lifetime = 0.3
	trail.local_coords = false
	trail.direction = Vector2(0, -1)
	trail.spread = 180.0
	trail.gravity = Vector2(0, -40)
	trail.initial_velocity_min = 2.0
	trail.initial_velocity_max = 12.0
	trail.scale_amount_min = 0.8
	trail.scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([trail_a, trail_b])
	trail.color_ramp = ramp
	add_child(trail)
	trail.emitting = true

func _physics_process(delta: float) -> void:
	var from := global_position
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
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
	queue_free()
