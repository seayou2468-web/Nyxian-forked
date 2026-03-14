cmake_minimum_required(VERSION 3.20)
project(libroot LANGUAGES C)

set(CMAKE_C_STANDARD 11)

set(LIBROOT_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../libroot")
file(GLOB SRC_FILES "${LIBROOT_SRC_DIR}/src/*.c")

add_library(libroot STATIC ${SRC_FILES})

target_include_directories(libroot PUBLIC "${LIBROOT_SRC_DIR}/src")
target_include_directories(libroot PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../../BaseBin/.include")

target_compile_options(libroot PRIVATE
    -fobjc-arc
    -miphoneos-version-min=14.0
)

target_compile_definitions(libroot PRIVATE IPHONEOS_ARM64)

set_target_properties(libroot PROPERTIES
    ARCHIVE_OUTPUT_NAME "root"
)
