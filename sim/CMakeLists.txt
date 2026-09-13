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
# dh-godot (godot-cpp GDExtension). Optional: it only joins the build once
# godot-cpp is vendored (tools/vendor_godot_cpp.sh), so a fresh checkout still
# configures and builds everything else without it.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/libs/dh-godot/third_party/godot-cpp/CMakeLists.txt")
  add_subdirectory(libs/dh-godot)
else()
  message(STATUS "dh-godot: godot-cpp not vendored — skipping. Run tools/vendor_godot_cpp.sh")
endif()

enable_testing()
add_subdirectory(tests)
