cmake_minimum_required(VERSION 3.20)
project(Nyxian LANGUAGES C)

# Set global version from Config.xcconfig (simplified parsing)
file(READ "Config.xcconfig" XCCONFIG_CONTENTS)
string(REGEX MATCH "VERSION = ([0-9.]+)" _ ${XCCONFIG_CONTENTS})
set(NXVERSION ${CMAKE_MATCH_1})
string(REGEX MATCH "BUILD_NUMBER = ([0-9.A-Za-z.]+)" _ ${XCCONFIG_CONTENTS})
set(NXBUILD ${CMAKE_MATCH_1})

# Subdirectories
add_subdirectory(cmake/libroot)
add_subdirectory(cmake/LLVM-On-iOS)
add_subdirectory(cmake/TrollStore)

# Main App configuration
set(SCHEME "Nyxian")
set(BUNDLE_ID "com.cr4zy.nyxian")

# Directories for artifacts
set(LINDCHAIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Nyxian/LindChain")
set(JB_SUPPORT_DIR "${LINDCHAIN_DIR}/JBSupport")

# Target for copying artifacts to LindChain
add_custom_target(prepare_lindchain ALL
    COMMAND ${CMAKE_COMMAND} -E make_directory "${JB_SUPPORT_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:libroot>" "${JB_SUPPORT_DIR}/libroot.a"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/libroot/src/libroot.h" "${JB_SUPPORT_DIR}/libroot.h"
    COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_BINARY_DIR}/cmake/TrollStore/_build/tshelper" "${JB_SUPPORT_DIR}/tshelper"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/cmake/LLVM-On-iOS/LLVM.xcframework" "${LINDCHAIN_DIR}/LLVM.xcframework"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_BINARY_DIR}/cmake/LLVM-On-iOS/Clang.xcframework" "${LINDCHAIN_DIR}/Clang.xcframework"
    DEPENDS libroot llvm_frameworks trollstore_components
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
    COMMAND ldid -Sent/nyxianforjb.xml "${CMAKE_CURRENT_BINARY_DIR}/NyxianForJB.xcarchive/Products/Applications/NyxianForJB.app"
    COMMAND ldid -Sent/tshelper.xml "${CMAKE_CURRENT_BINARY_DIR}/NyxianForJB.xcarchive/Products/Applications/NyxianForJB.app/tshelper"
    DEPENDS prepare_lindchain
)
