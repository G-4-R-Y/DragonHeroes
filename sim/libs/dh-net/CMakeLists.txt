add_library(dh-net INTERFACE)
target_include_directories(dh-net INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(dh-net INTERFACE dh-math)
