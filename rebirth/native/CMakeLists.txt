# REBIRTH / native — the "no engine" experiment (rebirth/docs/01-plan.md §2,
# row 3). C++20, the parent sim/ workspace's warning contract. Two targets:
#   rebirth-sim     static lib: 30 Hz fixed-step fight sim + CPU geometry (no GL)
#   rebirth-native  the client: X11/GLX/OpenGL 3.3 (REBIRTH_WITH_GL=ON) or sim-only
# Build:  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j
# Gate:   ./build/rebirth-native --sim-only --verify      (also `ctest --test-dir build`)
cmake_minimum_required(VERSION 3.22)
project(rebirth_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

option(REBIRTH_WITH_GL "Build the X11/GLX client (OFF = sim-only binary for headless boxes)" ON)

add_compile_options(-Wall -Wextra -Werror -ffp-contract=off)

add_library(rebirth-sim STATIC src/sim.cpp src/geometry.cpp)
target_include_directories(rebirth-sim PUBLIC src)

add_executable(rebirth-native src/main.cpp)
target_link_libraries(rebirth-native PRIVATE rebirth-sim)
target_compile_definitions(rebirth-native PRIVATE
  RB_ASSET_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../assets/glb"
  RB_CAPTURE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/captures")

if(REBIRTH_WITH_GL)
  find_package(OpenGL REQUIRED)
  find_package(X11 REQUIRED)
  target_sources(rebirth-native PRIVATE src/render_gl.cpp)
  target_link_libraries(rebirth-native PRIVATE OpenGL::GL X11::X11)
  target_compile_definitions(rebirth-native PRIVATE RB_WITH_GL=1)
endif()

# dh-sim link (the plan's actual bet: the parent's authoritative sim as combat
# authority). OFF here: the sibling rebirth-native/ (other session) does that
# link; this experiment measures the client. Flip when dh-sim grows a 3D arena.
option(REBIRTH_LINK_DHSIM "add_subdirectory(../../sim) and link dh-sim" OFF)
if(REBIRTH_LINK_DHSIM)
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../sim ${CMAKE_BINARY_DIR}/dh-sim)
  target_link_libraries(rebirth-native PRIVATE dh-sim)
  target_compile_definitions(rebirth-native PRIVATE RB_WITH_DHSIM=1)
endif()

enable_testing()
add_test(NAME sim-gate COMMAND rebirth-native --sim-only --verify)
