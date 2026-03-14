cmake_minimum_required(VERSION 3.20)
project(Nyxian LANGUAGES C)

function(ensure_submodule_ready submodule_path required_file)
    set(_absolute_required_file "${CMAKE_CURRENT_SOURCE_DIR}/${required_file}")
    if(EXISTS "${_absolute_required_file}")
        return()
    endif()

    find_package(Git QUIET)
    if(NOT GIT_FOUND)
        message(FATAL_ERROR
            "Required submodule '${submodule_path}' is missing (${required_file}) and git is unavailable. "
            "Run 'git submodule update --init --recursive'."
        )
    endif()

    message(STATUS "Submodule '${submodule_path}' is not initialized. Attempting to fetch it...")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" submodule update --init --recursive -- "${submodule_path}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE _submodule_result
        OUTPUT_VARIABLE _submodule_stdout
        ERROR_VARIABLE _submodule_stderr
    )

    if(NOT _submodule_result EQUAL 0 OR NOT EXISTS "${_absolute_required_file}")
        string(STRIP "${_submodule_stdout}" _submodule_stdout)
        string(STRIP "${_submodule_stderr}" _submodule_stderr)
        message(FATAL_ERROR
            "Failed to initialize submodule '${submodule_path}'.\n"
            "stdout: ${_submodule_stdout}\n"
            "stderr: ${_submodule_stderr}\n"
            "Run 'git submodule update --init --recursive' manually and retry."
        )
    endif()
endfunction()

# Set iOS defaults for the entire project
if(APPLE)
    if(NOT CMAKE_OSX_SYSROOT)
        if(DEFINED ENV{THEOS_PLATFORM_SDK_ROOT})
            set(CMAKE_OSX_SYSROOT $ENV{THEOS_PLATFORM_SDK_ROOT})
        else()
            execute_process(COMMAND xcrun --sdk iphoneos --show-sdk-path
                            OUTPUT_VARIABLE IOS_SDK_PATH
                            OUTPUT_STRIP_TRAILING_WHITESPACE)
            set(CMAKE_OSX_SYSROOT ${IOS_SDK_PATH})
        endif()
    endif()
    if(NOT CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES arm64)
    endif()
endif()

# Set global version from Config.xcconfig (simplified parsing)
file(READ "Config.xcconfig" XCCONFIG_CONTENTS)
string(REGEX MATCH "VERSION = ([0-9.]+)" _ ${XCCONFIG_CONTENTS})
set(NXVERSION ${CMAKE_MATCH_1})
string(REGEX MATCH "BUILD_NUMBER = ([0-9.A-Za-z.]+)" _ ${XCCONFIG_CONTENTS})
set(NXBUILD ${CMAKE_MATCH_1})

# Ensure required git submodules are available before configuring child projects.
ensure_submodule_ready("libroot" "libroot/src/libroot.h")
ensure_submodule_ready("TrollStore" "TrollStore/Makefile")
ensure_submodule_ready("LLVM-On-iOS" "LLVM-On-iOS/Makefile")

# Subdirectories
add_subdirectory(cmake/libroot)
add_subdirectory(cmake/TrollStore)

# Check if LLVM frameworks already exist
set(LINDCHAIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Nyxian/LindChain")
set(JB_SUPPORT_DIR "${LINDCHAIN_DIR}/JBSupport")

if(EXISTS "${LINDCHAIN_DIR}/LLVM.xcframework" AND EXISTS "${LINDCHAIN_DIR}/Clang.xcframework")
    message(STATUS "LLVM frameworks already exist in ${LINDCHAIN_DIR}. Skipping LLVM build.")
    set(BUILD_LLVM OFF)
else()
    message(STATUS "LLVM frameworks NOT found. Adding LLVM build subdirectory.")
    add_subdirectory(cmake/LLVM-On-iOS)
    set(BUILD_LLVM ON)
endif()

# Main App configuration
set(SCHEME "Nyxian")
set(BUNDLE_ID "com.cr4zy.nyxian")

# Target for copying artifacts to LindChain
set(PREPARE_COMMANDS
    COMMAND ${CMAKE_COMMAND} -E make_directory "${JB_SUPPORT_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:libroot>" "${JB_SUPPORT_DIR}/libroot.a"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/libroot/src/libroot.h" "${JB_SUPPORT_DIR}/libroot.h"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/cmake/TrollStore/_build/tshelper" "${JB_SUPPORT_DIR}/tshelper"
)

set(PREPARE_DEPENDS libroot trollstore_components)

if(BUILD_LLVM)
    list(APPEND PREPARE_COMMANDS
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/cmake/LLVM-On-iOS/LLVM.xcframework" "${LINDCHAIN_DIR}/LLVM.xcframework"
        COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/cmake/LLVM-On-iOS/Clang.xcframework" "${LINDCHAIN_DIR}/Clang.xcframework"
    )
    list(APPEND PREPARE_DEPENDS llvm_frameworks)
endif()

add_custom_target(prepare_lindchain ALL
    ${PREPARE_COMMANDS}
    DEPENDS ${PREPARE_DEPENDS}
)

# Main build and package target
add_custom_target(jailed ALL
    COMMAND chmod +x version.sh
    COMMAND ./version.sh
    COMMAND xcodebuild
            -project Nyxian.xcodeproj
            -scheme ${SCHEME}
            -configuration Debug
            -destination 'generic/platform=iOS'
            -archivePath "${CMAKE_CURRENT_BINARY_DIR}/Nyxian.xcarchive"
            archive
            CODE_SIGN_IDENTITY=""
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGNING_ALLOWED=NO
            CODE_SIGN_IDENTITY_EXEMPT=YES
    COMMAND mkdir -p "${CMAKE_CURRENT_BINARY_DIR}/Payload"
    COMMAND cp -r "${CMAKE_CURRENT_BINARY_DIR}/Nyxian.xcarchive/Products/Applications" "${CMAKE_CURRENT_BINARY_DIR}/Payload"
    COMMAND zip -r "${CMAKE_CURRENT_BINARY_DIR}/Nyxian.ipa" "${CMAKE_CURRENT_BINARY_DIR}/Payload"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    DEPENDS prepare_lindchain
    COMMENT "Building and packaging Nyxian iOS app"
)

# Rootless target (example)
add_custom_target(rootless
    COMMAND xcodebuild
            -project Nyxian.xcodeproj
            -scheme NyxianForJB
            -configuration Debug
            -destination 'generic/platform=iOS'
            -archivePath "${CMAKE_CURRENT_BINARY_DIR}/NyxianForJB.xcarchive"
            archive
            CODE_SIGN_IDENTITY=""
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGNING_ALLOWED=NO
            CODE_SIGN_IDENTITY_EXEMPT=YES
    COMMAND ldid -Sent/nyxianforjb.xml "${CMAKE_CURRENT_BINARY_DIR}/NyxianForJB.xcarchive/Products/Applications/NyxianForJB.app"
    COMMAND ldid -Sent/tshelper.xml "${CMAKE_CURRENT_BINARY_DIR}/NyxianForJB.xcarchive/Products/Applications/NyxianForJB.app/tshelper"
    DEPENDS prepare_lindchain
)
