# PROTOTYPE HARNESS — orchestrator for the playable slice.
# World: real dh-procgen output (chunks.json) under a ~3-minute day/night cycle.
# Creatures: 14 packs sourced from the GENERATED BESTIARY when it exists
# (data/bestiary_normal.json, ~1000 species): each hunt samples 6-10 species
# fresh and every pack fields them via creature.setup_from_entry (archetype
# behavior + species tint/scale/stat/gold mults + optional baked art bundle);
# without catalogs the classic Gloamfen Stalker/Wisp mix spawns. FOUR boss
# hunts up the difficulty ladder: the Fenwitch Hag (Elite mid-boss, pack 8),
# the Pyre Sovereign + Terravore Colossus LEGENDARY DUO (pack 11) whose fire +
# earth fields fuse into LAVA while both live (the Duologue — canon §4
# field-combo system, spawn_field), ONE hunt legendary sampled from
# data/bestiary_legendary.json riding a signature chassis (pack 12), and the
# Emberwing Matriarch (pack 13). ALL bosses scale power with the player level
# (creature.gd _power_rates, Ricardo). Kills roll REAL item drops (items.gd),
# grant level-ups, shed Spirit Essences from abyssal prey, and Elites drop
# runes (canon §4). Pet capture (Soul Snares, F) fills up to 3 pet slots that
# all hunt together. This whole layer is the placeholder for dh-sim + dh-godot
# (docs/tech/21-22) — it exists to make the game feel real today.
extends Node2D

const TILE := 16.0
const WorldScene := preload("res://prototype/world_gen.gd")
const PlayerScene := preload("res://prototype/player.gd")
const CreatureScene := preload("res://prototype/creature.gd")
const WispScene := preload("res://prototype/wisp.gd")
const BossScene := preload("res://prototype/boss.gd")
const HagScene := preload("res://prototype/hag.gd")
const PyreScene := preload("res://prototype/pyre_sovereign.gd")
const ColossusScene := preload("res://prototype/terravore_colossus.gd")
const PetScene := preload("res://prototype/pet.gd")
const PickupScene := preload("res://prototype/pickup.gd")
const MinimapScene := preload("res://prototype/minimap.gd")
const AmbientScene := preload("res://prototype/ambient.gd")
const CharacterPanelScene := preload("res://prototype/ui/character_panel.gd")
const HAVEN_SCENE := "res://prototype/ui/haven.tscn"

const NIGHT_COLOR := Color(0.55, 0.62, 0.88)   # (proposal) sinusoidal ~3 min cycle
const DAY_CYCLE_S := 180.0
const PIP_ON := Color("59d6e6")
const PIP_OFF := Color(0.16, 0.28, 0.33, 0.7)

const LEVEL_CAP := 100           # (proposal) fast 1→100: quick dings all the way
const POINTS_PER_LEVEL := 5      # (proposal) attribute points per level-up
const ELITE_AFFIXES := ["Brutal", "Swift", "Fiery", "Bulwark"]   # effects registry
const ARCHETYPES := ["stalker", "stalker", "lunger", "brute"]     # spawn weights
const WISP_ELEMENTS := ["umbral", "umbral", "ember", "frost"]
# Canonical damage types (canon §4) -> the wisp bolt flavors the prototype has.
const ELEMENT_FLAVOR := {"fire": "ember", "frost": "frost"}       # rest -> umbral
const SPECIES_MIN := 6           # distinct species fielded per hunt (task 1)
const SPECIES_MAX := 10
const PACK_OFF_SPECIES := 0.25   # chance a member strays from the pack species
const LEGENDARY_SNARE_SHOWER := 0.10   # (proposal) Soul Snare shower on the kill
const ESSENCE_CHANCE := 0.08     # (proposal) Spirit Essence from abyssal kills
const RUNE_CHANCE_ELITE := 0.05  # (proposal) rune from Elite+ kills after the first

# Elemental fields (canon §4 tile field-interaction system, prototype stand-in).
# Per-kind visuals + slow; dps is per-spawn. Lava is the Duologue payoff: while
# BOTH duo bosses live, fire over earth (either order) fuses into lava —
# registries/fields.json combo table made playable. All numbers (proposal).
const FIELD_KINDS := {
	"fire": {"glow": Color(1.0, 0.45, 0.12), "glow_r": 1.5, "glow_a": 0.4,
			"pulse": 5.0, "amp": 0.3, "fill": Color(1.0, 0.35, 0.1, 0.22),
			"edge": Color(1.0, 0.5, 0.15, 0.6), "tele": Color(1.0, 0.55, 0.15, 0.35),
			"slow": 0.0},
	"earth": {"glow": Color(0.85, 0.6, 0.28), "glow_r": 1.2, "glow_a": 0.2,
			"pulse": 3.0, "amp": 0.15, "fill": Color(0.6, 0.44, 0.22, 0.24),
			"edge": Color(0.82, 0.6, 0.3, 0.6), "tele": Color(0.85, 0.6, 0.3, 0.35),
			"slow": 0.0},
	"mire": {"glow": Color(0.4, 0.85, 0.35), "glow_r": 1.3, "glow_a": 0.25,
			"pulse": 2.5, "amp": 0.2, "fill": Color(0.22, 0.45, 0.18, 0.28),
			"edge": Color(0.45, 0.8, 0.3, 0.6), "tele": Color(0.5, 0.85, 0.3, 0.35),
			"slow": 0.5},   # Creeping Mire: re-applied every tick while inside
	"lava": {"glow": Color(1.0, 0.32, 0.05), "glow_r": 1.8, "glow_a": 0.55,
			"pulse": 6.0, "amp": 0.35, "fill": Color(1.0, 0.22, 0.04, 0.32),
			"edge": Color(1.0, 0.65, 0.12, 0.85), "tele": Color(1.0, 0.4, 0.08, 0.4),
			"slow": 0.0},   # strongest glow of any field — it should read HOT
}
const LAVA_DPS := 14.0           # (proposal) hotter than fire (6-7) + earth (5)
const LAVA_DURATION := 10.0      # (proposal) outlasts both parent fields

var gold := 0
var kills := 0
var stones := 0
var snares := 0

var world: ProtoWorld
var player: ProtoPlayer
var boss: ProtoBoss              # the Matriarch (minimap marker keys off this)
# untyped on purpose: the hunt legendary rides whichever chassis its catalog
# base picked (boss/hag/duo classes) — the minimap draws its distinct marker
var legendary_boss: Variant = null
var _legendary_name := ""        # hint line flavor while the legendary stands
var camera: Camera2D
var fx: ProtoFx                  # pooled elemental VFX (fx.gd): bursts/lightning
var _bosses: Array = []          # every boss node: hag, duo pair, Matriarch
var _shake := 0.0
var _fields: Array = []          # {pos, radius, until, dps, tick, kind, glow}
var _scorches: Array = []        # {pos, until} — Rune of Cinders decals (visual)
var _fields_node: Node2D
var _hud := {}
var _kb_overlay: CanvasLayer     # K — keybind reference card
var _prev_dodge_charges := ProtoPlayer.DODGE_CHARGES_MAX
var _pip_flash := 0.0            # white flash when a dodge charge completes
var _q_flash := 0.0              # white flash when Shadow Rend comes off cooldown
var _q_was_ready := true
var _chip_t := 0.0               # pet-chip refresh accumulator (4 Hz)
var _char_panel: ProtoCharacterPanel
var _confirm: CanvasLayer
var _pets: Array = []            # live ProtoPet nodes, parallel to Session.pets
var _replace_window := 0.0       # F-again confirm window when pet slots are full
var _cycle: CanvasModulate
var _day_t := 0.0
var _sfx_players: Array = []     # 8 positional players, round-robin
var _sfx_idx := 0
var _ui_player: AudioStreamPlayer

func _ready() -> void:
	add_to_group("main")
	randomize()   # every hunt is a NEW world + fresh packs (Ricardo)
	y_sort_enabled = true

	world = WorldScene.new()
	world.add_to_group("world")
	add_child(world)

	player = PlayerScene.new()
	player.global_position = world.spawn_point()
	add_child(player)

	# Hunts are fresh; the character is not — carry state from the Session autoload.
	# Gear/attribute effects apply through player.apply_stats() (stats.gd).
	gold = Session.gold
	stones = Session.stones
	snares = Session.snares
	kills = Session.kills

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	camera.make_current()

	_fields_node = Node2D.new()
	_fields_node.z_index = -5
	add_child(_fields_node)
	_fields_node.draw.connect(_draw_fields)

	fx = ProtoFx.new()   # pooled one-shot emitters — nothing allocates mid-fight
	add_child(fx)

	# OPT-IN Vulkan/Metal HDR glow (canon §4): under forward_plus/mobile the
	# additive "emissive" sprites feed a real WorldEnvironment bloom. Nothing
	# changes on gl_compatibility (project.godot still ships it) — the only way
	# into this path is tools/run_vulkan.sh.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_hdr_threshold = 1.0   # only the hottest pixels bloom (tasteful)
		env.glow_intensity = 0.55
		env.glow_strength = 1.0
		env.glow_bloom = 0.04
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT   # soft, no smear
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)

	# day/night: CanvasModulate tints the world canvas only — HUD CanvasLayers escape it
	_cycle = CanvasModulate.new()
	_cycle.color = Color(1, 1, 1)
	add_child(_cycle)

	_build_audio()
	_spawn_packs()
	for pet_data in Session.pets:   # every bonded pet joins every hunt (3 slots)
		_spawn_pet(pet_data, world.random_walkable_in_ring(
				player.global_position, TILE, 2.5 * TILE))
	add_child(AmbientScene.new())   # spores + vignette (before HUD: same canvas layer)
	_build_hud()
	add_child(MinimapScene.new())
	_char_panel = CharacterPanelScene.new()
	add_child(_char_panel)
	_build_confirm()
	_build_keybinds()
	refresh_hud()

# Input actions live in Session.setup_input() (autoload — v4 Haven-close fix);
# the character panel owns its toggle/close keys itself.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("capture"):
		_try_capture()
	elif event.is_action_pressed("mount"):
		player.toggle_mount()
	elif event.is_action_pressed("toggle_keybinds"):
		_kb_overlay.visible = not _kb_overlay.visible
	elif event.is_action_pressed("ui_cancel"):
		_confirm.visible = not _confirm.visible

# ---- bestiary catalogs (generated by GenForge; graceful when absent) ----------
# Parsed ONCE per process into a static cache (60 FPS: no re-reads, no per-spawn
# parsing). Missing/invalid files simply yield an empty Array and the spawner
# falls back to the classic hand-authored mix.
static var _bestiary := {}       # kind ("normal"/"legendary") -> Array of entries

static func bestiary(kind: String) -> Array:
	if not _bestiary.has(kind):
		_bestiary[kind] = _load_bestiary(kind)
	return _bestiary[kind]

static func _load_bestiary(kind: String) -> Array:
	var out: Array = []
	var path := "res://prototype/data/bestiary_%s.json" % kind
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return out   # absent catalog: classic spawns (the other agent is baking)
	var json := JSON.new()   # instance API: a corrupt file warns, not ERROR-spams
	if json.parse(text) != OK:
		push_warning("bestiary_%s.json: parse error line %d — catalog ignored" % [
				kind, json.get_error_line()])
		return out
	var parsed: Variant = json.data
	var rows: Variant = parsed
	if typeof(parsed) == TYPE_DICTIONARY:   # accept {"entries": [...]} wrappers too
		for key in ["entries", "creatures", kind]:
			if typeof(parsed.get(key)) == TYPE_ARRAY:
				rows = parsed[key]
				break
	if typeof(rows) != TYPE_ARRAY:
		push_warning("bestiary_%s.json: unrecognized shape — catalog ignored" % kind)
		return out
	for e in rows:
		if typeof(e) == TYPE_DICTIONARY and not str(e.get("id", "")).is_empty() \
				and not str(e.get("name", "")).is_empty():
			out.append(e)
	if not out.is_empty():
		print("[bestiary] %s catalog: %d entries" % [kind, out.size()])
	return out

# Fresh species roster per hunt: 6-10 distinct entries sampled from the ~1000
# (task 1). One shuffle of a duplicated Array per hunt — nothing per-frame.
static func _sample_species() -> Array:
	var all := bestiary("normal")
	if all.is_empty():
		return []
	var pool := all.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(randi_range(SPECIES_MIN, SPECIES_MAX), pool.size()))

func _spawn_packs() -> void:
	# HORDES (Ricardo: "only 3 or so and the whole map is empty"): 14 packs of 3-7
	# spread across the map, half backed by 1-2 kiting wisps, leaders from pack 3
	# on are affixed elites. Pack members come from the hunt's species roster
	# (bestiary_normal.json) when it exists: each pack owns a primary species so
	# it reads as a pack, with ~25% strays for texture. Boss ladder by distance:
	# pack 8 nests the Fenwitch Hag (Elite mid-boss), pack 11 the Legendary DUO
	# (both together — canon §4), pack 12 the hunt's sampled LEGENDARY
	# (bestiary_legendary.json), the farthest the Matriarch. The first pack
	# guarantees a Bestial Skill stone drop (discovery).
	var roster := _sample_species()
	var ground: Array = roster.filter(
			func(e): return str(e.get("archetype", "")) != "wisp")
	var casters: Array = roster.filter(
			func(e): return str(e.get("archetype", "")) == "wisp")
	if not roster.is_empty():
		print("[hunt] species roster: %d ground + %d wisp of %d normals" % [
				ground.size(), casters.size(), bestiary("normal").size()])
	for i in 14:
		var anchor := world.random_walkable_in_ring(player.global_position,
				(10.0 + i * 3.0) * TILE, (16.0 + i * 3.5) * TILE)
		var pack_species: Dictionary = ground.pick_random() if not ground.is_empty() else {}
		var n := randi_range(3, 7)
		for j in n:
			var c := CreatureScene.new()
			# spawn-table variety: mixed archetypes; packs 3+ are led by an
			# affixed elite (Brutal/Swift/Fiery/Bulwark — see the CODEX)
			var affix: String = ELITE_AFFIXES.pick_random() if j == 0 and i >= 2 else ""
			if pack_species.is_empty():
				c.setup_archetype(ARCHETYPES.pick_random(), affix)
			else:
				var entry := pack_species
				if j > 0 and randf() < PACK_OFF_SPECIES:   # a stray for texture
					entry = ground.pick_random()
				c.setup_from_entry(entry, affix)
			c.global_position = world.random_walkable_in_ring(anchor, 0.0, 3.0 * TILE)
			c.pack_anchor = anchor
			if i == 0 and j == 0:
				c.guaranteed_stone = true   # players must find the Q skill
			add_child(c)
		if i % 2 == 1:
			for _w in randi_range(1, 2):
				var wisp := WispScene.new()
				if casters.is_empty():
					wisp.element = WISP_ELEMENTS.pick_random()
				else:   # catalog wisp: canonical element -> bolt flavor + species skin
					var wentry: Dictionary = casters.pick_random()
					wisp.element = ELEMENT_FLAVOR.get(
							str(wentry.get("element", "umbral")), "umbral")
					wisp.setup_from_entry(wentry)
				wisp.global_position = world.random_walkable_in_ring(
						anchor, 2.0 * TILE, 4.0 * TILE)
				wisp.pack_anchor = anchor
				add_child(wisp)
		if i == 8:
			var hag: ProtoHag = HagScene.new()
			hag.global_position = world.random_walkable_in_ring(anchor, 0.0, 2.0 * TILE)
			hag.pack_anchor = anchor
			add_child(hag)
			_bosses.append(hag)
		if i == 11:   # the Legendary duo nests TOGETHER — they hunt as one
			var pyre: ProtoPyreSovereign = PyreScene.new()
			var colossus: ProtoTerravoreColossus = ColossusScene.new()
			pyre.partner = colossus
			colossus.partner = pyre
			pyre.global_position = world.random_walkable_in_ring(anchor, 0.0, 2.0 * TILE)
			colossus.global_position = world.random_walkable_in_ring(
					anchor, 2.0 * TILE, 4.0 * TILE)
			pyre.pack_anchor = anchor
			colossus.pack_anchor = anchor
			add_child(pyre)
			add_child(colossus)
			_bosses.append(pyre)
			_bosses.append(colossus)
		if i == 12:   # the hunt's own legendary, sampled from the generated 100
			_spawn_legendary(anchor)
		if i == 13:
			boss = BossScene.new()
			boss.global_position = world.random_walkable_in_ring(anchor, 0.0, 2.0 * TILE)
			boss.pack_anchor = anchor
			add_child(boss)
			_bosses.append(boss)

# Hunt legendary (task 2): each hunt samples ONE entry from
# bestiary_legendary.json and spawns it at pack 12 riding a signature boss
# chassis — base "dragon" -> the Matriarch kit (boss.gd, fire fields),
# "colossus" -> earthshatter/spikes zoner (terravore_colossus.gd, partner-less),
# "hag" -> kiting caster (hag.gd). setup_legendary rescales the chassis by the
# entry's hp_mult (2.5-6) / dmg_mult (1.3-2.2) + tint/scale/bundle; death routes
# to on_legendary_died. No catalog -> no pack-12 boss (classic hunt).
func _spawn_legendary(anchor: Vector2) -> void:
	var pool := bestiary("legendary")
	if pool.is_empty():
		return
	var entry: Dictionary = pool.pick_random()
	# untyped on purpose: display_name/bar_color live on each chassis class
	var leg: Variant
	match str(entry.get("base", "dragon")):
		"colossus":
			leg = ColossusScene.new()
		"hag":
			leg = HagScene.new()
		_:
			leg = BossScene.new()   # dragon chassis (unknown bases land here too)
	leg.setup_legendary(entry)
	_legendary_name = str(entry.get("name", "???"))
	leg.display_name = "%s — Legendary" % _legendary_name.to_upper()
	var tint := ProtoCreature.tint_from(entry)
	if tint != Color(1, 1, 1):
		leg.bar_color = tint
	leg.global_position = world.random_walkable_in_ring(anchor, 0.0, 2.0 * TILE)
	leg.pack_anchor = anchor
	add_child(leg)
	_bosses.append(leg)
	legendary_boss = leg
	print("[hunt] legendary: %s (%s chassis) of %d" % [
			_legendary_name, str(entry.get("base", "dragon")), pool.size()])

func _physics_process(delta: float) -> void:
	# Camera shake decay
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 20.0, 0.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	_replace_window = maxf(_replace_window - delta, 0.0)
	# Day/night: sinusoidal ~3 min cycle; glow speckles/eyes pop at night naturally
	_day_t += delta
	var night := 0.5 - 0.5 * cos(TAU * _day_t / DAY_CYCLE_S)
	_cycle.color = Color(1, 1, 1).lerp(NIGHT_COLOR, night)
	_update_gauges(delta)
	# Elemental fields: the tile field-interaction system's prototype stand-in
	# (docs/tech/21 §5) — per-kind dps ("status" packets) and slow (Creeping Mire).
	var now := Time.get_ticks_msec() / 1000.0
	var dirty := false
	for f in _fields:
		if now > f.until:
			dirty = true
			continue
		f.tick -= delta
		if f.tick <= 0.0:
			f.tick = 0.25
			var k: Dictionary = FIELD_KINDS[f.kind]
			if f.get("friendly", false):
				# player-cast fields (class skill tree): tick CREATURES instead
				for c in get_tree().get_nodes_in_group("creatures"):
					if c.dead:
						continue
					if c.global_position.distance_to(f.pos) < f.radius + c.body_radius:
						if f.dps > 0.0:
							c.dot_damage(f.dps * 0.25, k.edge)
						if float(k.slow) > 0.0:
							c.apply_slow(float(k.slow))
			elif not player.dead and player.global_position.distance_to(f.pos) < f.radius:
				if f.dps > 0.0:
					player.take_damage(f.dps * 0.25, Vector2.ZERO, "status")
				if float(k.slow) > 0.0:
					player.apply_slow(float(k.slow))
	if dirty:
		for f in _fields:
			if now > f.until and is_instance_valid(f.get("glow")):
				f.glow.queue_free()
		_fields = _fields.filter(func(f): return now <= f.until)
	if not _scorches.is_empty() and now > _scorches[0].until:
		_scorches = _scorches.filter(func(s): return now <= s.until)
	_fields_node.queue_redraw()
	_update_boss_bar()

# Kept as the classic entry point (Matriarch's Magma Breath calls this).
func spawn_fire_field(at: Vector2, radius: float, duration: float, dps: float) -> void:
	spawn_field(at, radius, duration, dps, "fire")

# One field system, four kinds (fire/earth/mire/lava). The field LIGHTS the
# arena: per-kind pulsing additive glow (lava strongest) + landing telegraph
# ring + a per-kind ignition burst (canon §4 fake-bloom on gl_compatibility).
func spawn_field(at: Vector2, radius: float, duration: float, dps: float,
		kind := "fire", friendly := false) -> void:
	# THE DUOLOGUE (canon §4 + registries/fields.json combo table): while BOTH
	# duo bosses live, a fire field landing on an earth field (either order)
	# consumes both and fuses into LAVA — hotter, brighter, longer. Friendly
	# (player-cast, skill tree) fields never fuse — no griefing yourself.
	var counter: String = {"fire": "earth", "earth": "fire"}.get(kind, "")
	if counter != "" and not friendly and _duo_combo_active():
		var t_now := Time.get_ticks_msec() / 1000.0
		for f in _fields:
			if f.kind == counter and t_now <= f.until \
					and f.pos.distance_to(at) < (f.radius + radius) * 0.75:
				var mid: Vector2 = (f.pos + at) * 0.5
				f.until = 0.0   # consumed by the fusion
				if is_instance_valid(f.get("glow")):
					f.glow.queue_free()
				fx.explosion(mid, Color(1.0, 0.4, 0.08), true)
				shake(4.0)
				damage_number(mid + Vector2(0, -20), 0, Color("ff5a2e"), "LAVA!")
				spawn_field(mid, maxf(f.radius, radius) * 1.05,
						LAVA_DURATION, LAVA_DPS, "lava")
				return
	var k: Dictionary = FIELD_KINDS[kind]
	var glow := ProtoGlow.make(k.glow, radius * float(k.glow_r), float(k.glow_a),
			float(k.pulse), float(k.amp))
	glow.position = at
	glow.z_index = 2
	add_child(glow)
	var tg := ProtoTelegraph.new()
	tg.radius = radius
	tg.duration = 0.45
	tg.color = k.tele
	tg.position = at
	add_child(tg)
	match kind:
		"fire":
			fx.flame_cone(at, Vector2.UP)
		"lava":
			fx.flame_cone(at, Vector2.UP)
			fx.debris(at, Color(0.35, 0.12, 0.05))
		"earth":
			fx.debris(at)
		"mire":
			fx.burst(at, {"amount": 10, "lifetime": 0.4, "v_min": 20.0, "v_max": 70.0,
					"gravity": Vector2(0, -50), "s_min": 0.8, "s_max": 1.6,
					"color": Color(0.5, 0.9, 0.4, 0.6)})
	_fields.append({"pos": at, "radius": radius,
			"until": Time.get_ticks_msec() / 1000.0 + duration, "dps": dps, "tick": 0.0,
			"glow": glow, "kind": kind, "friendly": friendly})

# The Duologue is only live while BOTH Legendary duo bosses stand (canon §4).
func _duo_combo_active() -> bool:
	var alive := 0
	for b in _bosses:
		if is_instance_valid(b) and b is ProtoDuoBoss and not b.dead:
			alive += 1
	return alive >= 2

# Rune of Cinders: brief ground scorch decal (visual only, proposal).
func spawn_scorch(at: Vector2) -> void:
	_scorches.append({"pos": at, "until": Time.get_ticks_msec() / 1000.0 + 0.8})

func _draw_fields() -> void:
	for f in _fields:
		var k: Dictionary = FIELD_KINDS[f.kind]
		_fields_node.draw_circle(f.pos, f.radius, k.fill)
		_fields_node.draw_arc(f.pos, f.radius, 0, TAU, 40, k.edge, 2.0)
	var now := Time.get_ticks_msec() / 1000.0
	for s in _scorches:
		var a := clampf((s.until - now) / 0.8, 0.0, 1.0)
		_fields_node.draw_circle(s.pos, 8.0, Color(0.95, 0.45, 0.15, 0.3 * a))
		_fields_node.draw_arc(s.pos, 8.0 + (1.0 - a) * 5.0, 0, TAU, 16,
				Color(1.0, 0.6, 0.2, 0.5 * a), 1.5)

# ---- combat feedback -------------------------------------------------------

func hitstop() -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func hit_spark(at: Vector2, color: Color) -> void:
	# two-tone: the passed-through hue plus a few hot white pixels
	_spark_burst(at, color, 12, 60.0, 140.0, 1.0, 2.5)
	_spark_burst(at, Color(1, 1, 1, 0.95), 5, 90.0, 180.0, 0.7, 1.4)

func _spark_burst(at: Vector2, color: Color, amount: int, v_min: float, v_max: float,
		s_min: float, s_max: float) -> void:
	var p := CPUParticles2D.new()
	p.global_position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.35
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = Vector2(0, 220)
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.color = color
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

func damage_number(at: Vector2, amount: float, color: Color, text := "") -> void:
	var label := Label.new()
	label.text = text if text != "" else str(int(round(amount)))
	label.modulate = color
	label.z_index = 50
	label.position = at + Vector2(randf_range(-6, 6), 0)
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 24.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(label.queue_free)

# ---- procedural SFX (sfx.gd static cache; 8 positional players, round-robin) ---

func _build_audio() -> void:
	ProtoSfx.warm()   # synthesize every stream once, up front — no mid-fight hitch
	for i in 8:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 480.0
		add_child(p)
		_sfx_players.append(p)
	_ui_player = AudioStreamPlayer.new()
	add_child(_ui_player)

func play_sfx(sfx_name: String, at: Vector2, vol_db := -8.0) -> void:
	var p: AudioStreamPlayer2D = _sfx_players[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_players.size()
	p.stream = ProtoSfx.stream(sfx_name)
	p.global_position = at
	p.volume_db = vol_db
	p.play()

func play_ui(sfx_name: String, vol_db := -8.0) -> void:
	_ui_player.stream = ProtoSfx.stream(sfx_name)
	_ui_player.volume_db = vol_db
	_ui_player.play()

# ---- pet capture (canon §3, design/13 §7.1 — now THREE slots, proposal) ---------

# F: consume a Soul Snare on a weakened (<35% HP) stalker within 3 m.
# Capture chance = 0.25 + 0.6 * (1 - hp/max_hp)  (proposal). With all pet slots
# full, the first F opens a 3 s confirm window; F again replaces the OLDEST bond.
func _try_capture() -> void:
	if player.dead:
		return
	if snares <= 0:
		damage_number(player.global_position + Vector2(0, -24), 0,
				Color(0.7, 0.9, 1.0, 0.9), "no Soul Snare — stalkers drop them")
		return
	var best: ProtoCreature = null
	var best_d := 3.0 * TILE
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead or not c.capturable:
			continue
		var d: float = c.global_position.distance_to(player.global_position)
		if d <= best_d:
			best_d = d
			best = c
	if best == null:
		damage_number(player.global_position + Vector2(0, -24), 0,
				Color(0.7, 0.9, 1.0, 0.9), "no stalker within 3 m")
		return
	if best.hp > best.max_hp * 0.35:
		damage_number(best.global_position + Vector2(0, -24), 0,
				Color(0.7, 0.9, 1.0, 0.9), "too strong — wound it below 35%")
		return
	if Session.pets.size() >= Session.MAX_PETS and _replace_window <= 0.0:
		_replace_window = 3.0
		damage_number(player.global_position + Vector2(0, -24), 0,
				Color(0.7, 0.9, 1.0, 0.9), "pet slots full — F again in 3 s stables %s"
				% str(Session.pets[0].get("name", "?")))
		return
	_replace_window = 0.0
	snares -= 1
	var chance := 0.25 + 0.6 * (1.0 - best.hp / best.max_hp)
	if randf() < chance:
		play_ui("capture", -6.0)
		if Session.pets.size() >= Session.MAX_PETS:   # oldest bond goes to the STABLES
			var old: Dictionary = Session.pets.pop_front()
			Session.stables.append(old)   # never abandoned (Ricardo) — Pets tab manages
			if not _pets.is_empty():
				var old_node: Node2D = _pets.pop_front()
				if is_instance_valid(old_node):
					old_node.queue_free()
			damage_number(player.global_position + Vector2(0, -36), 0,
					Color(0.7, 0.9, 1.0, 0.8), "%s sent to the stables" % str(old.get("name", "")))
		var data := _roll_pet()
		Session.pets.append(data)
		var at: Vector2 = best.global_position
		hit_spark(at, Color("7fe7ff"))
		damage_number(at + Vector2(0, -24), 0, Color("7fe7ff"), "BONDED — %s (pet %d/%d)"
				% [data["name"], Session.pets.size(), Session.MAX_PETS])
		best.dead = true   # removed, not killed: no loot, no kill credit
		best.queue_free()
		_spawn_pet(data, at)
	else:
		play_ui("snare_fail", -6.0)
		damage_number(best.global_position + Vector2(0, -24), 0, Color("ff8a7a"), "RESISTED!")
		best.enrage(5.0)   # +30% speed for 5 s
	_sync_session()
	refresh_hud()

# INSTANCE ROLL per canon §3: 2-3 skills from the Abyssal pool (abyssal.json) —
# species signature weighted ~70%, family-shared ~30%, at least 1 signature —
# plus a 70-110% attribute roll applied to hp/damage.
func _roll_pet() -> Dictionary:
	var fam: Dictionary = Session.load_content("abyssal")
	var sig_pool: Array = []
	for sp in fam.get("species", []):
		if str(sp.get("creature", "")) == "core.creature.gloamfen_stalker":
			sig_pool = (sp.get("signature_skills", []) as Array).duplicate()
	if sig_pool.is_empty():
		sig_pool = ["core.skill.shadow_rend"]
	var shared_pool: Array = (fam.get("family_shared_skills", []) as Array).duplicate()
	var slots := randi_range(2, 3)
	var skills: Array = [sig_pool.pop_front()]   # signature guaranteed
	while skills.size() < slots and (not sig_pool.is_empty() or not shared_pool.is_empty()):
		var from_sig := randf() < 0.7
		var pool := sig_pool if (from_sig and not sig_pool.is_empty()) or shared_pool.is_empty() \
				else shared_pool
		var pick: Variant = pool.pick_random()
		pool.erase(pick)
		skills.append(pick)
	var roll := randi_range(70, 110)
	return {"uid": ProtoItems.next_uid(), "name": "Gloam Stalker %d%%" % roll,
			"species": "core.creature.gloamfen_stalker",
			"roll_pct": roll, "skills": skills}

func _spawn_pet(data: Dictionary, at: Vector2) -> void:
	var p := PetScene.new()
	p.setup(data)
	p.global_position = at
	add_child(p)
	_pets.append(p)

# Character panel hook: active/stabled swaps mid-hunt rebuild the live pet nodes.
func sync_pet_nodes() -> void:
	for p in _pets:
		if is_instance_valid(p):
			p.queue_free()
	_pets.clear()
	for pet_data in Session.pets:
		_spawn_pet(pet_data, world.random_walkable_in_ring(
				player.global_position, TILE, 2.5 * TILE))

# ---- session persistence (Session autoload survives scene changes) -----------

func _sync_session() -> void:
	Session.gold = gold
	Session.stones = stones
	Session.snares = snares
	Session.kills = kills
	Session.request_save()   # throttled autosave (2 s) — characters persist

func _return_to_haven() -> void:
	Engine.time_scale = 1.0   # in case a hitstop was in flight
	_sync_session()
	get_tree().change_scene_to_file(HAVEN_SCENE)

func _build_confirm() -> void:
	_confirm = CanvasLayer.new()
	_confirm.layer = 5
	_confirm.visible = false
	add_child(_confirm)
	var pc := PanelContainer.new()
	pc.theme = ProtoTheme.get_theme()
	pc.custom_minimum_size = Vector2(200, 0)
	pc.position = Vector2(220, 140)
	_confirm.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	var q := Label.new()
	q.text = "Return to Haven?"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_color_override("font_color", Color("ff9a3c"))
	vb.add_child(q)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var yes := Button.new()
	yes.text = "Yes"
	yes.custom_minimum_size = Vector2(64, 0)
	yes.pressed.connect(_return_to_haven)
	hb.add_child(yes)
	var no := Button.new()
	no.text = "No"
	no.custom_minimum_size = Vector2(64, 0)
	no.pressed.connect(func() -> void: _confirm.visible = false)
	hb.add_child(no)

# ---- economy: REAL loot ------------------------------------------------------

func on_creature_died(c: ProtoCreature) -> void:
	kills += 1
	hit_spark(c.global_position, Color("6b4f8f"))
	fx.explosion(c.global_position, Color(0.55, 0.35, 0.85))   # umbral death bloom
	fx.debris(c.global_position)
	play_sfx("hit", c.global_position, -5.0)   # heavier death thud
	shake(1.5)
	_drop(c.global_position, "gold", randi_range(c.gold_min, c.gold_max))
	if c.guaranteed_stone or randf() < c.stone_chance:
		_drop(c.global_position + Vector2(10, 0), "stone", 1)
	if randf() < c.snare_chance:
		_drop(c.global_position + Vector2(-10, 4), "snare", 1)
	# REAL item rolls (items.gd): base pool + rarity weights by tier, rolled at
	# the hunter's level so drops keep pace with the scaled monsters (proposal)
	if randf() < c.item_chance:
		_drop_item(ProtoItems.roll_loot(c.elite, Session.level),
				c.global_position + Vector2(4, 10))
	if c.capturable and randf() < ESSENCE_CHANCE:   # Spirit Essence: abyssal kills
		_drop_item(ProtoItems.make_essence(), c.global_position + Vector2(-14, -4))
	if c.elite:
		_maybe_drop_rune(c.global_position + Vector2(0, -14))
	_grant_level_ups()
	_sync_session()
	refresh_hud()

func on_boss_died(b: ProtoBoss) -> void:
	hit_spark(b.global_position, Color("ff7a33"))
	fx.explosion(b.global_position, Color(1.0, 0.55, 0.18), true)
	fx.debris(b.global_position, Color(0.5, 0.32, 0.2))
	fx.lightning(b.global_position + Vector2(-22, 0))   # the sky answers
	fx.lightning(b.global_position + Vector2(26, -8))
	play_ui("victory", -4.0)
	shake(8.0)
	# Signature drop: the Emberfang Blade minted as a REAL legendary instance
	# (implicit fire roll + 4 affixes). Elite item/rune rolls run in on_creature_died.
	_drop_item(ProtoItems.roll_item("emberfang_blade", "legendary", Session.level, 0.35),
			b.global_position + Vector2(-12, 0))
	damage_number(b.global_position + Vector2(0, -40), 0, Color("ffd166"), "MATRIARCH FELLED!")
	if not Session.owns_mount("emberwing_drakeling"):   # her brood takes to you
		Session.grant_mount({"uid": ProtoItems.next_uid(), "key": "emberwing_drakeling",
				"name": "Emberwing Drakeling", "kind": "fly", "speed_mult": 1.9,
				"rarity": "legendary", "tint": "ff9a5c"})
		damage_number(b.global_position + Vector2(0, -54), 0, Color("ff9a3c"),
				"MOUNT BONDED — Emberwing Drakeling (press M to FLY)")
	_hud.hint.text = "Victory — the Emberfang Blade is yours. Forge/enchant/sell at the Haven (Esc)."

# The Fenwitch Hag (Elite mid-boss): elite loot/rune rolls run in
# on_creature_died; this adds the boss-kill flourish.
func on_hag_died(h: Node2D) -> void:
	hit_spark(h.global_position, Color("a06ce0"))
	fx.explosion(h.global_position, Color(0.62, 0.42, 0.9), true)
	play_ui("victory", -6.0)
	shake(6.0)
	damage_number(h.global_position + Vector2(0, -40), 0, Color("cf9dff"),
			"THE FENWITCH FALLS!")

# Legendary duo (canon §4): each boss guarantees an epic+ item (proposal: 25%
# legendary). First death enrages the survivor; second is the real victory.
func on_duo_boss_died(b: ProtoDuoBoss) -> void:
	hit_spark(b.global_position, b.bar_color)
	fx.explosion(b.global_position, b.bar_color, true)
	fx.debris(b.global_position, Color(0.5, 0.32, 0.2))
	shake(8.0)
	var rarity := "legendary" if randf() < 0.25 else "epic"
	_drop_item(ProtoItems.roll_item(ProtoItems.ALL_BASES.pick_random(), rarity,
			Session.level, 0.35), b.global_position + Vector2(-12, 0))
	# untyped on purpose: the partner may already be a freed instance, and
	# assigning a freed object to a typed var is a runtime error
	var mate: Variant = b.partner
	if is_instance_valid(mate) and not mate.dead:
		mate.avenge()   # the Duologue dies with the fallen; fury remains
		damage_number(b.global_position + Vector2(0, -40), 0, Color("ffd166"),
				"ONE FALLS — the other AVENGES!")
		_hud.hint.text = "Half the duo is down — the survivor is enraged. Finish it."
	else:
		fx.lightning(b.global_position + Vector2(-22, 0))
		fx.lightning(b.global_position + Vector2(26, -8))
		play_ui("victory", -4.0)
		damage_number(b.global_position + Vector2(0, -40), 0, Color("ffd166"),
				"THE LEGENDARY DUO FALLS!")
		_hud.hint.text = "Victory — Legendary spoils twice over. Forge/enchant/sell at the Haven (Esc)."

# Hunt legendary down (task 2): guaranteed rare+ item (proposal weights
# 60/30/10 rare/epic/legendary) on top of the chassis's elite rolls; gold
# already rides the entry's gold_mult + the boss power curve through
# on_creature_died; 10% chance of a Soul Snare shower (proposal, 5 snares).
func on_legendary_died(b) -> void:
	hit_spark(b.global_position, b.bar_color)
	fx.explosion(b.global_position, b.bar_color, true)
	fx.debris(b.global_position, Color(0.5, 0.32, 0.2))
	fx.lightning(b.global_position + Vector2(-22, 0))
	fx.lightning(b.global_position + Vector2(26, -8))
	play_ui("victory", -4.0)
	shake(8.0)
	var r := randf()
	var rarity := "rare"
	if r < 0.10:
		rarity = "legendary"
	elif r < 0.40:
		rarity = "epic"
	# quality 0.5: a legendary kill never drops bottom-of-band rolls (Ricardo)
	_drop_item(ProtoItems.roll_item(ProtoItems.ALL_BASES.pick_random(), rarity,
			Session.level, 0.5), b.global_position + Vector2(-12, 0))
	if randf() < LEGENDARY_SNARE_SHOWER:
		for k in 5:
			_drop(b.global_position + Vector2(randf_range(-24, 24),
					randf_range(-24, 24)), "snare", 1)
		damage_number(b.global_position + Vector2(0, -54), 0, Color("7fe7ff"),
				"SOUL SNARE SHOWER!")
	damage_number(b.global_position + Vector2(0, -40), 0, Color("d84aff"),
			"%s FALLS!" % str(b.species_name).to_upper())
	legendary_boss = null
	_legendary_name = ""
	_hud.hint.text = "The hunt's Legendary falls — rare spoils are yours. Forge/enchant/sell at the Haven (Esc)."

# Runes (canon §4): guaranteed on the FIRST Elite kill, then 5% per Elite+ kill
# (proposal). Prefers a rune the player doesn't own yet.
func _maybe_drop_rune(at: Vector2) -> void:
	if Session.rune_granted and randf() >= RUNE_CHANCE_ELITE:
		return
	Session.rune_granted = true
	var owned := Session.owned_rune_keys()
	var pool: Array = []
	for def in ProtoItems.rune_defs():
		if not owned.has(str(def.get("key", ""))):
			pool.append(str(def.get("key", "")))
	if pool.is_empty():
		for def in ProtoItems.rune_defs():
			pool.append(str(def.get("key", "")))
	_drop_item(ProtoItems.make_rune(pool.pick_random()), at)

# Fast 1→100 curve (Ricardo loved the 1-10 pace): level n needs 10 + n/2 kills,
# ~3.5k kills to cap. Early dings every ~10 kills, endgame ~60.
func _kills_for_level(lvl: int) -> int:
	return 10 + int(lvl * 0.5)

func _level_for_kills(k: int) -> int:
	var lvl := 1
	var need := 0
	while lvl < LEVEL_CAP:
		need += _kills_for_level(lvl)
		if k < need:
			break
		lvl += 1
	return lvl

func _level_progress(k: int) -> float:
	var lvl := 1
	var need := 0
	while lvl < LEVEL_CAP:
		var prev := need
		need += _kills_for_level(lvl)
		if k < need:
			return float(k - prev) / float(need - prev)
		lvl += 1
	return 1.0

func _grant_level_ups() -> void:
	var new_level := _level_for_kills(kills)
	if new_level <= Session.level:
		return
	var levels := new_level - Session.level
	var gained := levels * POINTS_PER_LEVEL
	Session.level = new_level
	Session.attribute_points += gained
	Session.skill_points += levels   # 1 skill point per level (Reaver tree)
	play_ui("victory", -6.0)
	shake(3.0)
	fx.lightning(player.global_position)   # the sky marks the hunter
	hit_spark(player.global_position, Color("ffd166"))
	damage_number(player.global_position + Vector2(0, -36), 0, Color("ffd166"),
			"LEVEL %d!" % new_level)
	damage_number(player.global_position + Vector2(0, -24), 0, Color("ffe9d0"),
			"+%d attribute points · +%d skill point (C)" % [gained, levels])
	player.apply_stats()   # higher level unlocks higher affix tiers on future rolls

func _drop(at: Vector2, kind: String, amount: int) -> void:
	var pk := PickupScene.new()
	pk.kind = kind
	pk.amount = amount
	pk.global_position = at + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	add_child(pk)

func _drop_item(item: Dictionary, at: Vector2) -> void:
	var pk := PickupScene.new()
	pk.kind = "item"
	pk.item = item
	pk.global_position = at + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	add_child(pk)

# pickup.gd gate: item drops stay on the ground while the bag is full (cap 40).
func can_collect_item() -> bool:
	return Session.inventory.size() < ProtoItems.INVENTORY_CAP

func collect(kind: String, amount: int, at: Vector2, item: Dictionary = {}) -> void:
	play_sfx("pickup", at, -10.0)
	match kind:
		"gold":
			gold += amount
			damage_number(at, 0, Color("ffd166"), "+%d gold" % amount)
		"stone":
			var first := stones == 0
			stones += amount
			damage_number(at, 0, Color("b06cff"), "Bestial Skill stone!")
			if first:   # owning a stone awakens the bestial slot
				damage_number(at + Vector2(0, -14), 0, Color("cf9dff"),
						"SHADOW REND awakened — press Q")
				_hud.hint.text = _hint_text()
		"snare":
			snares += amount
			damage_number(at, 0, Color("7fe7ff"), "Soul Snare!")
		"item":
			_collect_item(item, at)
	_sync_session()
	refresh_hud()

func _collect_item(item: Dictionary, at: Vector2) -> void:
	var col := ProtoItems.rarity_color(str(item.get("rarity", "common")))
	var slot := str(item.get("slot", ""))
	# QoL (proposal): gear auto-equips into an EMPTY slot; everything else bags.
	if ProtoItems.GEAR_SLOTS.has(slot) \
			and (Session.equipment[slot] as Dictionary).is_empty():
		Session.equipment[slot] = item
		if str(item.get("base_id", "")) == "core.item.emberfang_blade":
			Session.has_blade = true
		player.apply_stats()
		damage_number(at, 0, col, "%s — equipped" % str(item.get("name", "?")))
	else:
		Session.add_item(item)   # can_collect_item() gated the pickup
		damage_number(at, 0, col, str(item.get("name", "?")))
	if slot == "rune":
		damage_number(at + Vector2(0, -14), 0, Color("cf9dff"),
				"a RUNE — socket it on a skill (C - Skills)")

# Panel/vendor hook — gold earned or spent mid-hunt flows through main.
func add_gold(amount: int) -> void:
	gold += amount
	_sync_session()
	refresh_hud()

func on_player_death() -> void:
	# Death rules taste (design/12 owns them): lose 25% of carried Gold.
	var lost := int(gold * 0.25)
	gold -= lost
	_sync_session()
	_hud.hint.text = "You died — %d gold lost to the dark. Respawning..." % lost
	refresh_hud()
	await get_tree().create_timer(2.0).timeout
	player.respawn(world.spawn_point())
	# Pets reset WITH the hunter: full HP beside the player (they never die).
	for p in _pets:
		if is_instance_valid(p):
			p.reset_at(world.random_walkable_in_ring(
					player.global_position, TILE, 2.5 * TILE))
	_hud.hint.text = _hint_text()
	refresh_hud()

# ---- HUD --------------------------------------------------------------------

const HINT_TEXT := "LMB cleave · Shift dodge x3 · Q rend · E whirlwind · 1-4 skills · Z mount · F bond · C character · K keys · Esc haven"

func _hint_text() -> String:
	var t := HINT_TEXT
	if stones >= 1:
		t += " · Q shadow rend"
	t += " — hunt the Fenwitch Hag, the Legendary duo, the Matriarch"
	if _legendary_name != "":
		t += " · a LEGENDARY prowls: %s" % _legendary_name
	return t

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.position = Vector2(12, 12)
	hp_bg.size = Vector2(184, 14)
	canvas.add_child(hp_bg)
	var hp_bar := ColorRect.new()
	hp_bar.color = Color("58c470")
	hp_bar.position = Vector2(2, 2)
	hp_bar.size = Vector2(180, 10)
	hp_bg.add_child(hp_bar)
	# dodge charge pips — 3 small cyan bars under the HP bar (dim when spent)
	var pips: Array = []
	for i in 3:
		var pip := ColorRect.new()
		pip.color = PIP_ON
		pip.position = Vector2(12 + i * 14, 29)
		pip.size = Vector2(10, 4)
		canvas.add_child(pip)
		pips.append(pip)
	# XP progress to the next level (kills-based, proposal) — thin gold sliver
	var xp_bg := ColorRect.new()
	xp_bg.color = Color(0, 0, 0, 0.55)
	xp_bg.position = Vector2(12, 35)
	xp_bg.size = Vector2(90, 3)
	canvas.add_child(xp_bg)
	var xp_bar := ColorRect.new()
	xp_bar.color = Color("ffd166")
	xp_bar.size = Vector2(0, 3)
	xp_bg.add_child(xp_bar)
	# pet chips: bonded pets at a glance (name + hunting/resting state)
	var pet_chips: Array = []
	for i in 3:
		var chip := Label.new()
		chip.position = Vector2(12, 296 + i * 12)
		chip.add_theme_font_size_override("font_size", 8)
		canvas.add_child(chip)
		pet_chips.append(chip)
	# Shadow Rend (Q) cooldown gauge — fills as the cooldown burns, glows when ready
	var q_label := Label.new()
	q_label.text = "Q"
	q_label.position = Vector2(56, 22)
	q_label.add_theme_font_size_override("font_size", 10)
	canvas.add_child(q_label)
	var q_bg := ColorRect.new()
	q_bg.color = Color(0, 0, 0, 0.55)
	q_bg.position = Vector2(68, 29)
	q_bg.size = Vector2(36, 6)
	canvas.add_child(q_bg)
	var q_bar := ColorRect.new()
	q_bar.color = Color("8a5cff")
	q_bar.position = Vector2(2, 1)
	q_bar.size = Vector2(32, 4)
	q_bg.add_child(q_bar)
	# Whirlwind (E) gauge — same treatment, steel-blue
	var e_label := Label.new()
	e_label.text = "E"
	e_label.position = Vector2(110, 22)
	e_label.add_theme_font_size_override("font_size", 10)
	canvas.add_child(e_label)
	var e_bg := ColorRect.new()
	e_bg.color = Color(0, 0, 0, 0.55)
	e_bg.position = Vector2(122, 29)
	e_bg.size = Vector2(36, 6)
	canvas.add_child(e_bg)
	var e_bar := ColorRect.new()
	e_bar.color = Color("6fb7ff")
	e_bar.position = Vector2(2, 1)
	e_bar.size = Vector2(32, 4)
	e_bg.add_child(e_bar)
	# skill bar (1-4): class-tree actives — chips in the Q/E gauge style, one
	# row below (cooldown fill + the assigned skill's leading name word)
	var slots: Array = []
	for i in 4:
		var x := 56.0 + i * 52.0
		var s_key := Label.new()
		s_key.text = str(i + 1)
		s_key.position = Vector2(x, 38)
		s_key.add_theme_font_size_override("font_size", 10)
		canvas.add_child(s_key)
		var s_bg := ColorRect.new()
		s_bg.color = Color(0, 0, 0, 0.55)
		s_bg.position = Vector2(x + 10, 45)
		s_bg.size = Vector2(36, 6)
		canvas.add_child(s_bg)
		var s_bar := ColorRect.new()
		s_bar.color = Color("c9853c")
		s_bar.position = Vector2(2, 1)
		s_bar.size = Vector2(32, 4)
		s_bg.add_child(s_bar)
		var s_name := Label.new()
		s_name.position = Vector2(x + 10, 52)
		s_name.add_theme_font_size_override("font_size", 7)
		s_name.modulate = Color(1, 1, 1, 0.6)
		canvas.add_child(s_name)
		slots.append({"key": s_key, "bar": s_bar, "name": s_name})
	# class charge chip (Veilblade Combo / Gloam Mage Attunement)
	var charge := Label.new()
	charge.position = Vector2(268, 43)
	charge.add_theme_font_size_override("font_size", 9)
	charge.add_theme_color_override("font_color", Color("cf9dff"))
	canvas.add_child(charge)
	var stats := Label.new()
	stats.position = Vector2(12, 60)
	canvas.add_child(stats)
	var hint := Label.new()
	hint.text = _hint_text()
	hint.position = Vector2(12, 334)
	hint.size = Vector2(616, 24)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.75)
	canvas.add_child(hint)
	# Boss bar(s): the label names the nearest engaged boss; a Legendary duo
	# stacks two thin bars (one per boss, each in its own color) under one label.
	var boss_bar_bg := ColorRect.new()
	boss_bar_bg.color = Color(0, 0, 0, 0.55)
	boss_bar_bg.position = Vector2(170, 12)
	boss_bar_bg.size = Vector2(304, 12)
	boss_bar_bg.visible = false
	canvas.add_child(boss_bar_bg)
	var boss_bar := ColorRect.new()
	boss_bar.color = Color("ff7a33")
	boss_bar.position = Vector2(2, 2)
	boss_bar.size = Vector2(300, 8)
	boss_bar_bg.add_child(boss_bar)
	var boss_name := Label.new()
	boss_name.text = ""
	boss_name.position = Vector2(2, -13)
	boss_name.add_theme_font_size_override("font_size", 9)
	boss_name.add_theme_color_override("font_color", Color("ff9a3c"))
	boss_bar_bg.add_child(boss_name)
	var boss_bar_bg2 := ColorRect.new()
	boss_bar_bg2.color = Color(0, 0, 0, 0.55)
	boss_bar_bg2.position = Vector2(170, 23)
	boss_bar_bg2.size = Vector2(304, 9)
	boss_bar_bg2.visible = false
	canvas.add_child(boss_bar_bg2)
	var boss_bar2 := ColorRect.new()
	boss_bar2.color = Color("c9a05a")
	boss_bar2.position = Vector2(2, 2)
	boss_bar2.size = Vector2(300, 5)
	boss_bar_bg2.add_child(boss_bar2)
	_hud = {"hp_bar": hp_bar, "stats": stats, "hint": hint, "pips": pips,
			"q_label": q_label, "q_bar": q_bar, "xp_bar": xp_bar,
			"e_bar": e_bar, "pet_chips": pet_chips, "slots": slots, "charge": charge,
			"boss_bar_bg": boss_bar_bg, "boss_bar": boss_bar, "boss_name": boss_name,
			"boss_bar_bg2": boss_bar_bg2, "boss_bar2": boss_bar2}

# Nearest engaged boss owns the bar; if it is half of a living duo, both bosses
# render as stacked thin bars under a combined label (task: keep it clean).
func _update_boss_bar() -> void:
	_bosses = _bosses.filter(func(b): return is_instance_valid(b))
	var engaged: Array = []
	for b in _bosses:
		if not b.dead and b._state != "idle":
			engaged.append(b)
	if engaged.is_empty():
		_hud.boss_bar_bg.visible = false
		_hud.boss_bar_bg2.visible = false
		return
	engaged.sort_custom(func(a, b):
		return a.global_position.distance_squared_to(player.global_position) \
				< b.global_position.distance_squared_to(player.global_position))
	var focus: Node2D = engaged[0]
	var rows: Array = [focus]
	if focus is ProtoDuoBoss:
		# untyped: a fallen partner is a freed instance (see on_duo_boss_died)
		var mate: Variant = focus.partner
		if is_instance_valid(mate) and not mate.dead:
			rows = [focus, mate]
			rows.sort_custom(func(a, b): return a.display_name < b.display_name)
	var duo := rows.size() == 2
	_hud.boss_bar_bg.visible = true
	_hud.boss_bar_bg.size.y = 9.0 if duo else 12.0
	_hud.boss_bar.size.y = 5.0 if duo else 8.0
	_hud.boss_bar.color = rows[0].bar_color
	_hud.boss_bar.size.x = 300.0 * clampf(rows[0].hp / rows[0].max_hp, 0, 1)
	if duo:
		_hud.boss_name.text = "%s + %s — Legendary Duo" % [
				str(rows[0].display_name).split(" — ")[0],
				str(rows[1].display_name).split(" — ")[0]]
	else:
		_hud.boss_name.text = focus.display_name
	_hud.boss_bar_bg2.visible = duo
	if duo:
		_hud.boss_bar2.color = rows[1].bar_color
		_hud.boss_bar2.size.x = 300.0 * clampf(rows[1].hp / rows[1].max_hp, 0, 1)

func refresh_hud() -> void:
	_hud.hp_bar.size.x = 180.0 * clampf(player.hp / player.max_hp, 0, 1)
	_hud.stats.text = "Lv %d   Gold %d   Kills %d   Stones %d   Snares %d   Bag %d/%d   Pets %d/%d" % [
			Session.level, gold, kills, stones, snares,
			Session.inventory.size(), ProtoItems.INVENTORY_CAP,
			Session.pets.size(), Session.MAX_PETS]

# ---- gauges: fill animations + glow on charge-complete (canon §4 UI) ----------

func _update_gauges(delta: float) -> void:
	_pip_flash = maxf(_pip_flash - delta * 3.0, 0.0)
	_q_flash = maxf(_q_flash - delta * 3.0, 0.0)
	_hud.xp_bar.size.x = 90.0 * _level_progress(kills)
	_chip_t -= delta
	if _chip_t <= 0.0:   # pet chips refresh at 4 Hz — cheap
		_chip_t = 0.25
		_update_pet_chips()
	if player.dodge_charges > _prev_dodge_charges:
		_pip_flash = 1.0   # a charge just completed
	_prev_dodge_charges = player.dodge_charges
	var full := player.dodge_charges >= ProtoPlayer.DODGE_CHARGES_MAX
	var pulse := 0.5 + 0.5 * sin(_day_t * 7.0)
	var prog: float = player.dodge_recharge_progress()
	for i in _hud.pips.size():
		var pip: ColorRect = _hud.pips[i]
		if i < player.dodge_charges:
			pip.size.x = 10.0
			var col := PIP_ON
			if full:   # all three ready — the pips breathe together
				col = PIP_ON.lerp(Color(0.85, 1.0, 1.0), 0.35 * pulse)
			pip.color = col.lerp(Color.WHITE, _pip_flash)
		elif i == player.dodge_charges:   # the refilling charge fills left-to-right
			pip.size.x = maxf(10.0 * prog, 1.0)
			pip.color = PIP_ON.darkened(0.35)
		else:
			pip.size.x = 10.0
			pip.color = PIP_OFF
	_update_skill_slots(pulse)
	# Whirlwind (E): always owned — fill + soft glow when ready
	var ep: float = player.whirl_progress()
	var eready := ep >= 1.0
	_hud.e_bar.size.x = 32.0 * ep
	_hud.e_bar.color = Color("6fb7ff") if not eready \
			else Color("9fd4ff").lerp(Color(0.95, 1.0, 1.0), 0.45 * pulse)
	# Shadow Rend (Q): dim until a stone is owned; fills, then glows when ready
	var owned := stones >= 1
	_hud.q_bar.get_parent().visible = owned
	_hud.q_label.modulate = Color(1, 1, 1, 0.9 if owned else 0.25)
	if not owned:
		return
	var qp: float = player.rend_progress()
	var ready := qp >= 1.0
	if ready and not _q_was_ready:
		_q_flash = 1.0
		play_ui("pickup", -20.0)   # soft "charged" blip
	_q_was_ready = ready
	_hud.q_bar.size.x = 32.0 * qp
	var qcol := Color("8a5cff") if not ready \
			else Color("b06cff").lerp(Color(0.95, 0.85, 1.0), 0.45 * pulse)
	_hud.q_bar.color = qcol.lerp(Color.WHITE, _q_flash)

# Skill bar chips (1-4): cooldown fill per assigned class-tree active + the
# class charge counter (Combo/Attunement). Same treatment as the Q/E gauges.
func _update_skill_slots(pulse: float) -> void:
	for i in 4:
		var chip: Dictionary = _hud.slots[i]
		var id := str(Session.skill_loadout[i])
		var def: Dictionary = Session.skill_def(id) if id != "" else {}
		if def.is_empty() or not Session.node_learned(id):
			chip.bar.size.x = 0.0
			chip.name.text = "—"
			chip.key.modulate = Color(1, 1, 1, 0.25)
			continue
		chip.key.modulate = Color(1, 1, 1, 0.9)
		var total: float = float((def.get("params", {}) as Dictionary).get("cd", 6.0)) \
				* player.cdr_mult
		var left: float = player.skill_cd_left(id)
		var prog := 1.0 if total <= 0.0 else clampf(1.0 - left / total, 0.0, 1.0)
		chip.bar.size.x = 32.0 * prog
		chip.bar.color = Color("c9853c") if prog < 1.0 \
				else Color("ffb45c").lerp(Color(1.0, 0.95, 0.85), 0.45 * pulse)
		chip.name.text = str(def.get("name", "?")).get_slice(" ", 0).left(8)
	if player.charge_name == "" or player.charge_stacks <= 0:
		_hud.charge.text = ""
	else:
		_hud.charge.text = "◈ %s x%d" % [player.charge_name, player.charge_stacks]

func _update_pet_chips() -> void:
	for i in _hud.pet_chips.size():
		var chip: Label = _hud.pet_chips[i]
		if i >= Session.pets.size():
			chip.text = ""
			continue
		var pet: Dictionary = Session.pets[i]
		var resting := false
		for n in get_tree().get_nodes_in_group("pet"):
			if n.uid == int(pet.get("uid", 0)):
				resting = n.resting()
		chip.text = "◆ %s%s" % [str(pet.get("name", "?")),
				"  · resting" if resting else ""]
		chip.add_theme_color_override("font_color",
				Color("ff8a7a") if resting else Color("7fe7ff"))

# K — keybind reference card (its own overlay, separate from the hint line).
func _build_keybinds() -> void:
	_kb_overlay = CanvasLayer.new()
	_kb_overlay.layer = 4
	_kb_overlay.visible = false
	add_child(_kb_overlay)
	var pc := PanelContainer.new()
	pc.theme = ProtoTheme.get_theme()
	pc.position = Vector2(408, 44)
	_kb_overlay.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	pc.add_child(vb)
	var title := Label.new()
	title.text = "KEYBINDS"
	title.add_theme_color_override("font_color", Color("ffd166"))
	title.add_theme_font_size_override("font_size", 10)
	vb.add_child(title)
	for line in [
		"WASD / arrows   move",
		"mouse           aim",
		"LMB / Space     cleave",
		"Shift / RMB     dodge (3 charges)",
		"Q               Shadow Rend (stone)",
		"E               Whirlwind",
		"1-4             class skills (learn/assign: C - Skills)",
		"F               bond pet (Soul Snare)",
		"Z               mount / dismount",
		"C / Tab         character panel",
		"K               this card",
		"Esc             return to Haven",
	]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 9)
		l.modulate = Color(0.92, 0.95, 1.0, 0.95)
		vb.add_child(l)
