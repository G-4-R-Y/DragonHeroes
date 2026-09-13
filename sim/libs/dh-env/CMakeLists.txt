# dh-env — vectorized RL training environment (C API + nanobind): see README.md.
# The C API is the primary surface (PufferLib-native); the nanobind module joins
# once third_party/nanobind is vendored. Python consumes this today via ctypes
# (ml/env/dh_env.py).
add_library(dh-env SHARED
    src/dh_env.cpp
)
target_include_directories(dh-env PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
# dh_env_step_many drains the per-tick env fan-out across a worker pool
find_package(Threads REQUIRED)
target_link_libraries(dh-env PRIVATE dh-sim Threads::Threads)
