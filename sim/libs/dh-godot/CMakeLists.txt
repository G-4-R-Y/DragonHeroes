# dh-godot — GDExtension. Today it exposes ONE thing: the arena policy forward
# pass, which the profile of 2026-09-13 showed to be 93% of the arena tick when
# written in GDScript. Bindings and math only; no gameplay rules (canon §10).
#
# godot-cpp's generated bindings do not compile under the sim's -Werror, so this
# directory relaxes it. -ffp-contract=off is INHERITED on purpose: the forward
# pass has to stay bit-identical to the GDScript one it replaces, and FMA
# contraction would silently change the last bits.
add_compile_options(-Wno-error)

set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/build_profile.json"
    CACHE PATH "Trim the generated bindings to the classes dh-godot uses" FORCE)
set(GODOTCPP_DISABLE_EXCEPTIONS ON CACHE BOOL "" FORCE)

# template_debug is what the Godot EDITOR binary loads, and training runs through
# that binary today. DH_GODOT_TARGET=template_release builds the one the release
# trainer export needs (tools/build_arena.sh).
set(DH_GODOT_TARGET "template_debug" CACHE STRING "godot-cpp target")
set(GODOTCPP_TARGET "${DH_GODOT_TARGET}" CACHE STRING "" FORCE)

add_subdirectory(third_party/godot-cpp)

add_library(dhgodot SHARED
    src/dh_policy_net.cpp
    src/register_types.cpp
)
target_link_libraries(dhgodot PRIVATE godot-cpp)
set_target_properties(dhgodot PROPERTIES
    PREFIX "lib"
    OUTPUT_NAME "dhgodot.linux.${DH_GODOT_TARGET}.x86_64"
    CXX_VISIBILITY_PRESET hidden
)
