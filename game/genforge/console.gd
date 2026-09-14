# GENFORGE CONSOLE — the content pipeline as a cockpit (Ricardo, 2026-09-13:
# "And how about the asset generation console?").
#
# tools/genforge.py made create/check/approve one command; this makes it one
# screen. Same seam the training console uses: the GUI NEVER re-implements the
# rules — it shells out to the python tool with --json and renders what comes
# back. A finding is a finding in exactly one place (tools/genforge.py), so the
# console cannot drift into saying an asset is fine when the CI gate says it is
# not.
#
#   PACKS      every release and its bundles, with approval state (left column)
#   AUDIT      the findings, coloured: ok / warn / FAIL
#   ART        one row per art entry — provenance verified? clips complete?
#   REVIEW     THE ASSETS THEMSELVES: the sprite sheet, its clips playing at
#              their own fps, its frame rects and its blockers — in the console
#   CREATE     draft a new release from an existing chapter, optionally build it
#   APPROVE    record the human half, pinned to the bundle's content hash
#
# REBUILT 2026-09-14. Ricardo: "assets generation console not working properly:
# console design is bloated and overflowing ... as well as I can't see anything
# for reviewing". Both were true and they were the same mistake — this was a flat
# two-column Control with every panel stacked into one screen, no window fitting,
# no scrolling, no tabs, and a REVIEW button that shelled out to an external
# browser (on packs[0], not even the selected pack). An assets console has to
# SHOW the assets. It now fits its window like the arena cockpit
# (game/tools/console_fit.gd), files the panels into tabs, and draws the bundle's
# art itself. Gated by game/genforge/tests/console_layout_probe.tscn.
#
# Launch:
#   godot --path game res://genforge/console.tscn
#   godot --headless --path game res://genforge/console.tscn -- --selftest
#
# check/list/approve are sub-second, so they run through OS.execute inline.
# build is not, so it is spawned and polled like the trainer.
extends Control

const TOOL := "tools/genforge.py"
const POLL_S := 0.5
const LOG_DIR := "ml/data/logs"

const EMBER := Color("ff9a3c")
const PALE := Color("d9d4c7")
const DIM := Color(0.5, 0.49, 0.45)
const CYAN := Color("7fd8ff")
const GREEN := Color("7ce7a2")
const RED := Color("ff5a5a")
const LEVEL_COLOR := {"ok": GREEN, "warn": EMBER, "bad": RED}

var _repo := ""
var _selftest := false
var _packs: Array = []
var _templates: Array = []
var _audit: Dictionary = {}
var _note := ""
var _pid := -1
var _pid_kind := ""
var _proc_note := ""
var _poll := 0.0

var _pack_list: ItemList
var _findings: ItemList
var _art_list: ItemList
var _status: Label
var _detail: Label
var _note_edit: LineEdit
var _new_pack: LineEdit
var _new_title: LineEdit
var _template: OptionButton
var _buttons: Dictionary = {}

# REVIEW — the bundle's art, drawn here instead of in someone else's browser
var _art_pick: OptionButton
var _clip_pick: OptionButton
var _clip_list: ItemList
var _sheet: TextureRect
var _frame: TextureRect
var _frame_note: Label
var _review_note: Label
var _play_btn: Button
var _atlas: Dictionary = {}        # the selected art entry's atlas.json
var _sheet_tex: Texture2D = null
var _frame_i := 0
var _frame_t := 0.0
var _playing := true

func _ready() -> void:
	_repo = DhRepoRoot.find()
	_selftest = OS.get_cmdline_user_args().has("--selftest")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _selftest:
		DhConsoleFit.apply(get_window())   # the same rule the arena cockpit uses
	_build_ui()
	_refresh()
	if _selftest:
		_run_selftest()

# ---- UI ------------------------------------------------------------------------------

# Wrapping is the DEFAULT. A Label reports its whole string as its minimum
# width, and that minimum propagates up through the tab and the root HBox — one
# unwrapped sentence is all it takes to push the cockpit off the right edge of
# the screen. Callers opt out for the short captions inside a row, where a wrap
# would put one word per line.
func _label(text: String, color: Color, size := ProtoTheme.SIZE_BODY,
		wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(1, 0)
		l.clip_text = true
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _to_main_menu() -> void:
	if _selftest:
		return        # the button is LAID OUT under selftest, it just does not navigate
	get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn")

# A way out that no layout can take away. The BACK button was unreachable
# because it depended on there being room for it; Escape does not.
func _unhandled_input(event: InputEvent) -> void:
	if _selftest:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_to_main_menu()


func _button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	_buttons[text] = b
	return b

func _list(min_h: int) -> ItemList:
	var l := ItemList.new()
	l.custom_minimum_size = Vector2(0, min_h)
	l.auto_height = false
	l.focus_mode = Control.FOCUS_NONE
	return l

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c1116")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 6.0
	root.offset_top = 6.0
	root.offset_right = -6.0
	root.offset_bottom = -6.0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# ---- left: the packs and the actions. 236 px, and it SCROLLS — the column
	# used to be 330 px of stacked panels on a canvas that can be 640 wide.
	var left_frame := VBoxContainer.new()
	left_frame.custom_minimum_size = Vector2(236, 0)
	left_frame.add_theme_constant_override("separation", 3)
	root.add_child(left_frame)
	# Ricardo, 2026-09-14: "we just can't go back from it to the main menu".
	# The BACK button existed, at the bottom of the RIGHT column under a
	# TabContainer that expands to fill — so whenever a tab's contents wanted
	# more height than the viewport had, the only way out was pushed off the
	# bottom edge. It lives in the title row now: the left column is a fixed
	# 236 px and its first row is never the one that gets clipped.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	left_frame.add_child(title_row)
	# Built even under --selftest, deliberately: the layout probe skipped the old
	# BACK button, which is exactly why nobody measured the one control that had
	# been pushed off the canvas. A button that is never laid out is never gated.
	_button(title_row, "< BACK", _to_main_menu).tooltip_text = \
			"Back to the main menu (Esc)"
	title_row.add_child(_label("GENFORGE", EMBER, ProtoTheme.SIZE_TITLE))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_frame.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	scroll.add_child(left)

	left.add_child(_label("content packs — genforge/releases/ + the bundles they bake", DIM))
	_pack_list = _list(120)
	_pack_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pack_list.item_selected.connect(func(_i: int) -> void: _select_pack())
	left.add_child(_pack_list)

	# a row of buttons must WRAP, not force the column open
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 3)
	_button(row, "CHECK", _check).tooltip_text = \
			"Audit this pack: schema, lore refs, art provenance (sha256 of the image " \
			+ "against the prompt that made it), clip coverage, bundle digests, approval."
	_button(row, "BUILD", _build).tooltip_text = \
			"Bake the reviewable bundle. Identical inputs re-verify the existing one " \
			+ "instead of rewriting it — the bundle is immutable and hash-named."
	_button(row, "REVIEW", _review).tooltip_text = \
			"Load this pack's bundle into the REVIEW tab: the sheet, the clips, the blockers."
	_button(row, "APPROVE", func() -> void: _decide("approve"))
	_button(row, "REJECT", func() -> void: _decide("reject"))
	_button(row, "REFRESH", _refresh)
	left.add_child(row)

	left.add_child(_label("note / reason — recorded with the decision", DIM))
	_note_edit = LineEdit.new()
	_note_edit.placeholder_text = "art reviewed, frame time captured"
	_note_edit.text_changed.connect(func(t: String) -> void: _note = t)
	left.add_child(_note_edit)

	_status = _label("", PALE)
	left.add_child(_status)

	# ---- right: the tabs
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	root.add_child(right)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_color_override("font_selected_color", EMBER)
	tabs.add_theme_color_override("font_unselected_color", DIM)
	right.add_child(tabs)
	_build_review_tab(tabs)      # first: this is what the console is FOR
	_build_audit_tab(tabs)
	_build_art_tab(tabs)
	_build_create_tab(tabs)

	# (BACK now lives in the title row above — see _build_ui's title_row.)

# REVIEW — Ricardo, 2026-09-14: "I can't see anything for reviewing". The old
# button called OS.shell_open on the bundle's index.html: an external browser,
# outside the app, on packs[0] rather than the selected pack. The bundle already
# holds everything a reviewer needs — art/<name>/albedo.png and an atlas.json
# with the clips, their fps, their frame rects and the blockers the build
# refused to clear — so the console draws it.
func _build_review_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "REVIEW"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)

	var pick := HFlowContainer.new()
	pick.add_theme_constant_override("h_separation", 4)
	pick.add_child(_label("art", DIM, ProtoTheme.SIZE_BODY, false))
	_art_pick = OptionButton.new()
	_art_pick.focus_mode = Control.FOCUS_NONE
	_art_pick.item_selected.connect(func(_i: int) -> void: _load_art())
	pick.add_child(_art_pick)
	pick.add_child(_label("clip", DIM, ProtoTheme.SIZE_BODY, false))
	_clip_pick = OptionButton.new()
	_clip_pick.focus_mode = Control.FOCUS_NONE
	_clip_pick.item_selected.connect(func(_i: int) -> void: _select_clip())
	pick.add_child(_clip_pick)
	_play_btn = _button(pick, "PAUSE", func() -> void:
		_playing = not _playing
		_refresh_ui())
	_button(pick, "OPEN PAGE", _open_page).tooltip_text = \
			"The bundle's index.html in a browser — the same data, plus the stat tables."
	v.add_child(pick)

	_review_note = _label("", PALE)
	_review_note.custom_minimum_size = Vector2(1, 24)
	v.add_child(_review_note)

	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 6)
	v.add_child(stage)

	var frame_col := VBoxContainer.new()
	frame_col.custom_minimum_size = Vector2(104, 0)
	frame_col.add_theme_constant_override("separation", 2)
	stage.add_child(frame_col)
	frame_col.add_child(_label("FRAME", EMBER))
	_frame = TextureRect.new()
	_frame.custom_minimum_size = Vector2(96, 96)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_col.add_child(_frame)
	_frame_note = _label("", DIM)
	frame_col.add_child(_frame_note)

	var sheet_col := VBoxContainer.new()
	sheet_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_col.add_theme_constant_override("separation", 2)
	stage.add_child(sheet_col)
	sheet_col.add_child(_label("SHEET — every frame in the atlas", EMBER))
	var sheet_scroll := ScrollContainer.new()
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_col.add_child(sheet_scroll)
	_sheet = TextureRect.new()
	_sheet.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.add_child(_sheet)

	v.add_child(_label("CLIPS — and the blockers the build refused to clear", EMBER))
	_clip_list = _list(52)
	v.add_child(_clip_list)

func _build_audit_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "AUDIT"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("AUDIT — every finding, in order", EMBER))
	v.add_child(_label("the GUI never re-implements a rule: this is what "
			+ "tools/genforge.py said, rendered.", DIM))
	_findings = _list(80)
	_findings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_findings)
	_detail = _label("", PALE)
	_detail.custom_minimum_size = Vector2(1, 40)
	v.add_child(_detail)

func _build_art_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "ART"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("ART — one row per asset: is the image verifiable, are the "
			+ "clips complete?", EMBER))
	v.add_child(_label("provenance = sha256 of the image against the prompt that made "
			+ "it. A mismatch means the file on disk is not what the prompt produced.", DIM))
	_art_list = _list(80)
	_art_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art_list.item_selected.connect(func(i: int) -> void:
		if _art_pick != null and i < _art_pick.item_count:
			_art_pick.select(i)
			_load_art())
	v.add_child(_art_list)

func _build_create_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "CREATE"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("CREATE — draft a new chapter from an existing one", EMBER))
	v.add_child(_label("a template remap is NOT new content: replace the inherited "
			+ "stories, kits, art sources and season.", DIM))
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 4)
	form.add_child(_label("from", DIM, ProtoTheme.SIZE_BODY, false))
	_template = OptionButton.new()
	_template.focus_mode = Control.FOCUS_NONE
	form.add_child(_template)
	form.add_child(_label("pack", DIM, ProtoTheme.SIZE_BODY, false))
	_new_pack = LineEdit.new()
	_new_pack.placeholder_text = "ash_wake"
	_new_pack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_new_pack)
	form.add_child(_label("title", DIM, ProtoTheme.SIZE_BODY, false))
	_new_title = LineEdit.new()
	_new_title.placeholder_text = "The Ash Wake"
	_new_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_new_title)
	v.add_child(form)
	var crow := HFlowContainer.new()
	crow.add_theme_constant_override("h_separation", 4)
	_button(crow, "CREATE", func() -> void: _create(false))
	_button(crow, "CREATE + BUILD", func() -> void: _create(true))
	v.add_child(crow)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

# ---- running the tool ------------------------------------------------------------------

static func _sq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

# Blocking, for the sub-second commands. Returns [exit_code, stdout].
func _tool(args: String) -> Array:
	if _repo == "":
		return [127, DhRepoRoot.missing_note()]
	var out: Array = []
	var cmd := "cd %s && python3 %s %s" % [_sq(_repo), TOOL, args]
	var code := OS.execute("bash", ["-lc", cmd], out, true)
	return [code, out[0] if out.size() > 0 else ""]

func _tool_json(args: String) -> Dictionary:
	var r := _tool(args + " --json")
	var text := str(r[1])
	var brace := text.find("{")
	if brace < 0:
		_proc_note = "genforge.py produced no JSON: " + text.substr(0, 160)
		return {}
	var parsed = JSON.parse_string(text.substr(brace))
	if not (parsed is Dictionary):
		_proc_note = "could not parse genforge.py output"
		return {}
	return parsed

func _spawn(args: String, kind: String) -> void:
	if _pid > 0:
		return
	if _repo == "":
		_proc_note = DhRepoRoot.missing_note()
		_refresh_ui()
		return
	DirAccess.make_dir_recursive_absolute(_repo.path_join(LOG_DIR))
	var log := _repo.path_join(LOG_DIR).path_join("genforge_console.log")
	var cmd := "cd %s && exec python3 %s %s >> %s 2>&1" % [
			_sq(_repo), TOOL, args, _sq(log)]
	_pid = OS.create_process("bash", ["-lc", cmd])
	if _pid <= 0:
		_pid = -1
		_proc_note = "could not spawn bash"
	else:
		_pid_kind = kind
		_proc_note = "%s running · pid %d · %s/genforge_console.log" % [kind, _pid, LOG_DIR]
	_refresh_ui()

func _process(delta: float) -> void:
	_advance(delta)                 # the review clip plays whether or not a build runs
	if _pid <= 0:
		return
	_poll += delta
	if _poll < POLL_S:
		return
	_poll = 0.0
	if not OS.is_process_running(_pid):
		_proc_note = "%s finished" % _pid_kind
		_pid = -1
		_pid_kind = ""
		_refresh()

# ---- actions ---------------------------------------------------------------------------

func _selected_pack() -> String:
	var sel := _pack_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _packs.size():
		return ""
	return str((_packs[sel[0]] as Dictionary).get("pack", ""))

func _refresh() -> void:
	var data := _tool_json("list")
	_packs = data.get("packs", [])
	_templates = data.get("templates", [])
	_pack_list.clear()
	for p in _packs:
		var d: Dictionary = p
		var state := str(d.get("state", ""))
		var i := _pack_list.add_item("%s   %s" % [d.get("pack", "?"), state])
		_pack_list.set_item_custom_fg_color(i, GREEN if state == "approved"
				else RED if state == "REJECTED" else PALE)
	if not _packs.is_empty() and _pack_list.get_selected_items().is_empty():
		_pack_list.select(0)
	if _template != null:
		_template.clear()
		for t in _templates:
			_template.add_item(str(t))
	_select_pack()

func _select_pack() -> void:
	_audit = {}
	_art_list.clear()
	_findings.clear()
	if _art_pick != null:
		_art_pick.clear()
	_load_art()                     # clears the sheet, the clips and the note
	_refresh_ui()

func _check() -> void:
	var pack := _selected_pack()
	if pack == "":
		_proc_note = "pick a pack"
		_refresh_ui()
		return
	_audit = _tool_json("check " + _sq(pack))
	_render_audit()

func _render_audit() -> void:
	_art_list.clear()
	_findings.clear()
	var packs: Array = _audit.get("packs", [])
	if packs.is_empty():
		_refresh_ui()
		return
	var p: Dictionary = _audit_row()
	if p.is_empty():
		p = packs[0]
	for a in p.get("art", []):
		var d: Dictionary = a
		var worst := str(d.get("worst", "ok"))
		var clips: Array = d.get("required_clips", [])
		var i := _art_list.add_item("%s   %d required clip(s)" % [d.get("id", "?"), clips.size()])
		_art_list.set_item_custom_fg_color(i, LEVEL_COLOR.get(worst, PALE))
		_art_list.set_item_tooltip(i, str(d.get("source", "")))
	for f in p.get("findings", []):
		var d: Dictionary = f
		var level := str(d.get("level", "ok"))
		var i := _findings.add_item("[%s] %s: %s" % [level.to_upper(),
				d.get("who", ""), d.get("message", "")])
		_findings.set_item_custom_fg_color(i, LEVEL_COLOR.get(level, PALE))
	# a fresh audit re-arms the review tab: new bundle, new art list
	_fill_art_pick()
	_load_art()
	_refresh_ui()

func _build() -> void:
	var pack := _selected_pack()
	if pack == "":
		_proc_note = "pick a pack"
		_refresh_ui()
		return
	_spawn("build " + _sq(pack), "build " + pack)

# ---- REVIEW: the bundle's art, in the console --------------------------------------

# The audit row for the SELECTED pack. The old code read packs[0] unconditionally,
# so on a multi-pack repo REVIEW opened somebody else's bundle.
func _audit_row() -> Dictionary:
	var pack := _selected_pack()
	for entry in _audit.get("packs", []):
		var d: Dictionary = entry
		if pack == "" or str(d.get("pack", "")) == pack:
			return d
	return {}

func _bundle_dir() -> String:
	var row := _audit_row()
	var bundle := str(row.get("bundle", ""))
	if bundle == "" or bundle.begins_with("("):
		return ""
	return bundle if bundle.begins_with("/") else _repo.path_join(bundle)

# REVIEW arms the tab for the selected pack: CHECK first if it has not run, then
# list the pack's art entries and load the first one.
func _review() -> void:
	if _selected_pack() == "":
		_proc_note = "pick a pack"
		_refresh_ui()
		return
	if _audit_row().is_empty():
		_check()
	_fill_art_pick()
	_load_art()
	_refresh_ui()

func _fill_art_pick() -> void:
	if _art_pick == null:
		return
	var want := ""
	if _art_pick.selected >= 0:
		want = str(_art_pick.get_item_metadata(_art_pick.selected))
	_art_pick.clear()
	for entry in _audit_row().get("art", []):
		var d: Dictionary = entry
		var id := str(d.get("id", ""))
		_art_pick.add_item(id.get_slice(".", id.get_slice_count(".") - 1))
		_art_pick.set_item_metadata(_art_pick.item_count - 1, id)
		if want != "" and want == id:
			_art_pick.select(_art_pick.item_count - 1)
	if _art_pick.item_count > 0 and _art_pick.selected < 0:
		_art_pick.select(0)

# atlas.json + albedo.png for the selected art entry. Everything here is outside
# res://, so the image is loaded from disk at runtime rather than imported.
func _load_art() -> void:
	_atlas = {}
	_sheet_tex = null
	_frame_i = 0
	_frame_t = 0.0
	if _sheet != null:
		_sheet.texture = null
	if _frame != null:
		_frame.texture = null
	if _clip_list != null:
		_clip_list.clear()
	if _clip_pick != null:
		_clip_pick.clear()
	var bundle := _bundle_dir()
	if bundle == "":
		_review_note.text = "no bundle yet — BUILD this pack, then REVIEW"
		_refresh_ui()
		return
	if _art_pick == null or _art_pick.selected < 0:
		_review_note.text = "no art entries in this pack's audit — run CHECK"
		_refresh_ui()
		return
	var id := str(_art_pick.get_item_metadata(_art_pick.selected))
	var short := id.get_slice(".", id.get_slice_count(".") - 1)
	var dir := bundle.path_join("art").path_join(short)
	var atlas_raw := FileAccess.get_file_as_string(dir.path_join("atlas.json"))
	if atlas_raw == "":
		_review_note.text = "no atlas at %s — the build did not bake this entry" % \
				dir.path_join("atlas.json")
		_refresh_ui()
		return
	var parsed: Variant = JSON.parse_string(atlas_raw)
	if not (parsed is Dictionary):
		_review_note.text = "atlas.json is not readable JSON"
		_refresh_ui()
		return
	_atlas = parsed
	var albedo := dir.path_join(str(_atlas.get("albedo", "albedo.png")))
	var img := Image.load_from_file(albedo)
	if img != null:
		_sheet_tex = ImageTexture.create_from_image(img)
		_sheet.texture = _sheet_tex
	for entry in _atlas.get("clips", []):
		var c: Dictionary = entry
		_clip_pick.add_item(str(c.get("name", "?")))
		_clip_pick.set_item_metadata(_clip_pick.item_count - 1, str(c.get("name", "?")))
	if _clip_pick.item_count > 0:
		_clip_pick.select(0)
	_fill_clip_list()
	_select_clip()

func _fill_clip_list() -> void:
	_clip_list.clear()
	for entry in _atlas.get("clips", []):
		var c: Dictionary = entry
		var frames: Array = c.get("frames", [])
		var i := _clip_list.add_item("%s — %d frame(s) @ %s fps%s" % [
				str(c.get("name", "?")), frames.size(), str(c.get("fps", "?")),
				" · loops" if bool(c.get("loop", false)) else ""])
		_clip_list.set_item_custom_fg_color(i, GREEN)
	# A blocker is the reason this asset is not shippable. It belongs next to the
	# clips it is about, not buried in a findings list on another tab.
	for b in _atlas.get("blockers", []):
		var i := _clip_list.add_item("BLOCKER — %s" % str(b))
		_clip_list.set_item_custom_fg_color(i, RED)

func _current_clip() -> Dictionary:
	if _clip_pick == null or _clip_pick.selected < 0:
		return {}
	var want := str(_clip_pick.get_item_metadata(_clip_pick.selected))
	for entry in _atlas.get("clips", []):
		var c: Dictionary = entry
		if str(c.get("name", "")) == want:
			return c
	return {}

func _select_clip() -> void:
	_frame_i = 0
	_frame_t = 0.0
	var clip := _current_clip()
	var blockers: Array = _atlas.get("blockers", [])
	var anchor: Array = _atlas.get("anchor", [])
	_review_note.text = "%s · %d clip(s) · %d blocker(s)%s" % [
			str(_art_pick.get_item_text(_art_pick.selected)) if _art_pick.selected >= 0 else "?",
			(_atlas.get("clips", []) as Array).size(), blockers.size(),
			" · anchor %s" % str(anchor) if not anchor.is_empty() else ""]
	if not blockers.is_empty():
		_review_note.add_theme_color_override("font_color", EMBER)
	else:
		_review_note.add_theme_color_override("font_color", PALE)
	_show_frame()
	_refresh_ui()

# One frame of the selected clip, cut out of the sheet with an AtlasTexture so
# nothing is copied per tick.
func _show_frame() -> void:
	var clip := _current_clip()
	var rects: Array = clip.get("rects", [])
	if _sheet_tex == null or rects.is_empty():
		_frame.texture = null
		_frame_note.text = "no frames"
		return
	_frame_i = _frame_i % rects.size()
	var r: Array = rects[_frame_i]
	if r.size() < 4:
		return
	var at := AtlasTexture.new()
	at.atlas = _sheet_tex
	at.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	_frame.texture = at
	_frame_note.text = "%s  %d/%d  %dx%d" % [str(clip.get("name", "?")),
			_frame_i + 1, rects.size(), int(r[2]), int(r[3])]

func _advance(delta: float) -> void:
	if not _playing or _sheet_tex == null:
		return
	var clip := _current_clip()
	var rects: Array = clip.get("rects", [])
	if rects.size() < 2:
		return
	var fps := maxf(float(clip.get("fps", 10)), 1.0)
	var ticks: Array = clip.get("frame_ticks", [])
	# frame_ticks is in 1/fps units, so a 3-tick frame is three times as long as
	# a 1-tick one — honouring it is the difference between a review and a flicker
	var hold := float(ticks[_frame_i]) if _frame_i < ticks.size() else 1.0
	_frame_t += delta
	if _frame_t < maxf(hold, 1.0) / fps:
		return
	_frame_t = 0.0
	_frame_i += 1
	if _frame_i >= rects.size() and not bool(clip.get("loop", true)):
		_frame_i = rects.size() - 1
	_show_frame()

func _open_page() -> void:
	var page := str(_audit_row().get("review_page", ""))
	if page == "":
		_proc_note = "run CHECK first — the review page comes from the audit"
	elif not FileAccess.file_exists(page):
		_proc_note = "no bundle yet: BUILD the pack first"
	else:
		OS.shell_open("file://" + page)
		_proc_note = "opened " + page.get_file()
	_refresh_ui()

func _decide(what: String) -> void:
	var pack := _selected_pack()
	if pack == "":
		_proc_note = "pick a pack"
		_refresh_ui()
		return
	if what == "reject" and _note.strip_edges() == "":
		_proc_note = "a rejection needs a reason — type it above"
		_refresh_ui()
		return
	var flag := "--note" if what == "approve" else "--reason"
	var r := _tool("%s %s %s %s" % [what, _sq(pack), flag, _sq(_note)])
	_proc_note = ("%s: %s" % [what, str(r[1]).strip_edges().replace("\n", " · ")]) \
			if int(r[0]) == 0 else "%s failed: %s" % [what, str(r[1]).substr(0, 160)]
	_refresh()
	_check()

func _create(and_build: bool) -> void:
	var pack := _new_pack.text.strip_edges()
	var title := _new_title.text.strip_edges()
	if pack == "" or title == "" or _template.selected < 0:
		_proc_note = "CREATE needs a template, a pack name and a title"
		_refresh_ui()
		return
	var args := "create --from %s --pack %s --title %s" % [
			_sq(_template.get_item_text(_template.selected)), _sq(pack), _sq(title)]
	if and_build:
		args += " --build"
	_spawn(args, "create " + pack)

# ---- status ------------------------------------------------------------------------------

func _refresh_ui() -> void:
	var running := _pid > 0
	for name in _buttons:
		(_buttons[name] as Button).disabled = running and name != "REFRESH"
	if _play_btn != null:
		_play_btn.text = "PAUSE" if _playing else "PLAY"
		_play_btn.disabled = _sheet_tex == null
	var packs: Array = _audit.get("packs", [])
	if packs.is_empty():
		_status.text = "%d pack(s) — select one and CHECK.%s" % [
				_packs.size(), "\n" + _proc_note if _proc_note != "" else ""]
		_detail.text = ""
		return
	var p: Dictionary = _audit_row()
	if p.is_empty():
		p = packs[0]
	var approval = p.get("approval")
	var verdict := "READY — machine checks clean and a human approved it" \
			if bool(p.get("ready", false)) \
			else "NOT READY — %d failure(s), %d open item(s)" % [
					p.get("failures", 0), p.get("open_items", 0)]
	_status.text = "%s   %s\n%s%s" % [p.get("pack", "?"), verdict,
			p.get("bundle", "(never built)"),
			"\n" + _proc_note if _proc_note != "" else ""]
	_status.add_theme_color_override("font_color",
			GREEN if bool(p.get("ready", false)) else
			RED if int(p.get("failures", 0)) > 0 else EMBER)
	var lines := PackedStringArray()
	if approval is Dictionary:
		lines.append("approval: %s by %s on %s — %s" % [
				approval.get("decision", "?"), approval.get("who", "?"),
				approval.get("when", "?"),
				approval.get("note", approval.get("reason", ""))])
	else:
		lines.append("approval: none — APPROVE records the human half, pinned to this "
				+ "bundle's content hash")
	var blockers: Array = p.get("blockers", [])
	if not blockers.is_empty():
		lines.append("%d blocker(s) the build refused to clear" % blockers.size())
	_detail.text = "\n".join(lines)

# ---- selftest ------------------------------------------------------------------------------

func _run_selftest() -> void:
	var packs_seen := _packs.size()
	if packs_seen == 0:
		push_error("GENFORGE CONSOLE SELFTEST FAILED — genforge.py list returned no packs")
		get_tree().quit(1)
		return
	_pack_list.select(0)
	_select_pack()
	_check()
	var audit_packs: Array = _audit.get("packs", [])
	if audit_packs.is_empty():
		push_error("GENFORGE CONSOLE SELFTEST FAILED — check produced no audit")
		get_tree().quit(1)
		return
	var p: Dictionary = audit_packs[0]
	# The live catalog must still fail on the dungeon boss; a console that renders
	# a clean audit for it is a console that is lying.
	if _findings.item_count == 0:
		push_error("GENFORGE CONSOLE SELFTEST FAILED — no findings rendered")
		get_tree().quit(1)
		return
	var fails := 0
	for i in _findings.item_count:
		if _findings.get_item_text(i).begins_with("[BAD]"):
			fails += 1
	# --- REVIEW: the whole point of an assets console ------------------------
	# Ricardo, 2026-09-14: "I can't see anything for reviewing". A viewer that
	# silently shows nothing is the bug being fixed, so this asserts PIXELS:
	# the sheet really decoded, a clip really produced a frame region, and the
	# blockers really reached the list next to the clips they are about.
	_review()
	var review_ok := true
	if _art_pick.item_count == 0:
		review_ok = false
		push_error("GENFORGE CONSOLE SELFTEST: REVIEW offered no art entries")
	if _sheet_tex == null or _sheet_tex.get_width() <= 0 or _sheet_tex.get_height() <= 0:
		review_ok = false
		push_error("GENFORGE CONSOLE SELFTEST: the sprite sheet did not load — "
				+ "REVIEW would show an empty box, which is the bug")
	if _clip_pick.item_count == 0:
		review_ok = false
		push_error("GENFORGE CONSOLE SELFTEST: atlas.json produced no clips")
	var blockers := 0
	for i in _clip_list.item_count:
		if _clip_list.get_item_text(i).begins_with("BLOCKER"):
			blockers += 1
	# the live catalog's bellwether is missing five of its six required clips;
	# a REVIEW tab that does not say so is a REVIEW tab that is lying
	if blockers == 0:
		review_ok = false
		push_error("GENFORGE CONSOLE SELFTEST: no blockers shown beside the clips, "
				+ "but the audit reports failures")
	var region := Rect2()
	if _frame.texture is AtlasTexture:
		region = (_frame.texture as AtlasTexture).region
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		review_ok = false
		push_error("GENFORGE CONSOLE SELFTEST: no frame region — nothing would be drawn")
	# and it has to MOVE: a still first frame is not a clip review
	var first := _frame_i
	_playing = true
	for _i in 40:
		_advance(0.25)
	if _frame_i == first and _clip_list.item_count > 0 \
			and (_current_clip().get("rects", []) as Array).size() > 1:
		review_ok = false
		push_error("GENFORGE CONSOLE SELFTEST: the clip never advanced a frame")
	if not review_ok:
		get_tree().quit(1)
		return
	# `%` binds tighter than `+`, so the format args must meet the WHOLE string.
	var line := "GENFORGE CONSOLE SELFTEST OK — %d pack(s), %s: %d finding(s) rendered" \
			+ " (%d failing), %d art row(s); REVIEW drew %s at %dx%d, %d clip(s), " \
			+ "%d blocker(s), frame %dx%d"
	print(line % [packs_seen, p.get("pack", "?"), _findings.item_count, fails,
			_art_list.item_count,
			_art_pick.get_item_text(_art_pick.selected) if _art_pick.selected >= 0 else "?",
			_sheet_tex.get_width(), _sheet_tex.get_height(), _clip_pick.item_count,
			blockers, int(region.size.x), int(region.size.y)])
	get_tree().quit(0)
