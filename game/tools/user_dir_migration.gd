## Carry saves across the 2026-09-22 user-directory rename (R77, the build merge).
##
## Until the merge the client shipped as "Dragon Heroes — Codex" and kept its
## saves in a custom user directory called "Dragon Heroes Codex". Renaming the
## product to "Dragon Heroes" also renames that directory, and Godot simply
## creates the new one empty -- every playtester's hunter, stable, keybinds and
## lair collection would still be on disk but invisible to the game. So: the
## first launch on the new name copies the old directory across, once.
##
## Deliberately additive. It never overwrites a file that already exists at the
## destination and it never deletes the old directory, so running the old build
## again still finds its saves, and a partial copy is safe to re-run. A marker
## file makes it a one-shot: after the first success the player owns the new
## directory and re-copying would resurrect files they intentionally removed.
##
## This is an autoload and the FIRST one in project.godot, because the others
## (LairJourney, Session) read user:// on demand and must see the migrated
## files. The work happens in _init() rather than _ready() so it is finished
## before any other autoload is even instantiated.
extends Node

const OLD_USER_DIR := "Dragon Heroes Codex"
const NEW_USER_DIR := "Dragon Heroes"
const MARKER := "user://.user-dir-migrated"

func _init() -> void:
	migrate()

## Returns the number of files copied, or -1 when there was nothing to do.
func migrate() -> int:
	if FileAccess.file_exists(MARKER):
		return -1
	var current := OS.get_user_data_dir()
	# Guard the rename specifically: an export with --user-data-dir or a future
	# rename must not silently pull a stale "Codex" tree into a directory that
	# has nothing to do with it.
	if current.get_file() != NEW_USER_DIR:
		return -1
	var previous := current.get_base_dir().path_join(OLD_USER_DIR)
	if not DirAccess.dir_exists_absolute(previous):
		return -1
	var copied := _copy_tree(previous, current)
	var marker := FileAccess.open(MARKER, FileAccess.WRITE)
	if marker != null:
		marker.store_string("migrated %d file(s) from %s\n" % [copied, previous])
		marker.close()
	print("USER DIR MIGRATION: copied %d file(s) from %s" % [copied, previous])
	return copied

func _copy_tree(from: String, to: String) -> int:
	var source := DirAccess.open(from)
	if source == null:
		return 0
	DirAccess.make_dir_recursive_absolute(to)
	var copied := 0
	for name in source.get_files():
		var target := to.path_join(name)
		# Never clobber: whatever the new build already wrote is the live state.
		if FileAccess.file_exists(target):
			continue
		if DirAccess.copy_absolute(from.path_join(name), target) == OK:
			copied += 1
	for name in source.get_directories():
		copied += _copy_tree(from.path_join(name), to.path_join(name))
	return copied
