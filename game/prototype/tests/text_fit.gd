# Every string that must fit a box it cannot resize, measured in every language.
#
# R82's defect was geometry decided by COUNTING characters; it holds in English
# and breaks the moment a translation is a different width. This gate decides
# geometry by MEASURING glyphs with the shipping fonts, in both languages,
# before a capture can hide the overflow. Data strings (artifact/creature/skill
# names) come from the real chapter.json, so the budget stays honest as content
# grows — the longest one in the pack is the one that gets measured.
extends Node2D

# ProtoTheme._box content margins (left + right) — a button's usable text width.
const BTN_PAD := 12.0

var _small: Font
var _big: Font
var _failures: Array[String] = []
var _checked := 0

func _ready() -> void:
	_small = ProtoTheme.font_small()
	_big = ProtoTheme.font_big()
	var chapter: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://living/generated/chapter.json"))
	var skill := _longest(chapter.release.skills, "name")
	var artifact := _longest(chapter.release.artifacts, "name")
	var creature := _longest(chapter.release.creatures, "name").to_upper()
	var lair := _longest(chapter.playable.lairs, "name")
	for lang in ["en", "pt"]:
		ProtoLang._loaded = true
		ProtoLang.lang = lang
		# --- trial.gd: fixed-size buttons (game/living/trial.gd _build_ui) ----
		_fits(lang, "tr_lore_btn", ProtoLang.t("tr_lore_btn"), 74.0 - BTN_PAD)
		_fits(lang, "tr_return_btn", ProtoLang.t("tr_return_btn"), 96.0 - BTN_PAD)
		_fits(lang, "tr_continue_btn", ProtoLang.t("tr_continue_btn"), 190.0 - BTN_PAD)
		for key in ["tr_cast_cut", "tr_cast_step", "tr_cast_chime", "tr_cast_toll", "tr_cast_companion"]:
			_fits(lang, key, ProtoLang.t(key), 122.0 - BTN_PAD)
		for i in range(4):
			var tier := ProtoLang.t("tr_tier_%d" % i)
			_fits(lang, "artifact button %d" % i,
					"%d  %s%s" % [i + 1, tier, ProtoLang.t("tr_count_suffix") % 99], 150.0 - BTN_PAD)
			# lair_menu collection cards: four columns across the 548px box
			_fits(lang, "card tier %d" % i, tier, 132.0)
		# --- trial.gd: the status Label at x=16 and feedback at x=12 ----------
		var shrine: String = ProtoLang.t("tr_shrine")
		_fits(lang, "tr_status", ProtoLang.t("tr_status") % [shrine, skill], 624.0)
		_fits(lang, "tr_status paused", ProtoLang.t("tr_status") % [ProtoLang.t("tr_paused"), skill], 624.0)
		_fits(lang, "tr_status_rush", ProtoLang.t("tr_status_rush") % [99, skill], 624.0)
		_fits(lang, "tr_status_practice", ProtoLang.t("tr_status_practice") % skill, 624.0)
		for key in ["tr_opening", "tr_no_socket", "tr_no_helper", "tr_no_start", "tr_stamp_mismatch",
				"tr_dropped", "tr_locked_hint", "tr_absent_hint", "tr_save_failed", "tr_save_busy"]:
			_fits(lang, key, ProtoLang.t(key), 624.0)
		_fits(lang, "tr_feedback", ProtoLang.t("tr_feedback") % [artifact, 99, 99, 99, 99], 628.0)
		# --- trial.gd: the drawn overlay (fixed x, no container to grow) ------
		_fits(lang, "tr_vitals", ProtoLang.t("tr_vitals") % [999, 999, 99, ProtoLang.t("tr_wet_suffix")], 372.0)
		_fits(lang, "tr_bonded", ProtoLang.t("tr_bonded"), 420.0)
		_fits(lang, "boss name", creature, 420.0)
		# victory panel: Rect2(82,109,476,122), centred on x=320 by measurement
		_fits(lang, "tr_win", ProtoLang.t("tr_win"), 476.0, true)
		_fits(lang, "tr_lose", ProtoLang.t("tr_lose"), 476.0, true)
		_fits(lang, "tr_earned", ProtoLang.t("tr_earned") % artifact, 476.0)
		for key in ["tr_practice_done", "tr_rush_unlocked", "tr_next_round", "tr_retry"]:
			_fits(lang, key, ProtoLang.t(key), 476.0)
		_fits(lang, "tr_follows", ProtoLang.t("tr_follows"), 640.0)
		# --- lair_menu.gd: VBoxContainer at (46,18) sized 548x320 -------------
		_fits(lang, "lm_title", ProtoLang.t("lm_title"), 548.0, true)
		for key in ["lm_tagline", "lm_rush_header", "lm_collection", "lm_growth", "lm_scope",
				"lm_no_helper"]:
			_fits(lang, key, ProtoLang.t(key), 548.0)
		_fits(lang, "lm_unreadable", ProtoLang.t("lm_unreadable") % 99, 548.0)
		_fits(lang, "lm_victories", ProtoLang.t("lm_victories") % [99, 99], 548.0)
		_fits(lang, "lm_earned", ProtoLang.t("lm_earned") % 99, 132.0)
		for key in ["lm_explore", "lm_practice", "lm_back"]:
			_fits(lang, key, ProtoLang.t(key), 548.0 - BTN_PAD)
		_fits(lang, "lm_rush_start", ProtoLang.t("lm_rush_start") + lair, 548.0 - BTN_PAD)
		_fits(lang, "lm_rush_locked", ProtoLang.t("lm_rush_locked") + lair, 548.0 - BTN_PAD)
		# --- main_menu.gd: the doorway button is 310x22 -----------------------
		_fits(lang, "lm_menu_entry", ProtoLang.t("lm_menu_entry"), 310.0 - BTN_PAD)
	if _failures.is_empty():
		print("TEXT FIT OK  ·  %d strings measured in en + pt" % _checked)
	else:
		for line in _failures:
			printerr("TEXT FIT FAIL: " + line)
		printerr("TEXT FIT FAIL: %d of %d strings overflow their box" % [_failures.size(), _checked])
	get_tree().quit(0 if _failures.is_empty() else 1)

# The widest value of `field` across a content array — content grows, the gate
# keeps measuring the worst case without anyone editing this file.
func _longest(rows: Array, field: String) -> String:
	var best := ""
	for row in rows:
		var value := str(row.get(field, ""))
		if value.length() > best.length():
			best = value
	return best

func _fits(lang: String, label: String, text: String, box: float, large := false) -> void:
	_checked += 1
	var font := _big if large else _small
	var size := 16 if large else 8
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width > box:
		_failures.append("[%s] %s: %.0fpx in a %.0fpx box — \"%s\"" % [lang, label, width, box, text])
