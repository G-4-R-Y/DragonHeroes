# PROTOTYPE HARNESS — procedural PIXEL ART + SpriteFrames factory, the placeholder
# for the real Aseprite/atlas + gen-AI pipeline (docs/design/17). Art direction:
# dark fantasy in a luminous, beautiful world — deep dark bases, glowing accents
# (cyan/bioluminescent green for the world, ember orange for the boss, violet for
# abyssal creatures), chunky silhouettes, 1-2 px dark outlines, no anti-aliasing.
# Everything is generated ONCE into static caches so the slice holds 60 FPS.
class_name ProtoSprites

const TILE := 16
const OUT := Color("0d151a")

static var _tex_cache: Dictionary = {}
static var _frames_cache: Dictionary = {}

# ---- deterministic hash + tiny drawing kit -----------------------------------

# Deterministic tiny hash for pixel speckle (no RNG state).
static func _speck(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h & 1023) / 1023.0

static func _img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)

static func _hline(img: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(img, x, y, c)

static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (float(x) - cx) / rx
			var dy := (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)

# 1 px dark outline around every opaque pixel (crisp readable silhouette).
static func _outline(img: Image, c: Color = OUT) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := Image.new()
	src.copy_from(img)
	var neigh := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.55:
				continue
			for o in neigh:
				var nx: int = x + o.x
				var ny: int = y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.55:
					img.set_pixel(x, y, c)
					break

# Darkens opaque pixels whose lower or left neighbour is transparent — a cheap
# bottom-left form shadow so chunky silhouettes read as lit volumes. Call BEFORE
# _outline; stamp glow pixels afterwards so they stay pure.
static func _edge_shade(img: Image, amount: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := Image.new()
	src.copy_from(img)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.55:
				continue
			var below := y + 1 >= h or src.get_pixel(x, y + 1).a <= 0.55
			var left := x == 0 or src.get_pixel(x - 1, y).a <= 0.55
			if below or left:
				img.set_pixel(x, y, c.darkened(amount))

# GenForge bundle hook: the five key actors render from the baked hi-fi
# bundles (game/prototype/art/<actor>/, loaded by ProtoBundleArt) whenever
# they exist on disk; the procedural pixels below stay as the graceful
# fallback so a bare checkout still runs. Missing animations are aliased.
static func _bundle_frames(actor: String, required: Array) -> SpriteFrames:
	var sf := ProtoBundleArt.frames_for(actor)
	if sf != null:
		ProtoBundleArt.ensure_animations(sf, required)
	return sf

static func _anim(sf: SpriteFrames, anim_name: String, fps: float, loops: bool, frames: Array) -> void:
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, loops)
	for t in frames:
		sf.add_frame(anim_name, t)

# ---- tile atlas: 4 types x 4 variants (column = type*4+variant) ---------------

static var _tile_bases: Array[Color] = [
		Color("0e242c"), Color("24402c"), Color("18291e"), Color("31353e")]
static var _tile_accents: Array[Color] = [
		Color("17414d"), Color("35563b"), Color("243f2c"), Color("434a57")]

static func make_tile_atlas() -> ImageTexture:
	if _tex_cache.has("tile_atlas"):
		return _tex_cache["tile_atlas"]
	var img := _img(TILE * 16, TILE)
	for t in 4:
		for v in 4:
			var col := t * 4 + v
			for y in TILE:
				for x in TILE:
					img.set_pixel(x + col * TILE, y, _tile_px_at(t, v, x, y, x + col * TILE))
	var tex := _tex(img)
	_tex_cache["tile_atlas"] = tex
	return tex

# One ground pixel of tile type t / variant v. (x, y) are tile-local; ax is the
# speckle-space x (the base atlas passes its column offset so every variant's
# noise stays unique). SINGLE SOURCE of the ground look — the base atlas and the
# dual-grid transition atlas below both draw through here, so boundary tiles
# reuse EXACTLY the biome pixels they sit between.
static func _tile_px_at(t: int, v: int, x: int, y: int, ax: int) -> Color:
	var base: Color = _tile_bases[t]
	if t == 0:
		base = base.lightened(0.035 * v)         # variants: brightness steps
	elif t == 2:
		base = base.darkened(0.05 * v)           # variants: deeper forest
	var c := base
	var s := _speck(ax, y, 7 + t * 4 + v)
	var dither := (x + y) & 1
	match t:
		0:  # water — dithered ripple bands phased per variant, rare glint
			if (y + v * 2) % 6 == 0 and dither == 0:
				c = base.lerp(_tile_accents[0], 0.8)
			elif (y + v * 2) % 6 == 1 and dither == 1:
				c = base.lerp(_tile_accents[0], 0.35)
			if s < 0.05:
				c = Color("0a1b21")
			if s > 0.972 - 0.004 * v:
				c = Color("245a66")
			if v >= 2 and s > 0.996:
				c = base.lerp(Color("59d6e6"), 0.55)  # rare bright glint
		1:  # grass — dithered tone patches, 2 px blades, luminous fleck
			if dither == 0 and _speck(ax >> 2, y >> 2, 51) > 0.55:
				c = base.lerp(_tile_accents[1], 0.4)
			var bl := 0.952 - 0.01 * v
			if s > bl:
				c = Color("3a5a3c")                   # blade root
			if y < TILE - 1 and _speck(ax, y + 1, 7 + t * 4 + v) > bl:
				c = Color("4d7a4a")                   # blade tip above root
			if s > 0.996:
				c = base.lerp(Color("57ff9a"), 0.5)
		2:  # forest — blocky dark mottle, bioluminescent moss flecks
			var m := _speck(ax >> 2, y >> 2, 33)
			if m > 0.62:
				c = base.darkened(0.22)
			elif m < 0.2 and dither == 0:
				c = base.lerp(_tile_accents[2], 0.5)
			if s > 0.9 - 0.02 * v:
				c = _tile_accents[2]
			if s > 0.958:
				c = base.lerp(Color("57ff9a"), 0.3)
		3:  # rock — top-lit shading, cracks, moss-capped stones
			c = base.darkened(0.12 * float(y) / TILE)
			if dither == 0 and s > 0.6:
				c = c.lerp(_tile_accents[3], 0.3)
			if (x + y * 2 + v * 7) % 19 == 0 and s > 0.3:
				c = Color("1e2127")
			var b := _speck(ax >> 2, y >> 2, 87)
			if b > 0.84:                              # embedded stones
				c = Color("4c5260") if (y & 3) < 2 else Color("3b414c")
				if v >= 1 and (y & 3) == 0 and s > 0.5:
					c = Color("31543a")               # moss caps the stone
			if s > 0.988 - 0.008 * v:
				c = Color("5a6170")
	return c

# ---- macro variation: low-frequency value noise over the tile grid -------------
# Bilinear value noise from _speck lattice samples, smoothstep-eased. freq is
# per TILE (default 0.02 ~= 50-tile features). Deterministic from world coords —
# world_gen biases each region's variant pick through it so atlas repetition
# breaks into organic patches (mossy vs worn) instead of uniform confetti.
static func macro_noise(gx: int, gy: int, salt: int, freq := 0.02) -> float:
	var fx := gx * freq
	var fy := gy * freq
	var ix := floori(fx)
	var iy := floori(fy)
	var ux := fx - ix
	var uy := fy - iy
	ux = ux * ux * (3.0 - 2.0 * ux)
	uy = uy * uy * (3.0 - 2.0 * uy)
	return lerpf(
			lerpf(_speck(ix, iy, salt), _speck(ix + 1, iy, salt), ux),
			lerpf(_speck(ix, iy + 1, salt), _speck(ix + 1, iy + 1, salt), ux), uy)

# ---- dual-grid transition atlas (Oskar Stålberg corner tiles) ------------------
# 16 corner-mask tiles PER BIOME PAIR (column = pair*16 + mask). The tiles live
# on the HALF-TILE-SHIFTED display grid: each one straddles four world tiles,
# and mask bit0=TL bit1=TR bit2=BL bit3=BR marks which corners the OVERLAY biome
# owns. The 0.5 iso-contour of the bilinear corner field draws the rounded
# organic boundary arc, a per-pixel hash jitter dithers the edge, and a darkened
# band on the overlay side reads as ledge/canopy shadow. Both sides render
# through _tile_px_at, so the art IS the two biomes' base pixels (mid variant).
# `pairs` = Array of [overlay_type, under_type] — world_gen owns the semantics.
static func make_transition_atlas(pairs: Array) -> ImageTexture:
	var key := "trans_atlas_%s" % [str(pairs)]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := _img(TILE * 16 * pairs.size(), TILE)
	for p in pairs.size():
		var ta := int(pairs[p][0])
		var tb := int(pairs[p][1])
		for m in 16:
			var col := p * 16 + m
			for y in TILE:
				for x in TILE:
					# bilinear corner field: 1 where the overlay owns the corner
					var u := (float(x) + 0.5) / TILE
					var w := (float(y) + 0.5) / TILE
					var fld := lerpf(
							lerpf(float(m & 1), float((m >> 1) & 1), u),
							lerpf(float((m >> 2) & 1), float((m >> 3) & 1), u), w)
					var jit := (_speck(x + col * TILE, y, 173) - 0.5) * 0.26
					var t := ta if fld + jit > 0.5 else tb
					var c := _tile_px_at(t, 1, x, y, x + (t * 4 + 1) * TILE)
					if t == ta and fld < 0.62:
						c = c.darkened(0.18)      # edge shade — ledge shadow
					img.set_pixel(col * TILE + x, y, c)
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex

# ---- HERO (drawn facing right; flip_h on the node for left) --------------------

static func hero_frames() -> SpriteFrames:
	if _frames_cache.has("hero"):
		return _frames_cache["hero"]
	var bundled := _bundle_frames("hero", ["idle", "walk", "attack"])
	if bundled != null:
		_frames_cache["hero"] = bundled
		return bundled
	var sf := SpriteFrames.new()
	_anim(sf, "idle", 2.2, true, [_hero_tex("idle", 0), _hero_tex("idle", 1)])
	var walk: Array = []
	for f in 4:
		walk.append(_hero_tex("walk", f))
	_anim(sf, "walk", 8.0, true, walk)
	_anim(sf, "attack", 12.0, false, [_hero_tex("attack", 0), _hero_tex("attack", 1)])
	_frames_cache["hero"] = sf
	return sf

static func _hero_tex(pose: String, f: int) -> ImageTexture:
	var img := _img(26, 26)
	var hood := Color("1d4b56")
	var hood_d := Color("143741")
	var hood_hi := Color("2a6274")
	var face := Color("e8d2b0")
	var face_sh := Color("cfb28c")
	var eye := Color("14262c")
	var leg := Color("10262c")
	var boot := Color("0b1a1f")
	var blade := Color("dfe8ea")
	var blade_hi := Color("ffffff")
	var grip := Color("55341f")
	var bob := 0
	if (pose == "idle" and f == 1) or (pose == "walk" and (f == 1 or f == 3)):
		bob = 1
	# legs (alternating stride pixels on walk)
	if pose == "walk" and f == 0:
		_rect(img, 8, 18, 2, 5, leg)
		_rect(img, 7, 22, 3, 2, boot)
		_rect(img, 13, 18, 2, 4, leg)
		_rect(img, 13, 21, 2, 2, boot)
	elif pose == "walk" and f == 2:
		_rect(img, 13, 18, 2, 5, leg)
		_rect(img, 13, 22, 3, 2, boot)
		_rect(img, 8, 18, 2, 4, leg)
		_rect(img, 7, 21, 2, 2, boot)
	else:
		_rect(img, 9, 18, 2, 5, leg)
		_rect(img, 9, 22, 2, 2, boot)
		_rect(img, 12, 18, 2, 5, leg)
		_rect(img, 12, 22, 2, 2, boot)
	# hooded dark-teal cloak body (3-tone: hood_hi / hood / hood_d)
	_rect(img, 8, 10 + bob, 6, 3, hood)
	_rect(img, 7, 13 + bob, 8, 3, hood)
	_rect(img, 7, 16 + bob, 8, 2, hood_d)
	_rect(img, 7, 13 + bob, 2, 3, hood_d)
	_px(img, 13, 10 + bob, hood_hi)          # sword-shoulder rim light
	_px(img, 13, 13 + bob, hood_hi)
	# hooded head with pale face pixels
	_rect(img, 9, 3 + bob, 4, 1, hood)
	_rect(img, 8, 4 + bob, 6, 1, hood)
	_rect(img, 8, 5 + bob, 6, 4, hood)
	_rect(img, 9, 9 + bob, 4, 1, hood_d)
	_rect(img, 8, 5 + bob, 2, 4, hood_d)
	_hline(img, 10, 12, 3 + bob, hood_hi)    # moon-lit crown of the hood
	_rect(img, 11, 5 + bob, 3, 3, face)
	_px(img, 11, 7 + bob, face_sh)           # chin in hood shadow
	_px(img, 12, 6 + bob, eye)
	_px(img, 13, 4 + bob, hood_d)
	# sword arm
	if pose == "attack" and f == 0:
		_px(img, 14, 10, hood_d)
		_px(img, 15, 9, hood_d)
		_px(img, 15, 8, grip)
		_px(img, 16, 7, blade)
		_px(img, 16, 6, blade)
		_px(img, 16, 5, blade)
		_px(img, 17, 4, blade_hi)
	elif pose == "attack" and f == 1:
		_px(img, 14, 12, hood_d)
		_px(img, 15, 12, hood_d)
		_px(img, 16, 12, grip)
		_hline(img, 17, 20, 12, blade)
		_px(img, 20, 12, blade_hi)
	else:
		_px(img, 14, 12 + bob, hood_d)
		_px(img, 15, 13 + bob, hood_d)
		_px(img, 16, 14 + bob, grip)
		_px(img, 17, 15 + bob, blade)
		_px(img, 18, 16 + bob, blade)
		_px(img, 19, 17 + bob, blade)
	_edge_shade(img, 0.16)
	# faint cyan chest sigil (luminous accent — stamped after shading, stays pure)
	_px(img, 12, 12 + bob, Color("6fe3ff"))
	_px(img, 12, 13 + bob, Color("2e6b76"))
	_outline(img)
	# swing arc streak, added after outlining so it stays a pure light smear
	if pose == "attack" and f == 1:
		var arc := Color(0.75, 0.96, 1.0, 0.5)
		_px(img, 21, 8, arc)
		_px(img, 22, 9, arc)
		_px(img, 23, 11, arc)
		_px(img, 23, 13, arc)
		_px(img, 22, 15, arc)
		_px(img, 21, 16, arc)
	return _tex(img)

# ---- GLOAMFEN STALKER (low violet quadruped, glowing eyes) ---------------------

static func stalker_frames() -> SpriteFrames:
	if _frames_cache.has("stalker"):
		return _frames_cache["stalker"]
	var bundled := _bundle_frames("gloamfen_stalker", ["idle", "walk", "lunge"])
	if bundled != null:
		_frames_cache["stalker"] = bundled
		return bundled
	var sf := SpriteFrames.new()
	_anim(sf, "idle", 2.5, true, [_stalker_tex("idle", 0), _stalker_tex("idle", 1)])
	var walk: Array = []
	for f in 4:
		walk.append(_stalker_tex("walk", f))
	_anim(sf, "walk", 9.0, true, walk)
	_anim(sf, "lunge", 8.0, false, [_stalker_tex("lunge", 0), _stalker_tex("lunge", 1)])
	_frames_cache["stalker"] = sf
	return sf

static func _stalker_tex(pose: String, f: int) -> ImageTexture:
	var img := _img(24, 14)
	var body := Color("372c4e")
	var hi := Color("4b3d68")
	var mid := Color("2e2542")
	var dark := Color("241c33")
	var eye := Color("cf9dff")
	var brow := hi.lerp(eye, 0.45)   # violet glow bleeding onto the brow
	if pose == "lunge" and f == 1:
		# fully stretched pounce
		_hline(img, 0, 3, 6, dark)                       # tail whips straight
		_hline(img, 4, 16, 5, hi)
		_rect(img, 3, 6, 15, 3, body)
		_hline(img, 4, 16, 9, dark)
		_rect(img, 17, 4, 6, 3, body)                     # head thrown forward
		_hline(img, 18, 23, 6, body)
		_hline(img, 18, 22, 7, dark)                      # open jaw
		_px(img, 19, 5, mid)
		_edge_shade(img, 0.18)
		_px(img, 19, 4, eye)
		_px(img, 21, 4, eye)
		_px(img, 19, 3, brow)
		_px(img, 21, 3, brow)
		_rect(img, 7, 10, 1, 2, dark)                     # legs tucked back
		_rect(img, 9, 10, 1, 2, dark)
		_rect(img, 14, 10, 1, 2, dark)
		_rect(img, 16, 10, 1, 2, dark)
		_outline(img)
		return _tex(img)
	var yo := 0
	if pose == "idle" and f == 1:
		yo = 1
	var crouch := pose == "lunge"  # f == 0: coiled crouch before the pounce
	if crouch:
		yo = 2
	# thin tail
	_px(img, 1, 4 + yo, dark)
	_px(img, 2, 5 + yo, dark)
	_px(img, 3, 5 + yo, dark)
	_px(img, 4, 6 + yo, dark)
	# low body with ridge spines (3-tone: hi spine / body / mid flank / dark belly)
	_hline(img, 6, 15, 4 + yo, hi)
	_rect(img, 5, 5 + yo, 12, 4, body)
	_hline(img, 6, 15, 8 + yo, mid)
	_hline(img, 6, 15, 9 + yo, dark)
	_px(img, 8, 3 + yo, dark)
	_px(img, 12, 3 + yo, dark)
	# head + snout
	_rect(img, 16, 3 + yo, 5, 2, hi)
	_rect(img, 16, 4 + yo, 6, 3, body)
	_hline(img, 17, 22, 6 + yo, body)
	_hline(img, 17, 21, 7 + yo, dark)
	_edge_shade(img, 0.18)
	# two glowing violet eyes + brow glow (bright — stamped after shading)
	_px(img, 18, 4 + yo, eye)
	_px(img, 20, 4 + yo, eye)
	_px(img, 18, 3 + yo, brow)
	_px(img, 20, 3 + yo, brow)
	# 4 legs, 2-pose alternation on walk
	var legs: Array = [[6, 0], [9, 0], [13, 0], [16, 0]]
	if pose == "walk" and f == 0:
		legs = [[5, 0], [10, 1], [12, 0], [17, 1]]
	elif pose == "walk" and f == 2:
		legs = [[7, 1], [9, 0], [14, 1], [16, 0]]
	for l in legs:
		var lift: int = l[1] + (1 if crouch else 0)
		_rect(img, l[0], 10, 1, maxi(3 - lift, 1), dark)
	_outline(img)
	return _tex(img)

# ---- GLOAMFEN WISP (spirit archetype: glowing cyan-violet orb, 2-frame pulse) ---

static func wisp_frames() -> SpriteFrames:
	if _frames_cache.has("wisp"):
		return _frames_cache["wisp"]
	var bundled := _bundle_frames("gloamfen_wisp", ["idle", "walk", "lunge"])
	if bundled != null:
		_frames_cache["wisp"] = bundled
		return bundled
	var a := _wisp_tex(0, false)
	var b := _wisp_tex(1, false)
	var fa := _wisp_tex(0, true)
	var fb := _wisp_tex(1, true)
	var sf := SpriteFrames.new()
	_anim(sf, "idle", 3.0, true, [a, b])
	_anim(sf, "walk", 4.0, true, [a, b])
	_anim(sf, "lunge", 10.0, false, [fa, fb])   # windup flash frames
	_frames_cache["wisp"] = sf
	return sf

static func _wisp_tex(f: int, flare: bool) -> ImageTexture:
	var img := _img(18, 14)
	var cx := 11.5
	var cy := 7.0
	var r := 4.2 if f == 0 else 5.0             # 2-frame pulse
	var edge := Color("5e46b8")
	var mid := Color("8e6cf0")
	var core := Color("d9c8ff")
	if flare:                                    # brighter body = umbral bolt windup
		edge = Color("7a5fd8")
		mid = Color("bda6ff")
		core = Color("ffffff")
	_ellipse(img, cx, cy, r, r * 0.9, edge)
	_ellipse(img, cx, cy, r * 0.66, r * 0.6, mid)
	_ellipse(img, cx - 0.6, cy - 0.8, r * 0.34, r * 0.3, core)
	# two dim eye motes — a spirit "face" hollowed out of the glow
	var eye_c := Color("241245") if flare else Color("3a2470")
	_px(img, 10, 6, eye_c)
	_px(img, 12, 6, eye_c)
	# cyan glints — the cyan-violet mix that reads "spirit" at night
	_px(img, int(cx) - 1, int(cy) - 2, Color("7fe7ff"))
	_px(img, int(cx) + 1, int(cy) + 1, Color("59d6e6") if f == 0 else Color("7fe7ff"))
	# small trailing wisp pixels (drifting left; node flip_h mirrors them)
	var trail: Array = [Vector2i(5, 6), Vector2i(4, 8), Vector2i(2, 7)] if f == 0 \
			else [Vector2i(5, 8), Vector2i(3, 6), Vector2i(1, 8)]
	var i := 0
	for t in trail:
		_px(img, t.x, t.y, Color(0.62, 0.52, 0.95, 0.85 - 0.22 * i))
		i += 1
	_outline(img, Color("140b26"))
	return _tex(img)

# ---- EMBERWING MATRIARCH (great ember avian, 3-pose wing flap) -----------------

static func boss_frames() -> SpriteFrames:
	if _frames_cache.has("boss"):
		return _frames_cache["boss"]
	var bundled := _bundle_frames("emberwing_matriarch",
			["idle", "fly", "walk", "attack", "lunge"])
	if bundled != null:
		_frames_cache["boss"] = bundled
		return bundled
	var up := _boss_tex("fly", 0)
	var mid := _boss_tex("fly", 1)
	var down := _boss_tex("fly", 2)
	var a0 := _boss_tex("attack", 0)
	var a1 := _boss_tex("attack", 1)
	var sf := SpriteFrames.new()
	_anim(sf, "idle", 6.0, true, [up, mid, down, mid])
	_anim(sf, "fly", 7.0, true, [up, mid, down, mid])
	_anim(sf, "walk", 7.0, true, [up, mid, down, mid])   # alias: generic creature anim code
	_anim(sf, "attack", 8.0, false, [a0, a1])
	_anim(sf, "lunge", 8.0, false, [a0, a1])             # alias: generic creature anim code
	_frames_cache["boss"] = sf
	return sf

static func _boss_tex(anim_name: String, f: int) -> ImageTexture:
	var img := _img(48, 36)
	var body := Color("a8481a")
	var hi := Color("d06828")
	var dark := Color("6e2c0e")
	var wing := Color("8a3a12")
	var fwing := Color("5e250b")
	var wedge := Color("e07030")
	var beak := Color("d89040")
	var beak_d := Color("8a5a20")
	var eye := Color("ffd166")
	var attack := anim_name == "attack"
	var head_dx := 2 if attack else 0
	# far wing (behind the body, darker)
	if attack:
		for i in 7:
			_hline(img, 16 - i, 27 - i, 12 - i, fwing)
	elif f == 0:      # up
		for i in 8:
			_hline(img, 29, 32 + int(i * 0.7), 15 - i, fwing)
	elif f == 1:      # mid
		for i in 3:
			_hline(img, 29 + i, 38 - i, 14 + i, fwing)
	else:             # down
		for i in 6:
			_hline(img, 29 + int(i * 0.5), 36 - i, 17 + i, fwing)
	# tail wedge (left)
	for dy in range(-2, 3):
		_hline(img, 12 + absi(dy) * 2, 18, 22 + dy, wing)
	_px(img, 12, 22, wedge)
	# body (3-tone ramp + hot rim light along the back)
	_ellipse(img, 26.0, 22.0, 9.5, 6.0, body)
	_ellipse(img, 26.0, 20.0, 7.5, 3.5, hi)
	_ellipse(img, 25.0, 18.8, 5.5, 1.4, Color("e88a45"))
	_ellipse(img, 26.0, 25.5, 6.5, 2.2, dark)
	# neck + head
	_ellipse(img, 32.0 + head_dx, 19.0, 3.5, 3.0, body)
	_ellipse(img, 36.0 + head_dx, 16.0, 4.0, 3.6, body)
	_ellipse(img, 35.0 + head_dx, 14.8, 2.6, 1.6, hi)
	# crest feathers
	_px(img, 33 + head_dx, 11, wedge)
	_px(img, 34 + head_dx, 12, wedge)
	_px(img, 32 + head_dx, 12, wing)
	# hooked beak (opens on attack)
	if attack:
		_hline(img, 40 + head_dx, 45 + head_dx, 15, beak)
		_hline(img, 41 + head_dx, 44 + head_dx, 16, beak_d)
		_hline(img, 40 + head_dx, 43 + head_dx, 17, beak)
		_px(img, 45 + head_dx, 16, beak_d)
	else:
		_hline(img, 40, 45, 16, beak)
		_hline(img, 40, 43, 17, beak)
		_px(img, 45, 17, beak_d)
		_px(img, 44, 18, beak_d)
	_px(img, 36 + head_dx, 15, Color("2a1206"))
	_px(img, 37 + head_dx, 15, eye)
	_px(img, 37 + head_dx, 14, hi.lerp(eye, 0.5))   # glow bleeding onto the brow
	# near wing (front)
	if attack:
		var k := 1 if f == 1 else 0   # frame 1 folds tighter
		for i in 10:
			var y := 16 - i + k * 2
			var x1 := 24 - i
			var x0 := x1 - (8 - int(i * 0.4))
			_hline(img, x0, x1, y, wing)
			_px(img, x0, y, wedge)
	elif f == 0:      # up
		for i in 11:
			var w := 9 - int(i * 0.55)
			var x0 := 23 - i
			_hline(img, x0, x0 + w, 17 - i, wing)
			_px(img, x0, 17 - i, wedge)
	elif f == 1:      # mid
		for i in 4:
			_hline(img, 9 + i * 2, 25, 15 + i, wing)
			_px(img, 9 + i * 2, 15 + i, wedge)
		_px(img, 8, 15, wedge)
	else:             # down
		for i in 9:
			var x0 := 13 + i
			var x1 := 25 - int(i * 0.4)
			if x0 <= x1:
				_hline(img, x0, x1, 17 + i, wing)
				_px(img, x0, 17 + i, wedge)
	_edge_shade(img, 0.14)
	_outline(img, Color("160a04"))
	# flickering ember pixels — positions differ per frame
	var embers := [Vector2i(20, 27), Vector2i(31, 24), Vector2i(24, 14),
			Vector2i(18, 20), Vector2i(29, 27), Vector2i(22, 18)]
	for e in 3:
		var p: Vector2i = embers[(f * 2 + e * 2 + (1 if attack else 0)) % embers.size()]
		_px(img, p.x, p.y, Color("ffcf6a") if e == 0 else Color("ff8a33"))
	return _tex(img)

# ---- EMBER DRAKE (rideable adult mount — long horned head, jagged wings, saddle) -
# 56x44 centered frames, drawn facing right like every other creature.
# Rider contract: player.gd draws the hero as a separate sprite ~13 px above this
# frame's center (mount at y=-14, hero at y=-27 in player space), so the saddle
# seat is fixed on canvas rows 14-16 (x 22..30) and the BODY NEVER BOBS between
# frames — only wings, tail, head and embers animate, keeping the rider seated.

static func drake_frames() -> SpriteFrames:
	if _frames_cache.has("drake"):
		return _frames_cache["drake"]
	var bundled := _bundle_frames("ember_drake", ["fly", "walk", "idle"])
	if bundled != null:
		_frames_cache["drake"] = bundled
		return bundled
	var fly: Array = []
	for f in 4:
		fly.append(_drake_tex("fly", f))
	var idle: Array = []
	for f in 3:
		idle.append(_drake_tex("idle", f))
	var sf := SpriteFrames.new()
	_anim(sf, "fly", 7.0, true, fly)
	_anim(sf, "walk", 7.0, true, fly)    # alias: generic creature anim code
	_anim(sf, "idle", 3.0, true, idle)
	_frames_cache["drake"] = sf
	return sf

static func _drake_tex(pose: String, f: int) -> ImageTexture:
	var img := _img(56, 44)
	var mid := Color("b34f16")      # ember-orange scales
	var hi := Color("e07a30")
	var dark := Color("77270a")     # dark red shade
	var deep := Color("531806")
	var belly := Color("c68d52")
	var belly_d := Color("96602e")
	var memb := Color("7c250b")     # near wing membrane
	var memb_d := Color("511605")   # far wing / membrane shade
	var bone := Color("d06828")     # wing arm along the leading edge
	var horn := Color("e8d9c0")
	var horn_d := Color("a8906c")
	var leather := Color("3a2413")
	var leather_hi := Color("6e4526")
	var eye := Color("ffd166")
	# fly = up/mid/down/mid wingbeat; idle hovers on mid with a lazy half-flap
	var wing := 1
	var sway := 0                   # tail-tip vertical sway per frame
	var wlow := 0                   # idle: whole mid wing settles 1 px lower
	if pose == "fly":
		wing = [0, 1, 2, 1][f]
		sway = [0, 1, 0, -1][f]
	else:
		sway = [0, 1, 0][f]
		wlow = [0, 1, 0][f]
	# far wing (behind everything, darker)
	if wing == 0:
		for i in 9:
			_hline(img, 23, 27 + int(i * 0.6), 14 - i, memb_d)
	elif wing == 1:
		for i in 3:
			_hline(img, 25 + i * 2, 33, 12 + i + wlow, memb_d)
	else:
		for i in 5:
			_hline(img, 31, 36 - i, 16 + i, memb_d)
	# tail — thick at the hips, whip-thin at the swaying spade tip
	_hline(img, 10, 17, 20, mid)
	_hline(img, 8, 17, 21, mid)
	_hline(img, 8, 16, 22, dark)
	_hline(img, 10, 14, 23, deep)
	_hline(img, 5, 9, 20 + sway, mid)
	_hline(img, 6, 9, 21 + sway, dark)
	_px(img, 4, 19 + sway, mid)
	_px(img, 3, 18 + sway, hi)      # spade tip
	_px(img, 2, 17 + sway, hi)
	_px(img, 3, 20 + sway, dark)    # lower barb
	_px(img, 12, 19, dark)          # tail ridge spikes
	_px(img, 15, 18, dark)
	# tucked legs + rear haunch
	_ellipse(img, 20.0, 25.0, 4.0, 3.2, dark)
	_ellipse(img, 19.5, 24.0, 2.6, 1.8, mid)
	_rect(img, 18, 28, 2, 3, dark)
	_px(img, 17, 31, horn_d)
	_px(img, 19, 31, horn_d)
	_rect(img, 31, 28, 2, 3, dark)
	_px(img, 30, 31, horn_d)
	_px(img, 32, 31, horn_d)
	# body barrel + chest, lit along the back
	_ellipse(img, 26.0, 22.0, 11.0, 6.2, mid)
	_ellipse(img, 33.5, 23.0, 4.5, 5.4, mid)
	_ellipse(img, 25.0, 19.5, 9.0, 3.0, hi)
	_ellipse(img, 27.0, 26.5, 8.5, 2.5, belly)
	for k in 5:
		_px(img, 20 + k * 3, 27, belly_d)   # belly plate seams
	_hline(img, 21, 33, 25, belly_d)
	# dorsal ridge spines bracket the saddle
	_px(img, 17, 16, dark)
	_px(img, 19, 15, dark)
	_px(img, 32, 15, dark)
	# neck rises in front of the saddle
	_ellipse(img, 34.0, 17.0, 3.2, 3.6, mid)
	_ellipse(img, 37.0, 13.0, 2.8, 3.0, mid)
	_ellipse(img, 39.0, 11.0, 2.4, 2.4, mid)
	_ellipse(img, 34.0, 15.0, 1.8, 1.6, hi)
	_px(img, 37, 16, belly_d)               # throat
	_px(img, 39, 13, belly_d)
	_px(img, 34, 12, dark)                  # neck spines
	_px(img, 36, 10, dark)
	# long horned head: heavy skull, tapered snout, closed jaw with an overbite fang
	_rect(img, 39, 7, 6, 5, mid)
	_hline(img, 39, 44, 6, hi)              # brow ridge
	_rect(img, 45, 8, 6, 2, mid)
	_hline(img, 45, 52, 9, mid)
	_px(img, 51, 8, mid)
	_hline(img, 41, 44, 7, dark)            # scowl shadow under the brow
	_hline(img, 44, 51, 10, dark)           # mouth line
	_hline(img, 44, 49, 11, dark)           # lower jaw
	_px(img, 49, 11, horn)                  # fangs
	_px(img, 46, 11, horn)
	_px(img, 52, 8, deep)                   # nostril
	# swept-back horns — the intimidation silhouette
	_px(img, 40, 6, horn_d)
	_px(img, 39, 5, horn)
	_px(img, 38, 4, horn)
	_px(img, 37, 3, horn)
	_px(img, 36, 2, horn_d)
	_px(img, 43, 6, horn_d)
	_px(img, 42, 5, horn)
	_px(img, 41, 4, horn)
	_px(img, 40, 3, horn_d)
	_px(img, 44, 12, horn_d)                # jaw spike
	# saddle: rim + seat pad, cantle behind, pommel horn in front, girth strap
	_rect(img, 22, 15, 9, 2, leather)
	_hline(img, 22, 30, 14, leather_hi)
	_px(img, 21, 14, leather_hi)
	_px(img, 21, 15, leather)
	_px(img, 31, 14, leather_hi)
	_px(img, 31, 15, leather)
	_hline(img, 21, 31, 17, Color("1d4b56"))   # saddle blanket — hero-cloak teal
	_rect(img, 26, 18, 1, 9, leather)
	_px(img, 26, 26, Color("c8a441"))          # buckle glint
	# near wing, rooted behind the cantle so the seat stays clear
	if wing == 0:      # raised — tall jagged sail
		for i in 14:
			var y := 15 - i
			var x1 := 21 - int(i * 0.35)
			var x0 := maxi(18 - int(i * 1.05), 6)
			if i % 3 == 2:
				x0 = maxi(x0 - 2, 4)
			_hline(img, x0, x1, y, memb)
			_px(img, x0, y, memb_d)
		for j in 13:
			_px(img, 21 - int(j * 0.35), 15 - j, bone)
		for j in 6:
			_px(img, 14 - j, 12 - j, memb_d)   # finger shadow
		_px(img, 17, 1, horn)                  # wrist claw
	elif wing == 1:    # level — broad blade swept back, scalloped trailing edge
		for i in 6:
			var y := 11 + i + wlow
			var x0 := 3 + i * 3
			_hline(img, x0, 20, y, memb)
			_px(img, x0, y, memb_d)
			if i % 2 == 1:
				_px(img, x0 - 1, y, memb_d)
		_hline(img, 3, 14, 10 + wlow, bone)
		_hline(img, 14, 20, 11 + wlow, bone)
		_px(img, 2, 9 + wlow, horn)            # wrist claw
	else:              # swept down past the flank
		for i in 11:
			var y := 16 + i
			var x1 := 19 - int(i * 0.35)
			var x0 := maxi(x1 - (9 - int(i * 0.7)), 3)
			if i % 3 == 1:
				x0 = maxi(x0 - 1, 3)
			_hline(img, x0, x1, y, memb)
			_px(img, x0, y, memb_d)
		for j in 10:
			_px(img, 19 - int(j * 0.35), 16 + j, bone)
		for j in 4:
			_px(img, 15 - j, 18 + j * 2, memb_d)   # membrane fold
		_px(img, 15, 27, horn)                 # wrist claw
	_edge_shade(img, 0.15)
	# glow accents stamped after shading so they stay hot
	_px(img, 42, 8, Color("2a1206"))           # eye socket
	_px(img, 43, 8, eye)
	_px(img, 43, 7, hi.lerp(eye, 0.55))        # glow bleeding onto the brow
	_px(img, 50, 10, Color("ff8a33"))          # smolder between the jaws
	_px(img, 38, 15, Color("ff8a33"))          # throat ember
	var embers := [Vector2i(24, 20), Vector2i(30, 22), Vector2i(35, 20),
			Vector2i(21, 23), Vector2i(28, 26), Vector2i(33, 25), Vector2i(37, 12)]
	for e in 3:
		var p: Vector2i = embers[(f * 3 + e * 2 + (0 if pose == "fly" else 1)) % embers.size()]
		_px(img, p.x, p.y, Color("ffcf6a") if e == 0 else Color("ff8a33"))
	_outline(img, Color("160a04"))
	return _tex(img)

# ---- PROPS (plain textures; scattered by world_gen, visual only) ---------------

static func prop_tex(kind: String) -> ImageTexture:
	var key := "prop_" + kind
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img: Image
	match kind:
		"tree_a":
			img = _tree_img(false)
		"tree_b":
			img = _tree_img(true)
		"rock":
			img = _rock_img()
		"dead_tree":
			img = _dead_tree_img()
		"ruin":
			img = _ruin_img()
		"bone":
			img = _bone_img()
		_:
			img = _shroom_img()
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex

static func _tree_img(conifer: bool) -> Image:
	var img := _img(20, 30)
	var trunk := Color("2a1e15")
	var trunk_d := Color("1d150e")
	var g1 := Color("1b2f22")
	var g2 := Color("223a2b")
	var g3 := Color("2c4a33")
	var g4 := Color("35573c")
	if conifer:
		_rect(img, 9, 21, 2, 8, trunk)
		_rect(img, 9, 21, 1, 8, trunk_d)
		_ellipse(img, 10.0, 17.0, 7.0, 4.0, g1)
		_ellipse(img, 10.0, 11.5, 5.0, 4.0, g2)
		_ellipse(img, 10.0, 6.0, 3.0, 3.0, g2)
		_ellipse(img, 11.0, 5.0, 1.6, 1.4, g3)
	else:
		_rect(img, 9, 19, 3, 10, trunk)
		_rect(img, 9, 19, 1, 10, trunk_d)
		_hline(img, 8, 12, 28, trunk_d)
		_ellipse(img, 10.0, 12.0, 8.0, 7.0, g1)
		_ellipse(img, 8.0, 10.0, 5.0, 4.0, g2)
		_ellipse(img, 13.0, 11.0, 5.0, 4.0, g2)
		_ellipse(img, 11.0, 8.0, 4.0, 3.0, g3)
		_ellipse(img, 13.0, 7.0, 2.0, 1.5, g4)
	# a few luminous green speckles in the canopy
	var salt := 31 if conifer else 47
	for y in 20:
		for x in 20:
			if img.get_pixel(x, y).a > 0.5:
				var s := _speck(x, y, salt)
				if s > 0.975:
					img.set_pixel(x, y, Color("57ff9a"))
				elif s > 0.94:
					img.set_pixel(x, y, g4)
	_outline(img)
	return img

static func _rock_img() -> Image:
	var img := _img(12, 9)
	var r := Color("3a3f49")
	var rd := Color("2b2f36")
	var rh := Color("565d6a")
	_ellipse(img, 5.0, 5.5, 4.5, 3.0, r)
	_ellipse(img, 9.0, 6.0, 2.5, 2.0, r)
	_ellipse(img, 4.5, 4.5, 2.5, 1.5, rh)
	_hline(img, 2, 10, 8, rd)
	_px(img, 6, 4, rd)
	_px(img, 6, 5, rd)
	_px(img, 7, 6, rd)
	_outline(img)
	return img

static func _dead_tree_img() -> Image:
	var img := _img(16, 28)
	var bark := Color("2e241a")
	var bark_d := Color("1c1610")
	var bark_h := Color("463828")
	# gnarled trunk with a root flare
	_rect(img, 7, 10, 3, 17, bark)
	_rect(img, 7, 10, 1, 17, bark_d)
	_hline(img, 6, 10, 27, bark_d)
	_rect(img, 6, 8, 3, 3, bark)
	_rect(img, 8, 5, 2, 4, bark)
	# clawing bare branches
	for j in 5:
		_px(img, 7 - j, 7 - j, bark)
	_px(img, 3, 2, bark_d)
	for j in 4:
		_px(img, 10 + j, 6 - j, bark)
	_px(img, 14, 2, bark_d)
	_px(img, 11, 12, bark)                  # snapped stub
	_px(img, 12, 13, bark_d)
	_px(img, 9, 4, bark_h)                  # moon-lit bark
	_px(img, 8, 9, bark_h)
	_px(img, 9, 14, bark_h)
	# one gloam-lit fungus shelf
	_px(img, 10, 18, Color("39d8e8"))
	_px(img, 11, 18, Color("1899a8"))
	_edge_shade(img, 0.2)
	_outline(img)
	return img

static func _ruin_img() -> Image:
	var img := _img(18, 18)
	var st := Color("4a515f")
	var st_d := Color("2f333c")
	var st_h := Color("636b7a")
	var moss := Color("2e5138")
	# broken column, sheared diagonally at the fracture
	_rect(img, 4, 6, 5, 11, st)
	_rect(img, 4, 6, 1, 11, st_d)
	_rect(img, 7, 6, 2, 11, st_h)           # moon-lit face
	_px(img, 4, 5, st)
	_rect(img, 5, 4, 2, 2, st)
	_px(img, 7, 3, st_h)
	_px(img, 8, 4, st_h)
	_px(img, 8, 5, st)
	# block seams + a vertical crack
	_hline(img, 4, 8, 9, st_d)
	_hline(img, 4, 8, 13, st_d)
	_px(img, 6, 10, st_d)
	_px(img, 6, 11, st_d)
	_px(img, 5, 12, st_d)
	# fallen capstone shard, lit on top
	_rect(img, 11, 13, 5, 3, st)
	_hline(img, 11, 15, 13, st_h)
	_hline(img, 11, 15, 15, st_d)
	# creeping moss + one luminous fleck
	_px(img, 5, 16, moss)
	_px(img, 6, 15, moss)
	_px(img, 8, 16, moss)
	_px(img, 11, 14, moss)
	_px(img, 4, 6, moss)
	_px(img, 5, 9, Color("57ff9a"))
	_edge_shade(img, 0.18)
	_outline(img)
	return img

static func _bone_img() -> Image:
	var img := _img(16, 10)
	var b := Color("cbc3ad")
	var bd := Color("8f866d")
	# half-buried ribcage — curved ribs of uneven height sinking into the ground
	var ribs := [[7, 2], [10, 1], [13, 3]]
	for r in ribs:
		var x: int = r[0]
		var top: int = r[1]
		_px(img, x + 1, top, bd)
		_px(img, x, top + 1, b)
		_px(img, x, top + 2, b)
		_px(img, x - 1, top + 3, b)
		_px(img, x - 1, top + 4, bd)
	_hline(img, 5, 14, 8, bd)               # buried spine line
	# skull, hollow eye socket toward the viewer
	_ellipse(img, 3.0, 5.0, 2.8, 2.4, b)
	_px(img, 2, 5, Color("14100a"))
	_px(img, 4, 5, Color("14100a"))
	_hline(img, 2, 4, 7, bd)                # jaw
	_px(img, 3, 3, Color("ffffff"))         # crown glint
	_edge_shade(img, 0.15)
	_outline(img)
	return img

static func _shroom_img() -> Image:
	var img := _img(9, 12)
	var stem := Color("cbc3ad")
	var stem_d := Color("989077")
	var cap := Color("39d8e8")
	var cap_hi := Color("a8f4ff")
	var cap_d := Color("1899a8")
	_rect(img, 4, 6, 2, 5, stem)
	_rect(img, 4, 6, 1, 5, stem_d)
	_hline(img, 3, 6, 2, cap)
	_rect(img, 2, 3, 6, 2, cap)
	_hline(img, 2, 7, 5, cap_d)
	_px(img, 4, 2, cap_hi)
	_px(img, 5, 2, cap_hi)
	_px(img, 3, 3, cap_hi)
	_outline(img)
	return img

# ---- PICKUPS -------------------------------------------------------------------

static func pickup_tex(kind: String) -> ImageTexture:
	var key := "pickup_" + kind
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img: Image
	match kind:
		"gold":
			img = _img(10, 10)
			_ellipse(img, 5.0, 7.5, 3.6, 1.4, Color("d8a63f"))
			_ellipse(img, 5.0, 5.5, 3.6, 1.4, Color("f2c14e"))
			_ellipse(img, 4.5, 3.5, 3.0, 1.3, Color("ffd166"))
			_hline(img, 2, 8, 6, Color("a87c28"))  # seams: 3 stacked coins
			_hline(img, 2, 7, 4, Color("b8892e"))
			_px(img, 3, 3, Color("fff3c9"))
			_outline(img, Color("4a3408"))
		"stone":
			img = _img(10, 10)
			for y in 10:
				for x in 10:
					var d := absf(x - 4.5) + absf(y - 4.5)
					if d <= 4.0:
						var c := Color("b06cff")
						if x + y < 8:
							c = Color("cf9dff")
						elif x >= 6:
							c = Color("7e46c9")
						_px(img, x, y, c)
			_px(img, 4, 2, Color("efe0ff"))
			_px(img, 3, 3, Color("efe0ff"))
			_outline(img, Color("321a56"))
		"snare":  # Soul Snare — small cyan loop with a trailing tie
			img = _img(10, 10)
			for y in 10:
				for x in 10:
					var d := Vector2(x - 4.0, y - 4.0).length()
					if d >= 2.1 and d <= 3.6:
						var c := Color("3fd0e0")
						if x + y < 7:
							c = Color("a8f4ff")   # top-left highlight
						elif x >= 6 and y >= 5:
							c = Color("1f8a9a")   # bottom-right shade
						_px(img, x, y, c)
			_px(img, 7, 7, Color("3fd0e0"))       # knot + trailing tie
			_px(img, 8, 8, Color("1f8a9a"))
			_px(img, 9, 9, Color("1f8a9a"))
			_outline(img, Color("0d3a44"))
		_:  # blade — diagonal sword, pale blade, ember cross-guard
			img = _img(14, 14)
			for i in 8:
				_px(img, 5 + i, 8 - i, Color("e8f0f2"))
				_px(img, 6 + i, 8 - i, Color("e8f0f2"))
			_px(img, 12, 1, Color("ffffff"))
			_px(img, 13, 1, Color("ffffff"))
			_px(img, 2, 7, Color("ff7a33"))
			_px(img, 3, 8, Color("ff7a33"))
			_px(img, 4, 9, Color("ff7a33"))
			_px(img, 5, 10, Color("ff7a33"))
			_px(img, 6, 11, Color("ff7a33"))
			_px(img, 3, 10, Color("55341f"))
			_px(img, 2, 11, Color("55341f"))
			_px(img, 1, 12, Color("ff7a33"))
			_outline(img, Color("101820"))
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex

# ---- ITEM ICONS (inventory/equipment UI + ground item drops) --------------------
# Per-slot silhouette tinted by rarity (grey/green/blue/purple/orange — items.gd
# owns the palette). Generated ONCE per (kind, rarity) into the static cache.

static func item_icon(kind: String, rarity: String) -> ImageTexture:
	var key := "icon_%s_%s" % [kind, rarity]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var base: Color = ProtoItems.rarity_color(rarity)
	var dark := base.darkened(0.45)
	var mid := base.darkened(0.12)
	var light := base.lightened(0.45)
	var img := _img(14, 14)
	match kind:
		"sword":
			for i in 8:
				_px(img, 4 + i, 10 - i, mid)
				_px(img, 5 + i, 10 - i, light)
			_px(img, 12, 2, light)
			_px(img, 3, 9, dark)   # crossguard
			_px(img, 4, 11, dark)
			_px(img, 5, 12, dark)
			_px(img, 2, 11, mid)   # grip
			_px(img, 1, 12, dark)
		"staff":
			_rect(img, 6, 4, 2, 9, dark)
			_px(img, 6, 5, mid)
			_px(img, 6, 8, mid)
			_ellipse(img, 7.0, 3.0, 2.4, 2.4, mid)
			_ellipse(img, 6.5, 2.5, 1.2, 1.2, light)
		"chest":
			_rect(img, 3, 3, 8, 2, mid)     # shoulders
			_rect(img, 4, 5, 6, 6, mid)     # torso
			_rect(img, 4, 5, 2, 6, dark)
			_px(img, 6, 3, dark)            # neck notch
			_px(img, 7, 3, dark)
			_px(img, 8, 6, light)
			_px(img, 8, 8, light)
		"helm":
			_ellipse(img, 7.0, 6.0, 4.5, 4.0, mid)
			_rect(img, 3, 7, 8, 4, mid)
			_hline(img, 4, 9, 8, dark)      # visor slit
			_px(img, 7, 2, light)           # crest glint
			_rect(img, 3, 7, 2, 4, dark)
		"boots":
			_rect(img, 4, 2, 3, 7, mid)     # shaft
			_rect(img, 4, 8, 6, 3, mid)     # foot
			_hline(img, 4, 10, 11, dark)    # sole
			_px(img, 4, 2, light)
			_rect(img, 4, 5, 1, 4, dark)
		"amulet":
			for i in 5:                     # chain arc
				_px(img, 3 + i * 2, 2 + absi(i - 2), dark)
			for y in range(6, 11):          # pendant diamond
				var half := 3 - absi(y - 8)
				_hline(img, 7 - half, 7 + half, y, mid)
			_px(img, 6, 7, light)
			_px(img, 8, 9, dark)
		"ring":
			for y in 14:
				for x in 14:
					var d := Vector2(x - 6.5, y - 7.5).length()
					if d >= 2.6 and d <= 4.4:
						_px(img, x, y, mid if x + y > 13 else dark)
			_px(img, 6, 3, light)           # gem
			_px(img, 7, 3, light)
			_px(img, 6, 2, mid)
		"rune":
			for y in 14:                    # carved diamond tablet
				for x in 14:
					var d := absf(x - 6.5) + absf(y - 6.5)
					if d <= 5.5:
						_px(img, x, y, dark if d > 4.0 else mid)
			_rect(img, 6, 4, 1, 5, light)   # glyph
			_hline(img, 5, 8, 6, light)
			_px(img, 8, 4, light)
		_:  # essence — swirling spirit orb
			_ellipse(img, 7.0, 7.0, 4.4, 4.4, dark)
			_ellipse(img, 7.0, 7.0, 3.2, 3.2, mid)
			_px(img, 6, 5, light)
			_px(img, 5, 6, light)
			_px(img, 8, 8, light)
			_px(img, 9, 7, mid)
			_px(img, 7, 3, light)           # rising wisp
			_px(img, 8, 1, mid)
	_outline(img)
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex

# ---- SHADOW / PARTICLE / OVERLAY textures --------------------------------------

static func shadow_tex(w: int, h: int) -> ImageTexture:
	var key := "shadow_%d_%d" % [w, h]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := _img(w, h)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := dx * dx + dy * dy
			if d <= 0.55:
				img.set_pixel(x, y, Color(0, 0, 0, 0.3))
			elif d <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.16))
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex

static func spore_tex() -> ImageTexture:
	if _tex_cache.has("spore"):
		return _tex_cache["spore"]
	var img := _img(3, 3)
	for y in 3:
		for x in 3:
			var d := absi(x - 1) + absi(y - 1)
			var a := 1.0 if d == 0 else (0.55 if d == 1 else 0.22)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := _tex(img)
	_tex_cache["spore"] = tex
	return tex

const GLOW_TEX_SIZE := 64

# Soft radial falloff for ProtoGlow additive sprites (the gl_compatibility
# stand-in for HDR bloom, canon §4). Quadratic ease keeps the core hot and the
# rim gentle so stacked glows never band.
static func glow_tex() -> ImageTexture:
	if _tex_cache.has("glow"):
		return _tex_cache["glow"]
	var img := _img(GLOW_TEX_SIZE, GLOW_TEX_SIZE)
	var c := (GLOW_TEX_SIZE - 1) * 0.5
	for y in GLOW_TEX_SIZE:
		for x in GLOW_TEX_SIZE:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	var tex := _tex(img)
	_tex_cache["glow"] = tex
	return tex

static func vignette_tex() -> ImageTexture:
	if _tex_cache.has("vignette"):
		return _tex_cache["vignette"]
	var img := _img(160, 90)
	for y in 90:
		for x in 160:
			var dx := (x + 0.5 - 80.0) / 80.0
			var dy := (y + 0.5 - 45.0) / 45.0
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf((d - 0.55) / 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.02, 0.03, 0.05, a * a * 0.38))
	var tex := _tex(img)
	_tex_cache["vignette"] = tex
	return tex

# Soft strip for the MultiMesh ribbon quads (ribbons.gd). Alpha is a transverse (Y)
# gaussian falloff, ~uniform along the length (X), so abutting segment quads read as
# ONE continuous glowing strip — a radial glow_tex() would go dotty at the joins.
# Cached once like the other textures. Sampled with LINEAR filter on the ribbon node.
const RIBBON_TEX_W := 32
const RIBBON_TEX_H := 16

static func ribbon_tex() -> ImageTexture:
	if _tex_cache.has("ribbon"):
		return _tex_cache["ribbon"]
	var img := _img(RIBBON_TEX_W, RIBBON_TEX_H)
	var cy := (RIBBON_TEX_H - 1) * 0.5
	for y in RIBBON_TEX_H:
		var dy := (y - cy) / cy               # -1 (top edge) .. +1 (bottom edge)
		var a := exp(-3.5 * dy * dy)          # transverse gaussian; ~0 at the rims
		a *= smoothstep(0.0, 0.12, 1.0 - absf(dy))   # crisp fade to zero at the edge
		for x in RIBBON_TEX_W:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	var tex := _tex(img)
	_tex_cache["ribbon"] = tex
	return tex

# ---- legacy shape helpers (projectiles etc.) ------------------------------------

static func circle_tex(diameter: int, fill: Color, core: Color, outline: Color) -> ImageTexture:
	var key := "circ_%d_%s_%s_%s" % [diameter, fill, core, outline]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := _img(diameter, diameter)
	var r := diameter / 2.0 - 0.5
	var c := Vector2(r, r)
	for y in diameter:
		for x in diameter:
			var d := Vector2(x, y).distance_to(c)
			if d <= r * 0.45:
				img.set_pixel(x, y, core)
			elif d <= r - 1.0:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, outline)
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex

static func diamond_tex(size: int, fill: Color, outline: Color) -> ImageTexture:
	var key := "diam_%d_%s_%s" % [size, fill, outline]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var img := _img(size, size)
	var half := size / 2.0
	for y in size:
		for x in size:
			var d := absf(x - half + 0.5) + absf(y - half + 0.5)
			if d <= half - 1.5:
				img.set_pixel(x, y, fill)
			elif d <= half - 0.5:
				img.set_pixel(x, y, outline)
	var tex := _tex(img)
	_tex_cache[key] = tex
	return tex
