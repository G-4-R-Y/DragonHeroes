# game/prototype/projectile.gd

Owns finite flight, prototype swept collision and pooled trail/light handles.
Player, wisp, boss, hag and pet skill callers configure velocity/damage/lifetime
before adding the node. Registers projectiles for encounter residency interest.

Camera visibility never stops flight. Removing the shooter does not cancel the
shot; raw damage remains available, while class-synergy callbacks require a valid
shooter. _finished guards movement/impact/expiry during deferred destruction.
Impact, expiry and tree exit detach pooled visuals idempotently. Arena proxy
routing remains supported. Real production CCD belongs to dh-sim, not this harness.

Gates: ground_state_probe (offscreen motion, removed shooter, exactly one hit,
expiry/pool release), arena/arena.tscn -- --selftest, fx_stress.tscn. Wall collision
and native dormant-world combat remain broader existing roadmap work.
