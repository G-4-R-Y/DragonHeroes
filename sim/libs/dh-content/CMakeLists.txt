add_library(dh-content
    src/content_db.cpp
)
target_include_directories(dh-content PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(dh-content PUBLIC dh-math)
