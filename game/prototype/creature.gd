# PROTOTYPE HARNESS — creature logic. The shipping path is data-driven utility/BT
# profiles executed in dh-sim (content/core/ai-profiles/, docs/tech/25); this
# hand-rolled chase/windup/strike loop is its stand-in. Numbers hand-copied from
# content/core/creatures/gloamfen_stalker.json.
class_name ProtoCreature
extends Node2D

const TILE := 16.0

var max_hp := 120.0
var hp := 120.0
var damage := 14.0
var move_speed := 4.5 * TILE     # px/s
var body_radius := 9.0
# One HP reference for every hunt legendary regardless of chassis (Matriarch
# base); the entry's rolled hp_mult picks a spot inside a x1.4-3.0 band of it.
const LEGENDARY_HP_BUDGET := 900.0
var aggro_range := 7.0 * TILE
var attack_reach := 1.8 * TILE
var attack_arc_deg := 90.0
var windup_time := 0.35
var attack_cd := 1.2
var gold_min := 4
var gold_max := 18
var stone_chance := 0.08
var snare_chance := 0.12         # Soul Snare drop (pet capture, design/13 §7.1)
var capturable := true           # in the Abyssal pool (abyssal.json) — boss/wisp opt out
var guaranteed_stone := false    # first pack seeds the Bestial Skill discovery
var elite := false               # Elite+ tier: boosted loot rarity + rune drops (proposal)
var item_chance := 0.10          # (proposal) chance a kill rolls a real item drop

var archetype := "stalker"       # stalker | lunger | brute (spawn tables, proposal)
var elite_affix := ""            # Brutal | Swift | Fiery | Bulwark on pack leaders
var fiery := false               # Fiery affix: strikes add a 50% fire packet
var name_tag := ""               # elite title shown above the sprite
var species_name := ""           # bestiary catalog display name (brutes/elites only)
var dmg_scale := 1.0             # entry dmg_mult x level curve — scales skill packets
var legendary_entry := {}        # hunt legendary riding this chassis (main routes _die)
var _entry := {}                 # bestiary_normal.json species entry (applied in _ready)
var _bundle := ""                # baked GenForge actor key ("" = archetype frames)
var _base_tint := Color(1, 1, 1)
var _scale := 1.0

var pack_anchor := Vector2.ZERO
var dead := false
var threat := false              # fought the player — the pet hunts these

var _state := "idle"            # idle | chase | windup | recover
var _timer := 0.0
var _cd := 0.0
var _enrage_t := 0.0            # failed snare: +30% speed while > 0
var _slow_t := 0.0              # Chill (Frostbinder hits): -30% speed while > 0
var _pounce_target := Vector2.ZERO   # lunger pounce landing point
var _burn_t := 0.0              # Rune of Cinders ignite: 3 dmg/s while > 0
var _burn_tick := 0.0
var _burn_dps := 0.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _attack_dir := Vector2.RIGHT
var _flash := 0.0
var _step_accum := Vector2.ZERO
var sprite: AnimatedSprite2D
var _shadow: Sprite2D

func _ready() -> void:
	_apply_entry()   # catalog species/legendary mults + player-level power scaling
	add_to_group("creatures")
	var sh := _shadow_dims()
	_shadow = Sprite2D.new()
	_shadow.texture = ProtoSprites.shadow_tex(sh.x, sh.y)
	_shadow.position.y = -1.0
	add_child(_shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _make_frames()
	sprite.position.y = -_sprite_lift()
	sprite.self_modulate = _base_tint
	sprite.scale = Vector2.ONE * _scale
	sprite.play("idle")
	add_child(sprite)
	if name_tag != "":   # elite title floats above the sprite
		var tag := Label.new()
		tag.text = name_tag
		tag.add_theme_font_size_override("font_size", 8)
		tag.add_theme_color_override("font_color", Color("ffd166"))
		tag.position = Vector2(-40, -32.0 * _scale)
		tag.size = Vector2(80, 10)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tag)
	elif species_name != "" and archetype == "brute":
		# catalog species names show only on brutes/elites — commons stay clean
		# (task 1: labels only where they matter; 60 FPS label budget)
		var tag := Label.new()
		tag.text = species_name
		tag.add_theme_font_size_override("font_size", 7)
		tag.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.45))
		tag.position = Vector2(-40, -30.0 * _scale)
		tag.size = Vector2(80, 10)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tag)
	hp = max_hp

# Spawn-table variety (call BEFORE add_child). Archetypes reshape the base kit;
# elite affixes mark pack leaders with boosted loot (elite=true). All proposals;
# the registry of affixes/archetypes lives in effects.json + the in-game CODEX.
func setup_archetype(kind: String, affix := "") -> void:
	archetype = kind
	match kind:
		"lunger":   # glass cannon: fast, frail, quick bites
			max_hp *= 0.65
			damage *= 0.8
			move_speed *= 1.45
			windup_time = 0.22
			attack_cd = 0.9
			_base_tint = Color(0.8, 1.05, 1.1)
			_scale = 0.9
			body_radius = 8.0
		"brute":    # slow wall: heavy telegraphed hits, double gold
			max_hp *= 1.9
			damage *= 1.7
			move_speed *= 0.7
			windup_time = 0.55
			attack_cd = 1.8
			gold_min *= 2
			gold_max *= 2
			_base_tint = Color(1.15, 0.85, 0.75)
			_scale = 1.3
			body_radius = 11.5
	elite_affix = affix
	match affix:
		"Brutal":
			damage *= 1.5
			_base_tint *= Color(1.25, 0.75, 0.75)
		"Swift":
			move_speed *= 1.4
			attack_cd *= 0.75
			_base_tint *= Color(0.8, 1.1, 1.2)
		"Fiery":
			fiery = true
			_base_tint *= Color(1.3, 0.95, 0.6)
		"Bulwark":
			max_hp *= 1.8
			_base_tint *= Color(1.2, 1.15, 0.8)
	if affix != "":
		elite = true
		name_tag = "%s %s" % [affix.to_upper(), kind.to_upper()]
	hp = max_hp

# Bestiary catalog species (bestiary_normal.json — call BEFORE add_child, like
# setup_archetype, which it wraps): archetype reshapes the kit first, then the
# species entry lands on top in _apply_entry() at _ready time so subclass stat
# blocks (wisp/boss) keep the multipliers.
func setup_from_entry(entry: Dictionary, affix := "") -> void:
	var kind := str(entry.get("archetype", "stalker"))
	if kind != "wisp":   # wisp flavor is the ProtoWisp class + element field
		if not ["stalker", "lunger", "brute"].has(kind):
			kind = "stalker"   # unknown archetype: stalker behavior (graceful)
		setup_archetype(kind, affix)
	_entry = entry

# Hunt legendary (bestiary_legendary.json): ride an existing boss chassis and
# rescale from its base kit. Call BEFORE add_child; main routes _die through
# on_legendary_died and owns display_name/bar_color.
func setup_legendary(entry: Dictionary) -> void:
	legendary_entry = entry
	_entry = entry

# Species tint normalized so the max channel is 1: hue survives the multiply
# over the archetype tint without crushing sprites toward black.
static func tint_from(entry: Dictionary) -> Color:
	var tint := str(entry.get("tint", ""))
	if not Color.html_is_valid(tint):
		return Color(1, 1, 1)
	var c := Color.html(tint)
	var m := maxf(c.r, maxf(c.g, c.b))
	return Color(c.r / m, c.g / m, c.b / m) if m > 0.01 else Color(1, 1, 1)

# Power scaling with the player (task 3, proposal): (hp_rate, dmg_rate) per
# level above 1, read from Session.level ONCE at spawn. Normals gentle
# (0.02/0.01); boss chassis override to (0.06/0.03). Gold rides the dmg curve.
func _power_rates() -> Vector2:
	return Vector2(0.02, 0.01)

# Runs FIRST in _ready: bestiary entry multipliers + player-level power scaling
# land on top of whatever stat block the subclass set up. Parsed catalogs and
# per-entry clamps keep hostile/typo'd data from breaking the sim.
func _apply_entry() -> void:
	var rates := _power_rates()
	var lvl := float(maxi(Session.level - 1, 0))
	var hp_mult := 1.0 + rates.x * lvl
	var dmg_mult := 1.0 + rates.y * lvl
	var gold_mult := 1.0 + rates.y * lvl   # loot scales mildly with the same curve
	if not _entry.is_empty():
		species_name = str(_entry.get("name", ""))
		_bundle = str(_entry.get("bundle", ""))
		_base_tint = _base_tint * tint_from(_entry)   # species tint OVER archetype tint
		var entry_scale := clampf(float(_entry.get("scale", 1.0)), 0.5, 3.0)
		_scale *= entry_scale
		body_radius *= entry_scale   # the hitbox follows the sprite (Ricardo 2026-07-11)
		if not legendary_entry.is_empty():
			# Flow over sponge (Ricardo 2026-07-11): legendaries roll a NORMALIZED
			# HP budget off one reference instead of multiplying the chassis base —
			# no more 13.8k colossus walls at level 1. Rolled hp_mult 2.5-6 maps to
			# x1.4-3.0 of the budget; threat comes from dmg_mult, not sponge.
			var hm := clampf(float(_entry.get("hp_mult", 3.0)), 2.5, 6.0)
			max_hp = LEGENDARY_HP_BUDGET * remap(hm, 2.5, 6.0, 1.4, 3.0)
			dmg_mult *= clampf(float(_entry.get("dmg_mult", 1.6)), 1.3, 2.2)
			gold_mult *= maxf(float(_entry.get("gold_mult", 2.0)), 1.0)
			name_tag = species_name.to_upper()
		else:
			hp_mult *= clampf(float(_entry.get("hp_mult", 1.0)), 0.2, 4.0)
			dmg_mult *= clampf(float(_entry.get("dmg_mult", 1.0)), 0.2, 3.0)
			move_speed *= clampf(float(_entry.get("speed_mult", 1.0)), 0.4, 2.0)
			gold_mult *= maxf(float(_entry.get("gold_mult", 1.0)), 0.0)
			if elite_affix != "" and species_name != "":   # "BRUTAL MIREFANG..." tag
				name_tag = "%s %s" % [elite_affix.to_upper(), species_name.to_upper()]
	max_hp *= hp_mult
	damage *= dmg_mult
	dmg_scale = dmg_mult   # boss kits multiply their hardcoded packets by this
	gold_min = maxi(int(gold_min * gold_mult), 1)
	gold_max = maxi(int(gold_max * gold_mult), gold_min)

# Baked GenForge bundle for a catalog species when the actor exists on disk —
# else the archetype's procedural frames (sliced once, cached in ProtoBundleArt).
func _bundle_or(fallback_frames: SpriteFrames) -> SpriteFrames:
	if _bundle != "":
		var sf := ProtoBundleArt.frames_for(_bundle)
		if sf != null:
			ProtoBundleArt.ensure_animations(sf, ["idle", "walk", "lunge"])
			return sf
	return fallback_frames

func _make_frames() -> SpriteFrames:
	return _bundle_or(ProtoSprites.stalker_frames())

func _sprite_lift() -> float:
	return 6.0

func _shadow_dims() -> Vector2i:
	return Vector2i(16, 5)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_cd = maxf(_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	var base_tint := Color(1, 1, 1) if _burn_t <= 0.0 else Color(1.5, 0.95, 0.6)
	if _slow_t > 0.0:
		base_tint *= Color(0.7, 0.9, 1.25)   # chilled: icy cast
	sprite.modulate = base_tint.lerp(Color(3, 3, 3), _flash)
	if _burn_t > 0.0:   # ignite DoT (Rune of Cinders): 0.5 s ticks
		_burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_burn_damage(_burn_dps * 0.5)
			if dead:
				return
	if _enrage_t > 0.0:
		_enrage_t -= delta
		if _enrage_t <= 0.0:
			sprite.self_modulate = _base_tint
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		_state = "idle"
	match _state:
		"idle":
			_idle(delta, player)
		"chase":
			_chase(delta, player)
		"windup":
			_timer -= delta
			if _timer <= 0.0:
				_strike(player)
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "chase"
	_update_anim()
	queue_redraw()

func _update_anim() -> void:
	if _state == "windup" or _state == "recover":
		_play_anim("lunge")
	elif _step_accum.length() > 0.15:
		if absf(_step_accum.x) > 0.02:
			sprite.flip_h = _step_accum.x < 0.0
		_play_anim("walk")
	else:
		_play_anim("idle")
	_step_accum = Vector2.ZERO

func _play_anim(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

func _idle(delta: float, player: Node2D) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.0, 3.0)
		_wander = Vector2.from_angle(randf() * TAU) * move_speed * 0.25
		if global_position.distance_to(pack_anchor) > 4.0 * TILE:
			_wander = (pack_anchor - global_position).normalized() * move_speed * 0.3
	_move(_wander * delta)
	if player and not player.dead and global_position.distance_to(player.global_position) < aggro_range:
		_state = "chase"

func _chase(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var to_player := player.global_position - global_position
	# lunger pounce (monster active, effects registry): leaps 3 m onto you from
	# mid-range — the windup flash IS the tell, sidestep during it
	if archetype == "lunger" and _cd <= 0.0 \
			and to_player.length() >= 2.5 * TILE and to_player.length() <= 5.5 * TILE:
		_pounce_target = player.global_position
		_begin_windup(to_player.normalized())
		return
	if to_player.length() <= attack_reach * 0.9 and _cd <= 0.0:
		_begin_windup(to_player.normalized())
		return
	_move(to_player.normalized() * _speed() * delta)
	_separate(delta)
	if to_player.length() > aggro_range * 1.8:
		_state = "idle"

func _speed() -> float:
	return move_speed * (1.3 if _enrage_t > 0.0 else 1.0) \
			* (0.7 if _slow_t > 0.0 else 1.0)

# Chill (effects registry): Frostbinder hits and frost effects slow creatures.
func apply_slow(duration: float) -> void:
	if not dead:
		_slow_t = maxf(_slow_t, duration)

func enrage(duration: float) -> void:
	_enrage_t = duration
	sprite.self_modulate = _base_tint * Color(1.5, 0.82, 0.82)
	if _state == "idle":
		_state = "chase"

func _begin_windup(dir: Vector2) -> void:
	_state = "windup"
	_timer = windup_time
	_attack_dir = dir
	_flash = 0.6
	threat = true
	sprite.flip_h = dir.x < 0.0
	sprite.play("lunge")
	sprite.frame = 0
	if archetype == "brute":   # slam is radial — telegraph the landing circle
		var tg := ProtoTelegraph.new()
		tg.radius = 2.2 * TILE
		tg.duration = windup_time
		tg.position = global_position
		get_parent().add_child(tg)

func _strike(player: Node2D) -> void:
	_state = "recover"
	_timer = 0.4
	_cd = attack_cd
	var main := get_tree().get_first_node_in_group("main")
	if archetype == "brute":   # ground slam: radial AoE — dodge OUT, not around
		if main:
			main.shake(5.0)
			main.fx.debris(global_position)
			main.play_sfx("hit", global_position, -6.0)
		if player != null and not player.dead and global_position.distance_to(
				player.global_position) <= 2.2 * TILE + player.body_radius:
			player.take_damage(damage, (player.global_position
					- global_position).normalized())
		for pet in get_tree().get_nodes_in_group("pet"):
			if pet.hp > 0.0 and global_position.distance_to(
					pet.global_position) <= 2.2 * TILE + pet.body_radius:
				pet.take_damage(damage, (pet.global_position
						- global_position).normalized())
		return
	if archetype == "lunger" and _pounce_target != Vector2.ZERO:
		var dash: Vector2 = (_pounce_target - global_position).limit_length(3.0 * TILE)
		for _i in 6:   # stepped so walkability still gates the leap
			_move(dash / 6.0)
		_pounce_target = Vector2.ZERO
		if main:
			main.fx.burst(global_position, {"amount": 6, "lifetime": 0.25,
					"v_min": 30.0, "v_max": 90.0, "s_min": 0.6, "s_max": 1.2,
					"color": Color(0.7, 0.85, 0.9, 0.6)})
	var cos_half := cos(deg_to_rad(attack_arc_deg * 0.5))
	if player != null and not player.dead:
		var to_player := player.global_position - global_position
		if to_player.length() <= attack_reach + player.body_radius \
				and to_player.normalized().dot(_attack_dir) >= cos_half:
			player.take_damage(damage, _attack_dir)
			if fiery:   # Fiery affix: +50% as a fire packet (resist-mitigated)
				player.take_damage(damage * 0.5, _attack_dir, "fire")
	# bonded pets are valid melee targets too (they rest at 0 HP, never die)
	for pet in get_tree().get_nodes_in_group("pet"):
		if pet.hp <= 0.0:
			continue
		var to_pet: Vector2 = pet.global_position - global_position
		if to_pet.length() <= attack_reach + pet.body_radius \
				and to_pet.normalized().dot(_attack_dir) >= cos_half:
			pet.take_damage(damage, _attack_dir)

func _move(step: Vector2) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var target := global_position + step
	if world and world.is_walkable(target):
		global_position = target
		_step_accum += step

func _separate(delta: float) -> void:
	for other in get_tree().get_nodes_in_group("creatures"):
		if other == self or other.dead:
			continue
		var d: Vector2 = global_position - other.global_position
		var min_d: float = body_radius + other.body_radius
		if d.length() < min_d and d.length() > 0.01:
			_move(d.normalized() * (min_d - d.length()) * 4.0 * delta)

# Rune of Cinders ignite: refreshes the burn each application.
func ignite(dps: float, duration: float) -> void:
	if dead:
		return
	_burn_dps = dps
	_burn_t = duration
	threat = true

# Lightweight DoT tick — no knockback/flash spam, small ember number.
func _burn_damage(dmg: float) -> void:
	hp -= dmg
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.damage_number(global_position + Vector2(0, -14), dmg, Color("ff9a3c"))
	if hp <= 0.0:
		_die()

# Wind burst (Rune of the Gale) pushes creatures around.
func shove(dir: Vector2, dist: float) -> void:
	if not dead:
		_move(dir.normalized() * dist)

func take_damage(dmg: float, from_dir: Vector2, spark_color := Color("cfd6ff")) -> void:
	if dead:
		return
	hp -= dmg
	_flash = 1.0
	threat = true
	_move(from_dir.normalized() * 6.0)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.damage_number(global_position + Vector2(0, -18), dmg, Color("ffe9d0"))
		main.hit_spark(global_position, spark_color)
		main.play_sfx("hit", global_position, -12.0)
	if _state == "idle":
		_state = "chase"
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.on_creature_died(self)
	queue_free()

func _draw() -> void:
	if dead or hp >= max_hp:
		return
	var w := body_radius * 2.4
	var y := -body_radius * 2.0 - 6.0
	draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 3), Color("c94f4f"))
