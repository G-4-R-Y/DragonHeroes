# dh-sim link option (from the parallel session's rebirth-native/ scaffold)

That session's throwaway `rebirth-native/` proved one thing worth keeping:
**the parent repo's `dh-sim` (`sim/libs/dh-sim`) links and runs a full
deterministic arena episode from a plain C++20 consumer with zero engine
code** — cmake `add_subdirectory(../sim)` + `target_link_libraries(dh-sim)`,
episode done at tick 1151, state hash printed. That is canon §10's
engine-agnostic bet demonstrated end-to-end (the same library already powers
`dh-server` and `dh-env` at 258k steps/s/core).

This slice keeps its own `src/sim.*` on purpose (self-contained, no parent
build tree). If the native track ever goes beyond a slice, the upgrade path
is: delete `src/sim.*`, link `dh-sim`, keep the renderer. The deterministic
hash gate (`ctest`) is the equivalence check for that swap.

(The throwaway scaffold repo was deleted; its single commit's content is
preserved here and in the parent repo's git history of `rebirth-native/`.)
