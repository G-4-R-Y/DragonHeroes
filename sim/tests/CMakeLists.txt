add_executable(sim-tests
    test_main.cpp
)
target_link_libraries(sim-tests PRIVATE dh-sim dh-procgen dh-net)
add_test(NAME sim-tests COMMAND sim-tests)

add_executable(living-tests living_test.cpp)
target_link_libraries(living-tests PRIVATE dh-sim)
add_test(NAME living-tests COMMAND living-tests)
