add_executable(dh-server
    src/main.cpp
)
target_link_libraries(dh-server PRIVATE dh-sim dh-procgen dh-net)

add_executable(dh-effect-lab src/effect_lab.cpp)
target_link_libraries(dh-effect-lab PRIVATE dh-sim)
