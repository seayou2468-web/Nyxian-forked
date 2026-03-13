cmake_minimum_required(VERSION 3.20)
project(Nyxian LANGUAGES C CXX OBJC OBJCXX Swift)

set(CMAKE_Swift_LANGUAGE_VERSION 5.0)
set(CMAKE_OSX_SYSROOT iphoneos)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET 16.0)

# Set search paths
include_directories(
    Nyxian
    Nyxian/LindChain
    Nyxian/LindChain/ProcEnvironment
    Nyxian/LindChain/Private
    Shared
)

# Source files (simplified for now, ideally glob or list all)
file(GLOB_RECURSE SOURCES_C "Nyxian/*.c")
file(GLOB_RECURSE SOURCES_CPP "Nyxian/*.cpp")
file(GLOB_RECURSE SOURCES_M "Nyxian/*.m")
file(GLOB_RECURSE SOURCES_MM "Nyxian/*.mm")
file(GLOB_RECURSE SOURCES_SWIFT "Nyxian/*.swift")

add_executable(Nyxian ${SOURCES_C} ${SOURCES_CPP} ${SOURCES_M} ${SOURCES_MM} ${SOURCES_SWIFT})

# Add frameworks
target_link_libraries(Nyxian PRIVATE
    "-framework Foundation"
    "-framework UIKit"
    "-framework Security"
    "-framework CoreGraphics"
)

# Set output to bundle
set_target_properties(Nyxian PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.cr4zy.nyxian"
    MACOSX_BUNDLE_BUNDLE_NAME "Nyxian"
    MACOSX_BUNDLE_BUNDLE_VERSION "0.9.0"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "0.9.0"
)
