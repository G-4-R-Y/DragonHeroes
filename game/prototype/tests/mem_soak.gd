# MEM SOAK — infinite-world memory gate (Ricardo: "infinite map generation was
# exploding memory", roadmap 3c). Boots the hunt, force-streams chunks by
# teleporting the player in an expanding spiral, and samples static memory +
# node/object/resource counts. A healthy streamer grows bounded (caches fill,
# then flat); a leak climbs forever. Prints MEMSOAK lines for the log.
#
#   godot --headless --path game res://prototype/tests/mem_soak.tscn
extends Node

const SAMPLES := 12          # 12 x 10 s = 2 min of forced streaming
const STEP_S := 10.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var hunt := preload("res://prototype/main.tscn").instantiate()
	add_child(hunt)
	var waited := 0.0
	while waited < 60.0 and (hunt.world == null or hunt.player == null):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if hunt.player == null:
		print("MEMSOAK FAIL — hunt never booted")
		get_tree().quit(1)
		return
	var prev_nodes := 0
	var prev_mem := 0.0
	for i in SAMPLES:
		# spiral out: force virgin chunk loads every sample
		var ang := i * 1.1
		var r := 400.0 + i * 350.0
		hunt.player.global_position = Vector2(cos(ang), sin(ang)) * r
		await get_tree().create_timer(STEP_S).timeout
		var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		print("MEMSOAK %02d mem=%.0fMB nodes=%d objs=%d res=%d (d_nodes=%+d d_mem=%+.0f)" % [
				i, mem, nodes, objs, res, nodes - prev_nodes, mem - prev_mem])
		prev_nodes = nodes
		prev_mem = mem
	get_tree().quit(0)
