# ARENA — the training console (docs/design/25): a code-built front end for the
# ES trainer (ml/training/league.py). Pick the trainee build + opponents, spawn
# `league train` / `league gate` as detached child processes, tail the trainer's
# progress JSONL (design/25 §2 — THE contract) every 0.5 s and chart fitness per
# generation. ES has no loss: FITNESS (candidate match score vs its opponents —
# win rate + hp-margin shaping, higher wins) IS the metric, plus gate win rates.
#
#   godot --path game res://arena/console.tscn
#   godot --headless --path game res://arena/console.tscn -- --selftest   # CONSOLE SELFTEST OK
#
# The UI never blocks: processes run detached (OS.create_process) and outlive the
# console — Stop kills the tracked pid. The trainee KEY defaults to the build id's
# last dotted segment (the tools/train_all.sh convention; league.py takes --key
# verbatim, so the field stays editable). "Watch" spawns a WINDOWED arena for one
# episode with the trainee's latest registered net — candidate (latest undeployed)
# first, the deployed pin as fallback — v1 opens a window rather than embedding a
# SubViewport (design/25 §4). Everything is code-built on the 640x360 grid.
#
# THE COCKPIT TABS (2026-09-13, Ricardo: "Is the train_run included in arena
# console? can we run it there instead? as well as manage active and deployed
# nets, and even put one against the other for benchmarking (best of N)"):
#   PROGRESS — this run's fitness chart + match-score strip + gate verdict
#   RUNS     — every isolated run folder (tools/train_run.sh writes
#              ml/runs/<date>__<keys>__<config>/), its config and gate verdicts;
#              OPEN tails that run's own progress feed, PROMOTE copies its
#              gate-PASSING nets into the deployed registry
#   NETS     — the registry: every key's versions, which one is the DEPLOYED
#              pin, DEPLOY/RETIRE, and "set A"/"set B" for the benchmark
#   VERSUS   — best-of-N head to head between any two nets (or the native /
#              scripted baselines); the verdict is written to
#              ml/data/benchmarks/ so comparisons accumulate
# TRAIN runs through tools/train_run.sh by default (the ISOLATED switch): the
# run gets its own registry seeded from the deployed one, so experiments never
# overwrite what the game serves. Untick it to train straight into ml/serving.
#
# SPEED (2026-09-11, Ricardo: "it should be able to become faster with more
# compute"): the loop is CPU-bound — no GPU anywhere (numpy MLP + Godot physics
# and GDScript workers) — and the old fast mode was WALL-LOCKED at 4x, so --jobs
# plateaued at pop x opponents matches per generation of ~45 s each. The roster
# exposes --jobs (default = this machine's cores) and --speed (default max: one
# core-bound tick per frame via league.py's --fixed-fps 60); the hint line under
# the grid states the parallelism ceiling and the pop that fills the cores. The
# MATCH SCORE strip plots every match's win rate by opponent, so a zero-signal
# run (0 wins vs native, every match) is visible from the first generation.
extends Control

const POLL_S := 0.5
const PROGRESS_DIR := "ml/data/progress"
const LOG_DIR := "ml/data/logs"
const REGISTRY := "ml/serving/registry.json"
const RUNS_DIR := "ml/runs"                     # tools/train_run.sh writes here
const BENCH_DIR := "ml/data/benchmarks"         # versus verdicts accumulate here
const TRAIN_RUN := "tools/train_run.sh"
const BASELINES := ["native", "scripted"]       # selectable as a versus side
const DEFAULTS := {"generations": 3, "pop": 6, "episodes": 4}   # league.py's; jobs = cores
# TOURNAMENT (ml/training/tournament.py). ES reuses the knobs above; PPO has no
# spinbox here, so it gets a console-sized budget rather than its 2,000,000-step
# default — a tournament launched from a button should finish in an evening.
const TOURNEY_BEST_OF := 5
const TOURNEY_PPO_STEPS := 500000
const AI_DEFAULTS := "game/arena/data/ai_defaults.json"
# --speed choices: [arena spec, label]. "max" = CPU-bound (league.py adds --fixed-fps
# 60); numbers are wall-locked multipliers (4 = the original fast mode).
const SPEEDS := [["max", "max (CPU-bound)"], ["16", "16x wall"], ["8", "8x wall"],
		["4", "4x wall (old fast)"], ["2", "2x wall"], ["1", "1x real-time"]]
const STRIP_MAX := 4000   # per-match score points kept for the strip

const EMBER := Color("ff9a3c")
const PALE := Color("d9d4c7")
const DIM := Color(0.5, 0.49, 0.45)
const CYAN := Color("7fd8ff")
const GREEN := Color("7ce7a2")
const RED := Color("ff5a5a")

var _repo := ""
var _selftest := false

# roster
var _trainee: ItemList
var _key_edit: LineEdit
var _opps: ItemList
var _gens: SpinBox
var _pop: SpinBox
var _eps: SpinBox
var _jobs: SpinBox
var _speed: OptionButton
var _net: OptionButton
var _hint: Label
var _train_btn: Button
var _train_all_btn: Button
var _tourney_btn: Button
var _ai_mode: OptionButton
var _ai_info: Label
var _ai_stamp := ""          # trainee + config/registry mtimes; see _refresh_ai_default
var _previous_canvas := Vector2i.ZERO
var _sweep_progress := ""
var _stop_btn: Button
var _gate_btn: Button
var _watch_btn: Button
var _cmd_label: Label
# progress
var _status: Label
var _note: Label
var _gate_label: Label
var _chart: Control
var _strip: Control
var _chart_draws := 0

# cockpit tabs
var _isolated: CheckBox
var _gpu: CheckBox
var _runs: ItemList
var _runs_info: Label
var _runs_open_btn: Button
var _runs_promote_btn: Button
var _nets: ItemList
var _nets_info: Label
var _vs_a := {}                  # {label, spec, build} — spec: native|scripted|abs path
var _vs_b := {}
var _vs_a_label: Label
var _vs_b_label: Label
var _vs_eps: SpinBox
var _vs_best_of: SpinBox
var _vs_btn: Button
var _vs_result: Label
var _vs_history: ItemList
var _vs_pending := {}            # {out, a, b, eps, t0}
var _last_verdict := {}
# overridable so the selftest never touches the real registry / runs / benchmarks
var _registry_path := ""
var _runs_root := ""
var _bench_root := ""

# the tracked child (train | gate); watch windows are fire-and-forget
var _pid := -1
var _pid_kind := ""
var _proc_note := ""

# progress tail: re-opened each poll, byte offset past the last COMPLETE line
var _tail_path := ""
var _tail_offset := 0
var _poll_accum := 0.0
var _run := {}

func _ready() -> void:
	_selftest = OS.get_cmdline_user_args().has("--selftest")
	_repo = DhRepoRoot.find()  # not res://.. — an exported app would answer builds/
	theme = ProtoTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not _selftest and DisplayServer.get_name() != "headless":
		_fit_window()
	_registry_path = _repo.path_join(REGISTRY)
	_runs_root = _repo.path_join(RUNS_DIR)
	_bench_root = _repo.path_join(BENCH_DIR)
	_reset_run()
	_build_ui()
	_populate_roster()
	_refresh_runs()
	_refresh_nets()
	_refresh_history()
	if _trainee.item_count > 0:
		_trainee.select(0)
		_on_trainee_selected(0)
	_refresh_ui()
	if _selftest:
		_run_selftest()

func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_S:
		return
	_poll_accum = 0.0
	if _pid > 0 and not OS.is_process_running(_pid):
		_proc_note = "%s finished — log %s" % [_pid_kind, _log_rel(_key())]
		_pid = -1
		_pid_kind = ""
	_poll_progress()
	_poll_versus()
	_refresh_ui()

# ---- UI ---------------------------------------------------------------------------------

# The console is a desktop TOOL, not the 640x360 game: take the biggest 16:9
# logical canvas that fits the screen it opens on (the full-rect containers
# reflow). At 640x360 the roster column's minimum heights overflowed and the
# TRAIN/STOP/GATE/WATCH buttons rendered outside the window.
func _fit_window() -> void:
	var w := get_window()
	var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
	for cand in [Vector2i(1600, 900), Vector2i(1440, 810), Vector2i(1280, 720),
			Vector2i(1152, 648), Vector2i(1024, 576), Vector2i(960, 540)]:
		if cand.x <= usable.size.x - 24 and cand.y <= usable.size.y - 96:
			# the roster column needs ~400 logical px of height; when a 2x integer
			# step still clears that (1600x900 -> 800x450), take it — the pixel
			# typography reads at menu size instead of 1:1 dots on a 1080p screen
			var k := 2 if cand.y / 2 >= 420 else 1
			w.content_scale_size = cand / k
			w.size = cand
			w.position = usable.position + (usable.size - cand) / 2
			return

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c1116")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# BACK — the console also opens from the title menu in-process (standalone
	# console.tscn boots keep working; hidden in the selftest)
	if not _selftest:
		var back := Button.new()
		back.text = "< BACK"
		back.focus_mode = Control.FOCUS_NONE
		back.add_theme_font_size_override("font_size", 8)
		back.position = Vector2(6, 4)
		back.z_index = 10
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn"))
		add_child(back)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8.0
	hb.offset_top = 6.0
	hb.offset_right = -8.0
	hb.offset_bottom = -6.0
	hb.add_theme_constant_override("separation", 10)
	add_child(hb)

	# ---- left: the roster panel (fixed width; the chart takes the rest)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(236, 0)
	left.add_theme_constant_override("separation", 3)
	hb.add_child(left)

	var title := _label("TRAINING CONSOLE", EMBER, ProtoTheme.SIZE_TITLE)
	var big := ProtoTheme.font_big()
	if big != null:
		title.add_theme_font_override("font", big)
	left.add_child(title)

	left.add_child(_label("trainee — the build the net plays as", DIM))
	_trainee = _list(88, false)
	_trainee.item_selected.connect(_on_trainee_selected)
	left.add_child(_trainee)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 4)
	key_row.add_child(_label("key", DIM))
	_key_edit = LineEdit.new()
	_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_edit.placeholder_text = "registry key (--key)"
	_key_edit.text_submitted.connect(func(t: String) -> void:
		_attach(_progress_path(t.strip_edges()), 0))
	key_row.add_child(_key_edit)
	left.add_child(key_row)

	left.add_child(_label("opponents — multi-select · none = native + scripted", DIM))
	_opps = _list(72, true)
	_opps.multi_selected.connect(func(_i: int, _on: bool) -> void: _refresh_ui())
	left.add_child(_opps)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	_gens = _spin(grid, "gens", 1, 999, int(DEFAULTS.generations))
	_pop = _spin(grid, "pop", 2, 256, int(DEFAULTS.pop))
	_eps = _spin(grid, "eps", 1, 64, int(DEFAULTS.episodes))
	# jobs default: leave 4 threads for the desktop, cap at 16 — measured
	# 2026-09-13, jobs 16 and 20 both 6.4 s/gen, so the cap is free.
	# PREVIOUS: clampi(OS.get_processor_count() / 2, 1, 4)  # 4 jobs, 1.5x slower
	_jobs = _spin(grid, "jobs", 1, 64, clampi(OS.get_processor_count() - 4, 1, 16))
	left.add_child(grid)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 4)
	speed_row.add_child(_label("speed", DIM))
	_speed = OptionButton.new()
	_speed.focus_mode = Control.FOCUS_NONE
	_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in SPEEDS.size():
		_speed.add_item(str(SPEEDS[i][1]), i)
		_speed.set_item_metadata(i, str(SPEEDS[i][0]))
	_speed.select(0)
	_speed.item_selected.connect(func(_i: int) -> void: _refresh_ui())
	speed_row.add_child(_speed)
	left.add_child(speed_row)

	# NET — the architecture every trainer shares (Ricardo, 2026-09-13: "net
	# hyperparams should be configurable, as to test new architectures"). The
	# list is read from ml/training/architectures.json, so adding a preset there
	# is all it takes to try it from here.
	var net_row := HBoxContainer.new()
	net_row.add_theme_constant_override("separation", 4)
	net_row.add_child(_label("net", DIM))
	_net = OptionButton.new()
	_net.focus_mode = Control.FOCUS_NONE
	_net.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in _architectures():
		var i := _net.get_item_count()
		_net.add_item("%s  %s %s" % [row.name, str(row.hidden), row.activation], i)
		_net.set_item_metadata(i, row.name)
		_net.set_item_tooltip(i, "%s MACs/tick — %s" % [row.macs, row.note])
		if row.name == "default":
			_net.select(i)
	_net.item_selected.connect(func(_i: int) -> void: _refresh_ui())
	net_row.add_child(_net)
	left.add_child(net_row)

	_hint = _label("", DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(0, 34)
	left.add_child(_hint)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	# TRAIN routes through tools/train_run.sh: the run gets its own registry,
	# seeded from the deployed one, so an experiment never overwrites what the
	# game serves. Untick to train straight into ml/serving (the old path).
	_isolated = CheckBox.new()
	_isolated.text = "isolated run"
	_isolated.button_pressed = true
	_isolated.focus_mode = Control.FOCUS_NONE
	_isolated.tooltip_text = "tools/train_run.sh — own registry + weights + progress under ml/runs/"
	_isolated.toggled.connect(func(_on: bool) -> void: _refresh_ui())
	mode_row.add_child(_isolated)
	# the GPU tier: PPO over libdh-env, no Godot in the loop (needs ml/.venv)
	_gpu = CheckBox.new()
	_gpu.text = "GPU (PPO)"
	_gpu.focus_mode = Control.FOCUS_NONE
	_gpu.tooltip_text = "ml/training/ppo.py on CUDA instead of the ES league"
	_gpu.toggled.connect(func(_on: bool) -> void: _refresh_ui())
	mode_row.add_child(_gpu)
	left.add_child(mode_row)

	var btns := GridContainer.new()
	btns.columns = 3
	btns.add_theme_constant_override("h_separation", 4)
	btns.add_theme_constant_override("v_separation", 3)
	_train_btn = _button(btns, "TRAIN", _train)
	_train_all_btn = _button(btns, "TRAIN ALL", _train_all)
	_train_all_btn.tooltip_text = "Train every creature in an isolated run. Each species is trained and gated in sequence."
	_tourney_btn = _button(btns, "TOURNAMENT", _tournament)
	_tourney_btn.tooltip_text = ("Every training method trains this creature, then the candidates FIGHT "
			+ "(best-of-%d) and the winner takes the deployed pin. ES uses the knobs above; PPO runs %s steps "
			+ "and is skipped if ml/.venv is missing. No trainee selected = every creature.") % [
			TOURNEY_BEST_OF, TOURNEY_PPO_STEPS]
	_stop_btn = _button(btns, "STOP", _stop)
	_gate_btn = _button(btns, "GATE", _gate)
	_watch_btn = _button(btns, "WATCH", _watch)
	left_frame.add_child(btns)
	left_frame.move_child(btns, 1)   # launch/stop actions stay above the scrolling roster

	_cmd_label = _label("", DIM)
	_cmd_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cmd_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_cmd_label)

	# ---- right: the cockpit tabs (PROGRESS / RUNS / NETS / VERSUS)
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_color_override("font_selected_color", EMBER)
	tabs.add_theme_color_override("font_unselected_color", DIM)
	hb.add_child(tabs)

	var right := VBoxContainer.new()
	right.name = "PROGRESS"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	tabs.add_child(right)

	_status = _label("", PALE)
	_status.custom_minimum_size = Vector2(0, 46)
	right.add_child(_status)
	_note = _label("", DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 22)
	right.add_child(_note)

	right.add_child(_label("FITNESS by GENERATION", EMBER))
	_chart = Control.new()
	_chart.custom_minimum_size = Vector2(0, 120)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chart.draw.connect(_on_chart_draw)
	right.add_child(_chart)

	right.add_child(_label("MATCH SCORE — win rate per match, by opponent", EMBER))
	_strip = Control.new()
	_strip.custom_minimum_size = Vector2(0, 58)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_on_strip_draw)
	right.add_child(_strip)

	_gate_label = _label("", PALE)
	_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_label.custom_minimum_size = Vector2(0, 30)
	right.add_child(_gate_label)

	_build_runs_tab(tabs)
	_build_nets_tab(tabs)
	_build_versus_tab(tabs)

# ---- RUNS: every isolated run tools/train_run.sh has written ------------------------------

func _build_runs_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "RUNS"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("ISOLATED RUNS — ml/runs/, newest first", EMBER))
	v.add_child(_label("each folder is a whole experiment: its own registry, weights, "
			+ "progress and logs. Promoting copies its gate-PASSING nets into ml/serving.", DIM))
	_runs = _list(0, false)
	_runs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_runs.item_selected.connect(func(_i: int) -> void: _refresh_ui())
	v.add_child(_runs)
	_runs_info = _label("", PALE)
	_runs_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_runs_info.custom_minimum_size = Vector2(0, 76)
	v.add_child(_runs_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_runs_open_btn = _button(row, "OPEN PROGRESS", _runs_open)
	_runs_promote_btn = _button(row, "PROMOTE", _runs_promote)
	_button(row, "REFRESH", _refresh_runs)
	v.add_child(row)

# ---- NETS: the registry, and which version the fleet actually serves ----------------------

func _build_nets_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "NETS"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("REGISTRY — ml/serving/registry.json", EMBER))
	v.add_child(_label("one DEPLOYED pin per key is what the game and the arena load; "
			+ "everything else is a candidate. DEPLOY moves the pin, RETIRE clears it.", DIM))
	_nets = _list(0, false)
	_nets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nets.item_selected.connect(func(_i: int) -> void: _refresh_ui())
	v.add_child(_nets)
	_nets_info = _label("", PALE)
	_nets_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nets_info.custom_minimum_size = Vector2(0, 58)
	v.add_child(_nets_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_button(row, "DEPLOY", _net_deploy)
	_button(row, "RETIRE", _net_retire)
	_button(row, "SET A", func() -> void: _set_side("a"))
	_button(row, "SET B", func() -> void: _set_side("b"))
	_button(row, "REFRESH", _refresh_nets)
	v.add_child(row)
	_build_ai_default_row(v)

# ---- DEFAULT AI: which mind the GAME gives a build when nothing names one ------------
# The deployed pin says WHICH net is best for a key; this says whether the game
# should use a net at all. Written to game/arena/data/ai_defaults.json, read by
# game/arena/ai_defaults.gd, which fighter.gd consults for `--policy-a default`.

func _build_ai_default_row(v: VBoxContainer) -> void:
	v.add_child(_label("DEFAULT AI — what drives a creature when a match asks for "
			+ "'default' (game/arena/data/ai_defaults.json)", EMBER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_ai_mode = OptionButton.new()
	for m in ArenaAIDefaults.MODES:
		_ai_mode.add_item(m)
	_ai_mode.tooltip_text = ("deployed = the pinned trained net for that creature (falls back "
			+ "to `fallback` when none is pinned) · scripted = the utility heuristics · "
			+ "native = the creature's own built-in AI")
	row.add_child(_ai_mode)
	_button(row, "SET FOR ALL", func() -> void: _set_ai_default(false))
	_button(row, "SET FOR BUILD", func() -> void: _set_ai_default(true))
	_button(row, "CLEAR BUILD", _clear_ai_default)
	v.add_child(row)
	_ai_info = _label("", PALE)
	_ai_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_ai_info)
	_refresh_ai_default()

func _ai_config_path() -> String:
	return _repo.path_join(AI_DEFAULTS)

# _refresh_ui runs every frame, and resolving a default means parsing the whole
# registry off disk — so this recomputes only when the answer could have changed:
# a different trainee, or a rewritten config/registry.
func _refresh_ai_default(force: bool = false) -> void:
	if _ai_info == null:
		return
	var stamp := "%s|%d|%d" % [_selected_build(),
			FileAccess.get_modified_time(_ai_config_path()),
			FileAccess.get_modified_time(_registry_path)]
	if not force and stamp == _ai_stamp:
		return
	_ai_stamp = stamp
	var cfg := ArenaAIDefaults.load_config()
	var build := _selected_build()
	var per: Dictionary = cfg.get("per_build", {})
	var line := "global: %s · fallback: %s · %d per-build override(s)" % [
			str(cfg.get("mode", "deployed")), str(cfg.get("fallback", "native")), per.size()]
	if build != "":
		line += "\n%s -> %s (%s)" % [build, ArenaAIDefaults.mode_for(build, cfg),
				ArenaAIDefaults.policy_spec_for(build, cfg).get_file()]
	_ai_info.text = line

func _write_ai_config(cfg: Dictionary) -> void:
	var f := FileAccess.open(_ai_config_path(), FileAccess.WRITE)
	if f == null:
		_proc_note = "cannot write " + AI_DEFAULTS
	else:
		f.store_string(JSON.stringify(cfg, " "))
		f.close()
		_proc_note = "default AI updated — " + AI_DEFAULTS
	_refresh_ai_default(true)
	_refresh_ui()

func _set_ai_default(per_build: bool) -> void:
	var cfg := ArenaAIDefaults.load_config()
	var mode := str(_ai_mode.get_item_text(_ai_mode.selected)) if _ai_mode.selected >= 0 \
			else ArenaAIDefaults.DEFAULT_MODE
	if per_build:
		var build := _selected_build()
		if build == "":
			_proc_note = "pick a trainee first — SET FOR BUILD needs one"
			_refresh_ui()
			return
		var per: Dictionary = cfg.get("per_build", {})
		per[build] = mode
		cfg["per_build"] = per
	else:
		cfg["mode"] = mode
	cfg["schema"] = ArenaAIDefaults.SCHEMA
	_write_ai_config(cfg)

func _clear_ai_default() -> void:
	var build := _selected_build()
	var cfg := ArenaAIDefaults.load_config()
	var per: Dictionary = cfg.get("per_build", {})
	if build == "" or not per.has(build):
		_proc_note = "no per-build override for that trainee"
		_refresh_ui()
		return
	per.erase(build)
	cfg["per_build"] = per
	_write_ai_config(cfg)

# ---- VERSUS: best-of-N head to head -------------------------------------------------------

func _build_versus_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "VERSUS"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("BEST-OF-N — put one net against another", EMBER))
	v.add_child(_label("pick both sides in NETS (SET A / SET B), or use the baselines below. "
			+ "Every round is a real arena match set, so a verdict here means what a gate "
			+ "verdict means. Results land in ml/data/benchmarks/.", DIM))
	_vs_a_label = _label("A — (unset)", PALE)
	_vs_b_label = _label("B — (unset)", PALE)
	v.add_child(_vs_a_label)
	v.add_child(_vs_b_label)

	var base := HBoxContainer.new()
	base.add_theme_constant_override("separation", 4)
	base.add_child(_label("baselines", DIM))
	for side in ["a", "b"]:
		for who in BASELINES:
			var s2 := str(side)
			var w := str(who)
			_button(base, "%s=%s" % [s2.to_upper(), w], func() -> void: _set_baseline(s2, w))
	v.add_child(base)

	var knobs := HBoxContainer.new()
	knobs.add_theme_constant_override("separation", 4)
	knobs.add_child(_label("best of", DIM))
	_vs_best_of = SpinBox.new()
	_vs_best_of.min_value = 1
	_vs_best_of.max_value = 99
	_vs_best_of.value = 9
	_vs_best_of.rounded = true
	knobs.add_child(_vs_best_of)
	knobs.add_child(_label("episodes/round", DIM))
	_vs_eps = SpinBox.new()
	_vs_eps.min_value = 1
	_vs_eps.max_value = 32
	_vs_eps.value = 3
	_vs_eps.rounded = true
	knobs.add_child(_vs_eps)
	_vs_btn = _button(knobs, "RUN BEST-OF-N", _versus_run)
	_button(knobs, "SWAP", func() -> void:
		var t := _vs_a
		_vs_a = _vs_b
		_vs_b = t
		_refresh_ui())
	v.add_child(knobs)

	_vs_result = _label("", PALE)
	_vs_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vs_result.custom_minimum_size = Vector2(0, 66)
	v.add_child(_vs_result)
	v.add_child(_label("HISTORY — every verdict, newest first", EMBER))
	_vs_history = _list(0, false)
	_vs_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_vs_history)

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
	return b

# ml/training/architectures.json, or just the shipping shape if it is unreadable
# (a console with no repo still has to draw).
func _architectures() -> Array:
	var fallback := [{"name": "default", "hidden": [64, 64], "activation": "tanh",
			"macs": "7,744", "note": "what ships today"}]
	if _repo == "":
		return fallback
	var raw := FileAccess.get_file_as_string(
			_repo.path_join("ml/training/architectures.json"))
	if raw.is_empty():
		return fallback
	var doc: Variant = JSON.parse_string(raw)
	if not (doc is Dictionary):
		return fallback
	var out: Array = []
	for name in (doc as Dictionary).keys():
		var spec: Dictionary = doc[name]
		var hidden: Array = spec.get("hidden", [64, 64])
		var sizes: Array = [47] + hidden + [10]
		var macs := 0
		for i in sizes.size() - 1:
			macs += int(sizes[i]) * int(sizes[i + 1])
		out.append({"name": str(name), "hidden": hidden,
				"activation": str(spec.get("activation", "tanh")),
				"macs": String.num_uint64(macs), "note": str(spec.get("note", ""))})
	return fallback if out.is_empty() else out

# "" for the deployed shape — train_run.sh then passes no --net at all, so a
# default run's command line is exactly what it was before this existed.
func _net_spec() -> String:
	if _net == null or _net.selected < 0:
		return ""
	var name := str(_net.get_item_metadata(_net.selected))
	return "" if name == "default" else name

func _spin(parent: Container, text: String, lo: int, hi: int, val: int) -> SpinBox:
	parent.add_child(_label(text, DIM))
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.value = val
	s.rounded = true
	s.custom_minimum_size = Vector2(48, 0)
	s.value_changed.connect(func(_v: float) -> void: _refresh_ui())
	parent.add_child(s)
	return s

func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(3.0)
	return sb

# ItemList has no ProtoTheme styles — restamp it so it reads as a sibling of the
# menu panels (dark well, ember selection) instead of the engine default grey.
func _list(height: float, multi: bool) -> ItemList:
	var l := ItemList.new()
	l.custom_minimum_size = Vector2(0, height)
	l.select_mode = ItemList.SELECT_MULTI if multi else ItemList.SELECT_SINGLE
	l.focus_mode = Control.FOCUS_NONE
	l.add_theme_stylebox_override("panel", _box(Color(0.05, 0.07, 0.095), ProtoTheme.PANEL_BORDER))
	l.add_theme_stylebox_override("selected", ProtoTheme.chip_box(EMBER, 0.28))
	l.add_theme_stylebox_override("selected_focus", ProtoTheme.chip_box(EMBER, 0.28))
	l.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	l.add_theme_color_override("font_color", PALE)
	l.add_theme_color_override("font_selected_color", Color(1.0, 0.98, 0.92))
	return l

# ---- roster -------------------------------------------------------------------------------

func _populate_roster() -> void:
	var builds: Dictionary = ProtoBuild.catalog().get("builds", {})
	var ids: Array = builds.keys()
	# creatures first — they ARE the species nets; bosses, then player builds
	var order := {"creature": 0, "boss": 1, "duo": 2, "player": 3}
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ka := int(order.get(str((builds[a] as Dictionary).get("kind", "creature")), 9))
		var kb := int(order.get(str((builds[b] as Dictionary).get("kind", "creature")), 9))
		return ka < kb if ka != kb else str(a) < str(b))
	for id in ids:
		var def: Dictionary = builds[id]
		var row := "%s · %s" % [str(def.get("name", id)), str(def.get("kind", "creature"))]
		_trainee.add_item(row)
		_trainee.set_item_metadata(_trainee.item_count - 1, str(id))
		_opps.add_item(row)
		_opps.set_item_metadata(_opps.item_count - 1, str(id))

# The registry key for a build id: its last dotted segment
# (core.arena.fen_boar_alpha -> fen_boar_alpha), as tools/train_all.sh derives it.
static func key_for(build_id: String) -> String:
	return build_id.get_slice(".", build_id.get_slice_count(".") - 1)

func _on_trainee_selected(idx: int) -> void:
	var id := str(_trainee.get_item_metadata(idx))
	_key_edit.text = key_for(id)
	# the key's progress file holds its past runs: show the latest one right away
	_attach(_progress_path(_key_edit.text), 0)

func _selected_build() -> String:
	var sel := _trainee.get_selected_items()
	return str(_trainee.get_item_metadata(sel[0])) if sel.size() > 0 else ""

func _selected_opponents() -> Array[String]:
	var out: Array[String] = []
	for i in _opps.get_selected_items():
		out.append(str(_opps.get_item_metadata(i)))
	return out

# league.py --opponents syntax: "<policy>@<build>,..."; each build fights with
# its own default mind (players have no native one — scripted drives them).
func _opponent_spec() -> String:
	var parts: PackedStringArray = []
	for id in _selected_opponents():
		var def := ProtoBuild.build_def(id)
		var fallback := "scripted" if str(def.get("kind", "")) == "player" else "native"
		parts.append("%s@%s" % [str(def.get("policy", fallback)), id])
	return ",".join(parts)

func _key() -> String:
	return _key_edit.text.strip_edges() if _key_edit != null else ""

func _speed_spec() -> String:
	return str(_speed.get_item_metadata(_speed.selected)) if _speed != null else "max"

# Why --jobs alone never sped Ricardo's runs up: a generation is pop x opponents
# independent matches, so that is the most workers that can ever be busy.
# Returns [text, warn].
func _parallelism_hint() -> Array:
	var n_opp := _selected_opponents().size()
	if n_opp == 0:
		n_opp = 2   # league.py DEFAULT_OPPONENTS: native + scripted
	var pop := int(_pop.value)
	var par := pop * n_opp
	var jobs := int(_jobs.value)
	var cores := OS.get_processor_count()
	var text := "%d matches/gen (pop %d × %d opp) · jobs %d · %d cores" % [
			par, pop, n_opp, jobs, cores]
	var warn := false
	if jobs > par:
		warn = true
		text += " — %d workers idle: pop %d fills them" % [jobs - par, ceili(float(jobs) / n_opp)]
	elif jobs > cores:
		warn = true
		text += " — more jobs than cores: oversubscribed"
	elif jobs < mini(par, cores):
		text += " — %d cores idle: jobs %d" % [mini(par, cores) - jobs, mini(par, cores)]
	return [text, warn]

func _valid_key(key: String) -> bool:
	return key != "" and RegEx.create_from_string("^[A-Za-z0-9_\\-]+$").search(key) != null

# ---- processes ----------------------------------------------------------------------------

func _progress_path(key: String) -> String:
	return _repo.path_join(PROGRESS_DIR).path_join(key + ".jsonl")

func _log_rel(key: String) -> String:
	return LOG_DIR.path_join(key + ".console.log")

# POSIX single-quoting for bash -c (the repo path carries a space).
static func _sq(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"

func _spawn_league(args: String, kind: String, key: String) -> void:
	if _repo == "":
		_proc_note = DhRepoRoot.missing_note()
		return
	DirAccess.make_dir_recursive_absolute(_repo.path_join(LOG_DIR))
	DirAccess.make_dir_recursive_absolute(_repo.path_join(PROGRESS_DIR))
	# exec: the pid we track IS python's — through `&&` alone python would be a
	# grandchild of the bash we hold, out of Stop's reach
	var cmd := "cd %s && exec python3 -m ml.training.league %s >> %s 2>&1" % [
			_sq(_repo), args, _sq(_repo.path_join(_log_rel(key)))]
	_pid = OS.create_process("bash", ["-lc", cmd])
	if _pid <= 0:
		_pid = -1
		_proc_note = "could not spawn bash (OS.create_process failed)"
	else:
		_pid_kind = kind
		_proc_note = "%s started · pid %d · log %s" % [kind, _pid, _log_rel(key)]
	_cmd_label.text = "python3 -m ml.training.league " + args
	_refresh_ui()

func _train() -> void:
	var build := _selected_build()
	var key := _key()
	if build == "" or not _valid_key(key):
		_proc_note = "pick a trainee and a key ([A-Za-z0-9_-] only)"
		_refresh_ui()
		return
	if _isolated.button_pressed or _gpu.button_pressed:
		# tools/train_run.sh: own registry (seeded from the deployed one), own
		# weights, own progress — ml/serving is left exactly as the game found it
		_spawn_train_run(key, build)
		return
	var args := "train --key %s --build %s --generations %d --pop %d --episodes %d --jobs %d --speed %s" % [
			_sq(key), _sq(build), int(_gens.value), int(_pop.value), int(_eps.value),
			int(_jobs.value), _speed_spec()]
	var opps := _opponent_spec()
	if opps != "":
		args += " --opponents %s" % _sq(opps)
	# tail from the file's current end: the chart shows THIS run, not the history
	_attach(_progress_path(key), _file_len(_progress_path(key)))
	_spawn_league(args, "train", key)

func _train_all() -> void:
	if _pid > 0: return
	# Every creature, own registry; --all is the ES sweep, PPO requires a chosen matchup.
	_spawn_train_run("all-creatures", "", true)

# TRAIN ALL trains one way and assumes it was the right one. TOURNAMENT makes the
# methods compete: each trains the same creature, each is gated against the same
# pre-tournament pin, then they fight head to head and the winner takes the pin
# (ml/training/tournament.py). Ricardo, 2026-09-13: "compete intra-training when
# train-all, as to optimize for the best methods".
func _tournament() -> void:
	if _pid > 0: return
	var build := _selected_build()
	var key := _key()
	var args := "tournament --methods es,ppo --generations %d --pop %d --episodes %d --jobs %d --speed %s --best-of %d --steps %d" % [
			int(_gens.value), int(_pop.value), int(_eps.value), int(_jobs.value),
			_speed_spec(), TOURNEY_BEST_OF, TOURNEY_PPO_STEPS]
	var feed := "all-creatures"
	if build == "":
		args += " --all"                    # no trainee picked = the whole roster
	elif not _valid_key(key):
		_proc_note = "pick a key ([A-Za-z0-9_-] only)"
		_refresh_ui()
		return
	else:
		args += " --key %s --build %s" % [_sq(key), _sq(build)]
		feed = key
		_attach(_progress_path(key), _file_len(_progress_path(key)))
	_spawn_league(args, "tournament", feed)

func _gate() -> void:
	var build := _selected_build()
	var key := _key()
	if build == "" or not _valid_key(key):
		_proc_note = "pick a trainee and a key ([A-Za-z0-9_-] only)"
		_refresh_ui()
		return
	_run.gate = {}   # the chart stays; a fresh verdict replaces the old one
	_spawn_league("gate --key %s --build %s --episodes %d" % [
			_sq(key), _sq(build), int(_eps.value)], "gate", key)

func _stop() -> void:
	if _pid <= 0:
		return
	# freeze the trainer so it spawns nothing more, take its headless godot
	# workers with it (a lone SIGKILL would orphan one until its match times out),
	# then kill it
	OS.execute("bash", ["-lc", "kill -STOP %d; pkill -KILL -P %d; kill -KILL %d" % [
			_pid, _pid, _pid]])
	OS.kill(_pid)
	_proc_note = "%s stopped (pid %d)" % [_pid_kind, _pid]
	_pid = -1
	_pid_kind = ""
	_refresh_ui()

# The trainee's newest registered net: the CANDIDATE (latest undeployed version)
# first, the deployed pin as fallback. {} when the key has no net yet.
func _latest_net(key: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(_repo.path_join(REGISTRY))
	var reg: Variant = JSON.parse_string(raw) if raw != "" else null
	if not (reg is Dictionary):
		return {}
	var cand := {}
	var dep := {}
	for p in (reg as Dictionary).get("policies", []):
		if not (p is Dictionary) or str(p.get("key", "")) != key:
			continue
		var slot: Dictionary = dep if bool(p.get("deployed", false)) else cand
		if slot.is_empty() or int(p.get("version", 0)) > int(slot.get("version", 0)):
			slot.clear()
			slot.merge(p)
	var pick := cand if not cand.is_empty() else dep
	if pick.is_empty():
		return {}
	var spec := str(pick.get("game_json", ""))
	if spec != "" and spec.is_relative_path():
		spec = _repo.path_join(spec)
	return {"version": int(pick.get("version", 0)), "game_json": spec,
			"deployed": bool(pick.get("deployed", false))}

func _watch() -> void:
	var build := _selected_build()
	if build == "":
		return
	var key := _key()
	var net := _latest_net(key)
	var spec := str(net.get("game_json", ""))
	if spec == "":
		spec = "scripted"
		_proc_note = "no net registered for '%s' — watching the build on the scripted baseline" % key
	else:
		_proc_note = "watching %s v%d — [Q] closes the arena window" % [
				"deployed" if bool(net.deployed) else "candidate", int(net.version)]
	var opps := _selected_opponents()
	var opp: String = opps[0] if not opps.is_empty() else build
	# the running binary: same Godot as this console, no PATH dependency
	var exe := OS.get_executable_path()
	if exe == "":
		exe = "godot"
	var pid := OS.create_process(exe, ["--path", _repo.path_join("game"), "res://arena/arena.tscn",
			"--", "--a", build, "--b", opp, "--policy-a", spec, "--episodes", "1", "--spectate"])
	if pid <= 0:
		_proc_note = "could not spawn the arena window"
	_refresh_ui()

# ---- progress tail (design/25 §2) ---------------------------------------------------------

func _reset_run() -> void:
	_run = {"start": {}, "gens": [], "cands": [], "scores": [], "matches": 0, "dur_sum": 0.0,
			"dur_n": 0, "cur_g": -1, "cur_cand": -1, "last_match": {}, "registered": {},
			"gate": {}, "error": "", "last_t": 0.0, "unknown": 0,
			"versus": {}, "versus_done": {}}

func _attach(path: String, offset: int) -> void:
	_tail_path = path
	_tail_offset = offset
	_reset_run()
	_poll_progress()
	_refresh_ui()

func _file_len(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return n

# Re-opens the file each poll and ingests only COMPLETE new lines: a trailing
# partial write waits for its newline (byte offsets, so multibyte text can't
# split). Returns true when anything new was read.
func _poll_progress() -> bool:
	if _tail_path == "":
		return false
	var f := FileAccess.open(_tail_path, FileAccess.READ)
	if f == null:
		return false   # not created yet — the trainer writes it on its first event
	var length := f.get_length()
	if length < _tail_offset:   # truncated or replaced: start over
		_tail_offset = 0
		_reset_run()
	if length == _tail_offset:
		f.close()
		return false
	f.seek(_tail_offset)
	var bytes := f.get_buffer(length - _tail_offset)
	f.close()
	var nl := bytes.rfind(10)
	if nl < 0:
		return false
	var text := bytes.slice(0, nl + 1).get_string_from_utf8()
	_tail_offset += nl + 1
	for line in text.split("\n", false):
		_ingest(line)
	return true

func _ingest(line: String) -> void:
	var v: Variant = JSON.parse_string(line)
	if not (v is Dictionary):
		return   # garbage line — the contract says tolerate
	var e: Dictionary = v
	match str(e.get("ev", "")):
		"start":   # a new run in the same file: the panel follows the newest
			_reset_run()
			_run.start = e
		"match":
			_run.matches += 1
			if e.has("duration_s"):
				_run.dur_sum += float(e.duration_s)
				_run.dur_n += 1
			_run.cur_g = int(e.get("g", _run.cur_g))
			_run.cur_cand = int(e.get("cand", _run.cur_cand))
			_run.last_match = e
			var scores: Array = _run.scores
			scores.append({"opp": _opp_tag(e), "score": float(e.get("score", 0.0))})
			if scores.size() > STRIP_MAX:
				scores.pop_front()
		"candidate":
			_run.cands.append({"g": int(e.get("g", 0)), "cand": int(e.get("cand", 0)),
					"fitness": float(e.get("fitness", 0.0))})
		"generation":
			_run.gens.append({"g": int(e.get("g", _run.gens.size())),
					"best": float(e.get("best", 0.0)), "mean": float(e.get("mean", 0.0))})
			_run.cur_g = int(e.get("g", _run.cur_g))
		"registered":
			_run.registered = e
		"gate":
			_run.gate = e
		"versus_start":
			_reset_run()
			_run.start = e
			_run.versus = e
		"versus_round":   # each round rides the match strip like any other match
			_run.matches += 1
			if e.has("duration_s"):
				_run.dur_sum += float(e.duration_s)
				_run.dur_n += 1
			_run.last_match = e
			var vs_scores: Array = _run.scores
			vs_scores.append({"opp": "round %d" % (int(e.get("i", 0)) + 1),
					"score": float(e.get("score_a", 0.0))})
			if vs_scores.size() > STRIP_MAX:
				vs_scores.pop_front()
		"versus_done":
			_run.versus_done = e
		"error":
			_run.error = str(e.get("message", "error"))
		_:
			_run.unknown += 1
	_run.last_t = float(e.get("t", _run.last_t))

# "native@fen_boar_alpha": the opponent's policy + its build's last segment.
static func _opp_tag(e: Dictionary) -> String:
	var build := str(e.get("opp", "?"))
	var short := build.get_slice(".", build.get_slice_count(".") - 1)
	var pol := str(e.get("policy", ""))
	return ("%s@%s" % [pol, short]) if pol != "" else short

func _total_matches() -> int:
	var s: Dictionary = _run.start
	if not s.is_empty():
		var opps: Array = s.get("opponents", [])
		return int(s.get("generations", 0)) * int(s.get("pop", 0)) * maxi(opps.size(), 1)
	var n_opp := _selected_opponents().size()
	if n_opp == 0:
		n_opp = 2   # league.py DEFAULT_OPPONENTS: native + scripted
	return int(_gens.value) * int(_pop.value) * n_opp

# Wall-clock estimate: remaining matches x mean observed match duration, spread
# over the worker pool (jobs run matches concurrently).
func _eta_s() -> float:
	var remaining := _total_matches() - int(_run.matches)
	if int(_run.dur_n) == 0 or remaining <= 0:
		return 0.0
	var mean := float(_run.dur_sum) / float(_run.dur_n)
	var s: Dictionary = _run.start
	var jobs := maxi(int(s.get("jobs", int(_jobs.value))), 1)
	# workers past pop x opponents idle, so they never shorten a generation
	var per_gen := int(s.get("pop", int(_pop.value))) * maxi((s.get("opponents", []) as Array).size(), 1)
	return remaining * mean / maxi(mini(jobs, per_gen), 1)

static func _fmt_s(sec: float) -> String:
	var s := int(roundf(maxf(sec, 0.0)))
	if s >= 3600:
		return "%dh%02dm" % [floori(s / 3600.0), floori(fmod(s, 3600.0) / 60.0)]
	return "%d:%02d" % [floori(s / 60.0), s % 60]

# ---- status text --------------------------------------------------------------------------

func _refresh_ui() -> void:
	_refresh_tabs()
	var running := _pid > 0
	_train_btn.disabled = running
	_train_all_btn.disabled = running
	if _tourney_btn != null:
		_tourney_btn.disabled = running
	_refresh_ai_default()
	_gate_btn.disabled = running
	_stop_btn.disabled = not running
	var s: Dictionary = _run.start
	var build := str(s.get("build", _selected_build()))
	var key := str(s.get("key", _key()))
	var gtot := int(s.get("generations", int(_gens.value)))
	var pop := int(s.get("pop", int(_pop.value)))
	var total := _total_matches()
	var done := int(_run.matches)
	var lines: PackedStringArray = []
	var speed := str(s.get("speed", _speed_spec()))
	if running:
		lines.append("%s RUNNING · pid %d · %s · key %s · speed %s" % [
				_pid_kind.to_upper(), _pid, build, key, speed])
	else:
		lines.append("IDLE · %s · key %s · speed %s" % [build, key, speed])
	var g_disp := maxi(int(_run.cur_g) + 1, (_run.gens as Array).size())
	lines.append("gen %d/%d · cand %d/%d · match %d/%d" % [
			g_disp, gtot, int(_run.cur_cand) + 1, pop, done, total])
	var eta := "ETA —"
	if done >= total and total > 0:
		eta = "ETA done"
	elif int(_run.dur_n) > 0:
		eta = "ETA %s" % _fmt_s(_eta_s())
	var per := "%.1f s/match" % (float(_run.dur_sum) / float(_run.dur_n)) \
			if int(_run.dur_n) > 0 else "— s/match"
	var t0 := float(s.get("t", 0.0))
	var elapsed := ""
	if t0 > 0.0:
		var now := Time.get_unix_time_from_system() if running else float(_run.last_t)
		elapsed = " · elapsed %s" % _fmt_s(now - t0)
	lines.append("%s · %s%s" % [eta, per, elapsed])
	var lm: Dictionary = _run.last_match
	if not lm.is_empty():
		lines.append("last: g%d c%d vs %s  %d-%d-%d  score %.2f · %.1f s" % [
				int(lm.get("g", 0)), int(lm.get("cand", 0)), _opp_tag(lm),
				int(lm.get("wins_a", 0)), int(lm.get("wins_b", 0)), int(lm.get("draws", 0)),
				float(lm.get("score", 0.0)), float(lm.get("duration_s", 0.0))])
	_status.text = "\n".join(lines)
	var hint: Array = _parallelism_hint()
	_hint.text = str(hint[0])
	_hint.add_theme_color_override("font_color", EMBER if bool(hint[1]) else DIM)

	var notes: PackedStringArray = []
	if _proc_note != "":
		notes.append(_proc_note)
	var reg: Dictionary = _run.registered
	if not reg.is_empty():
		notes.append("registered v%d (candidate — GATE it) %s" % [
				int(reg.get("version", 0)), str(reg.get("npz", ""))])
	if str(_run.error) != "":
		notes.append("ERROR: " + str(_run.error))
	_note.text = "\n".join(notes)
	_note.add_theme_color_override("font_color", RED if str(_run.error) != "" else DIM)

	var gate: Dictionary = _run.gate
	if gate.is_empty():
		_gate_label.text = "GATE: — (no verdict for this run yet)"
		_gate_label.add_theme_color_override("font_color", DIM)
	else:
		var passed := bool(gate.get("pass", false))
		var parts: PackedStringArray = []
		var metrics: Variant = gate.get("metrics", {})
		var checks: Variant = metrics.get("checks", metrics) if metrics is Dictionary else {}
		if checks is Dictionary:
			for name in checks:
				var c: Variant = checks[name]
				if c is Dictionary:
					var bit := "%s %s" % [str(name), "ok" if bool(c.get("pass", false)) else "FAIL"]
					if c.has("win_rate"):
						bit += " wr %.2f" % float(c.win_rate)
					parts.append(bit)
		_gate_label.text = "GATE v%d: %s%s" % [int(gate.get("version", 0)),
				"PASS — deployed" if passed else "FAIL — previous pin stays",
				("  ·  " + " · ".join(parts)) if not parts.is_empty() else ""]
		_gate_label.add_theme_color_override("font_color", GREEN if passed else RED)
	if is_instance_valid(_chart):
		_chart.queue_redraw()
	if is_instance_valid(_strip):
		_strip.queue_redraw()

# ---- fitness chart --------------------------------------------------------------------------

# Snap to pixel centers so 1 px lines land on exactly one canvas pixel row.
static func _px(v: float) -> float:
	return floorf(v) + 0.5

# The cockpit panels are plain text: everything they show is a fact read off
# disk (a run's config.json, the registry, a verdict file), never cached state.
func _refresh_tabs() -> void:
	if _runs_info != null:
		var run := _selected_run()
		if run == "":
			_runs_info.text = "no run selected — TRAIN with 'isolated run' ticked writes one"
			_runs_open_btn.disabled = true
			_runs_promote_btn.disabled = true
		else:
			var dir := _runs_root.path_join(run)
			var cfg := _read_json(dir.path_join("config.json"))
			var es: Dictionary = cfg.get("es", {})
			var env: Dictionary = cfg.get("env", {})
			var summary := FileAccess.get_file_as_string(dir.path_join("summary.txt"))
			var head := ""
			for l in summary.split("\n"):
				if l.contains("PASS") or l.contains("fail") or l.begins_with("wall:"):
					head += l.strip_edges() + "\n"
			_runs_info.text = ("%s\nstarted %s · %s · seeded from %s\ngens %s pop %s eps %s jobs %s "
					+ "· godot %s · HEAD %s\n%s") % [
					run, str(cfg.get("started", "?")), str(cfg.get("mode", "?")),
					str(cfg.get("seeded_from", "?")), str(es.get("generations", "?")),
					str(es.get("pop", "?")), str(es.get("episodes", "?")), str(es.get("jobs", "?")),
					str(env.get("godot", "?")), str(env.get("git_head", "?")),
					head if head != "" else "still running — no summary yet"]
			_runs_open_btn.disabled = false
			_runs_promote_btn.disabled = (summary == "")
	if _nets_info != null:
		var ref := _selected_net()
		if ref == "":
			_nets_info.text = "select a net to deploy, retire, or send to VERSUS"
		else:
			var e := _net_entry(ref)
			var ev: Dictionary = e.get("eval", {})
			var checks: Dictionary = ev.get("checks", {})
			var parts: PackedStringArray = []
			for k in checks.keys():
				var c: Dictionary = checks[k]
				parts.append("%s=%s" % [str(k), str(c.get("win_rate", c.get("pass", "?")))])
			_nets_info.text = "%s · created %s · %s\n%s\n%s" % [
					ref, str(e.get("created", "?")),
					"DEPLOYED" if bool(e.get("deployed", false)) else "candidate",
					str(e.get("game_json", "(no exported weights)")),
					" ".join(parts) if parts.size() > 0 else "never gated"]
	if _vs_a_label != null:
		_vs_a_label.text = "A — %s" % (str(_vs_a.get("label", "")) if not _vs_a.is_empty() else "(unset)")
		_vs_b_label.text = "B — %s" % (str(_vs_b.get("label", "")) if not _vs_b.is_empty() else "(unset)")
		_vs_btn.disabled = _vs_a.is_empty() or _vs_b.is_empty() or _pid > 0
	if _vs_result != null and not _last_verdict.is_empty():
		var v := _last_verdict
		var a: Dictionary = v.get("a", {})
		var b: Dictionary = v.get("b", {})
		var clinch: Variant = v.get("clinched_round", null)
		_vs_result.text = "%s  %d-%d  %s\nbest of %d · %d episodes/round · %ss\n%s" % [
				"%s vs %s" % [str(a.get("label", "?")), str(b.get("label", "?"))],
				int(v.get("rounds_a", 0)), int(v.get("rounds_b", 0)),
				"WINNER: " + str(v.get("winner", "?")).to_upper(),
				int(v.get("best_of", 0)), int(v.get("episodes_per_round", 0)),
				str(v.get("wall_s", "?")),
				("clinched in round %s" % str(clinch)) if clinch != null else "no clinch — split decision"]

func _on_chart_draw() -> void:
	_chart_draws += 1
	var c := _chart
	var sz := c.size
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.05, 0.07))
	c.draw_rect(Rect2(Vector2.ZERO, sz), ProtoTheme.PANEL_BORDER, false, 1.0)
	var gens: Array = _run.gens
	var cands: Array = _run.cands
	if gens.is_empty() and cands.is_empty():
		c.draw_string(font, Vector2(0, sz.y * 0.5 + 3),
				"no progress yet — TRAIN, or pick a key with a past run",
				HORIZONTAL_ALIGNMENT_CENTER, sz.x, ProtoTheme.SIZE_BODY, DIM)
		return
	var l := 34.0
	var r := sz.x - 8.0
	var t := 10.0
	var b := sz.y - 14.0
	# y: the 0..1 fitness band, widened to 0.25 steps when shaping pushes past it
	var lo := 0.0
	var hi := 1.0
	for g in gens:
		lo = minf(lo, float(g.mean))
		hi = maxf(hi, float(g.best))
	for k in cands:
		lo = minf(lo, float(k.fitness))
		hi = maxf(hi, float(k.fitness))
	lo = floorf(lo / 0.25) * 0.25
	hi = ceilf(hi / 0.25) * 0.25
	if hi - lo < 0.25:
		hi = lo + 0.25
	# x: the run's planned generation count keeps the axis fixed while lines grow
	var gmax := maxi(int((_run.start as Dictionary).get("generations", 1)), 1) - 1
	for g in gens:
		gmax = maxi(gmax, int(g.g))
	for k in cands:
		gmax = maxi(gmax, int(k.g))
	var xf := func(g: float) -> float:
		return l + (g / float(gmax)) * (r - l) if gmax > 0 else (l + r) * 0.5
	var yf := func(v: float) -> float:
		return b - (v - lo) / (hi - lo) * (b - t)
	# grid + y ticks
	var v := lo
	while v <= hi + 0.001:
		var y := _px(yf.call(v))
		c.draw_line(Vector2(_px(l), y), Vector2(_px(r), y), Color(0.14, 0.19, 0.25), 1.0)
		c.draw_string(font, Vector2(2, y + 3), "%.2f" % v, HORIZONTAL_ALIGNMENT_RIGHT,
				int(l) - 6, ProtoTheme.SIZE_BODY, DIM)
		v += 0.25
	# x ticks (thin out past 8 generations)
	var step := maxi(1, ceili((gmax + 1) / 8.0))
	for g in range(0, gmax + 1, step):
		var x := _px(xf.call(float(g)))
		c.draw_line(Vector2(x, _px(b)), Vector2(x, _px(b) + 3), ProtoTheme.PANEL_BORDER, 1.0)
		c.draw_string(font, Vector2(x - 12, b + 12), "g%d" % g, HORIZONTAL_ALIGNMENT_CENTER,
				24, ProtoTheme.SIZE_BODY, DIM)
	# axes
	c.draw_line(Vector2(_px(l), _px(t)), Vector2(_px(l), _px(b)), Color(0.35, 0.45, 0.6), 1.0)
	c.draw_line(Vector2(_px(l), _px(b)), Vector2(_px(r), _px(b)), Color(0.35, 0.45, 0.6), 1.0)
	# candidate dots (the in-flight generation shows before its line point lands)
	for k in cands:
		var p := Vector2(floorf(xf.call(float(k.g))), floorf(yf.call(float(k.fitness))))
		c.draw_rect(Rect2(p.x - 1, p.y - 1, 2, 2), Color(CYAN.r, CYAN.g, CYAN.b, 0.45))
	# mean + best lines
	var sorted := gens.duplicate()
	sorted.sort_custom(func(a: Dictionary, bb: Dictionary) -> bool: return int(a.g) < int(bb.g))
	for series in [["mean", CYAN], ["best", EMBER]]:
		var field: String = series[0]
		var col: Color = series[1]
		var prev := Vector2.INF
		for g in sorted:
			var p := Vector2(_px(xf.call(float(g.g))), _px(yf.call(float(g[field]))))
			if prev != Vector2.INF:
				c.draw_line(prev, p, col, 1.0)
			c.draw_rect(Rect2(floorf(p.x) - 1, floorf(p.y) - 1, 3, 3), col)
			prev = p
	# legend
	var lx := l + 6.0
	for entry in [["best", EMBER], ["mean", CYAN], ["cand", Color(CYAN.r, CYAN.g, CYAN.b, 0.45)]]:
		c.draw_rect(Rect2(lx, t + 2, 4, 4), entry[1])
		c.draw_string(font, Vector2(lx + 7, t + 8), str(entry[0]), HORIZONTAL_ALIGNMENT_LEFT,
				-1, ProtoTheme.SIZE_BODY, DIM)
		lx += 34.0

# ---- match-score strip ----------------------------------------------------------------------

# One 2x2 dot per match at its win rate (0..1), coloured by opponent tag, x = match
# index over the run's planned total so the strip fills left to right. The legend
# carries each opponent's mean score: a flat 0.00 row IS the "no signal" diagnosis.
func _on_strip_draw() -> void:
	var c := _strip
	var sz := c.size
	var font := ThemeDB.fallback_font
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.05, 0.07))
	c.draw_rect(Rect2(Vector2.ZERO, sz), ProtoTheme.PANEL_BORDER, false, 1.0)
	var l := 34.0
	var r := sz.x - 8.0
	var t := 12.0
	var b := sz.y - 6.0
	for v in [0.0, 0.5, 1.0]:
		var y := _px(b - v * (b - t))
		c.draw_line(Vector2(_px(l), y), Vector2(_px(r), y), Color(0.14, 0.19, 0.25), 1.0)
		c.draw_string(font, Vector2(2, y + 3), "%.1f" % v, HORIZONTAL_ALIGNMENT_RIGHT,
				int(l) - 6, ProtoTheme.SIZE_BODY, DIM)
	var scores: Array = _run.scores
	if scores.is_empty():
		c.draw_string(font, Vector2(l, sz.y * 0.5 + 3), "no matches yet",
				HORIZONTAL_ALIGNMENT_CENTER, r - l, ProtoTheme.SIZE_BODY, DIM)
		return
	var total := maxi(_total_matches(), scores.size())
	var palette := [EMBER, CYAN, GREEN, PALE, RED]
	var cols := {}
	var sums := {}
	var counts := {}
	for i in scores.size():
		var m: Dictionary = scores[i]
		var opp := str(m.opp)
		if not cols.has(opp):
			cols[opp] = palette[cols.size() % palette.size()]
			sums[opp] = 0.0
			counts[opp] = 0
		sums[opp] = float(sums[opp]) + float(m.score)
		counts[opp] = int(counts[opp]) + 1
		var x := floorf(l + (float(i) + 0.5) / float(total) * (r - l))
		var y := floorf(b - float(m.score) * (b - t))
		c.draw_rect(Rect2(x - 1, y - 1, 2, 2), cols[opp])
	var lx := l + 6.0
	for opp in cols:
		c.draw_rect(Rect2(lx, 2, 4, 4), cols[opp])
		c.draw_string(font, Vector2(lx + 7, 8), "%s %.2f" % [
				opp, float(sums[opp]) / float(maxi(int(counts[opp]), 1))],
				HORIZONTAL_ALIGNMENT_LEFT, -1, ProtoTheme.SIZE_BODY, DIM)
		lx += 120.0

# ---- selftest ------------------------------------------------------------------------------

# A synthetic run per the §2 contract: start, two of three generations (2 cands x
# 2 opponents each), a registered net — plus a garbage line and an unknown event
# the console must shrug off.
static func _fixture_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	var opps := [["core.arena.fen_boar_alpha", "native"], ["core.arena.fen_boar_alpha", "scripted"]]
	var t := 1000.0
	lines.append(JSON.stringify({"t": t, "ev": "start", "key": "fen_boar",
			"build": "core.arena.fen_boar_alpha", "generations": 3, "pop": 2, "episodes": 2,
			"jobs": 1, "speed": "max", "opponents": opps, "warm_start": null}))
	lines.append("not json at all")
	lines.append(JSON.stringify({"t": t, "ev": "heartbeat"}))
	for g in 2:
		var fits: Array[float] = []
		for cand in 2:
			for o in opps:
				t += 20.0
				lines.append(JSON.stringify({"t": t, "ev": "match", "g": g, "cand": cand,
						"opp": o[0], "policy": o[1], "wins_a": 1, "wins_b": 1, "draws": 0,
						"score": 0.5, "duration_s": 20.0}))
			var fit := 0.3 + 0.1 * g + 0.15 * cand
			fits.append(fit)
			lines.append(JSON.stringify({"t": t, "ev": "candidate", "g": g, "cand": cand,
					"fitness": fit}))
		lines.append(JSON.stringify({"t": t, "ev": "generation", "g": g, "best": fits.max(),
				"mean": (fits[0] + fits[1]) * 0.5}))
	lines.append(JSON.stringify({"t": t, "ev": "registered", "version": 1,
			"npz": "ml/serving/weights/fen_boar_v1.npz"}))
	return lines

# ---- runs / nets / versus (the cockpit tabs) ----------------------------------------------

# Every run folder tools/train_run.sh has written, newest first. The name IS
# the record: <date>__<keys>__<knobs>, so sorting by name sorts by time.
func _refresh_runs() -> void:
	if _runs == null:
		return
	var sel := _selected_run()
	_runs.clear()
	var names: Array[String] = []
	var d := DirAccess.open(_runs_root)
	if d != null:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			if d.current_is_dir() and not n.begins_with("."):
				if FileAccess.file_exists(_runs_root.path_join(n).path_join("config.json")):
					names.append(n)
			n = d.get_next()
		d.list_dir_end()
	names.sort()
	names.reverse()
	for name in names:
		var cfg := _read_json(_runs_root.path_join(name).path_join("config.json"))
		var mode := str(cfg.get("mode", "?"))
		var done := FileAccess.file_exists(_runs_root.path_join(name).path_join("summary.txt"))
		_runs.add_item("%s  %s%s" % [name, mode, "" if done else "  · running"])
		_runs.set_item_metadata(_runs.item_count - 1, name)
		if name == sel:
			_runs.select(_runs.item_count - 1)
	_refresh_ui()

func _selected_run() -> String:
	if _runs == null:
		return ""
	var sel := _runs.get_selected_items()
	return str(_runs.get_item_metadata(sel[0])) if sel.size() > 0 else ""

func _read_json(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_string(path)
	if raw == "":
		return {}
	var v: Variant = JSON.parse_string(raw)
	return v as Dictionary if v is Dictionary else {}

# Tail the SELECTED run's own progress feed instead of the deployed one — an
# isolated run writes to <run>/progress/<key>.jsonl (ml/serving_paths.py).
func _runs_open() -> void:
	var run := _selected_run()
	if run == "":
		return
	var key := _key()
	if not _valid_key(key):
		_proc_note = "pick a trainee first — RUNS opens that key's feed inside the run"
		_refresh_ui()
		return
	var path := _runs_root.path_join(run).path_join("progress").path_join(key + ".jsonl")
	if not FileAccess.file_exists(path):
		_proc_note = "%s has no progress for '%s' yet" % [run, key]
		_refresh_ui()
		return
	_attach(path, 0)
	_proc_note = "showing %s · %s" % [run, key]
	_refresh_ui()

func _runs_promote() -> void:
	var run := _selected_run()
	if run == "":
		return
	var rel := RUNS_DIR.path_join(run)
	var log_path := _repo.path_join(_log_rel("promote"))
	DirAccess.make_dir_recursive_absolute(_repo.path_join(LOG_DIR))
	var cmd := "cd %s && exec tools/train_run.sh --promote %s >> %s 2>&1" % [
			_sq(_repo), _sq(rel), _sq(log_path)]
	var pid := OS.create_process("bash", ["-lc", cmd])
	_proc_note = ("promoting %s — gate-PASSING nets only; see %s" % [run, _log_rel("promote")]
			if pid > 0 else "could not spawn tools/train_run.sh")
	_cmd_label.text = "tools/train_run.sh --promote " + rel
	_refresh_ui()

# The registry, newest version first per key. The DEPLOYED pin is what the game
# loads; everything else is a candidate waiting on a gate.
func _refresh_nets() -> void:
	if _nets == null:
		return
	var sel := _selected_net()
	_nets.clear()
	var reg := _read_json(_registry_path)
	var pols: Array = reg.get("policies", [])
	var rows: Array = []
	for p in pols:
		if p is Dictionary:
			rows.append(p)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ka := str((a as Dictionary).get("key", ""))
		var kb := str((b as Dictionary).get("key", ""))
		if ka != kb:
			return ka < kb
		return int((a as Dictionary).get("version", 0)) > int((b as Dictionary).get("version", 0)))
	for p in rows:
		var d: Dictionary = p
		var key := str(d.get("key", "?"))
		var ver := int(d.get("version", 0))
		var dep := bool(d.get("deployed", false))
		var trainer := "ppo" if str(d.get("game_json", "")).contains("_ppo_") else "es"
		_nets.add_item("%s  v%-3d %s  %s" % [key.rpad(20), ver,
				"DEPLOYED" if dep else "candidate", trainer])
		_nets.set_item_metadata(_nets.item_count - 1, "%s@v%d" % [key, ver])
		if "%s@v%d" % [key, ver] == sel:
			_nets.select(_nets.item_count - 1)
	_refresh_ui()

func _selected_net() -> String:
	if _nets == null:
		return ""
	var sel := _nets.get_selected_items()
	return str(_nets.get_item_metadata(sel[0])) if sel.size() > 0 else ""

func _net_entry(ref: String) -> Dictionary:
	var key := ref.get_slice("@", 0)
	var ver := int(ref.get_slice("@", 1).substr(1))
	for p in _read_json(_registry_path).get("policies", []):
		if p is Dictionary and str((p as Dictionary).get("key", "")) == key \
				and int((p as Dictionary).get("version", 0)) == ver:
			return p
	return {}

# Moving the pin rewrites ml/serving/registry.json — one deployed entry per key,
# exactly the invariant ml/eval/gate.py and tools/train_run.sh --promote keep.
func _set_deployed(ref: String, on: bool) -> void:
	var reg := _read_json(_registry_path)
	if reg.is_empty():
		_proc_note = "no registry at " + REGISTRY
		_refresh_ui()
		return
	var key := ref.get_slice("@", 0)
	var ver := int(ref.get_slice("@", 1).substr(1))
	var hit := false
	for p in reg.get("policies", []):
		if not (p is Dictionary):
			continue
		var d: Dictionary = p
		if str(d.get("key", "")) != key:
			continue
		if int(d.get("version", 0)) == ver:
			d["deployed"] = on
			hit = true
		elif on:
			d["deployed"] = false          # one pin per key
	if not hit:
		_proc_note = "no such net: " + ref
		_refresh_ui()
		return
	var f := FileAccess.open(_registry_path, FileAccess.WRITE)
	if f == null:
		_proc_note = "cannot write " + REGISTRY
		_refresh_ui()
		return
	f.store_string(JSON.stringify(reg, " "))
	f.close()
	_proc_note = "%s %s" % [ref, "deployed — the fleet serves it now" if on else "retired"]
	_refresh_nets()

func _net_deploy() -> void:
	var ref := _selected_net()
	if ref != "":
		_set_deployed(ref, true)

func _net_retire() -> void:
	var ref := _selected_net()
	if ref != "":
		_set_deployed(ref, false)

func _set_side(side: String) -> void:
	var ref := _selected_net()
	if ref == "":
		return
	var entry := _net_entry(ref)
	var build := str(entry.get("build", ""))
	if build == "":
		build = _selected_build()
	var side_data := {"label": ref, "spec": ref, "build": build}
	if side == "a":
		_vs_a = side_data
	else:
		_vs_b = side_data
	_refresh_ui()

func _set_baseline(side: String, who: String) -> void:
	var build := _selected_build()
	var side_data := {"label": who, "spec": who, "build": build}
	if side == "a":
		_vs_a = side_data
	else:
		_vs_b = side_data
	_refresh_ui()

func _versus_run() -> void:
	if _vs_a.is_empty() or _vs_b.is_empty():
		_proc_note = "set both sides first (NETS: SET A / SET B, or a baseline)"
		_refresh_ui()
		return
	var a_build := str(_vs_a.get("build", ""))
	if a_build == "":
		a_build = _selected_build()
	var b_build := str(_vs_b.get("build", ""))
	if b_build == "":
		b_build = a_build
	if a_build == "":
		_proc_note = "pick a trainee — a versus needs a build to fight in"
		_refresh_ui()
		return
	DirAccess.make_dir_recursive_absolute(_bench_root)
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	var out := _bench_root.path_join("console_%s.json" % stamp)
	var args := ("versus --a %s --b %s --a-build %s --b-build %s --best-of %d "
			+ "--episodes %d --jobs %d --speed %s --label console --out %s") % [
			_sq(str(_vs_a.spec)), _sq(str(_vs_b.spec)), _sq(a_build), _sq(b_build),
			int(_vs_best_of.value), int(_vs_eps.value), int(_jobs.value),
			_speed_spec(), _sq(out)]
	_vs_pending = {"out": out, "t0": Time.get_ticks_msec()}
	_vs_result.text = "running best of %d — %s vs %s…" % [
			int(_vs_best_of.value), str(_vs_a.label), str(_vs_b.label)]
	# the versus feed is its own key, so the PROGRESS tab can watch it live
	_attach(_progress_path("versus"), _file_len(_progress_path("versus")))
	_spawn_league(args, "versus", "versus")

# The verdict file appears when the run finishes; poll for it rather than
# blocking the console (matches how the progress tail works).
func _poll_versus() -> void:
	if _vs_pending.is_empty():
		return
	var out := str(_vs_pending.get("out", ""))
	if out == "" or not FileAccess.file_exists(out):
		return
	var v := _read_json(out)
	if v.is_empty():
		return                              # still being written
	_last_verdict = v
	_vs_pending = {}
	_refresh_history()
	_refresh_ui()

func _refresh_history() -> void:
	if _vs_history == null:
		return
	_vs_history.clear()
	var names: Array[String] = []
	var d := DirAccess.open(_bench_root)
	if d != null:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			if not d.current_is_dir() and n.ends_with(".json"):
				names.append(n)
			n = d.get_next()
		d.list_dir_end()
	names.sort()
	names.reverse()
	for name in names:
		var v := _read_json(_bench_root.path_join(name))
		if v.is_empty():
			continue
		var a: Dictionary = v.get("a", {})
		var b: Dictionary = v.get("b", {})
		_vs_history.add_item("%s  %d-%d  %s" % [
				"%s vs %s" % [str(a.get("label", "?")), str(b.get("label", "?"))],
				int(v.get("rounds_a", 0)), int(v.get("rounds_b", 0)),
				str(v.get("winner", "?")).to_upper()])
		_vs_history.set_item_metadata(_vs_history.item_count - 1, name)

# ---- isolated / GPU training (tools/train_run.sh) -----------------------------------------

# The console's own run folder name: DATE FIRST so ml/runs/ sorts by time, and
# --run-dir hands it to the script so we know where to tail from.
func _console_run_dir(key: String) -> String:
	var t := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute]
	var knobs := ("steps%d_envs%d" % [2000000, 512]) if _gpu.button_pressed \
			else ("g%d_p%d_e%d_j%d" % [int(_gens.value), int(_pop.value),
					int(_eps.value), int(_jobs.value)])
	return RUNS_DIR.path_join("%s__%s-console__%s" % [stamp, key, knobs])

func _spawn_train_run(key: String, build: String) -> void:
	var run_dir := _console_run_dir(key)
	var log_path := _repo.path_join(_log_rel(key))
	DirAccess.make_dir_recursive_absolute(_repo.path_join(LOG_DIR))
	var env := ""
	var args := ""
	if _gpu.button_pressed:
		var opp := _selected_opponents()
		var opp_build: String = str(opp[0]) if not opp.is_empty() else build
		env = "ENVS=512 EPISODES=%d SEED=2026 " % int(_eps.value)
		if _net_spec() != "":
			env += "NET=%s " % _sq(_net_spec())
		args = "--ppo --key %s --build %s --opp-build %s --run-dir %s" % [
				_sq(key), _sq(build), _sq(opp_build), _sq(run_dir)]
	else:
		env = "GENERATIONS=%d POP=%d EPISODES=%d JOBS=%d SPEED=%s " % [
				int(_gens.value), int(_pop.value), int(_eps.value), int(_jobs.value),
				_speed_spec()]
		var opps := _opponent_spec()
		if opps != "":
			env += "OPPONENTS=%s " % _sq(opps)
		if _net_spec() != "":
			env += "NET=%s " % _sq(_net_spec())
		args = "--key %s --build %s --run-dir %s" % [_sq(key), _sq(build), _sq(run_dir)]
	var cmd := "cd %s && exec env %stools/train_run.sh %s >> %s 2>&1" % [
			_sq(_repo), env, args, _sq(log_path)]
	_pid = OS.create_process("bash", ["-lc", cmd])
	if _pid <= 0:
		_pid = -1
		_proc_note = "could not spawn tools/train_run.sh"
	else:
		_pid_kind = "ppo" if _gpu.button_pressed else "train"
		_proc_note = "%s started · pid %d · %s" % [_pid_kind, _pid, run_dir]
	# the isolated run writes its progress inside the run folder
	_attach(_repo.path_join(run_dir).path_join("progress").path_join(key + ".jsonl"), 0)
	_cmd_label.text = "env %stools/train_run.sh %s" % [env, args]
	_refresh_runs()
	_refresh_ui()

func _run_selftest() -> void:
	var path := ProjectSettings.globalize_path("user://console_fixture.jsonl")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var lines := _fixture_lines()
	var last := lines[lines.size() - 1]
	# stage 1: everything but the last line, then a PARTIAL trailing write
	var f := FileAccess.open(path, FileAccess.WRITE)
	for i in lines.size() - 1:
		f.store_line(lines[i])
	f.store_string(last.substr(0, 12))
	f.close()
	_attach(path, 0)
	for i in 15:
		await get_tree().process_frame
		_poll_progress()
	var gens_partial: int = (_run.gens as Array).size()
	var matches_partial := int(_run.matches)
	var registered_early: bool = not (_run.registered as Dictionary).is_empty()
	# stage 2: the trailing line completes
	f = FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string(last.substr(12) + "\n")
	f.close()
	for i in 15:
		await get_tree().process_frame
		_poll_progress()
	_refresh_ui()
	var ok := true
	if gens_partial < 2:
		ok = false
		push_error("CONSOLE SELFTEST: parsed %d generation points, want >= 2" % gens_partial)
	if matches_partial != 8 or int(_run.matches) != 8:
		ok = false
		push_error("CONSOLE SELFTEST: match count %d/%d, want 8/8 (dupes or drops)" % [
				matches_partial, int(_run.matches)])
	if registered_early:
		ok = false
		push_error("CONSOLE SELFTEST: a partial trailing line was consumed")
	if int((_run.registered as Dictionary).get("version", 0)) != 1:
		ok = false
		push_error("CONSOLE SELFTEST: completed trailing line never parsed")
	if int(_run.unknown) != 1 or (_run.cands as Array).size() != 4:
		ok = false
		push_error("CONSOLE SELFTEST: unknown=%d cands=%d, want 1/4" % [
				int(_run.unknown), (_run.cands as Array).size()])
	if (_run.scores as Array).size() != 8 or str((_run.scores as Array)[0].opp) != "native@fen_boar_alpha":
		ok = false
		push_error("CONSOLE SELFTEST: strip has %d points (want 8), first tag '%s'" % [
				(_run.scores as Array).size(), str((_run.scores as Array)[0].opp) if not (_run.scores as Array).is_empty() else ""])
	if _hint.text.find("matches/gen") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: parallelism hint missing: '%s'" % _hint.text)
	if _status.text == "" or _status.text.find("ETA") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: status text missing/without ETA: '%s'" % _status.text)
	if _eta_s() <= 0.0 or _total_matches() != 12:
		ok = false
		push_error("CONSOLE SELFTEST: ETA %.1f s of %d matches, want > 0 of 12" % [
				_eta_s(), _total_matches()])
	ok = _selftest_cockpit() and ok
	if ok:
		print("CONSOLE SELFTEST OK — %d generations, %d/%d matches, ETA %s, chart draws %d, hint '%s'" % [
				(_run.gens as Array).size(), int(_run.matches), _total_matches(),
				_fmt_s(_eta_s()), _chart_draws, _hint.text])
	get_tree().quit(0 if ok else 1)

# The cockpit tabs, against FIXTURES under user:// — the gate must never read or
# write the real ml/serving/registry.json, ml/runs/ or ml/data/benchmarks/.
func _selftest_cockpit() -> bool:
	var ok := true
	var root := ProjectSettings.globalize_path("user://console_selftest")
	DirAccess.make_dir_recursive_absolute(root.path_join("runs"))
	DirAccess.make_dir_recursive_absolute(root.path_join("bench"))
	_registry_path = root.path_join("registry.json")
	_runs_root = root.path_join("runs")
	_bench_root = root.path_join("bench")

	# --- a registry with two keys: one deployed pin, two candidates ----------
	var reg := {"schema": "arena.registry.v1", "policies": [
		{"key": "fen_boar", "version": 1, "deployed": true, "created": "2026-09-01T00:00:00",
			"build": "core.arena.fen_boar_alpha", "game_json": "weights/fen_boar_v1.json"},
		{"key": "fen_boar", "version": 2, "deployed": false, "created": "2026-09-02T00:00:00",
			"build": "core.arena.fen_boar_alpha", "game_json": "weights/fen_boar_v2.json",
			"eval": {"checks": {"suite_native": {"win_rate": 0.62, "pass": true}}}},
		{"key": "cinder_drake", "version": 1, "deployed": false, "created": "2026-09-03T00:00:00",
			"build": "core.arena.cinder_drake", "game_json": "weights/cinder_drake_ppo_v1.json"}]}
	var f := FileAccess.open(_registry_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(reg, " "))
	f.close()
	_refresh_nets()
	if _nets.item_count != 3:
		ok = false
		push_error("CONSOLE SELFTEST: registry shows %d nets, want 3" % _nets.item_count)
	# newest version first within a key, keys alphabetical
	if str(_nets.get_item_metadata(0)) != "cinder_drake@v1" \
			or str(_nets.get_item_metadata(1)) != "fen_boar@v2":
		ok = false
		push_error("CONSOLE SELFTEST: net order wrong: %s, %s" % [
				str(_nets.get_item_metadata(0)), str(_nets.get_item_metadata(1))])

	# --- deploying v2 must move the pin, not add a second one ---------------
	_nets.select(1)
	_net_deploy()
	var after := _read_json(_registry_path)
	var deployed: Array[String] = []
	for pol in after.get("policies", []):
		if bool((pol as Dictionary).get("deployed", false)):
			deployed.append("%s@v%d" % [str((pol as Dictionary).get("key", "")),
					int((pol as Dictionary).get("version", 0))])
	var want_pins: Array[String] = ["fen_boar@v2"]
	if deployed != want_pins:
		ok = false
		push_error("CONSOLE SELFTEST: after DEPLOY the pins are %s, want [fen_boar@v2]" % str(deployed))
	_net_retire()
	after = _read_json(_registry_path)
	for pol in after.get("policies", []):
		if bool((pol as Dictionary).get("deployed", false)):
			ok = false
			push_error("CONSOLE SELFTEST: RETIRE left a deployed pin behind")

	# --- a run folder shows up, and its progress is tailable ----------------
	var run_name := "2026-09-13_0700__fen_boar-console__g2_p2_e1_j4"
	var run_dir := _runs_root.path_join(run_name)
	DirAccess.make_dir_recursive_absolute(run_dir.path_join("progress"))
	f = FileAccess.open(run_dir.path_join("config.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"started": "2026-09-13T07:00:00", "mode": "es",
			"keys_label": "fen_boar", "knobs": "g2_p2_e1_j4", "seeded_from": "deployed registry",
			"es": {"generations": 2, "pop": 2, "episodes": 1, "jobs": 4},
			"env": {"godot": "4.6", "git_head": "abc1234"}}, " "))
	f.close()
	f = FileAccess.open(run_dir.path_join("progress").path_join("fen_boar.jsonl"), FileAccess.WRITE)
	for line in _fixture_lines():
		f.store_line(line)
	f.close()
	_refresh_runs()
	if _runs.item_count != 1 or str(_runs.get_item_metadata(0)) != run_name:
		ok = false
		push_error("CONSOLE SELFTEST: runs list has %d entries" % _runs.item_count)
	_runs.select(0)
	_key_edit.text = "fen_boar"
	_runs_open()
	if (_run.gens as Array).size() < 2 or int(_run.matches) != 8:
		ok = false
		push_error("CONSOLE SELFTEST: OPEN read %d gens / %d matches from the run folder" % [
				(_run.gens as Array).size(), int(_run.matches)])
	_refresh_ui()
	if _runs_info.text.find("abc1234") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: run panel does not show the run's config")
	if not _runs_promote_btn.disabled:
		ok = false
		push_error("CONSOLE SELFTEST: PROMOTE offered for a run with no summary.txt")

	# --- versus: sides, the command, and a verdict read back ----------------
	_nets.select(1)
	_set_side("a")
	_set_baseline("b", "native")
	if str(_vs_a.get("spec", "")) != "fen_boar@v2" or str(_vs_b.get("spec", "")) != "native":
		ok = false
		push_error("CONSOLE SELFTEST: versus sides are %s / %s" % [
				str(_vs_a.get("spec", "")), str(_vs_b.get("spec", ""))])
	var verdict := {"schema": "arena.versus.v1", "best_of": 5, "episodes_per_round": 3,
			"wall_s": 12.5, "rounds_a": 3, "rounds_b": 2, "rounds_drawn": 0,
			"clinched_round": 5, "winner": "a",
			"a": {"label": "fen_boar v2 (candidate)"}, "b": {"label": "native"}}
	f = FileAccess.open(_bench_root.path_join("2026-09-13_070000__a_vs_b.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(verdict, " "))
	f.close()
	_refresh_history()
	if _vs_history.item_count != 1 or _vs_history.get_item_text(0).find("3-2") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: benchmark history shows %d rows" % _vs_history.item_count)
	_last_verdict = verdict
	_refresh_ui()
	if _vs_result.text.find("WINNER: A") < 0 or _vs_result.text.find("clinched in round 5") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: verdict panel reads '%s'" % _vs_result.text)

	# --- the isolated-run command line, without spawning anything -----------
	_isolated.button_pressed = true
	_gpu.button_pressed = false
	var dir_es := _console_run_dir("fen_boar")
	_gpu.button_pressed = true
	var dir_ppo := _console_run_dir("fen_boar")
	_gpu.button_pressed = false
	if dir_es.find("ml/runs/") != 0 or dir_es.find("__fen_boar-console__g") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: ES run dir '%s'" % dir_es)
	if dir_ppo.find("envs512") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: PPO run dir '%s'" % dir_ppo)

	# --- the NET dropdown: the real presets, and no NET= on a default run ---
	# The list must come off ml/training/architectures.json, or the console would
	# quietly offer one architecture while the trainers know six. And "default"
	# must produce NO env var, so an ordinary TRAIN's command line is unchanged.
	var names: Array = []
	for row in _architectures():
		names.append(str(row.name))
	if not names.has("default") or not names.has("wide"):
		ok = false
		push_error("CONSOLE SELFTEST: architectures.json read as %s" % str(names))
	for i in _net.get_item_count():
		if str(_net.get_item_metadata(i)) == "default":
			_net.select(i)
	if _net_spec() != "":
		ok = false
		push_error("CONSOLE SELFTEST: the default net would pass NET=%s" % _net_spec())
	for i in _net.get_item_count():
		if str(_net.get_item_metadata(i)) == "wide":
			_net.select(i)
	if _net_spec() != "wide":
		ok = false
		push_error("CONSOLE SELFTEST: selecting 'wide' yields '%s'" % _net_spec())
	for i in _net.get_item_count():
		if str(_net.get_item_metadata(i)) == "default":
			_net.select(i)
	return ok
