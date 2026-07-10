add_executable(sim-tests
    test_main.cpp
)
target_link_libraries(sim-tests PRIVATE dh-sim dh-procgen dh-net)
add_test(NAME sim-tests COMMAND sim-tests)
