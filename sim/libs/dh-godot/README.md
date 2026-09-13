# dh-godot — GDExtension bindings (godot-cpp)

**Built and in use since 2026-09-13.** Today it exposes exactly one thing:
`DhPolicyNet`, the arena policy forward pass in C++.

## Why it exists

Profiling the arena on 2026-09-13 put the GDScript forward pass at **~93% of the
whole arena tick** — physics, projectiles, fields and every other node together
were the remaining ~7%. The net is tiny (47-64-64-10, 7,744 multiply-adds);
GDScript was simply spending ~400 ns on each one.

| forward pass | µs/tick (neural vs neural, idle box) |
|---|---|
| nested `Array` of `Array` (original) | ~986 |
| flat `PackedFloat64Array` (GDScript) | 566 |
| `DhPolicyNet` (this) | **105** |

Fights are **bit-identical** at every step, which is a requirement rather than a
nicety: the registry's nets were trained against the GDScript runtime, so a
different answer here would silently change every deployed policy. The C++ loop
accumulates in the same order, in double, with `-ffp-contract=off` inherited
from the sim build (no FMA contraction), no fast-math, and libm `tanh` — exactly
what GDScript's `tanh()` calls.

**Honest caveat:** 5.4× per tick did NOT become 5.4× per generation. Measured
end to end on the best configuration it is ~1.06×, inside the noise, because
once the forward pass got cheap the cost moved elsewhere — per-episode scene
teardown and rebuild, and per-match process overhead. The tick is no longer
where a generation's time goes. See `docs/tech/37-ml-parameter-reference.md`.

## Scope (canon §10)

Bindings and math only — no gameplay rules, no rendering, no I/O. GDScript still
parses the `arena.policy.v1` JSON and pushes flattened weights in via
`add_layer`, so the loading path and its error handling stay where they were.
`game/arena/neural_policy.gd` falls back to its own GDScript implementation when
the extension is absent, so the game and the trainer work without it — slower,
with identical results.

## Building

```bash
tools/vendor_godot_cpp.sh     # pins godot-4.5-stable (no 4.6 branch exists;
                              # GDExtension is forward compatible)
tools/build_dh_godot.sh       # both targets -> game/addons/dh_godot/
```

Neither the vendored godot-cpp nor the built `.so` is committed (see
`.gitignore`); the extension is optional by design. `build_profile.json` trims
the generated bindings to the classes actually used, which takes generation from
thousands of files to ~82 and the build from a quarter hour to seconds.

Note the build profile must include the classes **godot-cpp itself** needs
(`OS`, `Mutex`, `FileAccess`, `WorkerThreadPool`, `XMLParser`, `Image`,
`ClassDB`), not only `RefCounted` — trimming to just the subclassed type fails
to compile godot-cpp's own core.

## Still to come

The original purpose of this library — exposing `dh-sim` for **local-hero
prediction** (docs/tech/22 §3), where the client embeds the same simulation as
the server and replays unacknowledged inputs over authoritative snapshots — is
not built yet. It would link `dh-sim`, `dh-net` and `dh-content` here.
