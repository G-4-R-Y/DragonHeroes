# game/prototype/world_gen.gd

Godot presentation consumer of native dh-procgen chunk dumps. Owns a bounded
terrain window, asynchronous helper/SDF jobs, row-budgeted apply, minimap blocks,
props and per-chunk water MultiMeshes. Never implement biome-generation rules here.

Water nodes are intentionally OFF-TREE until WATER_FILL has set every transform.
_exit_tree joins workers and explicitly frees only still-unparented water nodes;
SceneTree owns attached children. Clearing queues alone leaks their Node/RIDs.
This fixes the intermittent MultiMesh/mesh/material/shader quit warning.

is_ready_at means fully drawn terrain, independent of walkability: flying
creatures can return over water. is_walkable remains the movement/placement test.
Stale loads are discarded; unloaded/partially applied ground remains fenced.

Gates: stream_test, stream_recovery, spawn_probe, ground_state_probe forced pending
water teardown, tools/check_hunt_exit.py repeated real quits, residency_capture.
Native five-biome classification and rich terrain art are still pending R09/R29.
