extends RefCounted
## Where the repository is, from inside a console — editor or exported app.
##
## Both cockpits shell out to the repo's python (tools/genforge.py, tools/train_run.sh)
## and read its JSON, so "where is the repo" is load-bearing, and it is NOT the
## same question in the two places the consoles run:
##
##   editor / `godot --path game`   res:// IS game/, so res://.. is the repo.
##   exported binary                res:// is the PCK next to the executable, so
##                                  res://.. is builds/ — the wrong answer, and a
##                                  silent one: the tool just reports nothing.
##
## That is exactly what the first GenForge Console build did — it booted the right
## cockpit and then said "genforge.py list returned no packs" (2026-09-13). So:
## honour $DH_REPO, else try res://.., else walk up from the executable, and check
## every candidate against a sentinel instead of trusting the path shape.
class_name DhRepoRoot

## A directory is the repo iff BOTH of these exist under it. docs/00-canon.md is
## the single source of truth (CLAUDE.md) and tools/ holds everything the consoles
## invoke — a build tree that has one but not the other is not a repo we can drive.
const SENTINELS := ["docs/00-canon.md", "tools/genforge.py"]
const MAX_CLIMB := 8

static func is_repo(path: String) -> bool:
	if path == "":
		return false
	for s in SENTINELS:
		if not FileAccess.file_exists(path.path_join(s)):
			return false
	return true

## The repo root, or "" when this binary was copied somewhere with no repo above it.
## Callers must handle "" — a console with no repo can still draw, it just cannot run.
static func find() -> String:
	var env := OS.get_environment("DH_REPO")
	if env != "":
		var e := env.simplify_path()
		if is_repo(e):
			return e
	var res := ProjectSettings.globalize_path("res://..").simplify_path()
	if is_repo(res):
		return res
	var climb := [res, OS.get_executable_path().get_base_dir()]
	for start in climb:
		var dir: String = start
		for _i in range(MAX_CLIMB):
			if is_repo(dir):
				return dir
			var up := dir.get_base_dir()
			if up == dir or up == "":
				break
			dir = up
	return ""

## One line for the UI when find() came back empty — say what to do, not just what broke.
static func missing_note() -> String:
	return ("no Dragon Heroes repository above %s — run this console from the repo, " +
			"or set DH_REPO=/path/to/Dragon Heroes") % OS.get_executable_path().get_base_dir()
