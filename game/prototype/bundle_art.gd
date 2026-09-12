# PROTOTYPE HARNESS — loader for the GenForge-baked hi-fi actor bundles
# (res://prototype/art/<actor>/{sheet.png, atlas.json}, baked by
# genforge/pipeline/bake_game_art.py). Frames are baked at 2x the logical
# on-screen pixel size; every sliced ImageTexture gets
# set_size_override(logical_size) so world-space sizes stay identical to the
# procedural ProtoSprites placeholders while the extra detail rides through
# the canvas_items window upscale. Everything is sliced ONCE into a static
# cache (misses included), and any missing/corrupt bundle returns null so the
# caller can fall back to the procedural art — a bare checkout still runs.
class_name ProtoBundleArt

const ART_DIR := "res://prototype/art"

static var _cache: Dictionary = {}

# The loader contract: SpriteFrames with the atlas's animations (per-anim fps
# + loop flags, frames sliced from the combined sheet), or null on ANY error.
static func frames_for(actor: String) -> SpriteFrames:
	if _cache.has(actor):
		return _cache[actor]
	var t0 := Time.get_ticks_usec()
	var sf := _build(actor)
	if sf != null:
		print("[ProtoBundleArt] %s: bundle loaded in %.1f ms" %
				[actor, float(Time.get_ticks_usec() - t0) / 1000.0])
	else:
		push_warning("[ProtoBundleArt] %s: no baked bundle — procedural fallback" % actor)
	_cache[actor] = sf   # nulls too: one disk probe per actor, ever
	return sf

# Aliases every animation the game plays but the bundle lacks (safety net —
# the bakes ship all of them). Donor preference: walk -> fly -> idle.
static func ensure_animations(sf: SpriteFrames, required: Array) -> void:
	for anim_name in required:
		if sf.has_animation(anim_name):
			continue
		var donor := ""
		for cand in ["walk", "fly", "idle"]:
			if cand != anim_name and sf.has_animation(cand) and sf.get_frame_count(cand) > 0:
				donor = cand
				break
		if donor.is_empty():
			for cand in sf.get_animation_names():
				if cand != anim_name and sf.get_frame_count(cand) > 0:
					donor = cand
					break
		if donor.is_empty():
			continue
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, sf.get_animation_speed(donor))
		# A missing action must finish; inheriting a looping walk could pin the
		# actor in its attack forever. This fallback is never an art approval.
		sf.set_animation_loop(anim_name, anim_name in ["idle", "walk", "fly"])
		for i in sf.get_frame_count(donor):
			sf.add_frame(anim_name, sf.get_frame_texture(donor, i))

static func _build(actor: String) -> SpriteFrames:
	var dir := "%s/%s" % [ART_DIR, actor]
	var atlas_text := FileAccess.get_file_as_string(dir + "/atlas.json")
	if atlas_text.is_empty():
		return null
	var atlas: Variant = JSON.parse_string(atlas_text)
	if typeof(atlas) != TYPE_DICTIONARY:
		return null
	var frame_size: Variant = atlas.get("frame_size")
	var logical: Variant = atlas.get("logical_size", frame_size)
	var anims: Variant = atlas.get("animations")
	if typeof(frame_size) != TYPE_ARRAY or frame_size.size() != 2 \
			or typeof(logical) != TYPE_ARRAY or logical.size() != 2 \
			or typeof(anims) != TYPE_DICTIONARY or anims.is_empty():
		return null
	var fw := int(frame_size[0])
	var fh := int(frame_size[1])
	var lsize := Vector2i(int(logical[0]), int(logical[1]))
	if fw <= 0 or fh <= 0 or lsize.x <= 0 or lsize.y <= 0:
		return null
	var img := _sheet_image(dir + "/" + str(atlas.get("combined_sheet", "sheet.png")))
	if img == null:
		return null
	# Optional normal-map sibling (genforge/pipeline/normal_gen.py --batch bakes
	# sheet_n.png next to every sheet). Frames become CanvasTextures so the
	# sprite-lit shader reads NORMAL for per-pixel N·L sculpting; actors without
	# a map degrade gracefully to flat normals.
	var sheet_name := str(atlas.get("combined_sheet", "sheet.png"))
	var nimg := _sheet_image(dir + "/" + sheet_name.get_basename() + "_n.png")
	var sf := SpriteFrames.new()
	for anim_name in anims:
		var a: Variant = anims[anim_name]
		if typeof(a) != TYPE_DICTIONARY:
			return null
		var count := int(a.get("frames", 0))
		var row := int(a.get("row", -1))
		if count <= 0 or row < 0 or (row + 1) * fh > img.get_height() \
				or count * fw > img.get_width():
			return null
		if not sf.has_animation(anim_name):   # SpriteFrames.new() pre-adds "default"
			sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(a.get("fps", 8.0)))
		sf.set_animation_loop(anim_name, bool(a.get("loop", true)))
		for i in count:
			var rect := Rect2i(i * fw, row * fh, fw, fh)
			var tex := ImageTexture.create_from_image(img.get_region(rect))
			tex.set_size_override(lsize)   # hi-res detail at logical world size
			if nimg != null and rect.end.x <= nimg.get_width() \
					and rect.end.y <= nimg.get_height():
				var ct := CanvasTexture.new()   # diffuse+normal bundle: the
				ct.diffuse_texture = tex        # sprite-lit shader reads NORMAL
				ct.normal_texture = ImageTexture.create_from_image(
						nimg.get_region(rect))
				sf.add_frame(anim_name, ct)
			else:
				sf.add_frame(anim_name, tex)
	return sf

# Imported texture first (the path that works in exported packs), raw PNG as
# the dev fallback for a fresh bake that has not been reimported yet.
static func _sheet_image(path: String) -> Image:
	if ResourceLoader.exists(path, "Texture2D"):
		var tex: Texture2D = load(path)
		if tex != null:
			var img := tex.get_image()
			if img != null:
				if img.is_compressed() and img.decompress() != OK:
					return null
				return img
	if FileAccess.file_exists(path):
		return Image.load_from_file(path)
	return null
