# dh-env — vectorized RL training environment (C API + nanobind)

Exposes headless `dh-sim` instances to Python for PufferLib training
(docs/tech/25): batch `reset`/`step` over contiguous NumPy observation/action
buffers, many arena instances per process, faster-than-realtime.

Not in the CMake build yet. Joining the build requires:

1. A plain C API (`dh_env.h`): `create(n_envs, config) / step(actions, out_obs,
   out_rewards, out_dones) / destroy` — PufferLib-native environments are C, so this
   is the primary surface.
2. A thin [nanobind](https://github.com/wjakob/nanobind) module wrapping it for
   ergonomic Python use (vendored under `third_party/nanobind`).
3. `ml/training/` owns the PufferLib configs that consume it.

Phase R0 (replay logging) does not need this library — it starts server-side in
`dh-server`. This library unblocks Phase R1 (self-play arena policies).
