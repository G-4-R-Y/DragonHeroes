# REBIRTH / Godot 3D — the Gen-AI asset hook. If rebirth/assets/glb/<name>.glb
# exists (GenForge concept -> TripoSR/Pixal3D -> GLB, or the pure-python
# placeholder from assets/tools), it replaces the code-built stand-in at boot.
# Runtime GLTF load, no import step: the pipeline lives OUTSIDE the engine
# folder on purpose (reusable by native/ and unreal/).
class_name RbGlb
extends RefCounted

static func dir() -> String:
	var env := OS.get_environment("REBIRTH_GLB_DIR")
	if env != "":
		return env
	return ProjectSettings.globalize_path("res://").path_join("../assets/glb")

static func load_scene(name: String) -> Node3D:
	var path := dir().path_join(name + ".glb")
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK:
		push_warning("RbGlb: %s failed to load (%d)" % [path, err])
		return null
	var scene := doc.generate_scene(st)
	if scene == null:
		return null
	print("RbGlb: loaded ", path)
	return scene as Node3D
