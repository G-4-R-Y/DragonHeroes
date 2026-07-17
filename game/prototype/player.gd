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
var whirl_cd_s := 4.0            # Whirlwind (E): full-circle strike (proposal)
var _whirl_cd := 0.0
var _whirl_t := 0.0
var _class_fx := ""              # Emberkin ignite / Frostbinder chill on hit
var _kit := "melee"              # melee | mage | rogue — LMB and E reshape

# Class skill tree (skill_trees.json): keys 1-4 cast the assigned actives via
# ONE generic executor (use_skill) — skills are DATA, never per-skill methods.
var skill_cds := {}              # node id -> seconds left
var cdr_mult := 1.0              # tree cooldown_reduction passives (stats.gd)
var charge_stacks := 0           # class charge: Veilblade Combo / Mage Attunement
var charge_name := ""            # "" = this class has no charge mechanic
var charge_max := 5
var charge_per_stack := 0.25
var _buffs: Array = []           # {until, mults:{attack_speed/move/damage/armor/leech}}

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
# Juice pass: ONE pose tween (killed on re-trigger, never stacked) drives swing
# lean/snap-back, cast pulses, dodge stretch and mount squash — transforms only,
# GenForge frames untouched. Every tween's final keys ARE the base pose
# (rotation 0, scale ONE, position (0, SPRITE_BASE_Y)); no per-frame allocation.
const SPRITE_BASE_Y := -12.0
var _anim_tw: Tween
var _walk_t := 0.0               # walk-bob phase (pure math, no nodes)

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
	# soft warm pool under the hero (lights.gd) — the cheapest "sits IN the
	# world" read there is. Deferred: main is still assembling fx at class cast.
	call_deferred("_attach_ground_glow")
	match str(Session.class_id):   # class cast (full class art: design/10/17)
		"core.class.emberkin":
			sprite.self_modulate = Color(1.15, 0.9, 0.8)
		"core.class.frostbinder":
			sprite.self_modulate = Color(0.85, 0.95, 1.15)
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
	_class_fx = str(s.get("class_fx", ""))
	# class kits (proposal): the same stat block wears three different weapons
	_kit = str(s.get("class_kit", "melee"))
	attack_arc_deg = 110.0
	attack_reach = 2.2 * TILE
	whirl_cd_s = 4.0
	match _kit:
		"mage":    # Arcane Bolt caster: ranged, slower cadence, nova on E
			attack_cd_s = 0.55 / maxf(attack_speed_mult, 0.1)
			whirl_cd_s = 5.0
		"rogue":   # Swift Stab: tight arc, blinding cadence, lighter hits
			attack_damage = s.melee_damage * 0.8
			attack_cd_s = 0.25 / maxf(attack_speed_mult, 0.1)
			attack_arc_deg = 60.0
			attack_reach = 1.8 * TILE
			whirl_cd_s = 4.5
	phys_reduction = s.phys_reduction
	resist_pct = s.resist_pct
	status_resist_pct = s.status_resist_pct
	_skill_mult = s.skill_damage_mult
	cdr_mult = float(s.get("cdr_mult", 1.0))
	# class charge mechanic (Attunement/Combo) — data from skill_trees.json
	var ch: Dictionary = Session.class_charge()
	charge_name = str(ch.get("name", ""))
	charge_max = int(ch.get("max", 5))
	charge_per_stack = float(ch.get("per_stack", 0.25))
	_rune_cleave = Session.rune_effect("cleave")
	_rune_rend = Session.rune_effect("rend")
	_rune_dodge = Session.rune_effect("dodge")

func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_rend_cd = maxf(_rend_cd - delta, 0.0)
	_whirl_cd = maxf(_whirl_cd - delta, 0.0)
	_whirl_t = maxf(_whirl_t - delta * 4.0, 0.0)
	_swing = maxf(_swing - delta * 6.0, 0.0)
	_rend_swing = maxf(_rend_swing - delta * 5.0, 0.0)
	_gale_t = maxf(_gale_t - delta * 4.0, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	# class-tree skill cooldowns + timed buffs (both tiny dicts/arrays)
	for k in skill_cds:
		skill_cds[k] = maxf(float(skill_cds[k]) - delta, 0.0)
	if not _buffs.is_empty():
		var now := Time.get_ticks_msec() / 1000.0
		_buffs = _buffs.filter(func(b: Dictionary) -> bool: return now <= float(b.until))
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
		var spd := move_speed * (0.65 if _slow_t > 0.0 else 1.0) * _buff_mult("move")
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
			_dodge_fx(_dodge_dir, main)   # stretch + pooled afterimages
			if main:
				main.play_sfx("swing", global_position, -16.0)   # soft whoosh
				main.fx.burst(global_position, {"amount": 8, "lifetime": 0.28,
						"direction": -_dodge_dir, "spread": 24.0, "v_min": 60.0,
						"v_max": 150.0, "gravity": Vector2.ZERO, "s_min": 0.6,
						"s_max": 1.4, "color": Color(0.55, 0.9, 1.0, 0.75)})
				# §3: cyan dash streak along the dodge path (ghosts kept as accent)
				main.fx.ribbon_streak(global_position, global_position + _dodge_dir * 4.0 * TILE, {"color": Color(0.55, 0.9, 1.0), "width": 7, "life": 0.25})
			if _rune_dodge == "rune_of_the_gale":
				_wind_burst(main)
		if not mounted and Input.is_action_pressed("attack") and _attack_cd <= 0.0:
			_attack()
		if not mounted and Input.is_action_just_pressed("skill2") and _whirl_cd <= 0.0:
			match _kit:
				"mage":
					_frost_nova()
				"rogue":
					_fan_of_knives()
				_:
					_whirlwind()
		if not mounted and Input.is_action_just_pressed("bestial") and _rend_cd <= 0.0:
			var main := get_tree().get_first_node_in_group("main")
			if main and main.stones >= 1:   # owning a stone unlocks the bestial slot
				_shadow_rend(main)
		if not mounted:   # skill bar: 1-4 cast the assigned class-tree actives
			for i in 4:
				if Input.is_action_just_pressed("slot%d" % (i + 1)):
					_cast_slot(i)
	step += _knockback * delta * 8.0
	_knockback = _knockback.lerp(Vector2.ZERO, delta * 10.0)
	_try_move(step)
	if not mounted and _dodging <= 0.0 and step.length() > 0.05:
		_walk_t += delta   # walk-bob phase only advances while actually stepping
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
		if _pose_free():   # step feel: subtle ground-contact bob (<=1.4 px)
			sprite.position.y = SPRITE_BASE_Y - absf(sin(_walk_t * 10.0)) * 1.4
	else:
		if sprite.animation != "idle":
			sprite.play("idle")
		if _pose_free():
			sprite.position.y = SPRITE_BASE_Y

# ---- pose juice helpers (transform tweens on the ONE hero sprite) -----------------

func _pose_free() -> bool:
	return _anim_tw == null or not _anim_tw.is_valid() or not _anim_tw.is_running()

func _kill_anim_tw() -> void:
	if _anim_tw != null and _anim_tw.is_valid():
		_anim_tw.kill()
	_anim_tw = null

func _reset_pose() -> void:
	_kill_anim_tw()
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.position = Vector2(0.0, SPRITE_BASE_Y)

# Melee swing: snap INTO a directional lean + shove, spring back elastic.
func _swing_lean(dir: Vector2, strength := 1.0) -> void:
	_kill_anim_tw()
	sprite.rotation = 0.17 * strength * (1.0 if dir.x >= 0.0 else -1.0)
	sprite.scale = Vector2.ONE
	sprite.position = Vector2(0.0, SPRITE_BASE_Y) + dir * 3.0 * strength
	_anim_tw = create_tween().set_parallel(true)
	_anim_tw.tween_property(sprite, "rotation", 0.0, 0.24) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_anim_tw.tween_property(sprite, "position", Vector2(0.0, SPRITE_BASE_Y), 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Cast: brief wind-up pulse (1.0 -> 1.08 -> 1.0) + recoil kick off the release.
func _cast_pulse(aim: Vector2) -> void:
	_kill_anim_tw()
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	sprite.position = Vector2(0.0, SPRITE_BASE_Y) - aim * 2.5
	_anim_tw = create_tween().set_parallel(true)
	_anim_tw.tween_property(sprite, "scale", Vector2.ONE * 1.08, 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tw.tween_property(sprite, "scale", Vector2.ONE, 0.13).set_delay(0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tw.tween_property(sprite, "position", Vector2(0.0, SPRITE_BASE_Y), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Whirlwind: one full sprite spin riding the strike.
func _whirl_spin() -> void:
	_reset_pose()
	_anim_tw = create_tween()
	_anim_tw.tween_property(sprite, "rotation", TAU, 0.28) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim_tw.tween_callback(func() -> void: sprite.rotation = 0.0)

# Dodge: stretch along the dash + 3 pooled afterimage ghosts along the path.
func _dodge_fx(dir: Vector2, main: Node) -> void:
	_kill_anim_tw()
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	sprite.rotation = 0.0
	sprite.position = Vector2(0.0, SPRITE_BASE_Y)   # clear any interrupted lean
	sprite.scale = Vector2(1.0 + 0.3 * ax - 0.18 * ay, 1.0 + 0.3 * ay - 0.18 * ax)
	_anim_tw = create_tween().set_parallel(true)
	_anim_tw.tween_property(sprite, "scale", Vector2.ONE, 0.22).set_delay(0.05) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if main:
		for i in 3:
			_anim_tw.tween_callback(_spawn_ghost.bind(main)) \
					.set_delay(0.02 + 0.035 * i)

# Snapshot the current hero frame into the pooled ghost sprites (fx.gd).
func _spawn_ghost(main: Node) -> void:
	if dead or sprite.sprite_frames == null:
		return
	var anim := sprite.animation
	if sprite.sprite_frames.get_frame_count(anim) == 0:
		return
	main.fx.afterimage(sprite.sprite_frames.get_frame_texture(anim, sprite.frame),
			sprite.global_position, sprite.flip_h, sprite.global_scale)

# Mount/dismount: quick saddle squash (scale only — the mount owns position.y).
func _mount_squash() -> void:
	_kill_anim_tw()
	sprite.rotation = 0.0
	sprite.position.x = 0.0
	sprite.scale = Vector2(1.22, 0.78)
	_anim_tw = create_tween()
	_anim_tw.tween_property(sprite, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	dmg *= _buff_mult("damage")   # timed buffs (Blood Howl, The Long Burn, ...)
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
			if crit and main:   # vfx_lab impact: the crit star-flash pop
				main.fx.shader_burst("impact", c.global_position,
						{"size": 46.0, "color": Color(1.0, 0.86, 0.55),
						"uniforms": {"intensity": 1.5}})
			hit_any = true
			if _class_fx == "ignite" and randf() < 0.2:   # Emberkin cast
				c.ignite(2.0 * _skill_mult, 2.0)
			elif _class_fx == "chill":                    # Frostbinder cast
				c.apply_slow(1.0)
			if crit and main:
				main.damage_number(c.global_position + Vector2(0, -30), 0,
						Color("ffd166"), "CRIT!")
			if rune == "rune_of_cinders":   # ignite: 3 dmg/s for 3 s + scorch
				c.ignite(3.0 * _skill_mult, 3.0)
				if main:
					main.spawn_scorch(c.global_position)
	var lp := leech_pct + _buff_add("leech")   # blood_price + Leech Fury
	if hit_any and lp > 0.0 and not dead:
		hp = minf(hp + dmg * lp, max_hp)
		if main:
			main.refresh_hud()
	return hit_any

func _attack() -> void:
	if _kit == "mage":   # the Mage's "swing" is a ranged Arcane Bolt
		_cast_bolt()
		return
	_attack_cd = attack_cd_s / _buff_mult("attack_speed")
	_swing = 1.0
	_swing_dir = (get_global_mouse_position() - global_position).normalized()
	if _swing_dir.length() < 0.1:
		_swing_dir = Vector2.RIGHT
	sprite.flip_h = _swing_dir.x < 0.0
	sprite.play("attack")
	sprite.frame = 0
	_swing_lean(_swing_dir)   # lean into the cleave, elastic snap-back
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.play_sfx("swing", global_position, -10.0)
		main.fx.arc_slash(global_position + _swing_dir * attack_reach * 0.6,
				_swing_dir, Color(0.85, 0.92, 1.0, 0.9))
		if _kit == "rogue":   # twin steel flicks — vfx_lab slash, short + tight
			main.fx.shader_burst("slash", global_position + _swing_dir * attack_reach * 0.5,
					{"size": 60.0, "life": 0.16, "dir": _swing_dir, "color": Color(0.85, 0.92, 1.0)})
			main.fx.shader_burst("slash", global_position + _swing_dir * attack_reach * 0.5,
					{"size": 52.0, "life": 0.2, "dir": _swing_dir.rotated(0.22), "color": Color(0.8, 0.88, 1.0)})
		else:   # cleave crescent — vfx_lab slash (drawn-with-light, hi-res)
			main.fx.shader_burst("slash", global_position + _swing_dir * attack_reach * 0.55,
					{"size": 88.0, "dir": _swing_dir, "color": Color(0.85, 0.9, 1.0)})
	var hit_any := _arc_hit(_swing_dir, attack_reach, attack_arc_deg,
			attack_damage, Color("cfd6ff"), _rune_cleave)
	if _rune_cleave == "rune_of_echoes":
		_echo_t = 0.25
		_echo_skill = "cleave"
		_echo_dir = _swing_dir
	if hit_any and main:
		main.hitstop()
		main.shake(2.0)
		if _kit != "rogue":   # §3: cleave impact shockwave on connect
			main.fx.shockwave(global_position + _swing_dir * attack_reach * 0.6, Color(0.85, 0.92, 1.0, 0.9), 24.0)

func _attach_ground_glow() -> void:
	var m := get_tree().get_first_node_in_group("main")
	if m != null and m.get("fx") != null:
		# the hero's LANTERN: with the darkness model live this is the player's
		# guaranteed pool of visibility, not just a cosmetic tint
		m.fx.light_attach(self, {"radius": 46.0, "color": Color(1.0, 0.86, 0.6),
				"alpha": 0.30, "flicker": 0.12, "rate": 3.0})

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
	_swing_lean(_rend_dir, 1.35)   # the bestial cleave throws the whole body
	main.play_sfx("swing", global_position, -4.0)
	# Over the DARK world (canon §12.28) fewer layers read as MORE: vortex +
	# umbra + slash + one shockwave. The old bright-ground recipe also stacked
	# an explosion burst + a fat ring and now just blows out to white.
	main.fx.shader_burst("vortex", global_position, {"size": 150.0, "life": 0.5,
			"dir": _rend_dir, "color": Color(0.42, 0.12, 0.95)})
	# the actual DARKNESS: mix-blend umbral smoke that occludes, rims in violet
	main.fx.shader_burst("umbra", global_position + _rend_dir * rend_reach * 0.4,
			{"size": 170.0, "life": 0.8})
	main.fx.shader_burst("slash", global_position + _rend_dir * rend_reach * 0.6,
			{"size": 110.0, "life": 0.32, "dir": _rend_dir, "color": Color(0.7, 0.45, 1.0)})
	main.fx.shockwave(global_position, Color(0.62, 0.38, 1.0), 80.0)
	if main.get("post") != null:
		main.post.pulse(0.8)
	var hit_any := _arc_hit(_rend_dir, rend_reach, rend_arc_deg,
			rend_damage, Color("b06cff"), _rune_rend)   # violet hit sparks
	if _rune_rend == "rune_of_echoes":
		_echo_t = 0.25
		_echo_skill = "rend"
		_echo_dir = _rend_dir
	if hit_any:
		main.hitstop()
		main.shake(3.0)

# Whirlwind (E, class active — proposal): full-circle strike at 0.8x melee with
# a small shove, 4 s cooldown. Every class owns it from the start.
func _whirlwind() -> void:
	_whirl_cd = whirl_cd_s
	_whirl_t = 1.0
	var main := get_tree().get_first_node_in_group("main")
	var dmg := attack_damage * 0.8 * _buff_mult("damage")
	if randf() < crit_chance:
		dmg *= crit_mult
	var hit_any := false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= 2.6 * TILE + c.body_radius:
			c.take_damage(dmg, to_c.normalized(), Color(0.85, 0.95, 1.0))
			c.shove(to_c.normalized(), 8.0)
			hit_any = true
			if _class_fx == "ignite" and randf() < 0.2:
				c.ignite(2.0 * _skill_mult, 2.0)
			elif _class_fx == "chill":
				c.apply_slow(1.0)
	var lp := leech_pct + _buff_add("leech")
	if hit_any and lp > 0.0:
		hp = minf(hp + dmg * lp, max_hp)
	sprite.play("attack")
	sprite.frame = 0
	_whirl_spin()   # the sprite rides the full-circle strike
	if main:
		main.play_sfx("swing", global_position, -6.0)
		main.fx.tornado(global_position)
		main.fx.ring(global_position, Color(0.85, 0.95, 1.0, 0.8), 2.6 * TILE)
		# §3: orbital vortex tracking the hero + impact shockwave
		main.fx.shader_burst("vortex", global_position, {"size": 128.0, "life": 0.55,
				"dir": _swing_dir, "color": Color(0.55, 0.75, 1.0),
				"uniforms": {"gain": 2.6}})
		main.fx.shockwave(global_position, Color(0.85, 0.95, 1.0), 60.0)
		if hit_any:
			main.hitstop()
			main.shake(3.0)
			main.refresh_hud()

# Arcane Bolt (Gloam Mage LMB, proposal): ranged umbral projectile, 0.9x stat.
func _cast_bolt() -> void:
	_attack_cd = attack_cd_s / _buff_mult("attack_speed")
	_swing_dir = (get_global_mouse_position() - global_position).normalized()
	if _swing_dir.length() < 0.1:
		_swing_dir = Vector2.RIGHT
	sprite.flip_h = _swing_dir.x < 0.0
	sprite.play("attack")
	sprite.frame = 0
	_cast_pulse(_swing_dir)   # wind-up pulse + recoil off the bolt
	var dmg := attack_damage * 0.9 * _buff_mult("damage")
	if randf() < crit_chance:
		dmg *= crit_mult
	var p := ProtoProjectile.new()
	p.friendly = true
	p.set_arcane()
	p.damage = dmg
	p.lifetime = 1.2
	p.global_position = global_position + Vector2(0, -10) + _swing_dir * 8.0
	p.velocity = _swing_dir * 13.0 * TILE
	get_parent().add_child(p)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.play_sfx("bolt", global_position, -12.0)
		main.fx.burst(global_position + _swing_dir * 10.0 + Vector2(0, -10),
				{"amount": 7, "lifetime": 0.18, "direction": _swing_dir,
				"spread": 30.0, "v_min": 60.0, "v_max": 160.0,
				"gravity": Vector2.ZERO, "s_min": 0.6, "s_max": 1.3,
				"color": Color(0.75, 0.6, 1.0, 0.9)})
		# §3: arcane muzzle orbital (bolt trail is projectile.gd, agent X)
		main.fx.orbital(global_position + _swing_dir * 10.0 + Vector2(0, -10), {"count": 4, "radius": 4.0, "life": 0.2, "color": Color(0.75, 0.6, 1.0)})

# Frost Nova (Gloam Mage E, proposal): radial chill burst, 0.7x + hard slow.
func _frost_nova() -> void:
	_whirl_cd = whirl_cd_s
	_whirl_t = 1.0
	var main := get_tree().get_first_node_in_group("main")
	var dmg := attack_damage * 0.7 * _skill_mult * _buff_mult("damage")
	var hit_any := false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= 2.8 * TILE + c.body_radius:
			c.take_damage(dmg, to_c.normalized(), Color(0.65, 0.9, 1.0))
			c.apply_slow(1.5)
			hit_any = true
	sprite.play("attack")
	sprite.frame = 0
	_cast_pulse(Vector2.ZERO)   # radial release: pulse without directional recoil
	if main:
		main.play_sfx("bolt", global_position, -8.0)
		main.fx.ring(global_position, Color(0.7, 0.92, 1.0, 0.9), 2.8 * TILE)
		main.fx.burst(global_position, {"amount": 26, "lifetime": 0.4,
				"v_min": 60.0, "v_max": 190.0, "gravity": Vector2.ZERO,
				"s_min": 0.8, "s_max": 1.8, "emission_radius": 10.0,
				"color": Color(0.75, 0.95, 1.0, 0.85)})
		# §3: triple frost shockwave + radial ribbon petals
		main.fx.shader_burst("nova", global_position, {"size": 2.8 * TILE * 2.6,
				"color": Color(0.35, 0.72, 1.0)})
		main.fx.shockwave(global_position, Color(0.7, 0.92, 1.0), 2.8 * TILE, {"rings": 1})
		if hit_any:
			main.shake(2.5)

# Fan of Knives (Veilblade E, proposal): five piercing steel fans, 0.5x each.
func _fan_of_knives() -> void:
	_whirl_cd = whirl_cd_s
	_whirl_t = 0.6
	var aim := (get_global_mouse_position() - global_position).normalized()
	if aim.length() < 0.1:
		aim = Vector2.RIGHT
	sprite.flip_h = aim.x < 0.0
	sprite.play("attack")
	sprite.frame = 0
	_cast_pulse(aim)   # recoil off the fan release
	for i in 5:
		var p := ProtoProjectile.new()
		p.friendly = true
		p.set_steel()
		p.damage = attack_damage * 0.5 * _buff_mult("damage")
		p.lifetime = 0.7
		p.global_position = global_position + Vector2(0, -10)
		p.velocity = aim.rotated(deg_to_rad(-28.0 + 14.0 * i)) * 15.0 * TILE
		get_parent().add_child(p)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.play_sfx("swing", global_position, -6.0)
		main.fx.arc_slash(global_position + aim * 12.0, aim, Color(0.85, 0.9, 0.95))
		# §3: wide steel muzzle fan (per-knife trails are projectile.gd, agent X)
		main.fx.ribbon_arc(global_position + aim * 12.0, aim, {"span": 1.4, "width": 5, "color": Color(0.85, 0.9, 0.95, 0.9)})

func whirl_progress() -> float:
	return clampf(1.0 - _whirl_cd / whirl_cd_s, 0.0, 1.0)

# ---- class skill tree: ONE generic executor (skill_trees.json) ---------------------
# Every tree active is pure data — {kind, params, applies, bonus_vs, consumes,
# spread, detonate, charge_gain/spend} — dispatched here. Kinds: projectile /
# nova / cone / melee_arc / dash_strike / buff / field / chain. Adding a skill
# is a JSON edit, never engine work (canon: extensibility is the product).

const ELEMENT_COLORS := {"ember": Color("ff9a3c"), "frost": Color("7fd8ff"),
		"arcane": Color("b48cff"), "steel": Color("cdd6dd"),
		"violet": Color("b06cff")}
# status application defaults (proposal — mirrored in the effects registry)
const STATUS_DURATION := {"chill": 1.6, "ignite": 3.0, "bleed": 4.0,
		"expose": 4.0, "stagger": 0.5}

func _cast_slot(i: int) -> void:
	var id := str(Session.skill_loadout[i]) if i < Session.skill_loadout.size() else ""
	if id == "" or not Session.node_learned(id):
		return
	var def := Session.skill_def(id)
	if not def.is_empty():
		use_skill(def)

func skill_cd_left(id: String) -> float:
	return float(skill_cds.get(id, 0.0))

func use_skill(def: Dictionary) -> bool:
	if dead or mounted:
		return false
	var id := str(def.get("id", ""))
	if float(skill_cds.get(id, 0.0)) > 0.0:
		return false
	var p: Dictionary = def.get("params", {})
	var kind := str(def.get("kind", ""))
	var aim := (get_global_mouse_position() - global_position).normalized()
	if aim.length() < 0.1:
		aim = Vector2.RIGHT
	var main := get_tree().get_first_node_in_group("main")
	var col: Color = ELEMENT_COLORS.get(str(p.get("element", "")), Color("cfd6ff"))
	# melee kinds ride the weapon; casts add Intellect/class skill scaling
	var dmg := attack_damage * float(p.get("mult", 1.0)) * _buff_mult("damage")
	if not kind in ["melee_arc", "dash_strike"]:
		dmg *= _skill_mult
	# charge spenders (Combo/Attunement): +25%/stack (data), every stack spent
	if bool(def.get("charge_spend", false)) and charge_stacks > 0:
		dmg *= 1.0 + charge_per_stack * charge_stacks
		charge_stacks = 0
	var crit := randf() < crit_chance
	if crit:
		dmg *= crit_mult
	sprite.flip_h = aim.x < 0.0
	sprite.play("attack")
	sprite.frame = 0
	match kind:   # pose juice: swings lean, casts pulse (transform-only)
		"melee_arc", "dash_strike":
			_swing_lean(aim)
		"nova", "buff", "field":
			_cast_pulse(Vector2.ZERO)
		_:
			_cast_pulse(aim)
	var hit_any := false
	match kind:
		"melee_arc":
			hit_any = _exec_arc(def, p, aim, dmg, col, main, true)
		"cone":
			hit_any = _exec_arc(def, p, aim, dmg, col, main, false)
		"nova":
			hit_any = _exec_nova(def, p, dmg, col, main)
		"projectile":
			hit_any = true
			_exec_projectile(def, p, aim, dmg, main)
		"chain":
			hit_any = _exec_chain(def, p, aim, dmg, col, main)
		"dash_strike":
			hit_any = _exec_dash(def, p, aim, dmg, col, main)
		"buff":
			hit_any = true
			_exec_buff(def, p, main)
		"field":
			hit_any = true
			_exec_field(p, main)
		_:
			return false
	# charge builders (stab/arcane-tagged actives) build on the cast
	if int(def.get("charge_gain", 0)) > 0 and charge_name != "":
		charge_stacks = mini(charge_stacks + int(def.get("charge_gain", 0)), charge_max)
	skill_cds[id] = float(p.get("cd", 6.0)) * cdr_mult
	if crit and hit_any and main \
			and kind in ["melee_arc", "cone", "nova", "chain", "dash_strike"]:
		main.damage_number(global_position + Vector2(0, -34), 0, Color("ffd166"), "CRIT!")
	return true

# Shared per-target pipeline: bonus_vs multipliers, damage, applied/consumed
# statuses, ignite spread/detonation. Everything a synergy needs, one place.
func _skill_hit(c: Node2D, dmg: float, dir: Vector2, def: Dictionary, col: Color,
		main: Node) -> void:
	var out := dmg
	var bonus: Dictionary = def.get("bonus_vs", {})
	for k in bonus:
		if c.has_status(str(k)):
			out *= float(bonus[k])
	c.take_damage(out, dir, col)
	for st in def.get("applies", []):
		c.apply_status(str(st), _status_power(str(st)),
				float(STATUS_DURATION.get(str(st), 3.0)))
	for st in def.get("consumes", []):
		c.clear_status(str(st))
	if def.has("spread"):   # Emberwake: the burn leaps to the pack
		c.spread_ignite(float((def.spread as Dictionary).get("radius", 2.5)) * TILE)
	if def.has("detonate"):   # Cinderburst: consume the burn, pop it as an AoE
		var dt: Dictionary = def.detonate
		var total: float = c.detonate_ignite() * float(dt.get("mult", 1.0))
		if total > 0.0:
			_detonate_pop(c.global_position, total,
					float(dt.get("radius", 2.2)) * TILE, main)

# Projectile skills call back here on impact (projectile.gd friendly path).
func projectile_hit(c: Node2D, dmg: float, dir: Vector2, def: Dictionary,
		col: Color) -> void:
	_skill_hit(c, dmg, dir, def, col, get_tree().get_first_node_in_group("main"))

# DoT strength defaults, skill-scaled (proposal — effects registry mirrors).
func _status_power(st: String) -> float:
	match st:
		"ignite":
			return 3.0 * _skill_mult
		"bleed":
			return maxf(attack_damage * 0.08, 1.0)   # per-stack dps
	return 0.0

func _detonate_pop(at: Vector2, total: float, radius: float, main: Node) -> void:
	if main:
		main.fx.explosion(at, Color(1.0, 0.5, 0.15))
		main.fx.ring(at, Color(1.0, 0.55, 0.2, 0.85), radius)
		# §3 Cinderburst detonate: fire shockwave + orbital burst
		main.fx.shader_burst("firestorm", at + Vector2(0, -radius * 0.5),
				{"size": radius * 2.6, "life": 0.55})
		main.fx.shader_burst("impact", at, {"size": 40.0, "color": Color(1.0, 0.7, 0.3)})
		# the blast heats the air and lights the ground (post haze + lights pool)
		if main.get("post") != null:
			main.post.haze(at, radius * 1.3, 2.6, 0.7)
		main.fx.light_at(at, {"radius": radius * 1.6, "color": Color(1.0, 0.55, 0.2),
				"alpha": 0.5, "life": 0.6, "flicker": 0.5, "rate": 18.0})
		main.play_sfx("hit", at, -6.0)
	for n in get_tree().get_nodes_in_group("creatures"):
		if n.dead:
			continue
		if n.global_position.distance_to(at) <= radius + n.body_radius:
			n.take_damage(total, (n.global_position - at).normalized(), Color("ff9a3c"))

func _targets_in_arc(dir: Vector2, reach: float, arc_deg: float) -> Array:
	var cos_half := cos(deg_to_rad(arc_deg * 0.5))
	var out: Array = []
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= reach + c.body_radius \
				and to_c.normalized().dot(dir) >= cos_half:
			out.append(c)
	return out

# melee_arc and cone share the arc hit; they differ in reach defaults + VFX.
func _exec_arc(def: Dictionary, p: Dictionary, aim: Vector2, dmg: float,
		col: Color, main: Node, melee: bool) -> bool:
	var reach := float(p.get("reach", 2.2 if melee else 3.0)) * TILE
	var hit := false
	for c in _targets_in_arc(aim, reach, float(p.get("arc_deg", 90.0 if melee else 50.0))):
		_skill_hit(c, dmg, aim, def, col, main)
		hit = true
	if main:
		if melee:
			main.play_sfx("swing", global_position, -8.0)
			main.fx.arc_slash(global_position + aim * reach * 0.6, aim, col)
			# element-tinted crescent — vfx_lab slash shader
			main.fx.shader_burst("slash", global_position + aim * reach * 0.55,
					{"size": maxf(reach * 2.4, 72.0), "dir": aim, "color": col})
		else:
			main.play_sfx("bolt", global_position, -8.0)
			if str(p.get("element", "ember")) == "ember":
				main.fx.flame_cone(global_position + aim * 8.0, aim)
			else:
				main.fx.burst(global_position + aim * 10.0, {"amount": 22,
						"lifetime": 0.5, "direction": aim,
						"spread": float(p.get("arc_deg", 50.0)) * 0.5,
						"v_min": 140.0, "v_max": 240.0, "gravity": Vector2.ZERO,
						"s_min": 1.2, "s_max": 2.6, "color": col})
			# cone spray — vfx_lab: flame plume for ember, wide light-sheet otherwise
			if str(p.get("element", "ember")) == "ember":
				main.fx.shader_burst("firestorm", global_position + aim * reach * 0.5,
						{"size": maxf(reach * 2.0, 80.0), "dir": aim, "life": 0.5})
			else:
				main.fx.shader_burst("slash", global_position + aim * reach * 0.5,
						{"size": maxf(reach * 2.2, 80.0), "life": 0.34, "dir": aim, "color": col})
	if hit:
		if melee:
			var lp := leech_pct + _buff_add("leech")
			if lp > 0.0:
				hp = minf(hp + dmg * lp, max_hp)
		if main:
			main.hitstop()
			main.shake(2.5)
			main.refresh_hud()
	return hit

func _exec_nova(def: Dictionary, p: Dictionary, dmg: float, col: Color,
		main: Node) -> bool:
	var radius := float(p.get("radius", 2.6)) * TILE
	var hit := false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var to_c: Vector2 = c.global_position - global_position
		if to_c.length() <= radius + c.body_radius:
			_skill_hit(c, dmg, to_c.normalized(), def, col, main)
			hit = true
	if hit and bool(p.get("leech", false)):   # Red Harvest: the ring feeds you
		var lp := maxf(leech_pct + _buff_add("leech"), 0.05)
		hp = minf(hp + dmg * lp, max_hp)
	if main:
		main.play_sfx("bolt", global_position, -8.0)
		main.fx.ring(global_position, Color(col.r, col.g, col.b, 0.9), radius)
		main.fx.burst(global_position, {"amount": 24, "lifetime": 0.4,
				"v_min": 60.0, "v_max": 190.0, "gravity": Vector2.ZERO,
				"s_min": 0.8, "s_max": 1.8, "emission_radius": 10.0, "color": col})
		# vfx_lab nova: expanding chromatic ring + shards + core flash
		main.fx.shader_burst("nova", global_position, {"size": radius * 2.6, "color": col})
		main.fx.shockwave(global_position, col, radius, {"rings": 1})
		if hit:
			main.shake(2.5)
			main.refresh_hud()
	return hit

func _exec_projectile(def: Dictionary, p: Dictionary, aim: Vector2, dmg: float,
		main: Node) -> void:
	var count := int(p.get("count", 1))
	var spread := deg_to_rad(float(p.get("spread_deg", 0.0)))
	for i in count:
		var ang := 0.0
		if count > 1:
			ang = -spread * 0.5 + spread * float(i) / float(count - 1)
		var b := ProtoProjectile.new()
		b.friendly = true
		match str(p.get("element", "ember")):
			"frost":
				b.set_frost()
			"arcane":
				b.set_arcane()
			"steel":
				b.set_steel()
			"violet":
				b.set_violet()
		b.damage = dmg
		b.skill_def = def
		b.shooter = self
		b.lifetime = float(p.get("lifetime", 1.2))
		b.global_position = global_position + Vector2(0, -10) + aim * 8.0
		b.velocity = aim.rotated(ang) * float(p.get("speed", 13.0)) * TILE
		get_parent().add_child(b)
	if main:
		main.play_sfx("bolt", global_position, -10.0)
		# §3 projectile: muzzle orbital flare (bolt trails are projectile.gd, agent X)
		var mcol: Color = ELEMENT_COLORS.get(str(p.get("element", "ember")), Color("cfd6ff"))
		main.fx.orbital(global_position + Vector2(0, -10) + aim * 8.0, {"count": 4, "radius": 4.0, "life": 0.2, "color": mcol})

func _nearest_creature(at: Vector2, max_d: float, exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead or exclude.has(c):
			continue
		var d: float = c.global_position.distance_to(at)
		if d <= best_d:
			best_d = d
			best = c
	return best

# Chain: leaps creature to creature, -15% damage per hop, pooled arc links.
func _exec_chain(def: Dictionary, p: Dictionary, aim: Vector2, dmg: float,
		col: Color, main: Node) -> bool:
	var range_px := float(p.get("range", 5.0)) * TILE
	var jumps := int(p.get("jumps", 3))
	var visited: Array = []
	var from := global_position + Vector2(0, -10)
	var seek := global_position + aim * range_px * 0.5
	var falloff := dmg
	var hit := false
	for j in jumps:
		var nxt := _nearest_creature(seek if j == 0 else from, range_px, visited)
		if nxt == null and j == 0:   # nothing along the aim — try around the hero
			nxt = _nearest_creature(global_position, range_px, visited)
		if nxt == null:
			break
		visited.append(nxt)
		if main:
			main.fx.arc_link(from, nxt.global_position + Vector2(0, -8), col)
			main.fx.shockwave(nxt.global_position, col, 14.0, {"rings": 1})   # §3: small pop per node
		_skill_hit(nxt, falloff, (nxt.global_position - global_position).normalized(),
				def, col, main)
		from = nxt.global_position + Vector2(0, -8)
		falloff *= 0.85
		hit = true
	if main and hit:
		main.play_sfx("bolt", global_position, -8.0)
		main.refresh_hud()
	return hit

# Dash strike: displacement along the aim (walkability-gated like the dodge),
# damaging everything within ~1.2 m of the traveled line.
func _exec_dash(def: Dictionary, p: Dictionary, aim: Vector2, dmg: float,
		col: Color, main: Node) -> bool:
	var start := global_position
	if main:
		_spawn_ghost(main)   # one afterimage left at the launch point
	var dist := float(p.get("dist", 4.5)) * TILE
	for _i in 8:   # stepped so walls still gate the dash
		_try_move(aim * dist / 8.0)
	var seg := global_position - start
	var hit := false
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var t := 0.0
		if seg.length_squared() > 0.0:
			t = clampf((c.global_position - start).dot(seg) / seg.length_squared(),
					0.0, 1.0)
		if (start + seg * t).distance_to(c.global_position) <= 1.2 * TILE + c.body_radius:
			_skill_hit(c, dmg, aim, def, col, main)
			hit = true
	if main:
		main.play_sfx("swing", global_position, -8.0)
		main.fx.burst(start, {"amount": 10, "lifetime": 0.3, "direction": -aim,
				"spread": 20.0, "v_min": 60.0, "v_max": 160.0,
				"gravity": Vector2.ZERO, "s_min": 0.6, "s_max": 1.4, "color": col})
		main.fx.arc_slash(global_position, aim, col)
		# §3 dash_strike: streak along the traveled segment + landing shockwave
		main.fx.ribbon_streak(start, global_position, {"color": col, "width": 7, "life": 0.25})
		main.fx.shockwave(global_position, col, 30.0)
	if hit:
		var lp := leech_pct + _buff_add("leech")
		if lp > 0.0:
			hp = minf(hp + dmg * lp, max_hp)
		if main:
			main.shake(2.5)
			main.refresh_hud()
	return hit

func _exec_buff(def: Dictionary, p: Dictionary, main: Node) -> void:
	_buffs.append({"until": Time.get_ticks_msec() / 1000.0
			+ float(p.get("duration", 5.0)), "mults": p.get("mults", {})})
	if main:
		main.play_ui("capture", -14.0)
		main.fx.ring(global_position, Color(1.0, 0.85, 0.5, 0.8), 1.6 * TILE)
		# §3 buff: green protective aura — bright ring + 3 orbiting ribbons for the duration
		main.fx.aura(self, Color(0.45, 1.0, 0.55), {"radius": 22.0, "dur": float(p.get("duration", 5.0)), "orbit_ribbons": 3})
		main.damage_number(global_position + Vector2(0, -30), 0, Color("ffd166"),
				str(def.get("name", "?")).to_upper())

# Ground effect at the cursor (range-clamped), FRIENDLY: ticks creatures, not
# the hunter (main.gd spawn_field).
func _exec_field(p: Dictionary, main: Node) -> void:
	if main == null:
		return
	var range_px := float(p.get("range", 5.0)) * TILE
	var at := get_global_mouse_position()
	var to := at - global_position
	if to.length() > range_px:
		at = global_position + to.normalized() * range_px
	main.spawn_field(at, float(p.get("radius", 2.5)) * TILE,
			float(p.get("duration", 6.0)),
			attack_damage * float(p.get("dps_mult", 0.4)) * _skill_mult
			* _buff_mult("damage"), str(p.get("field_kind", "fire")), true)
	# §3 field: ignition orbital burst (the danger-ring telegraph is main.spawn_field, agent M)
	var fcol := Color(1.0, 0.55, 0.2)
	match str(p.get("field_kind", "fire")):
		"mire":
			fcol = Color(0.5, 0.85, 0.35)
		"frost":
			fcol = Color(0.6, 0.9, 1.0)
		"earth":
			fcol = Color(0.7, 0.55, 0.35)
	main.fx.orbital(at, {"count": 5, "radius": 12.0, "life": 0.35, "color": fcol})

func _buff_mult(key: String) -> float:
	var m := 1.0
	for b in _buffs:
		m *= float((b.mults as Dictionary).get(key, 1.0))
	return m

func _buff_add(key: String) -> float:
	var v := 0.0
	for b in _buffs:
		v += float((b.mults as Dictionary).get(key, 0.0))
	return v

# ---- mounts (Z) -------------------------------------------------------------------

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
	# the drake is authored at final size in its own ember palette — no tint/scale
	_mount_sprite.sprite_frames = ProtoSprites.drake_frames() if flying \
			else ProtoSprites.stalker_frames()
	_mount_sprite.scale = Vector2.ONE * (1.0 if flying else 1.2)
	if not flying:
		_mount_sprite.modulate = Color(str(m.get("tint", "ffffff")))
	add_child(_mount_sprite)
	move_child(_mount_sprite, 1)   # between shadow and hero — the hero rides on top
	_mount_sprite.play("fly" if flying else "walk")
	_mount_squash()   # the hero drops into the saddle
	if main:
		main.play_ui("capture", -14.0)
		main.fx.orbital(global_position, {"count": 5, "radius": 14.0, "life": 0.3})   # §3: mount swirl

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
	sprite.position.y = SPRITE_BASE_Y
	_mount_squash()   # lands on his feet with a little give
	var main := get_tree().get_first_node_in_group("main")   # §3: landing dust burst
	if main:
		main.fx.shockwave(global_position, Color(0.72, 0.62, 0.48), 30.0)
		main.fx.dust(global_position)

# Chill (frost wisp bolts, effects registry): -35% move while active.
func apply_slow(duration: float) -> void:
	_slow_t = maxf(_slow_t, duration)

# Rune of Echoes payoff: re-strike the same arc at 40% damage (no crit).
func _fire_echo() -> void:
	if dead:
		return
	_swing_lean(_echo_dir, 0.5)   # the echo tugs the body along, half strength
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
			dmg *= (1.0 - phys_reduction) / _buff_mult("armor")   # bulwark buffs
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
		_reset_pose()   # never leave the sprite mid-tween across a respawn
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
	_reset_pose()
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
	if _whirl_t > 0.0:   # Whirlwind: expanding double ring
		var wr := 2.6 * TILE * (1.15 - _whirl_t * 0.15)
		draw_arc(Vector2(0, -body_radius), wr, 0, TAU, 32,
				Color(0.85, 0.95, 1.0, _whirl_t * 0.7), 3.0)
		draw_arc(Vector2(0, -body_radius), wr * 0.7, 0, TAU, 24,
				Color(0.7, 0.85, 1.0, _whirl_t * 0.4), 2.0)
	if _gale_t > 0.0:   # Rune of the Gale: expanding wind ring at the launch point
		var at := _gale_pos - global_position
		var r := 1.5 * TILE * (1.4 - _gale_t * 0.4)
		draw_arc(at, r, 0, TAU, 24, Color(0.73, 0.95, 1.0, _gale_t * 0.7), 2.0)
		draw_arc(at, r * 0.6, 0, TAU, 18, Color(0.85, 1.0, 1.0, _gale_t * 0.4), 1.5)
