# ESC PROBE — the return-to-haven flow as a gate (Ricardo: "clicking yes did
# nothing besides the animation"). Boots the hunt, drives the exact confirm
# path (ui_cancel -> _return_to_haven), and asserts the scene actually becomes
# the Haven. The probe survives the swap by handing current_scene to the hunt
# instance (change_scene_to_file frees only the CURRENT scene), so it can
# observe the transition. Static memory is logged around it (roadmap 3c).
#
#   godot --headless --path game res://prototype/tests/esc_probe.tscn   # ESC OK
extends Node

func _ready() -> void:
	call_deferred("_run")   # root is busy while OUR scene sets up

func _run() -> void:
	var hunt := preload("res://prototype/main.tscn").instantiate()
	get_tree().root.add_child(hunt)
	get_tree().current_scene = hunt   # the swap will free THIS, not us
	# boot is async (world dump, bundles): poll until the confirm dialog exists
	var waited := 0.0
	while waited < 60.0 and (not is_instance_valid(hunt) or hunt._confirm == null):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if not is_instance_valid(hunt) or hunt._confirm == null:
		_verdict(false, "hunt never built its confirm dialog (boot aborted?)")
		return
	var mem_before := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	# the exact user path: ESC opens the confirm, YES fires _return_to_haven
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	hunt._unhandled_input(ev)
	await get_tree().process_frame
	if not hunt._confirm.visible:
		_verdict(false, "ESC did not open the confirm dialog")
		return
	hunt._return_to_haven()   # what yes.pressed is connected to
	var swapped := false
	for i in 60:
		await get_tree().process_frame
		if not is_instance_valid(hunt) or get_tree().current_scene != hunt:
			swapped = true
			break
	var mem_after := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var now := get_tree().current_scene
	if swapped and now != null and now.scene_file_path.contains("haven"):
		_verdict(true, "returned to %s (static mem %.0f -> %.0f MB)" % [
				now.scene_file_path.get_file(), mem_before, mem_after])
	else:
		_verdict(false, "scene never changed (mem %.0f -> %.0f MB)" % [
				mem_before, mem_after])

func _verdict(ok: bool, msg: String) -> void:
	if ok:
		print("ESC OK — ", msg)
	else:
		push_error("ESC FAIL — " + msg)
	get_tree().quit(0 if ok else 1)
