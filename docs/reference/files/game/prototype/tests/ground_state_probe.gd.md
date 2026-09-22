# game/prototype/tests/ground_state_probe.gd

Actual Hunt outcome gate. Instantiates main.tscn, isolates AI/stream cadence,
then drives the real residency, pickup, projectile and teardown implementations.
Fixtures pause physics after child _ready through deferred calls, preventing
legitimate status ticks from changing deterministic assertions.

Covers node release, original legendary roll after level change, loot wake at
120 creatures, full bag retention, exact-once currency/item collection, no re-drop,
offscreen shot motion after caster removal, target residency interest, one impact,
normal shot expiry/pool release, and a forced off-tree water mesh at Hunt exit.
Companion .tscn/.uid files load this script. Uses an isolated gate profile.

Run: godot --headless --path game res://prototype/tests/ground_state_probe.tscn.
Required marker GROUND STATE OK and clean errors/resources. Not a visual or
production server-trust test; see residency_capture and tech/36 separately.
