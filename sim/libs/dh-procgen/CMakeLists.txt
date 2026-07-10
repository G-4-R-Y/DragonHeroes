add_library(dh-procgen
    src/chunk.cpp
)
target_include_directories(dh-procgen PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(dh-procgen PUBLIC dh-math)
