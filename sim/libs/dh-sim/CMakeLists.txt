add_library(dh-sim
    src/world.cpp
    src/arena.cpp
)
target_include_directories(dh-sim PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(dh-sim PUBLIC dh-math dh-content)
