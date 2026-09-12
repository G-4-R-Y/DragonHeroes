# MP — the co-op HOST driver (docs/tech/33). Lives inside the host's real hunt:
# spawns one bot-driven ProtoPlayer per remote friend (the arena's bot_drive +
# ProtoBuild seams — remote hunters fight with the same code path as the local
# one), applies their network inputs, and broadcasts 20 Hz snapshots. The host
# is authoritative for EVERYTHING (canon server-authoritative spirit): clients
# are views + input devices. Party loot/XP/gold are shared through the host's
# Session (friends co-op v1 — per-player inventories are a Nakama-era concern).
extends Node2D

const TILE := 16.0
const SNAP_HZ := 20.0
const PlayerScene := preload("res://prototype/player.gd")

const CLASS_PRIMARY := {   # attribute spread for auto-rolled remote builds
	"core.class.reaver": ["might", "vitality"],
	"core.class.emberkin": ["might", "intellect"],
	"core.class.frostbinder": ["vitality", "intellect"],
	"core.class.mage": ["intellect", "agility"],
	"core.class.rogue": ["agility", "might"],
}
const CLASS_ACTIVES := {
	"core.class.reaver": ["rv_gash", "rv_hurled_cleaver", "rv_blood_howl"],
	"core.class.emberkin": ["em_emberlash", "em_twin_suns", "em_emberwake"],
	"core.class.frostbinder": ["fb_frostbite", "fb_icelance", "fb_shatter"],
	"core.class.mage": ["gm_gloambolt", "gm_unravel", "gm_gloomburst"],
	"core.class.rogue": ["vb_quickstab", "vb_lacerate", "vb_heartseeker"],
}
const CLASS_ROOTS := {
	"core.class.reaver": "root_cleave", "core.class.emberkin": "em_root",
	"core.class.frostbinder": "fb_root", "core.class.mage": "gm_root",
	"core.class.rogue": "vb_root",
}

var _main: Node2D
var _remotes := {}          # peer_id -> {body, build, label, last_pkt, prev_pkt, respawn_t}
var _snap_t := 0.0
var _announced := {}        # creature instance_id -> true (manifest already sent)
var _level_seen := 0

func _ready() -> void:
	add_to_group("mp_host")
	_main = get_parent() as Node2D
	MpNet.input_received.connect(_on_input)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	_level_seen = Session.level
	for peer_id in MpNet.players:
		if peer_id != 1:
			_spawn_remote(peer_id, MpNet.players[peer_id])

func _spawn_remote(peer_id: int, info: Dictionary) -> void:
	var class_id := str(info.get("class_id", "core.class.reaver"))
	var build := ProtoBuild.make_player_build(_remote_def(class_id), null)
	var body: ProtoPlayer = PlayerScene.new()
	body.bot_drive = true
	body.build_source = build
	body.global_position = _main.world.random_walkable_in_ring(
			_main.player.global_position, TILE, 3.0 * TILE)
	_main.add_child(body)
	var label := Label.new()
	label.text = str(info.get("name", "Hunter"))
	label.position = Vector2(-24, -34)
	label.add_theme_font_size_override("font_size", 8)
	label.modulate = Color("7fd8ff")
	body.add_child(label)
	_remotes[peer_id] = {"body": body, "build": build, "label": label,
			"last_pkt": {}, "prev_pkt": {}, "respawn_t": 0.0}
	MpNet.send_event({"k": "toast", "text": "%s joined the hunt" % label.text})

func _remote_def(class_id: String) -> Dictionary:
	var lvl: int = maxi(Session.level, 1)
	var prim: Array = CLASS_PRIMARY.get(class_id, ["might", "vitality"])
	var attrs := {"might": 10, "agility": 10, "intellect": 10, "vitality": 10,
			"willpower": 10}
	attrs[prim[0]] += lvl
	attrs[prim[1]] += int(lvl * 0.5)
	var actives: Array = CLASS_ACTIVES.get(class_id, [])
	return {"id": "mp.remote", "kind": "player", "class_id": class_id,
			"level": lvl, "attributes": attrs,
			"equipment": [
				{"slot": "weapon", "base": "emberfang_blade", "rarity": "rare", "quality": 0.5},
				{"slot": "chest", "base": "gloamhide_vest", "rarity": "rare", "quality": 0.5}],
			"runes": {}, "learned": [CLASS_ROOTS.get(class_id, "root_cleave")] + actives,
			"loadout": [actives[0] if actives.size() > 0 else "",
					actives[1] if actives.size() > 1 else "",
					actives[2] if actives.size() > 2 else "", ""]}

# ---- inputs --------------------------------------------------------------------

func _on_input(peer_id: int, pkt: Dictionary) -> void:
	if _remotes.has(peer_id):
		_remotes[peer_id].prev_pkt = _remotes[peer_id].last_pkt
		_remotes[peer_id].last_pkt = pkt

func _edge(r: Dictionary, key: String) -> bool:
	return bool(r.last_pkt.get(key, false)) and not bool(r.prev_pkt.get(key, false))

func _physics_process(delta: float) -> void:
	for peer_id in _remotes:
		var r: Dictionary = _remotes[peer_id]
		var body: ProtoPlayer = r.body
		if not is_instance_valid(body) or body.dead:
			continue
		var pkt: Dictionary = r.last_pkt
		var m: Array = pkt.get("m", [0.0, 0.0])
		var spd: float = body.move_speed * (0.65 if body._slow_t > 0.0 else 1.0)
		body._bot_step = Vector2(m[0], m[1]).limit_length(1.0) * spd * delta
		var aim: Array = pkt.get("aim", [0.0, 0.0])
		body.bot_aim = Vector2(aim[0], aim[1])
		if bool(pkt.get("atk", false)) and body._attack_cd <= 0.0:
			body._attack()
		if _edge(r, "d"):
			body.bot_dodge(Vector2(m[0], m[1]) if Vector2(m[0], m[1]).length() > 0.1 \
					else (body.bot_aim - body.global_position).normalized())
		if _edge(r, "e") and body._whirl_cd <= 0.0:
			match str(body._kit):
				"mage": body._frost_nova()
				"rogue": body._fan_of_knives()
				_: body._whirlwind()
		if _edge(r, "q") and body._rend_cd <= 0.0 and _main.stones >= 1:
			body._shadow_rend(_main)
		var slots: Array = pkt.get("s", [])
		for i in mini(4, slots.size()):
			if _edge(r, "s%d" % i):
				var id := str(r.build.skill_loadout[i])
				if id != "" and body.skill_cd_left(id) <= 0.0:
					body.use_skill(r.build.skill_def(id))
	# respawn timers
	for peer_id in _remotes:
		var r: Dictionary = _remotes[peer_id]
		if is_instance_valid(r.body) and r.body.dead:
			r.respawn_t += delta
			if r.respawn_t >= 3.0:
				r.respawn_t = 0.0
				r.body.respawn(_main.world.random_walkable_in_ring(
						_main.player.global_position, TILE, 2.5 * TILE))
				MpNet.send_event({"k": "toast", "text": "%s is back up" % r.label.text})
	# level-up toasts (shared party progression)
	if Session.level != _level_seen:
		if Session.level > _level_seen:
			for r: Dictionary in _remotes.values():
				if is_instance_valid(r.body):
					r.build.level = Session.level
					r.body.refresh_on_level_up()
		_level_seen = Session.level
		MpNet.send_event({"k": "toast", "text": "Party level %d!" % _level_seen})
	# snapshots
	_snap_t += delta
	if _snap_t >= 1.0 / SNAP_HZ:
		_snap_t = 0.0
		_send_snapshot()

# ---- snapshots -------------------------------------------------------------------

func _send_snapshot() -> void:
	var pl: Array = []
	var host: ProtoPlayer = _main.player
	pl.append([1, snappedf(host.global_position.x, 0.1), snappedf(host.global_position.y, 0.1),
			snappedf(host.hp, 0.1), snappedf(host.max_hp, 0.1), host.dodge_charges,
			host.sprite.animation, host.sprite.flip_h])
	for peer_id in _remotes:
		var body: ProtoPlayer = _remotes[peer_id].body
		if is_instance_valid(body):
			pl.append([peer_id, snappedf(body.global_position.x, 0.1),
					snappedf(body.global_position.y, 0.1),
					snappedf(body.hp, 0.1), snappedf(body.max_hp, 0.1),
					body.dodge_charges, body.sprite.animation, body.sprite.flip_h])
	var cr: Array = []
	var sp := {}
	for c in get_tree().get_nodes_in_group("creatures"):
		if c.dead:
			continue
		var id := c.get_instance_id()
		cr.append([id, snappedf(c.global_position.x, 0.1), snappedf(c.global_position.y, 0.1),
				snappedf(c.hp / maxf(c.max_hp, 1.0), 0.01), str(c._state)])
		if not _announced.has(id):
			_announced[id] = true
			sp[id] = {"b": str(c._bundle), "a": str(c.archetype),
					"t": c._base_tint.to_html(), "sc": snappedf(c._scale, 0.01),
					"el": c.elite, "n": str(c.name_tag if c.name_tag != "" else c.species_name)}
	var pj: Array = []
	for n in _main.get_children():   # bolts are added to main by their casters
		if n is ProtoProjectile:
			var kind := 0
			match str(n.dmg_type):
				"umbral": kind = 1
				"frost": kind = 2
				"physical": kind = 5
			if n.friendly:
				kind = 4 if n.spin != 0.0 else 3
			pj.append([snappedf(n.global_position.x, 0.1),
					snappedf(n.global_position.y, 0.1), kind])
	var fd: Array = []
	for f in _main._fields:
		fd.append([snappedf(f.pos.x, 0.1), snappedf(f.pos.y, 0.1),
				snappedf(f.radius, 0.1), str(f.kind)])
	var snap := {"t": Time.get_ticks_msec(), "pl": pl, "cr": cr, "pj": pj, "fd": fd}
	if not sp.is_empty():
		snap["sp"] = sp
	MpNet.send_snapshot(snap)

func on_remote_death(who: Node2D) -> void:
	for peer_id in _remotes:
		if _remotes[peer_id].body == who:
			MpNet.send_event({"k": "toast",
					"text": "%s went down — back in 3s" % _remotes[peer_id].label.text})
			return

func _on_peer_left(peer_id: int) -> void:
	if _remotes.has(peer_id):
		var r: Dictionary = _remotes[peer_id]
		MpNet.send_event({"k": "toast", "text": "%s left the hunt" % r.label.text})
		if is_instance_valid(r.body):
			r.body.queue_free()
		_remotes.erase(peer_id)
