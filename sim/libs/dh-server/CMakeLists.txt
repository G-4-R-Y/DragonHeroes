add_executable(dh-server
    src/main.cpp
)
target_link_libraries(dh-server PRIVATE dh-sim dh-procgen dh-net)
