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
#   PACKS      every release and its bundles, with approval state
#   AUDIT      the findings, coloured: ok / warn / FAIL
#   ART        one row per art entry — provenance verified? clips complete?
#   REVIEW     opens the bundle's index.html (the offline sprite/stat review)
#   CREATE     draft a new release from an existing chapter, optionally build it
#   APPROVE    record the human half, pinned to the bundle's content hash
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

func _ready() -> void:
	_repo = ProjectSettings.globalize_path("res://..").simplify_path()
	_selftest = OS.get_cmdline_user_args().has("--selftest")
	_build_ui()
	_refresh()
	if _selftest:
		_run_selftest()

# ---- UI ------------------------------------------------------------------------------

func _label(text: String, color: Color, size := ProtoTheme.SIZE_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

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
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# ---- left: the packs and the actions
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 4)
	root.add_child(left)

	left.add_child(_label("GENFORGE", EMBER, ProtoTheme.SIZE_TITLE))
	left.add_child(_label("content packs — genforge/releases/ + the bundles they bake",
			DIM))
	_pack_list = _list(190)
	_pack_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pack_list.item_selected.connect(func(_i: int) -> void: _select_pack())
	left.add_child(_pack_list)

	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 3)
	_button(row, "CHECK", _check).tooltip_text = \
			"Audit this pack: schema, lore refs, art provenance (sha256 of the image " \
			+ "against the prompt that made it), clip coverage, bundle digests, approval."
	_button(row, "BUILD", _build).tooltip_text = \
			"Bake the reviewable bundle. Identical inputs re-verify the existing one " \
			+ "instead of rewriting it — the bundle is immutable and hash-named."
	_button(row, "REVIEW", _review).tooltip_text = \
			"Open the bundle's index.html: sprite sheets, clips, stats and blockers, offline."
	_button(row, "APPROVE", func() -> void: _decide("approve"))
	_button(row, "REJECT", func() -> void: _decide("reject"))
	_button(row, "REFRESH", _refresh)
	left.add_child(row)

	left.add_child(_label("note / reason — recorded with the decision", DIM))
	_note_edit = LineEdit.new()
	_note_edit.placeholder_text = "art reviewed, frame time captured"
	_note_edit.text_changed.connect(func(t: String) -> void: _note = t)
	left.add_child(_note_edit)

	left.add_child(_label("CREATE — draft a new chapter from an existing one", EMBER))
	left.add_child(_label("a template remap is NOT new content: replace the inherited "
			+ "stories, kits, art sources and season.", DIM))
	var form := GridContainer.new()
	form.columns = 2
	form.add_theme_constant_override("h_separation", 4)
	form.add_child(_label("from", DIM))
	_template = OptionButton.new()
	form.add_child(_template)
	form.add_child(_label("pack", DIM))
	_new_pack = LineEdit.new()
	_new_pack.placeholder_text = "ash_wake"
	form.add_child(_new_pack)
	form.add_child(_label("title", DIM))
	_new_title = LineEdit.new()
	_new_title.placeholder_text = "The Ash Wake"
	form.add_child(_new_title)
	left.add_child(form)
	var crow := HBoxContainer.new()
	_button(crow, "CREATE", func() -> void: _create(false))
	_button(crow, "CREATE + BUILD", func() -> void: _create(true))
	left.add_child(crow)

	# ---- right: what the audit says
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	root.add_child(right)

	_status = _label("", PALE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)

	right.add_child(_label("ART — one row per asset: is the image verifiable, are the "
			+ "clips complete?", EMBER))
	_art_list = _list(120)
	right.add_child(_art_list)

	right.add_child(_label("AUDIT — every finding, in order", EMBER))
	_findings = _list(200)
	_findings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_findings)

	_detail = _label("", PALE)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 56)
	right.add_child(_detail)

	if not _selftest:
		var back := HBoxContainer.new()
		_button(back, "BACK", func() -> void:
			get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn"))
		right.add_child(back)

# ---- running the tool ------------------------------------------------------------------

static func _sq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

# Blocking, for the sub-second commands. Returns [exit_code, stdout].
func _tool(args: String) -> Array:
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
	var p: Dictionary = packs[0]
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
	_refresh_ui()

func _build() -> void:
	var pack := _selected_pack()
	if pack == "":
		_proc_note = "pick a pack"
		_refresh_ui()
		return
	_spawn("build " + _sq(pack), "build " + pack)

func _review() -> void:
	var packs: Array = _audit.get("packs", [])
	var page := str((packs[0] as Dictionary).get("review_page", "")) if not packs.is_empty() else ""
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
	var packs: Array = _audit.get("packs", [])
	if packs.is_empty():
		_status.text = "%d pack(s) — select one and CHECK.%s" % [
				_packs.size(), "\n" + _proc_note if _proc_note != "" else ""]
		_detail.text = ""
		return
	var p: Dictionary = packs[0]
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
	# `%` binds tighter than `+`, so the format args must meet the WHOLE string.
	var line := "GENFORGE CONSOLE SELFTEST OK — %d pack(s), %s: %d finding(s) rendered" \
			+ " (%d failing), %d art row(s), review page %s"
	print(line % [packs_seen, p.get("pack", "?"), _findings.item_count, fails,
			_art_list.item_count,
			"present" if str(p.get("review_page", "")) != "" else "none"])
	get_tree().quit(0)
