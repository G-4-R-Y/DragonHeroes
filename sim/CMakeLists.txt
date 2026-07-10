cmake_minimum_required(VERSION 3.22)
project(dragon-heroes-sim LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Canon: maximized performance, but determinism first — no fast-math, no FP contraction
# (dh-procgen must be bit-exact across platforms; see docs/tech/24).
add_compile_options(-Wall -Wextra -Werror -ffp-contract=off)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

add_subdirectory(libs/dh-math)
add_subdirectory(libs/dh-content)
add_subdirectory(libs/dh-sim)
add_subdirectory(libs/dh-procgen)
add_subdirectory(libs/dh-net)
add_subdirectory(libs/dh-server)
# dh-godot (godot-cpp GDExtension) and dh-env (C API + nanobind) join the build once
# their third-party dependencies are vendored — see the READMEs in those directories.

enable_testing()
add_subdirectory(tests)
