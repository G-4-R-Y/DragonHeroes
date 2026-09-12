add_executable(sim-tests
    test_main.cpp
)
target_link_libraries(sim-tests PRIVATE dh-sim dh-procgen dh-net)
add_test(NAME sim-tests COMMAND sim-tests)

add_executable(living-tests living_test.cpp)
target_link_libraries(living-tests PRIVATE dh-sim)
add_test(NAME living-tests COMMAND living-tests)

add_executable(lair-tests lair_test.cpp)
target_link_libraries(lair-tests PRIVATE dh-sim dh-procgen)
add_test(NAME lair-tests COMMAND lair-tests)

add_executable(lair-profile-tests lair_profile_test.cpp ../libs/dh-server/src/lair_profile.cpp)
target_link_libraries(lair-profile-tests PRIVATE dh-sim)
add_test(NAME lair-profile-tests COMMAND lair-profile-tests)
