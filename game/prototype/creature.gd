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
# ---- pet capture (R57, design/13 §7.1) --------------------------------------
# Before R57 `capturable` did two jobs: gate the snare AND gate the Spirit
# Essence drop (main.on_creature_died). Bosses becoming capturable would have
# silently opened an essence faucet, so the two are separate flags now and the
# essence drop set is UNCHANGED (stalker/lunger/brute normals only) until a
# balance pass says otherwise.
var capturable := true           # a Soul Snare may target this body at all
var drops_essence := true        # Spirit Essence on death (was tied to capturable)
var capture_hp_gate := 0.35      # snare only below this HP fraction
var capture_chance_scale := 1.0  # multiplies the snare success roll
var capture_hp_share := 1.0      # the pet keeps this share of the body's HP...
var capture_dmg_share := 1.0     # ...and this share of its damage
var capture_scale := 1.0         # mini-pet sprite scale vs. the captured body
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
# The player-level factors _apply_entry folded into max_hp/damage at spawn. A
# captured pet divides them back out to recover PRE-LEVEL bases, so the bond
# levels with the player instead of freezing at capture-time power (R57).
var _level_hp_mult := 1.0
var _level_dmg_mult := 1.0
var _base_tint := Color(1, 1, 1)
var _scale := 1.0

var pack_anchor := Vector2.ZERO
var dead := false
var threat := false              # fought the player — the pet hunts these
# ARENA HOOKS (game/arena self-play, docs/design/23): target_override makes this
# creature hunt a specific node (an ArenaProxy) instead of the global "player"
# group — that's what enables creature-vs-creature. bot_drive skips the built-in
# chase/idle decisions (windup/recover still resolve) so an external policy can
# drive via _move()/bot_attack() — the RL-policy seam.
var target_override: Node2D = null
var bot_drive := false
# ARENA DUEL (game/arena only — set by game/arena/fighter.gd, never by the Hunt).
# In a duel both fighters are committed combatants placed 300 px apart to fight
# each other. The Hunt's unaware phase is correct there and wrong here: every
# species' aggro_range is BELOW that spawn separation (7-13 tiles at TILE = 16,
# i.e. 112-208 px), so an arena creature starts idle and only wakes if the
# opponent walks into it, and _chase gives the pursuit up again past
# aggro_range * 1.8 = 202 px, still inside the gap.
# MEASURED 2026-09-14, fen_boar mirror, 12 episodes: against a policy that keeps
# its distance, native dealt 0.083 health bars in 44.7 s — against 0.981 bars
# when native fights native and the two close on each other. So a policy that
# kites was being graded against a creature that was asleep, and had been for
# the whole history of the league.
# This flag does not change aggro_range, the Hunt, or any creature outside the
# arena: it says "this body is in a duel", and a duel has no disengage.
var arena_duel := false

var _state := "idle"            # idle | chase | windup | recover
var _timer := 0.0
var _cd := 0.0
var _enrage_t := 0.0            # failed snare: +30% speed while > 0
var _slow_t := 0.0              # Chill (Frostbinder hits): -30% speed while > 0
var _pounce_target := Vector2.ZERO   # lunger pounce landing point
var _burn_t := 0.0              # Ignite (runes + class skills): fire DoT while > 0
var _burn_tick := 0.0
var _burn_dps := 0.0
# Class skill-tree statuses (skill_trees.json synergies, effects registry).
# Plain timers, tint-only feedback — no nodes per status (60 FPS hard rule).
const BLEED_MAX_STACKS := 5      # (proposal) stacking phys DoT cap
const EXPOSE_MULT := 1.2         # (proposal) +20% damage taken from ALL sources
var _bleed_t := 0.0              # Bleed: _bleed_dps per stack while > 0
var _bleed_tick := 0.0
var _bleed_dps := 0.0
var _bleed_stacks := 0
var _expose_t := 0.0             # Expose: take_damage x1.2 while > 0
var _stagger_t := 0.0            # Stagger: brief stun — the state machine freezes
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _attack_dir := Vector2.RIGHT
var _flash := 0.0
var _step_accum := Vector2.ZERO
var sprite: AnimatedSprite2D
var _shadow: Sprite2D
# Juice pass: ONE pose tween per creature (killed on re-trigger, never stacked).
# Transform-only — GenForge frames stay intact; every tween's final keys ARE the
# base pose (rotation 0, scale Vector2.ONE * _scale) so the sprite can never be
# left off-base and hitboxes keep matching sprites (Ricardo 2026-07-11 tuning).
var _pose_tw: Tween

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
	# per-pixel N·L lighting from the light registry (bundle actors carry
	# CanvasTexture normal maps; others degrade to flat). Elites/bosses get
	# this REPLACED by their rim material in _apply_rim — identity read wins.
	sprite.material = ProtoGlow.lit_material()
	sprite.position.y = -_sprite_lift()
	sprite.self_modulate = _base_tint
	sprite.scale = Vector2.ONE * _scale
	sprite.play("idle")
	add_child(sprite)
	_apply_rim()
	call_deferred("_apply_presence_glow")
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

# Rim-glow silhouette (shaders/rim_glow.gdshader, Phantom-Tower elite read):
# legendaries magenta, boss chassis their bar color, elites their affix color.
# Materials are shared per color (ProtoGlow cache) — a pack costs one material.
const _AFFIX_RIM := {"Brutal": Color(1.0, 0.36, 0.32), "Swift": Color(0.5, 0.95, 1.0),
		"Fiery": Color(1.0, 0.68, 0.28), "Bulwark": Color(1.0, 0.85, 0.42)}

func _apply_rim() -> void:
	if not legendary_entry.is_empty():
		sprite.material = ProtoGlow.rim_material(Color("e05aff"), 1.4)
	elif get("bar_color") != null:            # boss chassis (Matriarch/Hag/duo)
		sprite.material = ProtoGlow.rim_material(get("bar_color"), 1.3)
	elif elite and _AFFIX_RIM.has(elite_affix):
		sprite.material = ProtoGlow.rim_material(_AFFIX_RIM[elite_affix])

# Legendaries and bosses light the ground they stand on (lights.gd pool) — a
# followed ellipse in their signature color. Deferred: creatures can spawn
# while main is still assembling its fx child. Commons/elites skip it (32-pool
# is for the few things that MATTER; elites already carry the rim).
func _apply_presence_glow() -> void:
	if not is_inside_tree():      # freed/culled before the deferred call landed
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.get("fx") == null:
		return
	if not legendary_entry.is_empty():
		main.fx.light_attach(self, {"radius": maxf(body_radius * 4.5, 34.0),
				"color": Color(0.85, 0.4, 1.0), "alpha": 0.30,
				"flicker": 0.25, "rate": 7.0, "casts": true})
	elif get("bar_color") != null:
		main.fx.light_attach(self, {"radius": maxf(body_radius * 4.0, 40.0),
				"color": get("bar_color"), "alpha": 0.26,
				"flicker": 0.2, "rate": 6.0, "casts": true})

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
	_level_hp_mult = hp_mult     # the level part only — capture_profile divides it out
	_level_dmg_mult = dmg_mult
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

# ---- what the bond carries away (R57) ---------------------------------------
# The pool key the pet skill roll reads for this body: bestiary archetype for
# normals, the legendary's chassis (dragon|hag|colossus) when one rides it.
# Boss subclasses override this so a hand-placed boss still finds a pool.
func capture_archetype() -> String:
	if not legendary_entry.is_empty():
		return str(legendary_entry.get("base", archetype))
	return archetype

# Everything needed to rebuild THIS body as a pet: the chassis it is drawn with
# (bundle/tint/scale/radius), the keys its skills roll from (species/element/
# archetype + any legendary kit), and PRE-LEVEL base stats plus the level rates,
# so pet.gd can re-derive hp/damage at whatever level the player is now.
# Values are plain JSON types — the record is saved with the character.
func capture_profile() -> Dictionary:
	var rates := _power_rates()
	var species_id := str(_entry.get("id", ""))
	if species_id.is_empty():
		species_id = "core.creature.gloamfen_stalker"   # hand-placed pack stalker
	var display := species_name if species_name != "" else "Gloam Stalker"
	return {
		"species": species_id,
		"species_name": display,
		"bundle": _bundle,
		"tint": [_base_tint.r, _base_tint.g, _base_tint.b],
		"scale": _scale * capture_scale,
		"body_radius": body_radius * capture_scale,
		"archetype": capture_archetype(),
		"element": str(_entry.get("element", "")),
		"kit": (legendary_entry.get("kit", []) as Array).duplicate(),
		# pre-level bases: undo the level curve _apply_entry baked in at spawn
		"base_hp": max_hp / maxf(_level_hp_mult, 0.01) * capture_hp_share,
		"base_damage": damage / maxf(_level_dmg_mult, 0.01) * capture_dmg_share,
		"base_speed": move_speed,
		"attack_reach": attack_reach,
		"attack_cd": attack_cd,
		"hp_rate": rates.x,
		"dmg_rate": rates.y,
	}

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

var _last_drawn_health := 1.0

func _refresh_health_drawing() -> void:
	var fraction := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	if fraction != _last_drawn_health:
		_last_drawn_health = fraction
		queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	_cd = maxf(_cd - delta, 0.0)
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_slow_t = maxf(_slow_t - delta, 0.0)
	_expose_t = maxf(_expose_t - delta, 0.0)
	var base_tint := Color(1, 1, 1) if _burn_t <= 0.0 else Color(1.5, 0.95, 0.6)
	if _slow_t > 0.0:
		base_tint *= Color(0.7, 0.9, 1.25)   # chilled: icy cast
	if _bleed_t > 0.0:
		base_tint *= Color(1.15, 0.72, 0.72)   # bleeding: raw-meat cast
	if _expose_t > 0.0:
		base_tint *= Color(1.1, 0.95, 1.2)     # exposed: pallid violet cast
	sprite.modulate = base_tint.lerp(Color(3, 3, 3), _flash)
	if _burn_t > 0.0:   # ignite DoT (Rune of Cinders + class skills): 0.5 s ticks
		_burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			dot_damage(_burn_dps * 0.5)
			if dead:
				return
	if _bleed_t > 0.0:   # Bleed: stacking phys DoT, dull-red ticks
		_bleed_t -= delta
		_bleed_tick -= delta
		if _bleed_tick <= 0.0:
			_bleed_tick = 0.5
			dot_damage(_bleed_dps * _bleed_stacks * 0.5, Color("d05a5a"))
			if dead:
				return
		if _bleed_t <= 0.0:
			_bleed_stacks = 0
	if _stagger_t > 0.0:   # staggered: DoTs keep ticking, the body does not move
		_stagger_t -= delta
		_update_anim()
		_refresh_health_drawing()
		return
	if _enrage_t > 0.0:
		_enrage_t -= delta
		if _enrage_t <= 0.0:
			sprite.self_modulate = _base_tint
	var player: Node2D = target_override if is_instance_valid(target_override) \
			else _nearest_player()
	if player == null or player.dead:
		_state = "idle"
	match _state:
		"idle":
			if not bot_drive:
				_idle(delta, player)
		"chase":
			if bot_drive:
				_state = "idle"   # policy-driven: no built-in chase decisions
			else:
				_chase(delta, player)
		"windup":
			_timer -= delta
			if _timer <= 0.0:
				_strike(player)
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "chase"
	# R59: every living, un-staggered body pushes off the PLAYER every tick —
	# chasing, winding up, recovering, or driven by a policy in the arena. That
	# is the bug Ricardo hit, and it is cheap: the "player" group holds one or
	# two nodes. A staggered body deliberately does not move at all: stagger is
	# CC. The O(n^2) creature-vs-creature pass is gated below.
	_separate_player(delta)
	# Creature-vs-creature is quadratic over a field capped at 120 bodies, so it
	# stays off for a sleeping one — that is the cost profile this file has
	# always had, since the only old call site was _chase. What changes is that
	# windup and recover now count as awake (a pile forms exactly while everyone
	# is mid-swing), and that an ARENA body always counts: bot_drive parks
	# `_state` at "idle" forever, and dh-sim separates all four duel bodies
	# unconditionally, so gating on _state alone would break runtime parity.
	if bot_drive or _state != "idle":
		_separate_creatures(delta)
	_update_anim()
	_refresh_health_drawing()

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

# ---- pose vocabulary (shared by every creature/boss subclass) --------------------
# Anticipation lean, strike recoil, hit squash, enrage pulse: all snap the sprite
# off base then spring HOME — one running tween max, killed on every re-trigger.

func _kill_pose_tw() -> void:
	if _pose_tw != null and _pose_tw.is_valid():
		_pose_tw.kill()
	_pose_tw = null

# Snap the sprite to an off-base pose and spring back to base (elastic).
# scale_mult is relative to the tuned base scale; rot in radians.
func _pose_punch(scale_mult: Vector2, rot := 0.0, dur := 0.25) -> void:
	if dead:
		return
	_kill_pose_tw()
	sprite.scale = Vector2(_scale * scale_mult.x, _scale * scale_mult.y)
	sprite.rotation = rot
	_pose_tw = create_tween().set_parallel(true)
	_pose_tw.tween_property(sprite, "scale", Vector2.ONE * _scale, dur) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pose_tw.tween_property(sprite, "rotation", 0.0, dur) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Windup anticipation: ease INTO a lean-back crouch over the telegraph window;
# the strike's own punch (every strike branch fires one) releases it to base.
func _anticipate(dir: Vector2, time: float) -> void:
	if dead:
		return
	_kill_pose_tw()
	var lean := -0.13 * (1.0 if dir.x >= 0.0 else -1.0)
	var t := clampf(time * 0.8, 0.1, 0.5)
	_pose_tw = create_tween().set_parallel(true)
	_pose_tw.tween_property(sprite, "scale",
			Vector2(_scale * 1.06, _scale * 0.9), t) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pose_tw.tween_property(sprite, "rotation", lean, t) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Strike release: lunge the pose INTO the attack direction, spring home.
func _strike_recoil(dir: Vector2, punch := 1.0) -> void:
	var horiz := absf(dir.x) >= absf(dir.y)
	var stretch := Vector2(1.0 + 0.18 * punch, 1.0 - 0.12 * punch) if horiz \
			else Vector2(1.0 - 0.12 * punch, 1.0 + 0.18 * punch)
	_pose_punch(stretch, 0.16 * punch * (1.0 if dir.x >= 0.0 else -1.0), 0.24)

# Hit reaction: squash perpendicular to the blow, spring back (white flash and
# the 6 px knockback nudge already live in take_damage).
func _hit_squash(from_dir: Vector2) -> void:
	if absf(from_dir.x) >= absf(from_dir.y):
		_pose_punch(Vector2(0.85, 1.15), 0.0, 0.22)
	else:
		_pose_punch(Vector2(1.15, 0.85), 0.0, 0.22)

# Radial pulse — enrages, blink landings, screeches.
func _pose_pulse(amount := 1.18, dur := 0.3) -> void:
	_pose_punch(Vector2(amount, amount), 0.0, dur)

func _idle(delta: float, player: Node2D) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.0, 3.0)
		_wander = Vector2.from_angle(randf() * TAU) * move_speed * 0.25
		if global_position.distance_to(pack_anchor) > 4.0 * TILE:
			_wander = (pack_anchor - global_position).normalized() * move_speed * 0.3
	_move(_wander * delta)
	if player == null or player.dead:
		return
	if arena_duel or global_position.distance_to(player.global_position) < aggro_range:
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
	# R59 (2026-09-21): separation moved to _physics_process. Calling it here
	# meant it ran ONLY while chasing, and _chase returns above the moment the
	# body is inside attack_reach * 0.9 — i.e. it switched off at exactly the
	# distance where bodies pile up. Old line kept for the record:
	# _separate(delta)   # (split into _separate_player / _separate_creatures)
	if not arena_duel and to_player.length() > aggro_range * 1.8:
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
	_pose_pulse(1.2)
	if _state == "idle":
		_state = "chase"

# MP HOOK (docs/tech/33): co-op has up to 4 hunters — creatures hunt the
# NEAREST living one instead of the first node in the group.
func _nearest_player() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p.dead:
			continue
		var d: float = p.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

# ARENA HOOK: policy-driven attack — the same windup/strike path the built-in
# AI uses, so telegraphs, recover windows and cooldowns all still apply.
func bot_attack(dir: Vector2) -> bool:
	if dead or _cd > 0.0 or _state == "windup":
		return false
	_begin_windup(dir)
	return true

func _begin_windup(dir: Vector2) -> void:
	_state = "windup"
	_timer = windup_time
	_attack_dir = dir
	_flash = 0.6
	threat = true
	sprite.flip_h = dir.x < 0.0
	sprite.play("lunge")
	sprite.frame = 0
	_anticipate(dir, windup_time)   # lean-back crouch — the tell reads in the body
	# Pooled amber danger ring under EVERY dangerous windup (spec §3) — migrated
	# from the old brute-only ProtoTelegraph node. Center + radius match the real
	# strike shape so the tell reads true; fire-and-forget (auto-expires with the
	# windup). `telegraphs` is mounted by main — guard via get() until it exists.
	var main := get_tree().get_first_node_in_group("main")
	var tg = main.get("telegraphs") if main else null
	if tg:
		var ring_pos := global_position
		var ring_r := attack_reach              # melee swipe: reach circle
		if archetype == "brute":
			ring_r = 2.2 * TILE                 # ground slam AoE (matches _strike)
		elif archetype == "lunger" and _pounce_target != Vector2.ZERO:
			ring_pos = _pounce_target           # telegraph the LANDING spot, not here
			ring_r = 1.6 * TILE
		tg.ring(ring_pos, ring_r, windup_time)

func _strike(player: Node2D) -> void:
	_state = "recover"
	_timer = 0.4
	_cd = attack_cd
	var main := get_tree().get_first_node_in_group("main")
	if archetype == "brute":   # ground slam: radial AoE — dodge OUT, not around
		_pose_punch(Vector2(1.3, 0.72), 0.0, 0.32)   # landing squash
		if main:
			main.shake(5.0)
			main.fx.shockwave(global_position, _base_tint, 48.0)
			main.fx.shader_burst("impact", global_position,
					{"size": 64.0, "color": Color(0.9, 0.7, 0.45)})   # fat impact nova (spec §3)
			main.fx.debris(global_position)
			main.fx.dust(global_position, 1.5)   # dust rolls out of the slam
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
		var launch := global_position
		for _i in 6:   # stepped so walkability still gates the leap
			_move(dash / 6.0)
		_pounce_target = Vector2.ZERO
		# pounce stretch: elongated along the leap, springs back on landing
		var horiz := absf(dash.x) >= absf(dash.y)
		_pose_punch(Vector2(1.32, 0.76) if horiz else Vector2(0.76, 1.32),
				0.12 * (1.0 if dash.x >= 0.0 else -1.0), 0.26)
		if main:
			main.fx.ribbon_streak(launch, global_position,
					{"color": _base_tint, "width": 6.0, "life": 0.22})   # leap streak (spec §3)
			main.fx.shockwave(global_position, _base_tint, 30.0)         # landing pop (spec §3)
			main.fx.dust(launch, 0.8)   # kick-off dirt at the launch point
			main.fx.burst(global_position, {"amount": 6, "lifetime": 0.25,
					"v_min": 30.0, "v_max": 90.0, "s_min": 0.6, "s_max": 1.2,
					"color": Color(0.7, 0.85, 0.9, 0.6)})
	else:
		_strike_recoil(_attack_dir)   # basic swipe: lunge into the bite
	var cos_half := cos(deg_to_rad(attack_arc_deg * 0.5))
	if player != null and not player.dead:
		var to_player := player.global_position - global_position
		# point-blank always connects: at zero separation the arc dot test
		# normalizes a zero vector and point-blank strikes would whiff
		if to_player.length() <= attack_reach + player.body_radius \
				and (to_player.length() <= 0.5 * player.body_radius \
				or to_player.normalized().dot(_attack_dir) >= cos_half):
			player.take_damage(damage, _attack_dir)
			if fiery:   # Fiery affix: +50% as a fire packet (resist-mitigated)
				player.take_damage(damage * 0.5, _attack_dir, "fire")
	# bonded pets are valid melee targets too (they rest at 0 HP, never die)
	for pet in get_tree().get_nodes_in_group("pet"):
		if pet.hp <= 0.0:
			continue
		var to_pet: Vector2 = pet.global_position - global_position
		if to_pet.length() <= attack_reach + pet.body_radius \
				and (to_pet.length() <= 0.5 * pet.body_radius \
				or to_pet.normalized().dot(_attack_dir) >= cos_half):
			pet.take_damage(damage, _attack_dir)

# R55-c (2026-09-22): this used to refuse the WHOLE step when the target was
# unwalkable, so a body that ran into the movement fence froze flat against it
# -- it could not even slide along the wall it was touching. `player.gd::_move`
# has had the axis-separated fallback since forever, and `hunt3d.gd` calls its
# copy "wall slide, 2D parity"; creatures never got one. It is a gameplay bug
# (a fleeing creature pins itself in a corner and dies to a wall, not to you)
# AND it was the arena/sim parity residual: `Arena::clamp_disc` projects onto
# the ring and KEEPS the tangential component, so the sim's retreating loser
# slid along the boundary and lived while the arena's stood still and died.
# Measured before this: chase phase 8.73 s in dh-env vs 3.58 s in the arena,
# 89% of the whole clock gap, while the exchange agreed at 1.08x.
func _move(step: Vector2) -> void:
	var world := get_tree().get_first_node_in_group("world")
	var target := global_position + step
	# A world that knows its own shape resolves the slide itself. Only the arena
	# ring does (`ArenaWorld::clamp_inside`), and it resolves it the way the sim
	# does -- radial projection, angle preserved -- so the two runtimes corner a
	# fleeing body identically instead of approximately. The tile grid in
	# `world_gen.gd` has no such closed form and takes the axis fallback below.
	if world != null and world.has_method("clamp_inside"):
		var slid: Vector2 = world.clamp_inside(target, body_radius)
		_step_accum += slid - global_position
		global_position = slid
		return
	if world == null or world.is_walkable(target):
		global_position = target
		_step_accum += step
	elif world.is_walkable(Vector2(target.x, global_position.y)):
		global_position.x = target.x
		_step_accum += Vector2(step.x, 0.0)
	elif world.is_walkable(Vector2(global_position.x, target.y)):
		global_position.y = target.y
		_step_accum += Vector2(0.0, step.y)

# R59 (2026-09-21, Ricardo: "make sure creatures collide with the player, so
# they are not right on top of me in a way I can't hit them (bizarre stuff and a
# bit annoying)"). Two bugs sat here:
#   (a) only the "creatures" group was iterated, so nothing ever pushed a body
#       off the hero — it could sit inside him, under the swing arc, forever;
#   (b) the call site was _chase, which returns before it inside attack_reach,
#       so separation was off at the one distance that needs it.
# Each body pushes only ITSELF. Two creatures therefore resolve symmetrically
# (both run this), while creature-vs-player is one-sided on purpose: the hero
# keeps authority over his own position, which is what "so I can hit them"
# means — he is never shoved out of his own swing.
const SEPARATE_RATE := 4.0          # /s, creature vs creature (unchanged)
const SEPARATE_RATE_PLAYER := 12.0  # /s, vs the player: the overlap that made
                                    # him unable to connect must clear fast

func _separate_creatures(delta: float) -> void:
	for other in get_tree().get_nodes_in_group("creatures"):
		if other == self or other.dead:
			continue
		_push_off(other.global_position, other.body_radius, SEPARATE_RATE, delta)

# The player — and, in an arena duel, the opposing player build — is a body too.
# The "player" group is NOT homogeneous: it holds ProtoPlayer in a hunt, an
# MpPuppet for the local hunter on a client (mp/client_hunt.gd), and in three
# probe harnesses a bare Node2D that exists only to give ProtoWorld a streaming
# focus. So duck-type it: a body whose radius we cannot read is a body we cannot
# push off. Reading `who.body_radius` directly raised "Invalid get index" every
# tick under residency_probe and took the whole _physics_process down with it.
func _separate_player(delta: float) -> void:
	for who in get_tree().get_nodes_in_group("player"):
		if who == self:
			continue
		var radius = who.get("body_radius")   # null when the property is absent
		if radius == null or who.get("dead"):
			continue
		_push_off(who.global_position, radius, SEPARATE_RATE_PLAYER, delta)

func _push_off(from: Vector2, other_radius: float, rate: float, delta: float) -> void:
	var d: Vector2 = global_position - from
	var min_d: float = body_radius + other_radius
	var distance_squared := d.length_squared()
	if distance_squared < min_d * min_d and distance_squared > 0.0001:
		var distance := sqrt(distance_squared)
		_move(d / distance * (min_d - distance) * rate * delta)

# Ignite (runes + class skills): refreshes the burn each application, but a
# weaker proc never erases a stronger burn's dps (same rule as Bleed stacks).
func ignite(dps: float, duration: float) -> void:
	if dead:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_t = duration
	threat = true

# Lightweight DoT tick (ignite/bleed/fields) — no knockback/flash spam.
func dot_damage(dmg: float, num_color := Color("ff9a3c")) -> void:
	if dead:
		return
	hp -= dmg
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.damage_number(global_position + Vector2(0, -14), dmg, num_color)
	if hp <= 0.0:
		_die()

# ---- skill-tree statuses (data keys from skill_trees.json "applies") -----------
# power = per-stack dps for DoTs (already skill-scaled by the caller).

func apply_status(key: String, power: float, duration: float) -> void:
	if dead:
		return
	threat = true
	match key:
		"chill":
			apply_slow(duration)
		"ignite":
			ignite(power, duration)
		"bleed":
			_bleed_stacks = mini(_bleed_stacks + 1, BLEED_MAX_STACKS)
			_bleed_dps = maxf(_bleed_dps, power)
			_bleed_t = duration
		"expose":
			_expose_t = maxf(_expose_t, duration)
		"stagger":
			_stagger_t = maxf(_stagger_t, duration)

# Accepts both the status key and the desc-friendly adjective ("chilled").
func has_status(key: String) -> bool:
	match key:
		"chill", "chilled":
			return _slow_t > 0.0
		"ignite", "ignited":
			return _burn_t > 0.0
		"bleed", "bleeding":
			return _bleed_t > 0.0
		"expose", "exposed":
			return _expose_t > 0.0
		"stagger", "staggered":
			return _stagger_t > 0.0
	return false

# Synergy consumers (Shatter, Exsanguinate, ...): the payoff spends the mark.
func clear_status(key: String) -> void:
	match key:
		"chill", "chilled":
			_slow_t = 0.0
		"ignite", "ignited":
			_burn_t = 0.0
		"bleed", "bleeding":
			_bleed_t = 0.0
			_bleed_stacks = 0
		"expose", "exposed":
			_expose_t = 0.0
		"stagger", "staggered":
			_stagger_t = 0.0

# Emberwake: this creature's burn leaps to packmates within radius (px).
func spread_ignite(radius: float) -> void:
	if dead or _burn_t <= 0.0:
		return
	for c in get_tree().get_nodes_in_group("creatures"):
		if c == self or c.dead:
			continue
		if c.global_position.distance_to(global_position) <= radius + c.body_radius:
			c.ignite(_burn_dps, maxf(_burn_t, 1.5))

# Cinderburst: consumes the burn, returning the remaining DoT total to the
# caller (player.gd deals it as an instant fire pop around this creature).
func detonate_ignite() -> float:
	if _burn_t <= 0.0:
		return 0.0
	var total := _burn_dps * _burn_t
	_burn_t = 0.0
	return total

# Wind burst (Rune of the Gale) pushes creatures around.
func shove(dir: Vector2, dist: float) -> void:
	if not dead:
		_move(dir.normalized() * dist)

func take_damage(dmg: float, from_dir: Vector2, spark_color: Variant = Color("cfd6ff"), crit := false) -> void:
	if dead:
		return
	if spark_color is String:   # ARENA: a player-style (dmg, dir, dmg_type) hit
		spark_color = Color("cfd6ff")   # landed on an unwrapped creature
	if _expose_t > 0.0:   # Exposed: +20% from ALL sources (skill-tree synergy)
		dmg *= EXPOSE_MULT
	hp -= dmg
	_flash = 1.0
	threat = true
	_move(from_dir.normalized() * 6.0)   # knockback nudge
	_hit_squash(from_dir)                # directional squash, springs back
	var main := get_tree().get_first_node_in_group("main")
	if main:
		# Pooled punchy number (spec §2.5 / §3): crit → gold + bigger pop. The spark
		# is pooled by main (routes to fx.burst). NO post.pulse per creature — a pack
		# taking simultaneous hits would strobe the whole screen.
		main.damage_number(global_position + Vector2(0, -18), dmg, Color("ffe9d0"), "", crit)
		main.hit_spark(global_position, spark_color)
		main.play_sfx("hit", global_position, -12.0)
	if _state == "idle":
		_state = "chase"
	if hp <= 0.0:
		_die()

# Death: 0.3 s collapse (squash to the ground + fade) instead of a blink-out.
# The corpse stops processing IMMEDIATELY (physics off, out of the "creatures"
# group — every consumer already filters `dead` too) and frees right after the
# collapse tween; loot/FX spawn up front via main.on_creature_died as before.
func _die() -> void:
	dead = true
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.on_creature_died(self)
	# Umbral things die INTO darkness: mix-blend smoke puff (umbra.gdshader) —
	# legendaries get a big rim-tinted void regardless of element.
	if main and main.get("fx") != null:
		if not legendary_entry.is_empty():
			main.fx.shader_burst("umbra", global_position,
					{"size": 120.0, "life": 0.9, "color": Color(0.88, 0.4, 1.0)})
		elif str(_entry.get("element", "")) == "umbral":
			main.fx.shader_burst("umbra", global_position,
					{"size": maxf(body_radius * 7.0, 56.0), "life": 0.7})
	remove_from_group("creatures")
	set_physics_process(false)
	queue_redraw()   # hides the health bar (guarded by `dead` in _draw)
	_kill_pose_tw()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale",
			Vector2(_scale * 1.25, _scale * 0.08), 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "position:y", -1.0, 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation", 0.0, 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)

func _draw() -> void:
	if dead or hp >= max_hp:
		return
	var w := body_radius * 2.4
	var y := -body_radius * 2.0 - 6.0
	draw_rect(Rect2(-w / 2, y, w, 3), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0, 1), 3), Color("c94f4f"))
