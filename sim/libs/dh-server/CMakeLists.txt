add_executable(dh-server
    src/main.cpp
    src/living_preview.cpp
)
target_link_libraries(dh-server PRIVATE dh-sim dh-procgen dh-net)

add_executable(dh-effect-lab src/effect_lab.cpp)
target_link_libraries(dh-effect-lab PRIVATE dh-sim)

if(WIN32)
    target_link_libraries(dh-server PRIVATE ws2_32)
    enable_language(RC)
    set(DH_APP_ICON "${CMAKE_CURRENT_SOURCE_DIR}/../../../game/branding/dragon-heroes.ico")
    configure_file(src/app_icon.rc.in app_icon.rc @ONLY)
    target_sources(dh-server PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/app_icon.rc")
    target_sources(dh-effect-lab PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/app_icon.rc")
endif()
