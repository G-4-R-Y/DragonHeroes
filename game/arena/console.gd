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
# The GPU tier's own budget, previously two bare literals inside the run-dir
# name. Named so the tooltip can state them (R60: the interface has to be
# legible at 20 M-step values) and so the folder name and the label can never
# drift apart. The folder keeps the raw digits — it is parsed, not read.
const GPU_PPO_STEPS := 2000000
const GPU_PPO_ENVS := 512
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
# THE WHOLE RUN, not just the key on the chart. Ricardo, 2026-09-14: "in
# tournament viz i can't see the total progress, only current key progress! Nor
# estimated time to conclude the full run". _run is ONE key's feed; a sweep walks
# the roster, so its totals have to be read across every feed in the run folder.
var _sweep := {}                 # key -> {off, total, g, methods, mdone, done, t0, t1}
var _sweep_keys: Array = []      # the PLANNED roster, from the run's config.json
var _sweep_root := ""            # the run folder itself, so config.json can be re-read
var _sweep_label: Label
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
var _bracket: CheckBox
var _runs: ItemList
var _runs_info: Label
var _runs_open_btn: Button
var _runs_promote_btn: Button
var _nets: ItemList
var _nets_info: Label
var _vs_a := {}                  # {label, spec, build} — spec: native|scripted|abs path
var _vs_b := {}
# the benchmark browser: every verdict under ml/data/benchmarks/, parsed once
var _bench: Array = []           # [{name, verdict, kind, keys, when}] newest first
var _bench_stamp := {}           # name -> modified time, so a re-filter re-reads nothing
var _vs_filter: OptionButton     # creature
var _vs_kind: OptionButton       # versus | tournament | ladder | everything
var _vs_count: Label
# RANK — the global, body-neutral net ranking (ml/training/ladder.py)
var _rank_table: ItemList
var _rank_head: Label
var _rank_btn: Button
var _rank_all_arenas: CheckBox
var _rank_deployed: CheckBox
var _rank_eps: SpinBox
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
# R56: the trainer's PROCESS GROUP id, resolved once while it runs and kept
# after it exits so stragglers can still be reaped. Only ever set when it
# equals _pid — that equality is the proof that `setsid` gave us a group of our
# own. Godot's own children inherit GODOT'S group, so group-killing a group we
# did not create would kill the editor running this console.
var _pgid := -1
var _pid_kind := ""
var _proc_note := ""

# progress tail: re-opened each poll, byte offset past the last COMPLETE line
var _tail_path := ""
var _tail_offset := 0
var _poll_accum := 0.0
var _run := {}

func _ready() -> void:
	_previous_canvas = get_window().content_scale_size
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

func _exit_tree() -> void:
	if _previous_canvas != Vector2i.ZERO:
		get_window().content_scale_size = _previous_canvas

func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_S:
		return
	_poll_accum = 0.0
	if _pid > 0 and _pgid <= 0:
		_resolve_pgid()
	if _pid > 0 and not OS.is_process_running(_pid):
		# R56: the leader is gone, but a crashed or SIGKILLed trainer orphans its
		# godot workers to init, where nothing ever reaps them. Sweep the group.
		var stragglers := _reap_group()
		_proc_note = "%s finished — log %s" % [_pid_kind, _log_rel(_key())]
		if stragglers:
			_proc_note += " (orphaned workers reaped)"
		_pid = -1
		_pgid = -1
		_pid_kind = ""
	_poll_progress()
	_sweep_scan()
	_follow_sweep()
	_poll_versus()
	_refresh_ui()

# ---- UI ---------------------------------------------------------------------------------

# The console is a desktop TOOL, not the 640x360 game: take the biggest 16:9
# logical canvas that fits the screen it opens on (the full-rect containers
# reflow). At 640x360 the roster column's minimum heights overflowed and the
# TRAIN/STOP/GATE/WATCH buttons rendered outside the window.
# The shared rule (game/tools/console_fit.gd) — the genforge cockpit uses the
# same one, so a fix to either lands in both.
func _fit_window() -> void:
	DhConsoleFit.apply(get_window())

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c1116")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# BACK — the console also opens from the title menu in-process (standalone
	# console.tscn boots keep working; hidden in the selftest)
	if not _selftest:
		var back := Button.new()
		back.name = "ArenaBack"
		back.text = ProtoLang.t("opt_back")
		back.focus_mode = Control.FOCUS_NONE
		back.add_theme_font_size_override("font_size", 8)
		back.position = Vector2(6, 4)
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://prototype/ui/main_menu.tscn"))
		add_child(back)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8.0
	hb.offset_top = 28.0   # reserve input/layout space for Back; z-index cannot fix hit testing
	hb.offset_right = -8.0
	hb.offset_bottom = -6.0
	hb.add_theme_constant_override("separation", 10)
	add_child(hb)

	# ---- left: the roster panel (fixed width; the chart takes the rest)
	var left_frame := VBoxContainer.new()
	left_frame.custom_minimum_size = Vector2(236, 0)
	left_frame.add_theme_constant_override("separation", 3)
	hb.add_child(left_frame)

	var title := _label("TRAINING CONSOLE", EMBER, ProtoTheme.SIZE_TITLE)
	var big := ProtoTheme.font_big()
	if big != null:
		title.add_theme_font_override("font", big)
	left_frame.add_child(title)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_frame.add_child(roster_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	roster_scroll.add_child(left)

	left.add_child(_label("trainee — the build the net plays as", DIM))
	_trainee = _list(88, false)
	_trainee.item_selected.connect(_on_trainee_selected)
	left.add_child(_trainee)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 4)
	# R60: no wrap for a caption that sits beside its control. A wrapping Label
	# reports a minimum width of 1, and an HBox/Grid hands it exactly that — the
	# 2026-09-22 capture shows "key" drawn as a one-letter vertical column at the
	# left edge. The VERSUS/RANK rows already opt out; these four never did.
	key_row.add_child(_label("key", DIM, ProtoTheme.SIZE_BODY, false))
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
	speed_row.add_child(_label("speed", DIM, ProtoTheme.SIZE_BODY, false))
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
	net_row.add_child(_label("net", DIM, ProtoTheme.SIZE_BODY, false))
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
	_gpu.tooltip_text = "ml/training/ppo.py on CUDA instead of the ES league\n%s steps over %s parallel envs" % [
			_si(GPU_PPO_STEPS), _si(GPU_PPO_ENVS)]
	_gpu.toggled.connect(func(_on: bool) -> void: _refresh_ui())
	mode_row.add_child(_gpu)
	# TRAIN ALL's second gear (Ricardo, 2026-09-14: "Add tournament mode for the
	# train all method, as well"). Off, the sweep trains every creature ONE way
	# and assumes that was the right one; on, every method trains each creature
	# and the candidates fight for that creature's pin — the TOURNAMENT button's
	# bracket, applied across the whole roster.
	_bracket = CheckBox.new()
	_bracket.text = "bracket"
	_bracket.focus_mode = Control.FOCUS_NONE
	_bracket.tooltip_text = ("TRAIN ALL only: tools/train_run.sh --tournament — every method "
			+ "trains each creature, then the candidates fight best-of-%d for the pin. "
			+ "PPO is one of the entrants, so the GPU tick does not apply.") % TOURNEY_BEST_OF
	_bracket.toggled.connect(func(_on: bool) -> void: _refresh_ui())
	mode_row.add_child(_bracket)
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
			TOURNEY_BEST_OF, _si(TOURNEY_PPO_STEPS)]
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
	# the WHOLE run, above the one key the chart is drawing
	_sweep_label = _label("", CYAN)
	_sweep_label.custom_minimum_size = Vector2(1, 0)
	right.add_child(_sweep_label)
	_note = _label("", DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(0, 22)
	right.add_child(_note)

	right.add_child(_label("FITNESS by GENERATION", EMBER))
	_chart = Control.new()
	# 64, not 120. This is a FLOOR, and the chart is the column's only expanding
	# child, so on any real canvas it still takes everything left over (194 px at
	# 800x450, 554 at 1440x810 — measured). A floor of 120 only ever mattered on a
	# canvas too short for the column, where it pushed the strip and the gate
	# verdict off the bottom of the screen instead of giving up its own height.
	_chart.custom_minimum_size = Vector2(0, 64)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# draw_string is NOT clipped to a Control's rect. Every label below is placed
	# inside the box on purpose, but one bad tick range should dirty this panel,
	# not paint over its neighbours and off the bottom of the screen.
	_chart.clip_contents = true
	_chart.draw.connect(_on_chart_draw)
	right.add_child(_chart)

	right.add_child(_label("MATCH SCORE — win rate per match, by opponent", EMBER))
	_strip = Control.new()
	_strip.custom_minimum_size = Vector2(0, 58)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.clip_contents = true
	_strip.draw.connect(_on_strip_draw)
	right.add_child(_strip)

	_gate_label = _label("", PALE)
	_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gate_label.custom_minimum_size = Vector2(0, 44)   # 3 lines: 6 checks do not fit in 2
	right.add_child(_gate_label)

	_build_runs_tab(tabs)
	_build_nets_tab(tabs)
	_build_versus_tab(tabs)
	_build_rank_tab(tabs)

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
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
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
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
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

	var base := HFlowContainer.new()
	base.add_theme_constant_override("h_separation", 4)
	base.add_child(_label("baselines", DIM, ProtoTheme.SIZE_BODY, false))
	for side in ["a", "b"]:
		for who in BASELINES:
			var s2 := str(side)
			var w := str(who)
			_button(base, "%s=%s" % [s2.to_upper(), w], func() -> void: _set_baseline(s2, w))
	v.add_child(base)

	var knobs := HFlowContainer.new()
	knobs.add_theme_constant_override("h_separation", 4)
	knobs.add_child(_label("best of", DIM, ProtoTheme.SIZE_BODY, false))
	_vs_best_of = SpinBox.new()
	_vs_best_of.min_value = 1
	_vs_best_of.max_value = 99
	_vs_best_of.value = 9
	_vs_best_of.rounded = true
	knobs.add_child(_vs_best_of)
	knobs.add_child(_label("episodes/round", DIM, ProtoTheme.SIZE_BODY, false))
	_vs_eps = SpinBox.new()
	_vs_eps.min_value = 1
	_vs_eps.max_value = 32
	_vs_eps.value = 3
	_vs_eps.rounded = true
	knobs.add_child(_vs_eps)
	_vs_btn = _button(knobs, "RUN BEST-OF-N", _versus_run)
	_button(knobs, "WATCH", _versus_watch).tooltip_text = \
			"Spectate this exact pairing — both nets attached, the whole set."
	_button(knobs, "SWAP", func() -> void:
		var t := _vs_a
		_vs_a = _vs_b
		_vs_b = t
		_refresh_ui())
	v.add_child(knobs)

	_vs_result = _label("", PALE)
	_vs_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# R60: this floor used to be a flat 66 px of EMPTY panel — reserved so the
	# layout would not jump when a verdict arrives. Once the captions above it
	# came back (they had been drawing 1 px tall), VERSUS wanted 342 px of a
	# 360 px canvas and the history list below was squeezed to ZERO rows at
	# MIN_CANVAS. The label autowraps, so it grows to whatever the verdict
	# needs anyway; two lines is enough of a reservation to stop the jump, and
	# the 42 px it gives back are what the history list is for.
	# PREVIOUS: _vs_result.custom_minimum_size = Vector2(0, 66)
	var line_h := ThemeDB.fallback_font.get_ascent(ProtoTheme.SIZE_BODY) \
			+ ThemeDB.fallback_font.get_descent(ProtoTheme.SIZE_BODY)
	_vs_result.custom_minimum_size = Vector2(0, line_h * 2.0)
	v.add_child(_vs_result)
	v.add_child(_label("HISTORY — every verdict, newest first", EMBER))
	# Ricardo, 2026-09-14: "a better benchmark interface, filtered by creature".
	# ml/data/benchmarks/ accumulates forever and holds TWO schemas; one flat
	# undifferentiated list was unreadable the moment the roster grew.
	var filt := HFlowContainer.new()
	filt.add_theme_constant_override("h_separation", 4)
	filt.add_child(_label("creature", DIM, ProtoTheme.SIZE_BODY, false))
	_vs_filter = OptionButton.new()
	_vs_filter.focus_mode = Control.FOCUS_NONE
	_vs_filter.tooltip_text = "Only verdicts that involve this creature — either side, or the bracket's key."
	_vs_filter.item_selected.connect(func(_i: int) -> void: _refresh_history())
	filt.add_child(_vs_filter)
	filt.add_child(_label("kind", DIM, ProtoTheme.SIZE_BODY, false))
	_vs_kind = OptionButton.new()
	_vs_kind.focus_mode = Control.FOCUS_NONE
	# R60: "distill" and "parity" were rendering as head-to-heads AND were
	# unreachable here — 9 of the 31 records on disk could not be filtered to.
	for row in [["everything", ""], ["head to head", "versus"], ["brackets", "tournament"],
			["global ranks", "ladder"], ["distills", "distill"], ["env parity", "parity"]]:
		_vs_kind.add_item(str(row[0]))
		_vs_kind.set_item_metadata(_vs_kind.item_count - 1, str(row[1]))
	_vs_kind.item_selected.connect(func(_i: int) -> void: _refresh_history())
	filt.add_child(_vs_kind)
	# R60: this one is filled by _refresh_history() ("12 verdicts"), and it sits
	# in a flow row — wrapping would hand it a minimum width of 1 and the count
	# would read as a vertical letter column. The new collapse check in
	# console_layout_probe.gd caught it on all seven canvases.
	_vs_count = _label("", DIM, ProtoTheme.SIZE_BODY, false)
	filt.add_child(_vs_count)
	_button(filt, "WATCH THIS", _verdict_watch).tooltip_text = \
			"Replay the selected verdict in a spectated arena window."
	v.add_child(filt)
	_vs_history = _list(0, false)
	_vs_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# a row is a verdict: selecting one puts it in the panel above
	_vs_history.item_selected.connect(func(i: int) -> void:
		var picked := _bench_entry(str(_vs_history.get_item_metadata(i)))
		if not picked.is_empty():
			_last_verdict = picked.verdict
			_refresh_ui())
	v.add_child(_vs_history)

# RANK — Ricardo, 2026-09-14: "a global rank for the all vs all, where every
# model net compete for the top in a balance fight".
#
# VERSUS answers "is this net better than that one". RANK answers "which net is
# best, full stop" — and the word that carries the weight is BALANCE. A ranking
# of NETS has to remove the body from the comparison, so every pairing is played
# with BOTH SIDES ON THE SAME BUILD, and both orientations, so the only variable
# left is the policy. ml/training/ladder.py does the fighting.
func _build_rank_tab(tabs: TabContainer) -> void:
	var v := VBoxContainer.new()
	v.name = "RANK"
	v.add_theme_constant_override("separation", 3)
	tabs.add_child(v)
	v.add_child(_label("GLOBAL RANK — every net against every other, same body", EMBER))
	v.add_child(_label("Both sides play the SAME arena build and every pair plays both "
			+ "sides, so the only thing that differs is the policy. The baselines "
			+ "(native/scripted) are the floor the table is read against. Verdicts land "
			+ "in ml/data/benchmarks/ and show up in VERSUS as 'global ranks'.", DIM))

	var knobs := HFlowContainer.new()
	knobs.add_theme_constant_override("h_separation", 4)
	_rank_all_arenas = CheckBox.new()
	_rank_all_arenas.text = "every arena"
	_rank_all_arenas.focus_mode = Control.FOCUS_NONE
	_rank_all_arenas.tooltip_text = ("Replay every pairing in every creature build. "
			+ "Fairer and far longer — without it the ladder runs in the selected "
			+ "trainee's build (or the roster's first).")
	knobs.add_child(_rank_all_arenas)
	_rank_deployed = CheckBox.new()
	_rank_deployed.text = "pins only"
	_rank_deployed.focus_mode = Control.FOCUS_NONE
	_rank_deployed.tooltip_text = "Only the deployed pin of each key, not every candidate version."
	knobs.add_child(_rank_deployed)
	knobs.add_child(_label("episodes/side", DIM, ProtoTheme.SIZE_BODY, false))
	_rank_eps = SpinBox.new()
	_rank_eps.min_value = 1
	_rank_eps.max_value = 16
	_rank_eps.value = 1
	_rank_eps.rounded = true
	knobs.add_child(_rank_eps)
	_rank_btn = _button(knobs, "RUN GLOBAL RANK", _rank_run)
	_button(knobs, "REFRESH", _refresh_rank)
	v.add_child(knobs)

	_rank_head = _label("", PALE)
	_rank_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rank_head.custom_minimum_size = Vector2(0, 30)
	v.add_child(_rank_head)
	_rank_table = _list(0, false)
	_rank_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_rank_table)

# The newest arena.ladder.v1 verdict in the benchmark folder — the ladder is not
# live-tailable (it emits pairings, not generations), so the table is whatever
# the last completed run wrote.
func _refresh_rank() -> void:
	if _rank_table == null:
		return
	_scan_bench()
	_rank_table.clear()
	var newest := {}
	for e in _bench:
		if str(e.kind) == "ladder":
			newest = e
			break                            # _bench is newest first
	if newest.is_empty():
		_rank_head.text = "no global rank yet — RUN GLOBAL RANK writes one"
		return
	var v: Dictionary = newest.verdict
	var arenas: Array = _as_strings(v.get("arenas", []))
	var short: PackedStringArray = []
	for a in arenas:
		short.append(str(a).get_slice(".", 2))
	_rank_head.text = "%s · %d entrants · %d pairing(s) · arena %s · %ss" % [
			str(newest.when), (v.get("entrants", []) as Array).size(),
			(v.get("pairings", []) as Array).size(), ", ".join(short),
			str(v.get("wall_s", "?"))]
	for row in (v.get("table", []) if v.get("table", []) is Array else []):
		var r: Dictionary = row
		_rank_table.add_item("%2d  %-28s pts %-4s %s-%s-%s  win %.0f%%  hp %+.3f  rating %s" % [
				int(r.get("rank", 0)), str(r.get("label", "?")), str(r.get("points", "?")),
				str(r.get("ep_wins", 0)), str(r.get("ep_draws", 0)), str(r.get("ep_losses", 0)),
				float(r.get("win_rate", 0.0)) * 100.0, float(r.get("hp_margin", 0.0)),
				str(r.get("rating", "?"))])
		_rank_table.set_item_metadata(_rank_table.item_count - 1, str(r.get("id", "")))

# Runs in the SELECTED trainee's build unless 'every arena' is ticked: one body
# is the cheap reading, every body is the fair one.
func _ladder_args() -> String:
	var args := "ladder --episodes %d --jobs %d --speed %s" % [
			int(_rank_eps.value), int(_jobs.value), _speed_spec()]
	if _rank_all_arenas.button_pressed:
		args += " --all-arenas"
	else:
		var build := _selected_build()
		if build != "":
			args += " --arena %s" % _sq(build)
	if _rank_deployed.button_pressed:
		args += " --deployed-only"
	return args

func _rank_run() -> void:
	if _pid > 0: return
	_spawn_league(_ladder_args(), "ladder", "ladder")

# Ricardo, 2026-09-14: the cockpit is "bloated and overflowing". It was, and
# SIDEWAYS — the axis the first layout gate never looked at. A Label does not
# wrap by default, so its minimum width is the whole string; that minimum
# propagates up through the tab, the TabContainer and the root HBox, and the
# cockpit ends up 1,984 px wide on a 1,440 px canvas. Every explanatory line in
# here is a sentence, so wrapping is the default now and a caller opts OUT for
# the few places a wrap would be wrong (a cell in a fixed grid).
func _label(text: String, color: Color, size := ProtoTheme.SIZE_BODY,
		wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# a wrapping Label still reports its longest WORD as a minimum width;
		# without this a long path or build id would push the column open again
		l.custom_minimum_size = Vector2(1, 0)
		# R60 (2026-09-22): clip_text is NOT how you hold that width, and it cost
		# us every caption in the cockpit. Measured on 4.6 with a 236 px column:
		#     autowrap + clip_text  -> minimum (1, 1)    rect 264x1   INVISIBLE
		#     autowrap, no clip     -> minimum (1, 23)   rect 264x23  correct
		#     no autowrap           -> minimum (264, 23)
		# Label::get_minimum_size collapses the HEIGHT to 1 as well when the text
		# is clipped, and a VBoxContainer hands a non-expanding child exactly its
		# minimum — so "trainee", "key", "opponents", gens/pop/eps/jobs, "speed",
		# "net" and both chart headings were all drawn 1 px tall. Ricardo:
		# "the arena console lost its value labels". Autowrap ALONE already
		# reports a minimum width of 1, which is the whole reason clip_text was
		# reached for, so dropping it keeps the 2026-09-14 overflow fix intact.
		# PREVIOUS: l.clip_text = true
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
				"macs": _grouped(macs), "note": str(spec.get("note", ""))})
	return fallback if out.is_empty() else out

# "" for the deployed shape — train_run.sh then passes no --net at all, so a
# default run's command line is exactly what it was before this existed.
func _net_spec() -> String:
	if _net == null or _net.selected < 0:
		return ""
	var name := str(_net.get_item_metadata(_net.selected))
	return "" if name == "default" else name

func _spin(parent: Container, text: String, lo: int, hi: int, val: int) -> SpinBox:
	# gens/pop/eps/jobs live in a 4-column grid: no wrap, or the caption column
	# collapses to a single letter per row (R60).
	parent.add_child(_label(text, DIM, ProtoTheme.SIZE_BODY, false))
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
	# grandchild of the bash we hold, out of Stop's reach.
	# R56 (2026-09-21): `setsid` in front of it puts the trainer in a NEW session,
	# so its process group contains the trainer and every descendant it will ever
	# spawn — the headless godot workers today, anything nested tomorrow — and
	# NOTHING of ours. Without it the trainer inherits Godot's own group and Stop
	# can only reach one generation (`pkill -P`), which is why a killed run could
	# leave workers holding the card. setsid execs in place when the caller is not
	# already a group leader, so the pid we track is still python's.
	var cmd := "cd %s && exec setsid python3 -m ml.training.league %s >> %s 2>&1" % [
			_sq(_repo), args, _sq(_repo.path_join(_log_rel(key)))]
	_pid = OS.create_process("bash", ["-lc", cmd])
	_pgid = -1
	if _pid <= 0:
		_pid = -1
		_proc_note = "could not spawn bash (OS.create_process failed)"
	else:
		_pid_kind = kind
		_proc_note = "%s started · pid %d · log %s" % [kind, _pid, _log_rel(key)]
	_cmd_label.text = "python3 -m ml.training.league " + args
	_refresh_ui()

func _train() -> void:
	if _pid > 0: return
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
	# Every creature, own registry. Plain: --all is the ES sweep (PPO requires a
	# chosen matchup). Ticked 'bracket': --tournament --all, so each creature's
	# methods compete and only the winner takes that creature's pin.
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

# R56. Read the tracked trainer's process group ONCE, and accept it only when it
# equals the pid — i.e. when the process is its own group leader, which is what
# `setsid` guarantees and what makes a group kill provably ours. Any other value
# means setsid did not take (it forks when the caller is already a leader, and
# some environments have no setsid at all); we then leave _pgid at -1 and Stop
# falls back to the old one-generation reap rather than signalling a group that
# may contain the editor.
func _resolve_pgid() -> void:
	var out: Array = []
	if OS.execute("bash", ["-lc", "ps -o pgid= -p %d" % _pid], out) != 0:
		return
	var text := "" if out.is_empty() else str(out[0]).strip_edges()
	if not text.is_valid_int():
		return
	var group := int(text)
	_pgid = group if group == _pid else -1

# Kill whatever is left of the trainer's group. Returns true if anything was
# still alive — `kill -0 -PGID` succeeds only while the group has a member.
func _reap_group() -> bool:
	if _pgid <= 0 or _pgid != _pid:
		return false
	var out: Array = []
	var alive := OS.execute("bash", ["-lc", "kill -0 -%d 2>/dev/null" % _pgid], out) == 0
	if alive:
		OS.execute("bash", ["-lc", "kill -KILL -%d 2>/dev/null" % _pgid], out)
	return alive

func _stop() -> void:
	if _pid <= 0:
		return
	if _pgid <= 0:
		_resolve_pgid()
	# freeze the trainer so it spawns nothing more, take its headless godot
	# workers with it (a lone SIGKILL would orphan one until its match times out),
	# then kill it.
	# R56: when we own the group (setsid worked), STOP and KILL the whole GROUP —
	# `-PGID` — instead of one generation of children. `pkill -KILL -P` reached
	# only the trainer's direct children, so anything spawned one level deeper
	# survived holding the card. The fallback below is the old behaviour, used
	# only when we could not prove the group is ours.
	if _pgid == _pid:
		OS.execute("bash", ["-lc", "kill -STOP -%d 2>/dev/null; kill -KILL -%d 2>/dev/null" % [
				_pgid, _pgid]])
	else:
		OS.execute("bash", ["-lc", "kill -STOP %d; pkill -KILL -P %d; kill -KILL %d" % [
				_pid, _pid, _pid]])
		OS.kill(_pid)
	_proc_note = "%s stopped (pid %d)" % [_pid_kind, _pid]
	_pid = -1
	_pgid = -1
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
	_arena_window(build, opp, spec, "", 1, _proc_note)

# Every watch route goes through here. It was inlined in _watch(), which is why
# only ONE shape was ever watchable: the selected key's latest net against an
# opponent BUILD, for a single episode, with no --policy-b. Ricardo,
# 2026-09-14: "in the console arena I can't watch the best of N showdowns when
# testing nets!" — a showdown needs BOTH sides' policies and the whole set.
func _arena_window(a_build: String, b_build: String, pol_a: String, pol_b: String,
		episodes: int, note: String) -> void:
	if a_build == "":
		_proc_note = "no build to fight in"
		_refresh_ui()
		return
	# the running binary: same Godot as this console, no PATH dependency
	var exe := OS.get_executable_path()
	if exe == "":
		exe = "godot"
	var argv := ["--path", _repo.path_join("game"), "res://arena/arena.tscn", "--",
			"--a", a_build, "--b", b_build if b_build != "" else a_build,
			"--episodes", str(maxi(episodes, 1)), "--spectate"]
	if pol_a != "":
		argv.append_array(["--policy-a", pol_a])
	if pol_b != "":
		argv.append_array(["--policy-b", pol_b])
	var pid := OS.create_process(exe, argv)
	_proc_note = note if pid > 0 else "could not spawn the arena window"
	_refresh_ui()

# WATCH from the VERSUS tab: the exact pairing RUN BEST-OF-N would play, for the
# whole set (best_of rounds x episodes per round), both policies attached.
func _versus_watch() -> void:
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
	var eps := int(_vs_best_of.value) * int(_vs_eps.value)
	_arena_window(a_build, b_build, str(_vs_a.get("spec", "")), str(_vs_b.get("spec", "")),
			eps, "watching %s vs %s — best of %d x %d episodes — [Q] closes the arena window" % [
			str(_vs_a.get("label", "A")), str(_vs_b.get("label", "B")),
			int(_vs_best_of.value), int(_vs_eps.value)])

# WATCH a verdict that ALREADY RAN, from the history list. Every schema stores
# enough to replay it: a versus verdict carries both sides' spec+build, and a
# bracket row carries `out` — the path of the versus verdict that decided it.
func _verdict_watch() -> void:
	if _last_verdict.is_empty():
		_proc_note = "pick a verdict in HISTORY first"
		_refresh_ui()
		return
	var v := _replayable(_last_verdict, 0)
	if v.is_empty():
		_proc_note = "%s verdicts do not record a single pairing to replay" % \
				_verdict_kind(_last_verdict)
		_refresh_ui()
		return
	var a: Dictionary = v.get("a", {})
	var b: Dictionary = v.get("b", {})
	var a_build := str(a.get("build", ""))
	var eps := int(v.get("best_of", 1)) * int(v.get("episodes_per_round", 1))
	_arena_window(a_build, str(b.get("build", a_build)), str(a.get("spec", "")),
			str(b.get("spec", "")), eps,
			"replaying %s vs %s — best of %d — [Q] closes the arena window" % [
			str(a.get("label", "A")), str(b.get("label", "B")), int(v.get("best_of", 1))])

# A versus verdict replays itself; a bracket points at the versus verdict that
# decided it. `depth` stops a malformed `out` chain from recursing forever.
func _replayable(v: Dictionary, depth: int) -> Dictionary:
	if depth > 3:
		return {}
	match _verdict_kind(v):
		"versus":
			return v
		"tournament":
			var br: Array = v.get("bracket", [])
			if br.is_empty():
				return {}
			var out := str((br[br.size() - 1] as Dictionary).get("out", ""))
			if out == "" or not FileAccess.file_exists(out):
				return {}
			var f := FileAccess.open(out, FileAccess.READ)
			if f == null:
				return {}
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				return _replayable(parsed as Dictionary, depth + 1)
	return {}

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

# R60 (Ricardo, 2026-09-21): "the interface must be legible at 20 M-step values."
# Two formats, because the two kinds of number want different things:
#
#   _grouped  exact counts you COMPARE — match 512,488/1,022,976, 7,744 MACs.
#             Every digit is kept; the separator only breaks up the run.
#   _si       budgets you SET — 500k steps, 20M steps. Three significant digits
#             is all anyone reads off a knob, and "20M" fits where "20000000"
#             wrecks a tooltip's line breaks.
#
# Neither ever touches a command line: --steps takes the integer, and a run-dir
# name stays machine-parseable. These are for human eyes only.
static func _grouped(n: int) -> String:
	var neg := n < 0
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out

static func _si(n: int) -> String:
	var a := absi(n)
	if a < 1000:
		return str(n)
	var sign := "-" if n < 0 else ""
	for step in [[1000000000, "G"], [1000000, "M"], [1000, "k"]]:
		var unit := int(step[0])
		if a >= unit:
			var v := float(a) / float(unit)
			# 3 significant digits: 20M, 1.5M, 999k — never "20.0M"
			var text := ("%.0f" % v) if v >= 100.0 else \
					(("%.1f" % v) if v >= 10.0 else ("%.2f" % v))
			if text.contains("."):
				text = text.rstrip("0").rstrip(".")
			return "%s%s%s" % [sign, text, str(step[1])]
	return str(n)

# ---- status text --------------------------------------------------------------------------

func _refresh_ui() -> void:
	_refresh_tabs()
	var running := _pid > 0
	_train_btn.disabled = running
	_train_all_btn.disabled = running
	if _bracket != null:
		# the label is the only place the two gears are visible at a glance
		_train_all_btn.text = "TRAIN ALL ⚔" if _bracket.button_pressed else "TRAIN ALL"
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
	# R60: at 999 gens x 256 pop x 4 opponents this line reads "match 512488/1022976";
	# grouped it is a number a human can check against the ETA.
	lines.append("gen %d/%d · cand %d/%d · match %s/%s" % [
			g_disp, gtot, int(_run.cur_cand) + 1, pop, _grouped(done), _grouped(total)])
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
	if _sweep_label != null:
		var sweep_line := _sweep_status()
		_sweep_label.text = sweep_line
		_sweep_label.visible = sweep_line != ""
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
			# Ricardo, 2026-09-14: "in the arena interface, can we get a little
			# polishing to better fit everything in there". This line was already
			# the longest thing on the tab at four checks — "GATE v6: FAIL —
			# previous pin stays · suite_scripted FAIL wr 0.00 · ..." — and the
			# statue/heuristic controls added two more. So it is COMPACTED rather
			# than allowed to grow: the suite_/control_ prefixes carry no
			# information a reader needs, and a failed sanity check is a property
			# of its suite rather than a row of its own.
			for name in checks:
				var c: Variant = checks[name]
				if not (c is Dictionary) or str(name).ends_with("_sanity"):
					continue
				var short := str(name).trim_prefix("suite_").trim_prefix("control_")
				short = short.replace("ladder_vs_deployed", "ladder")
				var bit := ""
				if bool(c.get("reported_only", false)):
					bit = short                     # a yardstick has no verdict
				else:
					bit = "%s %s" % [short, "✓" if bool(c.get("pass", false)) else "✗"]
				if c.has("win_rate"):
					bit += " %.2f" % float(c.win_rate)
				# the suite's own sanity check rides along as a marker
				var sanity: Variant = checks.get("%s_sanity" % str(name), null)
				if sanity is Dictionary and not bool(sanity.get("pass", true)):
					bit += " ⚠"
				parts.append(bit)
		_gate_label.text = "GATE v%d: %s%s" % [int(gate.get("version", 0)),
				"PASS — deployed" if passed else "FAIL — pin stays",
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
	if _rank_btn != null:
		_rank_btn.disabled = _pid > 0
	if _vs_result != null and not _last_verdict.is_empty():
		_vs_result.text = _verdict_detail(_last_verdict)

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
	# The x-tick row lives BELOW b, so b has to leave room for a whole line of
	# text — ascent and descent. It used to be a flat sz.y - 14 with the baseline
	# at b + 12, which put the descenders past the bottom edge (measured: 1 px at
	# SIZE_BODY, and more the moment the theme font changes).
	var line_h := font.get_ascent(ProtoTheme.SIZE_BODY) + font.get_descent(ProtoTheme.SIZE_BODY)
	var b := sz.y - line_h - 3.0
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
	# grid + y ticks. The label step is chosen so the rows cannot collide: a run
	# whose fitness shaping runs to -3 used to draw eighteen 0.25 labels into a
	# 96 px band, which is a grey smear, not an axis.
	var band := maxf(b - t, 1.0)
	var v_step := 0.25
	for candidate_step in [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 25.0]:
		v_step = candidate_step
		if (hi - lo) / v_step * (line_h + 2.0) <= band:
			break
	var v := ceilf(lo / v_step) * v_step
	while v <= hi + 0.001:
		var y := _px(yf.call(v))
		c.draw_line(Vector2(_px(l), y), Vector2(_px(r), y), Color(0.14, 0.19, 0.25), 1.0)
		c.draw_string(font, Vector2(2, y + 3), "%.2f" % v, HORIZONTAL_ALIGNMENT_RIGHT,
				int(l) - 6, ProtoTheme.SIZE_BODY, DIM)
		v += v_step
	# x ticks (thin out so the labels never touch: ~26 px each at body size)
	var per_label := font.get_string_size("g000", HORIZONTAL_ALIGNMENT_LEFT, -1,
			ProtoTheme.SIZE_BODY).x + 6.0
	var fit_n := maxi(2, int((r - l) / maxf(per_label, 1.0)))
	var step := maxi(1, ceili((gmax + 1) / float(fit_n)))
	for g in range(0, gmax + 1, step):
		var x := _px(xf.call(float(g)))
		c.draw_line(Vector2(x, _px(b)), Vector2(x, _px(b) + 2), ProtoTheme.PANEL_BORDER, 1.0)
		c.draw_string(font, Vector2(x - 12, b + font.get_ascent(ProtoTheme.SIZE_BODY) + 2),
				"g%d" % g, HORIZONTAL_ALIGNMENT_CENTER, 24, ProtoTheme.SIZE_BODY, DIM)
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
	# measured stride, not a flat 34 px: a theme font change must not push "cand"
	# off the plot the way the strip's flat 120 px pushed an opponent off (R60).
	var lx := l + 6.0
	for entry in [["best", EMBER], ["mean", CYAN], ["cand", Color(CYAN.r, CYAN.g, CYAN.b, 0.45)]]:
		var text := str(entry[0])
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				ProtoTheme.SIZE_BODY).x + 7.0
		if lx + w > r:
			break
		c.draw_rect(Rect2(lx, t + 2, 4, 4), entry[1])
		c.draw_string(font, Vector2(lx + 7, t + 8), text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, ProtoTheme.SIZE_BODY, DIM)
		lx += w + 10.0

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
	# R60 (2026-09-22): the legend used to step a flat 120 px per opponent and
	# draw whatever came next, so a four-opponent run ran off the right edge —
	# Ricardo's capture ends mid-word on "round 4 1.". Measure each entry, stop
	# at the edge, and say how many did not fit instead of half-drawing one.
	var lx := l + 6.0
	var drawn := 0
	var entries: Array = cols.keys()
	for opp in entries:
		var text := "%s %.2f" % [opp, float(sums[opp]) / float(maxi(int(counts[opp]), 1))]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				ProtoTheme.SIZE_BODY).x + 7.0
		var left_over := entries.size() - drawn
		# reserve room for "+N" whenever anything would be left behind
		var reserve := 0.0 if left_over <= 1 else font.get_string_size(
				"+%d" % (left_over - 1), HORIZONTAL_ALIGNMENT_LEFT, -1,
				ProtoTheme.SIZE_BODY).x + 8.0
		if lx + w + reserve > r and drawn > 0:
			c.draw_string(font, Vector2(lx, 8), "+%d" % left_over,
					HORIZONTAL_ALIGNMENT_LEFT, -1, ProtoTheme.SIZE_BODY, DIM)
			break
		c.draw_rect(Rect2(lx, 2, 4, 4), cols[opp])
		c.draw_string(font, Vector2(lx + 7, 8), text, HORIZONTAL_ALIGNMENT_LEFT,
				int(maxf(r - lx - 7.0, 1.0)), ProtoTheme.SIZE_BODY, DIM)
		lx += w + 10.0
		drawn += 1

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
	# Opening a MULTI-KEY run folder arms the sweep totals too, so a finished or
	# resumed sweep reads the same as a live one instead of showing one creature
	# and no idea how much of the run it was.
	var run_dir := _runs_root.path_join(run)
	var cfg := _read_json(run_dir.path_join("config.json"))
	if (cfg.get("keys", []) as Array).size() > 1:
		_sweep_arm(run_dir)
		_sweep_scan()
	else:
		_sweep_arm("")
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

# ---- the benchmark browser (ml/data/benchmarks/) ------------------------------------
#
# Two schemas live in that folder and they answer different questions:
#   arena.versus.v1      one net against one other, best-of-N   (`league versus`)
#   arena.tournament.v1  a whole bracket for ONE creature       (`tournament.py`)
# The old list rendered both through the versus fields, so every bracket read
# "? vs ?  0-0  ?". Now each schema gets its own row, and the folder is filtered
# by creature — Ricardo, 2026-09-14: "a better benchmark interface, filtered by
# creature".

# Which creature(s) a verdict is ABOUT. A bracket says so outright; a head to
# head has to be read off both sides — the registry spec ("bog_golem@v2") when
# there is one, and the arena build either side played otherwise, which is what
# makes a baseline row (native/scripted) filterable at all.
func _verdict_keys(v: Dictionary) -> Array:
	var keys: Array = []
	var add := func(k: String) -> void:
		if k != "" and not keys.has(k):
			keys.append(k)
	if str(v.get("key", "")) != "":
		add.call(str(v.get("key", "")))
	# R60: a distill/parity record names its creature in `build`, never in a
	# top-level `key` shaped like the versus records — without this they were
	# reachable only under "all creatures" and vanished the moment you filtered.
	if str(v.get("build", "")) != "":
		add.call(str(v.get("build", "")).get_slice(".", 2))
	for e in (v.get("entrants", []) if v.get("entrants", []) is Array else []):
		add.call(str((e as Dictionary).get("key", "")))   # a ladder: every entrant's creature
	for a in (v.get("arenas", []) if v.get("arenas", []) is Array else []):
		add.call(str(a).get_slice(".", 2))                # and every body it was fought in
	for side in ["a", "b"]:
		var s: Dictionary = v.get(side, {})
		if s.is_empty():
			continue
		var spec := str(s.get("spec", ""))
		if spec.contains("@"):
			add.call(spec.get_slice("@", 0))
		add.call(str(s.get("build", "")).get_slice(".", 2))
	add.call(str(v.get("build", "")).get_slice(".", 2))
	return keys

func _verdict_kind(v: Dictionary) -> String:
	var schema := str(v.get("schema", ""))
	if schema.begins_with("arena.tournament"):
		return "tournament"
	if schema.begins_with("arena.versus"):
		return "versus"
	if schema.begins_with("arena.ladder"):
		return "ladder"
	# R60 (2026-09-22): these two used to fall through to "other", and "other"
	# is rendered by the head-to-head branch below — so every distill and every
	# env-parity run in the folder drew as "? vs ?  0-0  ?" in the HISTORY list.
	# 9 of the 31 records on disk were unreadable that way.
	if schema.begins_with("arena.distill"):
		return "distill"
	if schema.begins_with("arena.env_parity"):
		return "parity"
	return "other"

# "2026-09-14_004448__tournament__bog_golem.json" -> "09-14 00:44". The name is
# DATE FIRST by construction (league.versus/tournament both stamp it), so the
# folder sorts chronologically and this only has to make it readable.
func _verdict_when(name: String, v: Dictionary, mtime: int) -> String:
	# R60: this used to slice blindly and return "" when it could not. Both
	# failures were on screen: "env_parity_fen_boar_scripted.json" produced the
	# nonsense stamp "arity fe:n_", and "console_20260914_044035.json" produced
	# an empty one, so its row began with two stray spaces. A name that is not
	# DATE_TIME__* is not a bug in the file — league.versus stamps its own, but
	# a hand-run parity check or an older console write need not. Fall back to
	# what the record says about itself, then to the file's mtime; there is
	# always a real time available, so no row has to invent one.
	if name.length() >= 17 and name[10] == "_" and name.substr(0, 4).is_valid_int():
		return "%s %s:%s" % [name.substr(5, 5), name.substr(11, 2), name.substr(13, 2)]
	var iso := str(v.get("started", v.get("finished", "")))
	if iso.length() >= 16 and iso[10] == "T":
		return "%s %s" % [iso.substr(5, 5), iso.substr(11, 5)]
	if mtime > 0:
		var d := Time.get_datetime_dict_from_unix_time(mtime)
		return "%02d-%02d %02d:%02d" % [int(d.month), int(d.day), int(d.hour), int(d.minute)]
	return "  ?  "

# The same resolution as _verdict_when, as an epoch, so HISTORY can sort by it.
# It used to sort on the FILENAME, which is only chronological while every
# writer stamps a date first — "env_parity_fen_boar_scripted.json" and
# "console_20260914_044035.json" both sorted above every 2026-* record and the
# list's own header ("newest first") was untrue (R60).
func _verdict_at(name: String, v: Dictionary, mtime: int) -> int:
	if name.length() >= 17 and name[10] == "_" and name.substr(0, 4).is_valid_int():
		var stamp := "%sT%s:%s:%s" % [name.substr(0, 10), name.substr(11, 2),
				name.substr(13, 2), name.substr(15, 2)]
		var at := int(Time.get_unix_time_from_datetime_string(stamp))
		if at > 0:
			return at
	var iso := str(v.get("started", v.get("finished", "")))
	if iso.length() >= 16 and iso[10] == "T":
		return int(Time.get_unix_time_from_datetime_string(iso))
	return mtime

func _verdict_row(e: Dictionary) -> String:
	var v: Dictionary = e.verdict
	if str(e.kind) == "ladder":
		return "%s  ★ global rank  %d entrants · %d arena(s)  champion %s" % [
				str(e.when), (v.get("entrants", []) as Array).size(),
				(v.get("arenas", []) as Array).size(), str(v.get("champion", "?"))]
	if str(e.kind) == "tournament":
		var pinned := "v%s pinned" % str(v.get("winner_version", "?")) if bool(v.get("deployed", false)) \
				else "no pin moved"
		return "%s  ⚔ %s  %s  champion %s · %s" % [
				str(e.when), str(v.get("key", "?")),
				"[" + ",".join(_as_strings(v.get("methods", []))) + "]",
				str(v.get("champion", "?")), pinned]
	if str(e.kind) == "distill":
		var q: Dictionary = v.get("qualify", {})
		var checks: Dictionary = q.get("checks", {})
		var scores: PackedStringArray = []
		for side in ["native", "scripted"]:
			if checks.has(side):
				scores.append("%s %s" % [side, str((checks[side] as Dictionary).get("rounds", "?"))])
		return "%s  ⚗ %s  %s → %s  %s%s" % [
				str(e.when), str(v.get("key", "?")),
				str((v.get("teacher", {}) as Dictionary).get("label", "?")),
				_arch_label(v.get("student", {})),
				"GATE PASS" if bool(q.get("passed", false)) else "gate fail",
				("  ·  " + " · ".join(scores)) if not scores.is_empty() else ""]
	if str(e.kind) == "parity":
		return "%s  ⇄ parity  %s vs %s  worst gap %.2f (tol %.2f)  %s" % [
				str(e.when), str(v.get("build", "?")).get_slice(".", 2),
				str(v.get("opponent", "?")), float(v.get("worst", 0.0)),
				float(v.get("tolerance", 0.0)),
				"AGREE" if bool(v.get("agree", false)) else "DISAGREE"]
	var a: Dictionary = v.get("a", {})
	var b: Dictionary = v.get("b", {})
	return "%s  %s vs %s  %d-%d  %s" % [
			str(e.when), str(a.get("label", "?")), str(b.get("label", "?")),
			int(v.get("rounds_a", 0)), int(v.get("rounds_b", 0)),
			str(v.get("winner", "?")).to_upper()]

# "[64, 64] tanh" for a net that records its shape, "heuristic" for one that has
# none. Shared by the distill row and the distill detail so they cannot drift.
func _arch_label(raw: Variant) -> String:
	if not (raw is Dictionary):
		return "?"
	var d: Dictionary = raw
	var hidden: Array = d.get("hidden", [])
	if hidden.is_empty():
		return str(d.get("label", d.get("spec", "scripted")))
	var dims: PackedStringArray = []
	for h in hidden:
		dims.append(str(int(h)))
	var act := str((d.get("arch", {}) as Dictionary).get("activation", ""))
	return "[%s]%s" % [",".join(dims), (" " + act) if act != "" else ""]

func _as_strings(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for x in (raw as Array):
			out.append(str(x))
	return out

# Re-read only what changed: the folder grows for the life of the project and a
# filter click must not cost a full re-parse of it.
func _scan_bench() -> void:
	var seen := {}
	var d := DirAccess.open(_bench_root)
	if d != null:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			if not d.current_is_dir() and n.ends_with(".json"):
				seen[n] = FileAccess.get_modified_time(_bench_root.path_join(n))
			n = d.get_next()
		d.list_dir_end()
	var kept: Array = []
	for e in _bench:
		if seen.has(str(e.name)) and _bench_stamp.get(str(e.name), -1) == seen[str(e.name)]:
			kept.append(e)
			seen.erase(str(e.name))
	for name in seen.keys():
		var v := _read_json(_bench_root.path_join(str(name)))
		if v.is_empty():
			continue                        # still being written — it will appear next poll
		var entry := {"name": str(name), "verdict": v, "kind": _verdict_kind(v),
				"keys": _verdict_keys(v), "when": _verdict_when(str(name), v, int(seen[name])),
				"at": _verdict_at(str(name), v, int(seen[name]))}
		entry["text"] = _verdict_row(entry)
		kept.append(entry)
		_bench_stamp[str(name)] = seen[name]
	kept.sort_custom(func(x, y) -> bool:
		if int(x.at) != int(y.at):
			return int(x.at) > int(y.at)
		return str(x.name) > str(y.name))     # same second: keep it deterministic
	_bench = kept

func _bench_entry(name: String) -> Dictionary:
	for e in _bench:
		if str(e.name) == name:
			return e
	return {}

func _refresh_history() -> void:
	if _vs_history == null:
		return
	_scan_bench()
	# the creature dropdown is built FROM the folder: a key nothing was ever
	# benchmarked against must not be offered as a filter that shows nothing
	var counts := {}
	for e in _bench:
		for k in (e.keys as Array):
			counts[k] = int(counts.get(k, 0)) + 1
	var names: Array = counts.keys()
	names.sort()
	var want := _filter_key()
	if _vs_filter != null:
		_vs_filter.clear()
		_vs_filter.add_item("all creatures (%d)" % _bench.size())
		_vs_filter.set_item_metadata(0, "")
		for k in names:
			_vs_filter.add_item("%s (%d)" % [str(k), int(counts[k])])
			_vs_filter.set_item_metadata(_vs_filter.item_count - 1, str(k))
			if str(k) == want:
				_vs_filter.select(_vs_filter.item_count - 1)
		if want == "" or not names.has(want):
			_vs_filter.select(0)
	want = _filter_key()
	var kind := str(_vs_kind.get_item_metadata(_vs_kind.selected)) if _vs_kind != null \
			and _vs_kind.selected >= 0 else ""
	_vs_history.clear()
	for e in _bench:
		if want != "" and not (e.keys as Array).has(want):
			continue
		if kind != "" and str(e.kind) != kind:
			continue
		_vs_history.add_item(str(e.text))
		_vs_history.set_item_metadata(_vs_history.item_count - 1, str(e.name))
	if _vs_count != null:
		_vs_count.text = "%d of %d" % [_vs_history.item_count, _bench.size()]
	_refresh_rank()

# The panel above the list: whatever verdict is in focus, run just now or picked
# out of the history. A bracket is not a head to head and must not be rendered
# as one — it has entrants, a champion, and a pin that may or may not have moved.
func _verdict_detail(v: Dictionary) -> String:
	if _verdict_kind(v) == "ladder":
		var arenas: PackedStringArray = []
		for a in _as_strings(v.get("arenas", [])):
			arenas.append(str(a).get_slice(".", 2))
		var out: PackedStringArray = ["★ global rank — %d entrants · %d pairings · arena %s · %ss" % [
				(v.get("entrants", []) as Array).size(),
				(v.get("pairings", []) as Array).size(),
				", ".join(arenas), str(v.get("wall_s", "?"))]]
		for row in (v.get("table", []) if v.get("table", []) is Array else []):
			var t: Dictionary = row
			if int(t.get("rank", 0)) > 4:
				out.append("   ... %d more — the RANK tab has the whole table"
						% ((v.get("table", []) as Array).size() - 4))
				break
			out.append("   %d. %s  pts %s · win %s · rating %s" % [
					int(t.get("rank", 0)), str(t.get("label", "?")), str(t.get("points", "?")),
					str(t.get("win_rate", "?")), str(t.get("rating", "?"))])
		return "\n".join(out)
	if _verdict_kind(v) == "tournament":
		var lines: PackedStringArray = []
		lines.append("⚔ %s — %s · champion %s · %s" % [
				str(v.get("key", "?")), "[" + ",".join(_as_strings(v.get("methods", []))) + "]",
				str(v.get("champion", "?")),
				("v%s took the pin" % str(v.get("winner_version", "?"))) if bool(v.get("deployed", false))
						else "no pin moved — nobody passed the gate"])
		lines.append("best of %d · %d episode(s)/round · gate %d · %ss" % [
				int(v.get("best_of", 0)), int(v.get("bracket_episodes", 0)),
				int(v.get("gate_episodes", 0)), str(v.get("wall_s", "?"))])
		for row in (v.get("table", []) if v.get("table", []) is Array else []):
			var r: Dictionary = row
			lines.append("   %-7s %-9s pts %s · rounds %s · ep win %s · %s" % [
					str(r.get("method", "?")), str(r.get("label", "")),
					str(r.get("points", "?")), str(r.get("rounds_won", "?")),
					str(r.get("episode_win_rate", "?")),
					"gate PASS" if bool(r.get("gate_pass", false)) else "gate fail"])
		return "\n".join(lines)
	# R60: same blind spot as _verdict_row had — clicking a distill or a parity
	# row in HISTORY fell into the head-to-head branch below and filled the
	# panel with "? vs ?  0-0  WINNER: ?". Neither record is a head to head:
	# a distill is a teacher against the student it trained, a parity run is the
	# SAME policy measured in two runtimes and only the gaps matter.
	if _verdict_kind(v) == "distill":
		var q: Dictionary = v.get("qualify", {})
		var out: PackedStringArray = ["⚗ distill %s — %s → %s · %s" % [
				str(v.get("key", "?")),
				str((v.get("teacher", {}) as Dictionary).get("label", "?")),
				_arch_label(v.get("student", {})),
				("QUALIFIED (margin %s)" % str(q.get("margin", "?"))) if bool(q.get("passed", false))
						else ("did not qualify — margin %s" % str(q.get("margin", "?")))]]
		out.append("arena %s · %d round(s) recorded" % [
				str(v.get("build", "?")).get_slice(".", 2),
				(v.get("rounds", []) as Array).size()])
		var checks: Dictionary = q.get("checks", {})
		for side in checks.keys():
			var c: Dictionary = checks[side]
			out.append("   vs %-9s rounds %s · ep win %s · %s" % [
					str(side), str(c.get("rounds", "?")), str(c.get("episode_win_rate", "?")),
					"PASS" if bool(c.get("passed", false)) else "fail"])
		return "\n".join(out)
	if _verdict_kind(v) == "parity":
		var gaps: Dictionary = v.get("gaps", {})
		var pv: PackedStringArray = ["⇄ env parity %s vs %s — %d episodes, seed %s" % [
				str(v.get("build", "?")).get_slice(".", 2), str(v.get("opponent", "?")),
				int(v.get("episodes", 0)), str(v.get("seed", "?"))]]
		pv.append("worst gap %s against a tolerance of %s — %s" % [
				str(v.get("worst", "?")), str(v.get("tolerance", "?")),
				"the runtimes AGREE" if bool(v.get("agree", false))
						else "the runtimes DISAGREE — dh-env and the arena are not the same game"])
		var de: Dictionary = v.get("dh_env", {})
		var ar: Dictionary = v.get("arena", {})
		for metric in ["win_rate", "hp_self", "hp_foe"]:
			pv.append("   %-8s dh-env %6.3f · arena %6.3f · gap %s" % [
					metric, float(de.get(metric, 0.0)), float(ar.get(metric, 0.0)),
					str(gaps.get(metric, "?"))])
		return "\n".join(pv)
	var a: Dictionary = v.get("a", {})
	var b: Dictionary = v.get("b", {})
	var clinch: Variant = v.get("clinched_round", null)
	return "%s  %d-%d  %s\nbest of %d · %d episodes/round · %ss\n%s" % [
			"%s vs %s" % [str(a.get("label", "?")), str(b.get("label", "?"))],
			int(v.get("rounds_a", 0)), int(v.get("rounds_b", 0)),
			"WINNER: " + str(v.get("winner", "?")).to_upper(),
			int(v.get("best_of", 0)), int(v.get("episodes_per_round", 0)),
			str(v.get("wall_s", "?")),
			("clinched in round %s" % str(clinch)) if clinch != null else "no clinch — split decision"]

func _filter_key() -> String:
	if _vs_filter == null or _vs_filter.selected < 0:
		return ""
	return str(_vs_filter.get_item_metadata(_vs_filter.selected))

# ---- isolated / GPU training (tools/train_run.sh) -----------------------------------------

# The console's own run folder name: DATE FIRST so ml/runs/ sorts by time, and
# --run-dir hands it to the script so we know where to tail from.
func _console_run_dir(key: String, all_creatures := false) -> String:
	var t := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d%02d" % [t.year, t.month, t.day, t.hour, t.minute]
	var knobs := ("steps%d_envs%d" % [GPU_PPO_STEPS, GPU_PPO_ENVS]) if _gpu.button_pressed and not all_creatures \
			else ("g%d_p%d_e%d_j%d" % [int(_gens.value), int(_pop.value),
					int(_eps.value), int(_jobs.value)])
	# Distinct directories even for two clicks in the same minute: never silently
	# replace an earlier experiment's configuration/registry.
	return RUNS_DIR.path_join("%s%02d-%d__%s-console__%s" % [stamp, t.second, Time.get_ticks_usec(), key, knobs])

func _spawn_train_run(key: String, build: String, all_creatures := false) -> void:
	var run_dir := _console_run_dir(key, all_creatures)
	_sweep_arm(_repo.path_join(run_dir) if all_creatures else "")
	var log_path := _repo.path_join(_log_rel(key))
	DirAccess.make_dir_recursive_absolute(_repo.path_join(LOG_DIR))
	var env := ""
	var args := ""
	if _gpu.button_pressed and not all_creatures:
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
		if all_creatures: args = "--all --run-dir %s" % _sq(run_dir)
		var sweep := _sweep_flags(all_creatures)
		env += str(sweep.env)
		args = str(sweep.prefix) + args
	var cmd := "cd %s && exec env %stools/train_run.sh %s >> %s 2>&1" % [
			_sq(_repo), env, args, _sq(log_path)]
	_pid = _launch_training(cmd)
	if _pid <= 0:
		_pid = -1
		_proc_note = "could not spawn tools/train_run.sh"
	else:
		_pid_kind = ("tournament-all" if (_bracket != null and _bracket.button_pressed) else "train-all") \
				if all_creatures else ("ppo" if _gpu.button_pressed else "train")
		_proc_note = "%s started · pid %d · %s" % [_pid_kind, _pid, run_dir]
	# the isolated run writes its progress inside the run folder
	_attach(_repo.path_join(run_dir).path_join("progress").path_join(key + ".jsonl"), 0)
	_cmd_label.text = "env %stools/train_run.sh %s" % [env, args]
	_refresh_runs()
	_refresh_ui()

# TRAIN ALL's two gears, as data: plain is the ES sweep, 'bracket' is
# tools/train_run.sh --tournament (every method trains each creature, the
# candidates fight for that creature's pin). Pure, so the selftest can check the
# dispatch without launching a sweep. A single-creature run never brackets — the
# TOURNAMENT button is that path, and it needs a chosen matchup.
func _sweep_flags(all_creatures: bool) -> Dictionary:
	if not all_creatures or _bracket == null or not _bracket.button_pressed:
		return {"env": "", "prefix": ""}
	return {"env": "METHODS=es,ppo BEST_OF=%d STEPS=%d " % [TOURNEY_BEST_OF, TOURNEY_PPO_STEPS],
			"prefix": "--tournament "}

# Test seam exercises the exact dispatch command without starting a real sweep.
func _launch_training(command: String) -> int:
	return OS.create_process("bash", ["-lc", command])

# ---- the whole sweep ----------------------------------------------------------------
#
# A sweep (TRAIN ALL, or --tournament --all) trains the WHOLE roster, one key at
# a time, into one run folder. The chart and the ETA above it are one key's — so
# the two numbers Ricardo actually wants while a sweep is running, "how far
# through the whole thing am I" and "when does it finish", were nowhere on the
# screen. They are not derivable from the focused feed: they need every key's.
#
# The run folder has them. config.json records the PLANNED key list (that is what
# makes --resume work), and progress/<key>.jsonl is each key's feed. Keys that
# have not started yet have no file, which is exactly why the planned list has to
# come from config.json and not from a directory listing.

func _sweep_arm(run_dir: String) -> void:
	_sweep = {}
	_sweep_keys = []
	_sweep_root = run_dir
	_sweep_progress = "" if run_dir == "" else run_dir.path_join("progress")
	_sweep_load_keys()

# The console names the run folder and spawns train_run.sh, which writes
# config.json a moment later — so the planned roster is NOT there at arm time.
# Keep asking until it is: a denominator that grows as keys start would report
# 100% for the whole sweep.
func _sweep_load_keys() -> void:
	if _sweep_root == "" or not _sweep_keys.is_empty():
		return
	var cfg := _read_json(_sweep_root.path_join("config.json"))
	for pair in cfg.get("keys", []):
		if pair is Array and (pair as Array).size() > 0:
			_sweep_keys.append(str((pair as Array)[0]))

# Incremental: each feed keeps a byte offset and only the new lines are parsed.
# A sweep folder holds one file per creature and this runs every poll.
func _sweep_scan() -> void:
	if _sweep_progress == "":
		return
	_sweep_load_keys()
	var directory := DirAccess.open(_sweep_progress)
	if directory == null:
		return
	for file in directory.get_files():
		if not file.ends_with(".jsonl"):
			continue
		var key := file.get_basename()
		var row: Dictionary = _sweep.get(key, {"off": 0, "total": 0, "g": 0,
				"methods": 0, "mdone": 0, "done": false, "t0": 0.0, "t1": 0.0})
		var f := FileAccess.open(_sweep_progress.path_join(file), FileAccess.READ)
		if f == null:
			continue
		var size := f.get_length()
		if size < int(row.off):        # rewritten (a fresh run in the same folder)
			row = {"off": 0, "total": 0, "g": 0, "methods": 0, "mdone": 0,
					"done": false, "t0": 0.0, "t1": 0.0}
		if size == int(row.off):
			f.close()
			_sweep[key] = row
			continue
		# get_as_text() ignores the cursor and re-reads the WHOLE file, which
		# double-counts every event on the second poll (a 2-method bracket read
		# as 2 of 3 methods done). Read the new BYTES, like _poll_progress does.
		f.seek(int(row.off))
		var bytes := f.get_buffer(size - int(row.off))
		f.close()
		var chunk := bytes.get_string_from_utf8()
		var cut := chunk.rfind("\n")
		if cut < 0:
			_sweep[key] = row          # a partial line: wait for the newline
			continue
		row.off = int(row.off) + chunk.substr(0, cut + 1).to_utf8_buffer().size()
		for line in chunk.substr(0, cut).split("\n"):
			if line.strip_edges() == "":
				continue
			var ev: Variant = JSON.parse_string(line)
			if not (ev is Dictionary):
				continue
			_sweep_apply(row, ev as Dictionary)
		_sweep[key] = row
	if not _sweep_keys.is_empty():
		return
	# a run folder that predates recorded keys: fall back to what is on disk, and
	# say so rather than pretending the denominator is the roster
	for key in _sweep.keys():
		if not _sweep_keys.has(key):
			_sweep_keys.append(str(key))

func _sweep_apply(row: Dictionary, ev: Dictionary) -> void:
	var t := float(ev.get("t", 0.0))
	if t > 0.0:
		if float(row.t0) <= 0.0:
			row.t0 = t
		row.t1 = t
	match str(ev.get("ev", "")):
		"start":
			row.total = int(ev.get("generations", int(row.total)))
		"generation":
			row.g = maxi(int(row.g), int(ev.get("g", 0)) + 1)
		"method_start":
			row.methods = maxi(int(row.methods), int(row.mdone) + 1)
		"method_done":
			row.mdone = int(row.mdone) + 1
			row.methods = maxi(int(row.methods), int(row.mdone))
		"tournament_done":
			row.done = true
		"gate":
			# the ES sweep gates a key right after training it, so a gate verdict
			# is this key's last event — a bracket gates per METHOD, and only
			# tournament_done ends it
			if int(row.methods) == 0:
				row.done = true
		"error":
			row.done = true          # it will not get further on its own

func _sweep_frac(key: String) -> float:
	var row: Dictionary = _sweep.get(key, {})
	if row.is_empty():
		return 0.0
	if bool(row.done):
		return 1.0
	if int(row.methods) > 0:
		# a bracket: entrants finished out of entrants seen, and the running one
		# counts as half so the bar is not frozen for a whole PPO run
		return clampf((float(row.mdone) + 0.5) / maxf(float(row.methods), 1.0), 0.0, 0.99)
	if int(row.total) > 0:
		return clampf(float(row.g) / float(row.total), 0.0, 0.99)
	return 0.0

# Progress over the PLANNED roster, so keys that have not started yet count as
# the zeroes they are. An average over only the files on disk would read 100%
# while six creatures had not been touched.
func _sweep_status() -> String:
	if _sweep_progress == "" or _sweep_keys.is_empty():
		return ""
	var frac := 0.0
	var done := 0
	var current := ""
	for key in _sweep_keys:
		var k := str(key)
		var f := _sweep_frac(k)
		frac += f
		if f >= 1.0:
			done += 1
		elif f > 0.0 and current == "":
			current = k
	frac /= float(_sweep_keys.size())
	var t0 := 0.0
	var t1 := 0.0
	for key in _sweep.keys():
		var row: Dictionary = _sweep[key]
		if float(row.t0) > 0.0 and (t0 <= 0.0 or float(row.t0) < t0):
			t0 = float(row.t0)
		t1 = maxf(t1, float(row.t1))
	var now := Time.get_unix_time_from_system() if _pid > 0 else t1
	# ETA for the WHOLE run: elapsed so far, scaled by how much is left. It needs
	# no per-key model, and it self-corrects as slower creatures pull the average.
	var eta := "ETA —"
	if t0 > 0.0 and frac > 0.02 and frac < 1.0:
		eta = "ETA %s" % _fmt_s((now - t0) * (1.0 - frac) / frac)
	elif frac >= 1.0:
		eta = "ETA done"
	var elapsed := "elapsed %s" % _fmt_s(now - t0) if t0 > 0.0 else "elapsed —"
	var detail := ""
	if current != "":
		var row: Dictionary = _sweep.get(current, {})
		detail = " · now %s %s" % [current,
				("method %d/%d" % [int(row.mdone) + 1, int(row.methods)]) if int(row.methods) > 0
						else ("g%d/%d" % [int(row.g), int(row.total)])]
	return "SWEEP %d/%d keys · %s %.0f%% · %s · %s%s" % [
			done, _sweep_keys.size(), _sweep_bar(frac), frac * 100.0, elapsed, eta, detail]

static func _sweep_bar(frac: float) -> String:
	var cells := 16
	var lit := clampi(int(roundf(frac * cells)), 0, cells)
	return "[" + "#".repeat(lit) + "-".repeat(cells - lit) + "]"

func _follow_sweep() -> void:
	if _sweep_progress == "": return
	var directory := DirAccess.open(_sweep_progress)
	if directory == null: return
	var latest := ""
	var modified := -1
	for file in directory.get_files():
		if not file.ends_with(".jsonl"): continue
		var path := _sweep_progress.path_join(file)
		var stamp := FileAccess.get_modified_time(path)
		if stamp > modified or (stamp == modified and path > latest):
			modified = stamp
			latest = path
	if latest != "" and latest != _tail_path: _attach(latest, 0)

# user:// persists between runs, so a fixture an older selftest left behind can
# fail a later one. Small and deliberate: one level of files, then the folder.
static func _rm_rf(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			_rm_rf(path.path_join(n))
		else:
			d.remove(n)
		n = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(path)

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
	ok = _selftest_watch() and ok
	if ok:
		print("CONSOLE SELFTEST OK — %d generations, %d/%d matches, ETA %s, chart draws %d, hint '%s'" % [
				(_run.gens as Array).size(), int(_run.matches), _total_matches(),
				_fmt_s(_eta_s()), _chart_draws, _hint.text])
	get_tree().quit(0 if ok else 1)

# Watching a best-of-N showdown (Ricardo, 2026-09-14). This gate checks the
# PAIRING RESOLUTION only and never spawns anything: launching an arena window
# from a headless gate is exactly the thing that must not happen. What it
# proves is that a bracket verdict resolves to the versus verdict that decided
# it, and that both sides' policies survive the hop — the old _watch() attached
# --policy-a only, so a net-vs-net showdown was unwatchable.
func _selftest_watch() -> bool:
	var ok := true
	var root := ProjectSettings.globalize_path("user://selftest_watch")
	_rm_rf(root)
	DirAccess.make_dir_recursive_absolute(root)
	var vs_path := root.path_join("versus.json")
	var vs := {"schema": "arena.versus.v1", "best_of": 5, "episodes_per_round": 3,
			"a": {"spec": "/nets/es_v2.json", "label": "es v2", "build": "core.arena.bog_golem"},
			"b": {"spec": "/nets/ppo_v3.json", "label": "ppo v3", "build": "core.arena.bog_golem"}}
	var f := FileAccess.open(vs_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(vs))
	f.close()
	# a versus verdict replays itself
	var direct := _replayable(vs, 0)
	if str((direct.get("a", {}) as Dictionary).get("spec", "")) != "/nets/es_v2.json":
		ok = false
		push_error("CONSOLE SELFTEST: a versus verdict did not resolve to itself")
	# a bracket resolves through `out` to the versus verdict that decided it
	var tour := {"schema": "arena.tournament.v1", "key": "bog_golem", "best_of": 5,
			"bracket": [{"a": "es", "b": "ppo", "out": vs_path}]}
	var hop := _replayable(tour, 0)
	if str((hop.get("b", {}) as Dictionary).get("spec", "")) != "/nets/ppo_v3.json" \
			or int(hop.get("best_of", 0)) != 5:
		ok = false
		push_error("CONSOLE SELFTEST: a bracket did not resolve to its deciding showdown")
	# BOTH sides carry a policy — the bug Ricardo hit was a one-sided watch
	if str((hop.get("a", {}) as Dictionary).get("spec", "")) == "" \
			or str((hop.get("b", {}) as Dictionary).get("spec", "")) == "":
		ok = false
		push_error("CONSOLE SELFTEST: a showdown resolved with only one side's policy")
	# a broken `out` must refuse, not crash or replay the wrong thing
	var broken := {"schema": "arena.tournament.v1", "bracket": [{"out": root.path_join("gone.json")}]}
	if not _replayable(broken, 0).is_empty():
		ok = false
		push_error("CONSOLE SELFTEST: a bracket with a missing verdict did not refuse")
	# a ladder has no single pairing, and must say so rather than guess
	if not _replayable({"schema": "arena.ladder.v1"}, 0).is_empty():
		ok = false
		push_error("CONSOLE SELFTEST: a ladder verdict claimed a replayable pairing")
	_rm_rf(root)
	return ok

# The cockpit tabs, against FIXTURES under user:// — the gate must never read or
# write the real ml/serving/registry.json, ml/runs/ or ml/data/benchmarks/.
func _selftest_cockpit() -> bool:
	var ok := true
	var root := ProjectSettings.globalize_path("user://console_selftest")
	DirAccess.make_dir_recursive_absolute(root.path_join("runs"))
	# an earlier version of this selftest wrote its sweep fixture here; user://
	# persists, so leaving it behind would fail the "one run folder" assertion
	_rm_rf(root.path_join("runs").path_join(
			"2026-09-14_0200__all-creatures-console__g10_p2_e1_j4"))
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
			"a": {"label": "fen_boar v2 (candidate)", "spec": "fen_boar@v2",
				"build": "core.arena.fen_boar_alpha"},
			"b": {"label": "native", "spec": "native", "build": "core.arena.fen_boar_alpha"}}
	f = FileAccess.open(_bench_root.path_join("2026-09-13_070000__a_vs_b.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(verdict, " "))
	f.close()
	# --- the benchmark browser: two schemas, filtered by creature -----------
	# A bracket is not a head to head. Rendered through the versus fields it read
	# "? vs ?  0-0  ?" — which is what this asserts can never come back.
	var bench_fixtures := {
		"2026-09-13_081500__bog_vs_bog.json": {
			"schema": "arena.versus.v1", "best_of": 5, "episodes_per_round": 1,
			"wall_s": 1.0, "rounds_a": 5, "rounds_b": 0, "winner": "a",
			"a": {"label": "bog_golem v2", "spec": "bog_golem@v2", "build": "core.arena.bog_golem"},
			"b": {"label": "bog_golem v3", "spec": "bog_golem@v3", "build": "core.arena.bog_golem"}},
		"2026-09-14_004448__tournament__bog_golem.json": {
			"schema": "arena.tournament.v1", "key": "bog_golem",
			"build": "core.arena.bog_golem", "methods": ["es", "ppo"],
			"best_of": 5, "bracket_episodes": 1, "gate_episodes": 4, "wall_s": 19.3,
			"champion": "es", "winner": null, "winner_version": null, "deployed": false,
			"table": [{"method": "es", "label": "es v2", "version": 2, "points": 3,
					"rounds_won": 5, "episode_win_rate": 1.0, "gate_pass": false},
				{"method": "ppo", "label": "ppo v3", "version": 3, "points": 0,
					"rounds_won": 0, "episode_win_rate": 0.0, "gate_pass": false}]},
		"2026-09-14_011856__ladder.json": {
			"schema": "arena.ladder.v1", "arenas": ["core.arena.bog_golem"],
			"episodes_per_orientation": 1, "wall_s": 7.2, "champion": "scripted",
			"pairings": [{"a": "bog_golem@v2", "b": "scripted",
					"arena": "core.arena.bog_golem"}],
			"entrants": [{"id": "bog_golem@v2", "label": "bog_golem v2 (candidate)",
					"key": "bog_golem"}, {"id": "scripted", "label": "scripted", "key": ""}],
			"table": [{"rank": 1, "id": "scripted", "label": "scripted", "points": 3,
					"ep_wins": 2, "ep_draws": 0, "ep_losses": 0, "win_rate": 1.0,
					"hp_margin": 0.381, "rating": 287.0},
				{"rank": 2, "id": "bog_golem@v2", "label": "bog_golem v2 (candidate)",
					"points": 0, "ep_wins": 0, "ep_draws": 0, "ep_losses": 2,
					"win_rate": 0.0, "hp_margin": -0.381, "rating": -287.0}]},
		# no spec, no build: an old or hand-made verdict must still be listed
		# under "all creatures" instead of silently vanishing from the history
		"2026-09-12_120000__scripted_vs_native.json": {
			"schema": "arena.versus.v1", "best_of": 3, "rounds_a": 3, "rounds_b": 0,
			"winner": "a", "a": {"label": "scripted"}, "b": {"label": "native"}},
		# R60: neither of these is a head to head, and before 2026-09-22 both
		# rendered as one ("? vs ?  0-0  ?"). They also name their creature in
		# `build` instead of `key`, so the creature filter could not reach them.
		# Dated 09-11 so they land at the END of the list and the row indices
		# the assertions above depend on do not move.
		"2026-09-11_093001__env_parity__mire_serpent.json": {
			"schema": "arena.env_parity.v1", "build": "core.arena.mire_serpent",
			"opponent": "scripted", "episodes": 12, "seed": 2026, "tolerance": 0.15,
			"dh_env": {"win_rate": 0.0, "hp_self": 0.0, "hp_foe": 0.913},
			"arena": {"win_rate": 0.0, "hp_self": 0.054, "hp_foe": 0.184},
			"gaps": {"win_rate": 0.0, "hp_self": 0.054, "hp_foe": 0.729},
			"worst": 0.729, "agree": false},
		"2026-09-11_093000__distill__mire_serpent_clone.json": {
			"schema": "arena.distill.v1", "key": "mire_serpent_clone",
			"build": "core.arena.mire_serpent", "started": "2026-09-11T09:30:00",
			"teacher": {"label": "heuristic", "hidden": []},
			"student": {"hidden": [64, 64], "arch": {"activation": "tanh"}},
			"rounds": [], "qualify": {"passed": false, "margin": 0.55, "checks": {
				"native": {"rounds": "5-0", "episode_win_rate": 1.0, "passed": true},
				"scripted": {"rounds": "1-4", "episode_win_rate": 0.25, "passed": false}}}},
		# R60: the one that made the "newest first" header a lie. Its name has no
		# date, so it sorts ABOVE every 2026-* file, but it is the OLDEST record
		# here — the list has to read the time out of the record, not the name.
		# Two real files on disk are shaped exactly like this.
		"env_parity_gloam_wisp_scripted.json": {
			"schema": "arena.versus.v1", "started": "2026-09-10T08:00:00",
			"best_of": 3, "rounds_a": 0, "rounds_b": 3, "winner": "b",
			"a": {"label": "gloam_wisp v1", "build": "core.arena.gloam_wisp"},
			"b": {"label": "scripted"}}}
	for fixture_name in bench_fixtures.keys():
		f = FileAccess.open(_bench_root.path_join(str(fixture_name)), FileAccess.WRITE)
		f.store_string(JSON.stringify(bench_fixtures[fixture_name], " "))
		f.close()
	_refresh_history()
	if _vs_history.item_count != 8 or _vs_count.text != "8 of 8":
		ok = false
		push_error("CONSOLE SELFTEST: history shows %d rows ('%s'), want 7" % [
				_vs_history.item_count, _vs_count.text])
	if _vs_history.get_item_text(0).find("★ global rank") < 0 \
			or _vs_history.get_item_text(0).find("champion scripted") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: newest row is not the ladder: '%s'" % _vs_history.get_item_text(0))
	if _vs_history.get_item_text(1).find("⚔ bog_golem") < 0 \
			or _vs_history.get_item_text(1).find("champion es") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: the bracket row is wrong: '%s'" % _vs_history.get_item_text(1))
	for row_i in _vs_history.item_count:
		if _vs_history.get_item_text(row_i).find("? vs ?") >= 0:
			ok = false
			push_error("CONSOLE SELFTEST: a verdict rendered through the wrong schema: '%s'"
					% _vs_history.get_item_text(row_i))
	if _vs_history.get_item_text(3).find("3-2") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: the head-to-head row lost its score: '%s'"
				% _vs_history.get_item_text(3))
	var filtered := func(key: String, kind: String) -> int:
		for fi in _vs_filter.item_count:
			if str(_vs_filter.get_item_metadata(fi)) == key:
				_vs_filter.select(fi)
		for ki in _vs_kind.item_count:
			if str(_vs_kind.get_item_metadata(ki)) == kind:
				_vs_kind.select(ki)
		_refresh_history()
		return _vs_history.item_count
	# bog_golem appears in a head to head, a bracket AND the ladder (as an
	# entrant's key and as the body it was fought in); fen_boar in one verdict
	if filtered.call("bog_golem", "") != 3 or filtered.call("fen_boar", "") != 1:
		ok = false
		push_error("CONSOLE SELFTEST: the creature filter does not select by creature")
	if filtered.call("", "tournament") != 1 or filtered.call("", "versus") != 4 \
			or filtered.call("", "ladder") != 1:
		ok = false
		push_error("CONSOLE SELFTEST: the kind filter does not split the three schemas")
	# R60: a distill and a parity run are their own kinds, reachable and legible
	if filtered.call("", "distill") != 1 or filtered.call("", "parity") != 1:
		ok = false
		push_error("CONSOLE SELFTEST: distill/parity verdicts are not filterable")
	if filtered.call("mire_serpent", "") != 2:
		ok = false
		push_error("CONSOLE SELFTEST: a record naming its creature in `build` is "
				+ "missing from the creature filter")
	filtered.call("", "")
	var distill_row := _vs_history.get_item_text(6)
	if distill_row.find("⚗ mire_serpent_clone") < 0 or distill_row.find("heuristic → [64,64] tanh") < 0 \
			or distill_row.find("gate fail") < 0 or distill_row.find("native 5-0") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: the distill row reads '%s'" % distill_row)
	var parity_row := _vs_history.get_item_text(5)
	if parity_row.find("⇄ parity") < 0 or parity_row.find("mire_serpent vs scripted") < 0 \
			or parity_row.find("worst gap 0.73") < 0 or parity_row.find("DISAGREE") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: the parity row reads '%s'" % parity_row)
	var pd := _verdict_detail(bench_fixtures["2026-09-11_093001__env_parity__mire_serpent.json"])
	if pd.find("runtimes DISAGREE") < 0 or pd.find("dh-env  0.913") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: parity detail reads '%s'" % pd)
	# HISTORY says "newest first" — it has to be true even for a record whose
	# name sorts above every dated one (R60)
	var undated := _verdict_at("env_parity_fen_boar_scripted.json", {}, 1757000000)
	var dated := _verdict_at("2026-09-19_104326__distill__x.json", {}, 0)
	if undated != 1757000000 or dated <= 0 or dated < undated:
		ok = false
		push_error("CONSOLE SELFTEST: history sort keys are wrong (undated %d, dated %d)" % [
				undated, dated])
	# _bench is the source of the list and the filter only ever drops rows from
	# it, so the whole promise lives in this one ordering
	var prev_at := 1 << 62
	for row_i in _bench.size():
		var at_i := int((_bench[row_i] as Dictionary).at)
		if at_i > prev_at:
			ok = false
			push_error("CONSOLE SELFTEST: HISTORY is not newest-first at row %d (%s)" % [
					row_i, str((_bench[row_i] as Dictionary).name)])
			break
		prev_at = at_i
	# and a name that is NOT date-stamped must still produce a real timestamp
	# instead of slicing one out of the letters (the "arity fe:n_" bug)
	var iso_when := _verdict_when("env_parity_fen_boar_scripted.json",
			{"started": "2026-09-19T10:43:25"}, 0)
	if iso_when != "09-19 10:43":
		ok = false
		push_error("CONSOLE SELFTEST: an undated name stamps '%s', want '09-19 10:43'" % iso_when)
	if _verdict_when("console_20260914_044035.json", {}, 0).strip_edges() != "?":
		ok = false
		push_error("CONSOLE SELFTEST: a name with no time anywhere must not invent one")
	if filtered.call("bog_golem", "tournament") != 1:
		ok = false
		push_error("CONSOLE SELFTEST: the two filters do not compose")
	var fk := _verdict_keys(bench_fixtures["2026-09-12_120000__scripted_vs_native.json"])
	if not fk.is_empty() or filtered.call("", "") != 8:
		ok = false
		push_error("CONSOLE SELFTEST: a verdict with no creature was dropped from the history")
	# a bracket's detail panel must show the bracket, not a made-up head to head
	var detail := _verdict_detail(bench_fixtures["2026-09-14_004448__tournament__bog_golem.json"])
	if detail.find("champion es") < 0 or detail.find("no pin moved") < 0 \
			or detail.find("es v2") < 0 or detail.find("vs") >= 0:
		ok = false
		push_error("CONSOLE SELFTEST: bracket detail reads '%s'" % detail)
	# --- RANK: the newest ladder verdict, in rank order ----------------------
	_refresh_rank()
	if _rank_table.item_count != 2:
		ok = false
		push_error("CONSOLE SELFTEST: rank table shows %d rows, want 2" % _rank_table.item_count)
	elif str(_rank_table.get_item_metadata(0)) != "scripted" \
			or str(_rank_table.get_item_metadata(1)) != "bog_golem@v2":
		ok = false
		push_error("CONSOLE SELFTEST: rank order is %s, %s" % [
				str(_rank_table.get_item_metadata(0)), str(_rank_table.get_item_metadata(1))])
	if _rank_head.text.find("bog_golem") < 0 or _rank_head.text.find("2 entrants") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: rank header reads '%s'" % _rank_head.text)
	# the dispatch, without fighting anything: one body by default, every body on
	# request, and 'pins only' must reach the ladder as --deployed-only
	_rank_all_arenas.button_pressed = false
	_rank_deployed.button_pressed = false
	var one_body := _ladder_args()
	if one_body.find("ladder --episodes") != 0 or one_body.find("--all-arenas") >= 0 \
			or one_body.find("--deployed-only") >= 0:
		ok = false
		push_error("CONSOLE SELFTEST: default ladder args are '%s'" % one_body)
	_rank_all_arenas.button_pressed = true
	_rank_deployed.button_pressed = true
	var every_body := _ladder_args()
	if every_body.find("--all-arenas") < 0 or every_body.find("--deployed-only") < 0 \
			or every_body.find("--arena ") >= 0:
		ok = false
		push_error("CONSOLE SELFTEST: 'every arena' ladder args are '%s'" % every_body)
	_rank_all_arenas.button_pressed = false
	_rank_deployed.button_pressed = false
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

	# --- the WHOLE sweep: total progress and an ETA for the run ---------------
	# Ricardo, 2026-09-14: "in tournament viz i can't see the total progress,
	# only current key progress! Nor estimated time to conclude the full run".
	# Four PLANNED keys; one finished the ES way, one is mid-bracket, two have
	# not started and therefore have no feed at all. That last part is the whole
	# point: averaging over the files on disk would read 87% while half the
	# roster had not been touched.
	# NOT under _runs_root: user:// survives between selftest runs, and a second
	# folder there would break the RUNS assertions above on the next run.
	var sweep_run := root.path_join("sweep").path_join(
			"2026-09-14_0200__all-creatures-console__g10_p2_e1_j4")
	DirAccess.make_dir_recursive_absolute(sweep_run.path_join("progress"))
	f = FileAccess.open(sweep_run.path_join("config.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"started": "2026-09-14T02:00:00", "mode": "tournament",
			"keys_label": "all-creatures", "knobs": "g10_p2_e1_j4",
			"keys": [["fen_boar", "core.arena.fen_boar_alpha"],
				["bog_golem", "core.arena.bog_golem"],
				["mire_serpent", "core.arena.mire_serpent"],
				["gloam_wisp", "core.arena.gloam_wisp"]],
			"es": {"generations": 10, "pop": 2, "episodes": 1, "jobs": 4},
			"env": {"godot": "4.6", "git_head": "abc1234"}}, " "))
	f.close()
	f = FileAccess.open(sweep_run.path_join("progress").path_join("fen_boar.jsonl"),
			FileAccess.WRITE)
	f.store_line(JSON.stringify({"t": 1000.0, "ev": "start", "key": "fen_boar",
			"generations": 10, "pop": 2}))
	f.store_line(JSON.stringify({"t": 1600.0, "ev": "generation", "g": 9, "best": 0.4}))
	f.store_line(JSON.stringify({"t": 1610.0, "ev": "gate", "key": "fen_boar", "pass": true}))
	f.close()
	f = FileAccess.open(sweep_run.path_join("progress").path_join("bog_golem.jsonl"),
			FileAccess.WRITE)
	f.store_line(JSON.stringify({"t": 1620.0, "ev": "method_start", "method": "es"}))
	f.store_line(JSON.stringify({"t": 1900.0, "ev": "method_done", "method": "es",
			"status": "ok"}))
	f.store_line(JSON.stringify({"t": 1905.0, "ev": "method_start", "method": "ppo"}))
	f.close()
	_sweep_arm(sweep_run)
	_sweep_scan()
	if _sweep_keys.size() != 4:
		ok = false
		push_error("CONSOLE SELFTEST: the sweep planned %d key(s), want 4 from config.json"
				% _sweep_keys.size())
	if absf(_sweep_frac("fen_boar") - 1.0) > 0.001:
		ok = false
		push_error("CONSOLE SELFTEST: a gated ES key is not done (%.2f)" % _sweep_frac("fen_boar"))
	if absf(_sweep_frac("bog_golem") - 0.75) > 0.001:
		ok = false
		push_error("CONSOLE SELFTEST: a key 1.5 methods into a 2-method bracket reads %.2f, want 0.75"
				% _sweep_frac("bog_golem"))
	if _sweep_frac("mire_serpent") != 0.0:
		ok = false
		push_error("CONSOLE SELFTEST: a key that never started is not 0")
	var sweep_line := _sweep_status()
	if sweep_line.find("SWEEP 1/4 keys") < 0 or sweep_line.find("44%") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: sweep line '%s' — want 1/4 keys at 44%%" % sweep_line)
	if sweep_line.find("ETA") < 0 or sweep_line.find("ETA —") >= 0:
		ok = false
		push_error("CONSOLE SELFTEST: the sweep has no ETA for the full run: '%s'" % sweep_line)
	if sweep_line.find("now bog_golem method 2/2") < 0:
		ok = false
		push_error("CONSOLE SELFTEST: the sweep line does not say which key is live: '%s'" % sweep_line)
	# a second scan must be a no-op: the feeds are read incrementally by offset,
	# and a double-counted method_done would push the bracket past its own total
	_sweep_scan()
	if absf(_sweep_frac("bog_golem") - 0.75) > 0.001:
		ok = false
		push_error("CONSOLE SELFTEST: re-scanning double-counted events (%.2f)"
				% _sweep_frac("bog_golem"))
	_sweep_arm("")
	if _sweep_status() != "":
		ok = false
		push_error("CONSOLE SELFTEST: a single-key run still shows a sweep line")

	# --- TRAIN ALL's two gears (Ricardo: "tournament mode for the train all") --
	# Unticked, the sweep's command line must be byte-for-byte what it was before
	# the bracket existed; ticked, it must reach tools/train_run.sh --tournament
	# with the bracket knobs. And a single-creature TRAIN never brackets.
	_bracket.button_pressed = false
	var plain := _sweep_flags(true)
	if str(plain.env) != "" or str(plain.prefix) != "":
		ok = false
		push_error("CONSOLE SELFTEST: an unticked bracket changed the sweep: '%s' '%s'" % [
				str(plain.env), str(plain.prefix)])
	_bracket.button_pressed = true
	var brack := _sweep_flags(true)
	if str(brack.prefix) != "--tournament " or str(brack.env).find("METHODS=es,ppo") < 0 \
			or str(brack.env).find("BEST_OF=%d" % TOURNEY_BEST_OF) < 0:
		ok = false
		push_error("CONSOLE SELFTEST: bracket dispatch is '%s%s'" % [
				str(brack.env), str(brack.prefix)])
	var single := _sweep_flags(false)
	if str(single.env) != "" or str(single.prefix) != "":
		ok = false
		push_error("CONSOLE SELFTEST: the bracket leaked into a single-creature run")
	_refresh_ui()
	if _train_all_btn.text != "TRAIN ALL ⚔":
		ok = false
		push_error("CONSOLE SELFTEST: TRAIN ALL does not show the bracket gear: '%s'" % _train_all_btn.text)
	_bracket.button_pressed = false
	_refresh_ui()
	if _train_all_btn.text != "TRAIN ALL":
		ok = false
		push_error("CONSOLE SELFTEST: TRAIN ALL stuck in the bracket gear: '%s'" % _train_all_btn.text)
	return ok
