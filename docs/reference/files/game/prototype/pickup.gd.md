# game/prototype/pickup.gd

Renders a real local ProtoItems instance or currency/stone/snare pickup. main.gd
creates it and owns collect()/inventory mutation; encounter_residency.gd may free
and reconstruct it from original primitive fields. Registers ground_loot on ready.

The bobbing anchor _base_y and phase _t are presentation state; keep both when
restoring so repeated visits do not shift the drop. Full bags leave the original
item on the ground. _collected commits before main.collect and guards the deferred
queue_free window against duplicate collection. This prototype still routes
pickup to the local hunter; official per-player loot is future server work.

Gate: ground_state_probe.tscn. Law: tech/29 and design/28. No distance expiry.
