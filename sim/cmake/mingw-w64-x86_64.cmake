# Cross toolchain: Linux -> Windows x86_64 via portable llvm-mingw
# (~/.local/share/dh-toolchains — no sudo needed; replaces the mingw-w64 apt ask).
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(TOOLCHAIN "$ENV{HOME}/.local/share/dh-toolchains/llvm-mingw-20260908-ucrt-ubuntu-22.04-x86_64")
set(CMAKE_C_COMPILER ${TOOLCHAIN}/bin/x86_64-w64-mingw32-clang)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN}/bin/x86_64-w64-mingw32-clang++)
set(CMAKE_RC_COMPILER ${TOOLCHAIN}/bin/x86_64-w64-mingw32-windres)
set(CMAKE_FIND_ROOT_PATH ${TOOLCHAIN}/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
