# PROTOTYPE HARNESS — the hero. Movement/dodge/cleave numbers follow canon and
# content/core (5 m/s move; Cleave: 110°, 2.2 m reach; displacement-only dodge,
# 3 charges / 1.5 s recharge each (proposal)). Q casts Shadow Rend — the bestial
# skill slot, unlocked by owning a Bestial Skill stone (numbers are proposals).
# All combat numbers now come from a REAL StatBlock (stats.gd: attributes + gear
# affixes + enchants), and socketed runes (canon §4 proposal) alter skills:
# Echoes = repeat at 40% 0.25 s later · Cinders = ignite 3/s 3 s + scorch ·
# Gale = dodge leaves a 10-damage knockback wind burst.
# Shipping path: inputs go to dh-sim (client prediction via dh-godot), docs/tech/22.
class_name ProtoPlayer
extends Node2D

const TILE := 16.0
const DODGE_CHARGES_MAX := 3

var max_hp := 100.0
var hp := 100.0
var body_radius := 8.0
var move_speed := 5.0 * TILE
var attack_damage := 25.0
var attack_reach := 2.2 * TILE
var attack_arc_deg := 110.0
var attack_cd_s := 0.4
var dead := false
var dodge_charges := DODGE_CHARGES_MAX
var dodge_recharge_s := 1.5      # (proposal) charges refill one at a time, oldest first
var crit_chance := 0.05
var crit_mult := 1.5
var phys_reduction := 0.0
var resist_pct := 0.0
var status_resist_pct := 0.0
var attack_speed_mult := 1.0     # Reaver tree (cleave_rampage)
var leech_pct := 0.0             # blood_price keystone: heal % of melee damage dealt

# Mounts (Ricardo, proposals): M rides the active mount. Walking respects
# terrain; FLYING crosses water/rock. Combat or damage dismounts.
var mounted := false
var mount_data := {}
var _mount_sprite: AnimatedSprite2D
var _fly_t := 0.0
var _slow_t := 0.0               # Chill (frost bolts): -35% move while > 0

# Shadow Rend (bestial slot, Q) — heavier umbral cleave (proposal numbers)
var rend_damage := 40.0
var rend_reach := 2.2 * TILE
var rend_arc_deg := 130.0
var rend_cd_s := 5.0

# Socketed rune effects per skill, read from Session at apply_stats time.
var _rune_cleave := ""
var _rune_rend := ""
var _rune_dodge := ""
var _skill_mult := 1.0           # Intellect scaling for rune damage (proposal)

var _attack_cd := 0.0
var _dodge_recharge := 0.0
var _dodging := 0.0
var _dodge_dir := Vector2.ZERO
var _swing := 0.0
var _swing_dir := Vector2.RIGHT
var _rend_cd := 0.0
var _rend_swing := 0.0
var _rend_dir := Vector2.RIGHT
var _echo_t := 0.0               # Rune of Echoes: pending repeat
var _echo_skill := ""
var _echo_dir := Vector2.RIGHT
var _gale_t := 0.0               # Rune of the Gale: burst draw timer
var _gale_pos := Vector2.ZERO
var _flash := 0.0
var _knockback := Vector2.ZERO
var _stats_applied := false
var sprite: AnimatedSprite2D
var _shadow: Sprite2D

func _ready() -> void:
	add_to_group("player")
	_shadow = Sprite2D.new()
	_shadow.texture = ProtoSprites.shadow_tex(14, 5)
	_shadow.position.y = -1.0
	add_child(_shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ProtoSprites.hero_frames()
	sprite.position.y = -12.0
	sprite.play("idle")
	add_child(sprite)
	apply_stats()

# Reads the real StatBlock (attributes + gear + enchants) and the rune sockets.
# Called at hunt start and again on every equip/allocate/socket change.
func apply_stats() -> void:
	var s := ProtoStats.compute(Session)
	max_hp = s.max_hp
	hp = max_hp if not _stats_applied else minf(hp, max_hp)
	_stats_applied = true
	attack_damage = s.melee_damage
	rend_damage = s.rend_damage
	move_speed = 5.0 * TILE * s.move_speed_mult
	dodge_recharge_s = s.dodge_recharge_s
	crit_chance = s.crit_chance
	crit_mult = s.crit_mult
	attack_speed_mult = s.attack_speed_mult
	attack_cd_s = 0.4 / maxf(attack_speed_mult, 0.1)
	leech_pct = s.leech_pct
	phys_reduction = s.phys_reduction
	resist_pct = s.resist_pct
	status_resist_pct = s.status_resist_pct
	_skill_mult = s.skill_damage_mult
	_rune_cleave = Session.rune_effect("cleave")
	_rune_rend = Session.rune_effect("rend")
	_rune_dodge = Session.rune_effect("dodge")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_rend_cd = maxf(_rend_cd - delta, 0.0)
	_swing = maxf(_swing - delta * 6.0, 0.0)
	_rend_swing = maxf(_rend_swing - delta * 5.0, 0.0)
	_gale_t = maxf(_gale_t - delta * 4.0, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	var base_tint := Color(1, 1, 1) if _slow_t <= 0.0 else Color(0.72, 0.9, 1.2)
	sprite.modulate = base_tint.lerp(Color(3, 1.5, 1.5), _flash)
	if mounted and is_instance_valid(_mount_sprite):   # saddle bob (flying floats)
		_fly_t += delta
		var flying: bool = str(mount_data.get("kind", "")) == "fly"
		var bob := (sin(_fly_t * 5.0) * 2.0) if flying else 0.0
		_mount_sprite.position.y = (-14.0 if flying else -8.0) + bob
		sprite.position.y = (-27.0 if flying else -22.0) + bob
	# dodge charges refill one at a time, oldest first
	if dodge_charges < DODGE_CHARGES_MAX:
		_dodge_recharge -= delta
		if _dodge_recharge <= 0.0:
			dodge_charges += 1
			_dodge_recharge = dodge_recharge_s
	# Rune of Echoes: the socketed skill repeats at 40% damage 0.25 s later
	if _echo_t > 0.0:
		_echo_t -= delta
		if _echo_t <= 0.0:
			_fire_echo()

	var step := Vector2.ZERO
	if _dodging > 0.0:
		_dodging -= delta
		step = _dodge_dir * (4.0 * TILE / 0.12) * delta
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd := move_speed * (0.65 if _slow_t > 0.0 else 1.0)
		if mounted:
			spd *= float(mount_data.get("speed_mult", 1.0))
		step = input * spd * delta
		if mounted and (Input.is_action_just_pressed("attack")
				or Input.is_action_just_pressed("dodge")
				or Input.is_action_just_pressed("bestial")):
			_dismount()   # no combat from the saddle — dismount first (proposal)
		if not mounted and Input.is_action_just_pressed("dodge") and dodge_charges > 0:
			if dodge_charges == DODGE_CHARGES_MAX:
				_dodge_recharge = dodge_recharge_s   # first spend starts the refill clock
			dodge_charges -= 1
			_dodge_dir = input if input.length() > 0.1 \
					else (get_global_mouse_position() - global_position).normalized()
			_dodging = 0.12
			var main := get_tree().get_first_node_in_group("main")
			if main:
				main.play_sfx("swing", global_position, -16.0)   # soft whoosh
				main.fx.burst(global_position, {"amount": 8, "lifetime": 0.28,
						"direction": -_dodge_dir, "spread": 24.0, "v_min": 60.0,
						"v_max": 150.0, "gravity": Vector2.ZERO, "s_min": 0.6,
						"s_max": 1.4, "color": Color(0.55, 0.9, 1.0, 0.75)})
			if _rune_dodge == "rune_of_the_gale":
				_wind_burst(main)
		if not mounted and Input.is_action_pressed("attack") and _attack_cd <= 0.0:
			_attack()
		if not mounted and Input.is_action_just_pressed("bestial") and _rend_cd <= 0.0:
			var main := get_tree().get_first_node_in_group("main")
			if main and main.stones >= 1:   # owning a stone unlocks the bestial slot
				_shadow_rend(main)
	step += _knockback * delta * 8.0
	_knockback = _knockback.lerp(Vector2.ZERO, delta * 10.0)
	_try_move(step)
	_update_anim(step)
	queue_redraw()

func _update_anim(step: Vector2) -> void:
	if mounted:
		if absf(step.x) > 0.01 and is_instance_valid(_mount_sprite):
			_mount_sprite.flip_h = step.x < 0.0
			sprite.flip_h = step.x < 0.0
		if sprite.animation != "idle":
			sprite.play("idle")   # the hero sits; the mount does the moving
		return
	if sprite.animation == "attack" and sprite.is_playing():
		return  # let the swing finish
	if step.length() > 0.05:
		if absf(step.x) > 0.01:
			sprite.flip_h = step.x < 0.0
		if sprite.animation != "walk":
			sprite.play("walk")
	elif sprite.animation != "idle":
		sprite.play("idle")

func _try_move(step: Vector2) -> void:
	if mounted and str(mount_data.get("kind", "")) == "fly":
		global_position += step   # the sky ignores terrain
		return
	var world := get_tree().get_first_node_in_group("world")
	if world == null:
		global_position += step
		return
	var target := global_position + step
	if world.is_walkable(target):
		global_position = target
	elif world.is_walkable(Vector2(target.x, global_position.y)):
		global_position.x = target.x
	elif world.is_walkable(Vector2(global_position.x, target.y)):
		global_position.y = target.y

# Shared arc strike: rolls crit per swing, applies the Cinders ignite when the
# skill carries that rune. Returns true if anything was hit.
func _arc_hit(dir: Vector2, reach: float, arc_deg: float, dmg: float,
		spark: Color, rune: String, allow_crit := true) -> bool:
	var cos_half := cos(deg_to_rad(arc_deg * 0.5))
	var main := get_tree().get_first_node_in_group("main")
	var crit := allow_crit and randf() < crit_chance
	if crit:
		dmg *= crit_mult
	var hit_any := false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= reach + c.body_radius \
				and to_c.normalized().dot(dir) >= cos_half:
			c.take_damage(dmg, dir, spark)
			hit_any = true
			if crit and main:
				main.damage_number(c.global_position + Vector2(0, -30), 0,
						Color("ffd166"), "CRIT!")
			if rune == "rune_of_cinders":   # ignite: 3 dmg/s for 3 s + scorch
				c.ignite(3.0 * _skill_mult, 3.0)
				if main:
					main.spawn_scorch(c.global_position)
	if hit_any and leech_pct > 0.0 and not dead:   # blood_price: melee leeches
		hp = minf(hp + dmg * leech_pct, max_hp)
		if main:
			main.refresh_hud()
	return hit_any

func _attack() -> void:
	_attack_cd = attack_cd_s
	_swing = 1.0
	_swing_dir = (get_global_mouse_position() - global_position).normalized()
	if _swing_dir.length() < 0.1:
		_swing_dir = Vector2.RIGHT
	sprite.flip_h = _swing_dir.x < 0.0
	sprite.play("attack")
	sprite.frame = 0
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.play_sfx("swing", global_position, -10.0)
	var hit_any := _arc_hit(_swing_dir, attack_reach, attack_arc_deg,
			attack_damage, Color("cfd6ff"), _rune_cleave)
	if _rune_cleave == "rune_of_echoes":
		_echo_t = 0.25
		_echo_skill = "cleave"
		_echo_dir = _swing_dir
	if hit_any and main:
		main.hitstop()
		main.shake(2.0)

# Shadow Rend — the bestial skill slot (Q): heavier umbral cleave, violet flash.
func _shadow_rend(main: Node) -> void:
	_rend_cd = rend_cd_s
	_rend_swing = 1.0
	_rend_dir = (get_global_mouse_position() - global_position).normalized()
	if _rend_dir.length() < 0.1:
		_rend_dir = Vector2.RIGHT
	sprite.flip_h = _rend_dir.x < 0.0
	sprite.play("attack")
	sprite.frame = 0
	main.play_sfx("swing", global_position, -4.0)
	main.fx.explosion(global_position, Color(0.62, 0.38, 1.0))   # umbral nova
	var hit_any := _arc_hit(_rend_dir, rend_reach, rend_arc_deg,
			rend_damage, Color("b06cff"), _rune_rend)   # violet hit sparks
	if _rune_rend == "rune_of_echoes":
		_echo_t = 0.25
		_echo_skill = "rend"
		_echo_dir = _rend_dir
	if hit_any:
		main.hitstop()
		main.shake(3.0)

# ---- mounts (M) -------------------------------------------------------------------

func toggle_mount() -> void:
	if dead:
		return
	if mounted:
		_dismount()
		return
	var m: Dictionary = Session.active_mount_data()
	var main := get_tree().get_first_node_in_group("main")
	if m.is_empty():
		if main:
			main.damage_number(global_position + Vector2(0, -24), 0,
					Color(0.7, 0.9, 1.0, 0.9),
					"no mount — the VENDOR sells one; the Matriarch guards a flying one")
		return
	mounted = true
	mount_data = m
	_fly_t = 0.0
	var flying: bool = str(m.get("kind", "")) == "fly"
	_mount_sprite = AnimatedSprite2D.new()
	_mount_sprite.sprite_frames = ProtoSprites.boss_frames() if flying \
			else ProtoSprites.stalker_frames()
	_mount_sprite.scale = Vector2.ONE * (0.5 if flying else 1.2)
	_mount_sprite.modulate = Color(str(m.get("tint", "ffffff")))
	add_child(_mount_sprite)
	move_child(_mount_sprite, 1)   # between shadow and hero — the hero rides on top
	_mount_sprite.play("fly" if flying else "walk")
	if main:
		main.play_ui("capture", -14.0)

# Flying mounts must land on walkable ground — unless forced (damage knocks you
# out of the sky and you tumble to the nearest solid tile).
func _dismount(force := false) -> void:
	if not mounted:
		return
	var world := get_tree().get_first_node_in_group("world")
	if str(mount_data.get("kind", "")) == "fly" and world \
			and not world.is_walkable(global_position):
		if not force:
			var main := get_tree().get_first_node_in_group("main")
			if main:
				main.damage_number(global_position + Vector2(0, -24), 0,
						Color(0.7, 0.9, 1.0, 0.9), "find solid ground to land")
			return
		global_position = world.random_walkable_in_ring(global_position, 0.0, 6.0 * TILE)
	mounted = false
	mount_data = {}
	if is_instance_valid(_mount_sprite):
		_mount_sprite.queue_free()
	sprite.position.y = -12.0

# Chill (frost wisp bolts, effects registry): -35% move while active.
func apply_slow(duration: float) -> void:
	_slow_t = maxf(_slow_t, duration)

# Rune of Echoes payoff: re-strike the same arc at 40% damage (no crit).
func _fire_echo() -> void:
	if dead:
		return
	if _echo_skill == "rend":
		_rend_swing = 0.6
		_arc_hit(_echo_dir, rend_reach, rend_arc_deg, rend_damage * 0.4,
				Color(0.6, 0.4, 0.85, 0.8), _rune_rend, false)
	else:
		_swing = 0.6
		_arc_hit(_echo_dir, attack_reach, attack_arc_deg, attack_damage * 0.4,
				Color(0.75, 0.8, 0.9, 0.8), _rune_cleave, false)
	_echo_skill = ""

# Rune of the Gale: the dodge leaves a wind burst at the launch point —
# 10 knockback damage (proposal) to everything within 1.5 m.
func _wind_burst(main: Node) -> void:
	_gale_t = 1.0
	_gale_pos = global_position
	if main:
		main.play_sfx("swing", global_position, -6.0)
		main.fx.tornado(global_position)
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= 1.5 * TILE + c.body_radius:
			var dir := to_c.normalized() if to_c.length() > 0.1 else Vector2.RIGHT
			c.take_damage(10.0 * _skill_mult, dir, Color("baf3ff"))
			c.shove(dir, 14.0)

func knockback(vec: Vector2) -> void:
	_knockback = vec

# dmg_type: "physical" (armor mitigates) | "fire"/"umbral"/... (resist mitigates)
# | "status" (field/DoT ticks — status resist mitigates, proposal).
func take_damage(dmg: float, _from_dir: Vector2, dmg_type := "physical") -> void:
	if dead or _dodging > 0.0:
		return  # dodging displaces you out of harm — no i-frames, position is the defense
	if mounted:
		_dismount(true)   # knocked out of the saddle
	match dmg_type:
		"physical":
			dmg *= 1.0 - phys_reduction
		"status":
			dmg *= (1.0 - resist_pct) * (1.0 - status_resist_pct)
		_:
			dmg *= 1.0 - resist_pct
	hp -= dmg
	_flash = 1.0
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.damage_number(global_position + Vector2(0, -20), dmg, Color("ff8a7a"))
		main.play_sfx("player_hurt", global_position, -8.0)
		main.shake(4.0)
		main.refresh_hud()
	if hp <= 0.0:
		dead = true
		visible = false
		if main:
			main.on_player_death()

func respawn(at: Vector2) -> void:
	if mounted:
		_dismount(true)
	global_position = at
	hp = max_hp
	dead = false
	visible = true
	dodge_charges = DODGE_CHARGES_MAX
	_knockback = Vector2.ZERO
	sprite.play("idle")

# HUD gauge feeds (main.gd _update_gauges): fill fraction of the currently
# refilling dodge charge and of the Shadow Rend cooldown, both 0..1.
func dodge_recharge_progress() -> float:
	if dodge_charges >= DODGE_CHARGES_MAX:
		return 1.0
	return clampf(1.0 - _dodge_recharge / dodge_recharge_s, 0.0, 1.0)

func rend_progress() -> float:
	return clampf(1.0 - _rend_cd / rend_cd_s, 0.0, 1.0)

func _draw() -> void:
	if _swing > 0.0:
		var ang := _swing_dir.angle()
		var half := deg_to_rad(attack_arc_deg * 0.5)
		draw_arc(Vector2(0, -body_radius), attack_reach, ang - half, ang + half, 24,
				Color(0.9, 1.0, 1.0, _swing * 0.8), 3.0)
	if _rend_swing > 0.0:   # Shadow Rend: heavier violet arc
		var rang := _rend_dir.angle()
		var rhalf := deg_to_rad(rend_arc_deg * 0.5)
		draw_arc(Vector2(0, -body_radius), rend_reach, rang - rhalf, rang + rhalf, 26,
				Color(0.72, 0.45, 1.0, _rend_swing * 0.85), 4.0)
		draw_arc(Vector2(0, -body_radius), rend_reach * 0.7, rang - rhalf, rang + rhalf, 20,
				Color(0.5, 0.3, 0.8, _rend_swing * 0.5), 2.0)
	if _gale_t > 0.0:   # Rune of the Gale: expanding wind ring at the launch point
		var at := _gale_pos - global_position
		var r := 1.5 * TILE * (1.4 - _gale_t * 0.4)
		draw_arc(at, r, 0, TAU, 24, Color(0.73, 0.95, 1.0, _gale_t * 0.7), 2.0)
		draw_arc(at, r * 0.6, 0, TAU, 18, Color(0.85, 1.0, 1.0, _gale_t * 0.4), 1.5)
