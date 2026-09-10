# MP — a replicated entity view (docs/tech/33). Zero gameplay logic: it renders
# a snapshot row (position + anim state + hp) with smoothing. Players, creatures
# and bolts all share this one puppet; creation data arrives once per entity in
# the snapshot manifest ("sp"), so steady-state snapshots stay compact.
class_name MpPuppet
extends Node2D

const LERP_RATE := 12.0     # exponential smoothing toward the 20 Hz snapshot pos

var target := Vector2.ZERO
var hp_frac := 1.0
var state := "idle"
var is_player_puppet := false
var sprite: AnimatedSprite2D
var _label: Label
var _fade := 1.0            # creatures missing from snapshots fade out

static func make_player(pname: String, class_id: String) -> MpPuppet:
	var p := MpPuppet.new()
	p.is_player_puppet = true
	p.sprite = AnimatedSprite2D.new()
	p.sprite.sprite_frames = ProtoSprites.hero_frames()
	p.sprite.position.y = -12.0
	p.sprite.play("idle")
	match class_id:
		"core.class.emberkin": p.sprite.self_modulate = Color(1.15, 0.9, 0.8)
		"core.class.frostbinder": p.sprite.self_modulate = Color(0.85, 0.95, 1.15)
	p.add_child(p.sprite)
	p._label = Label.new()
	p._label.text = pname
	p._label.position = Vector2(-24, -34)
	p._label.add_theme_font_size_override("font_size", 8)
	p._label.modulate = Color("7fd8ff")
	p.add_child(p._label)
	return p

static func make_creature(m: Dictionary) -> MpPuppet:
	var p := MpPuppet.new()
	p.sprite = AnimatedSprite2D.new()
	var frames := ProtoBundleArt.frames_for(str(m.get("b", "")))
	if frames == null:
		frames = ProtoSprites.stalker_frames()
	else:
		ProtoBundleArt.ensure_animations(frames, ["idle", "walk", "lunge"])
	p.sprite.sprite_frames = frames
	p.sprite.self_modulate = Color(str(m.get("t", "ffffff")))
	var sc: float = float(m.get("sc", 1.0))
	p.sprite.scale = Vector2(sc, sc)
	p.sprite.position.y = -6.0 * sc
	p.sprite.play("idle")
	p.add_child(p.sprite)
	var nm := str(m.get("n", ""))
	if nm != "":
		p._label = Label.new()
		p._label.text = nm
		p._label.position = Vector2(-20, -26 * sc)
		p._label.add_theme_font_size_override("font_size", 8)
		p._label.modulate = Color("ffb347") if bool(m.get("el", false)) else Color(1, 1, 1, 0.7)
		p.add_child(p._label)
	return p

func apply_row(pos: Vector2, hp: float, st: String) -> void:
	target = pos
	hp_frac = hp
	state = st
	_fade = 1.0
	modulate.a = 1.0

func mark_stale(delta: float) -> bool:
	# missing from snapshots: the corpse dissolve, then gone
	_fade -= delta * 2.5
	modulate.a = maxf(_fade, 0.0)
	return _fade <= 0.0

func _process(delta: float) -> void:
	global_position = global_position.lerp(target, 1.0 - exp(-LERP_RATE * delta))
	if sprite == null:
		return
	var anim := "idle"
	if state == "windup" or state == "recover":
		anim = "lunge"
	elif global_position.distance_to(target) > 2.0:
		anim = "walk"
	if is_player_puppet and state != "":
		anim = state   # player rows carry the real animation name
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	queue_redraw()

func _draw() -> void:
	if is_player_puppet or hp_frac >= 0.999:
		return
	var w := 16.0
	var y := -14.0
	draw_rect(Rect2(-w / 2, y, w, 2), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp_frac, 0, 1), 2), Color("c94f4f"))
