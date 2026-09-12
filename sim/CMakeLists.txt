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
add_subdirectory(libs/dh-env)   # C API over dh-sim's arena (ctypes today, nanobind later)
# dh-godot (godot-cpp GDExtension) joins the build once its third-party
# dependency is vendored — see the README in that directory.

enable_testing()
add_subdirectory(tests)
