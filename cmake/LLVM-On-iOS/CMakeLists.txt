cmake_minimum_required(VERSION 3.20)
project(LLVM-On-iOS NONE)

include(ExternalProject)

set(LLVM_VER "19.1.7")
set(LLVM_URL "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/llvm-project-${LLVM_VER}.src.tar.xz")

set(LLVM_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/llvm-build")
set(LLVM_INSTALL_DIR "${CMAKE_CURRENT_BINARY_DIR}/LLVM-iphoneos")
set(LLVM_SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/llvm-project-${LLVM_VER}.src")

ExternalProject_Add(llvm_project
    URL ${LLVM_URL}
    SOURCE_DIR ${LLVM_SOURCE_DIR}
    BINARY_DIR ${LLVM_BINARY_DIR}
    STAMP_DIR ${CMAKE_CURRENT_BINARY_DIR}/llvm-stamp
    TMP_DIR ${CMAKE_CURRENT_BINARY_DIR}/llvm-tmp
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    CONFIGURE_COMMAND cmake -G Ninja
        -DLLVM_ENABLE_PROJECTS=clang\;lld
        -DLLVM_TARGETS_TO_BUILD=AArch64
        -DLLVM_TARGET_ARCH=AArch64
        -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios
        -DLLVM_BUILD_TOOLS=OFF
        -DCLANG_BUILD_TOOLS=OFF
        -DBUILD_SHARED_LIBS=OFF
        -DLLVM_ENABLE_ZLIB=OFF
        -DLLVM_ENABLE_ZSTD=OFF
        -DLLVM_ENABLE_THREADS=ON
        -DLLVM_ENABLE_UNWIND_TABLES=OFF
        -DLLVM_ENABLE_EH=OFF
        -DLLVM_ENABLE_RTTI=ON
        -DLLVM_ENABLE_TERMINFO=OFF
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX=${LLVM_INSTALL_DIR}
        -DCMAKE_TOOLCHAIN_FILE=${LLVM_SOURCE_DIR}/llvm/cmake/platforms/iOS.cmake
        -DLLVM_ENABLE_LIBXML2=OFF
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF
        -DCLANG_ENABLE_ARCMT=OFF
        -DCLANG_TABLEGEN_TARGETS=AArch64
        -DCMAKE_C_FLAGS=-target\ arm64-apple-ios14.0\ -isysroot\ ${CMAKE_OSX_SYSROOT}
        -DCMAKE_CXX_FLAGS=-target\ arm64-apple-ios14.0\ -isysroot\ ${CMAKE_OSX_SYSROOT}
        -DCMAKE_OSX_ARCHITECTURES=arm64
        -DLLVM_FORCE_VC_REPOSITORY=https://github.com/ProjectNyxian/LLVM-On-iOS
        ${LLVM_SOURCE_DIR}/llvm
    BUILD_COMMAND cmake --build . --target install
    INSTALL_COMMAND ""
)

ExternalProject_Add_Step(llvm_project patch_cache
    COMMAND sed -i.bak "s/^HAVE_FFI_CALL:INTERNAL=/HAVE_FFI_CALL:INTERNAL=1/g" ${LLVM_BINARY_DIR}/CMakeCache.txt
    DEPENDEES configure
    DEPENDERS build
)

# Combine LLVM libraries
add_custom_command(
    OUTPUT "${LLVM_INSTALL_DIR}/llvm.a"
    COMMAND /usr/bin/libtool -static -o "${LLVM_INSTALL_DIR}/llvm.a"
            ${LLVM_INSTALL_DIR}/lib/libLLVM*.a
            ${LLVM_INSTALL_DIR}/lib/libclang*.a
            ${LLVM_INSTALL_DIR}/lib/liblld*.a
    DEPENDS llvm_project
)

# Create LLVM.xcframework
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/LLVM.xcframework"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/llvm-headers"
    COMMAND bash -c "cp -r ${LLVM_INSTALL_DIR}/include/* ${CMAKE_CURRENT_BINARY_DIR}/llvm-headers/"
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/llvm-headers/clang-c"
    COMMAND xcodebuild -create-xcframework
            -library "${LLVM_INSTALL_DIR}/llvm.a"
            -headers "${CMAKE_CURRENT_BINARY_DIR}/llvm-headers"
            -output "${CMAKE_CURRENT_BINARY_DIR}/LLVM.xcframework"
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/llvm-headers"
    DEPENDS "${LLVM_INSTALL_DIR}/llvm.a"
)

# Create Clang.xcframework
add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/Clang.xcframework"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/clang-headers"
    COMMAND bash -c "cp -r ${LLVM_INSTALL_DIR}/include/clang-c ${CMAKE_CURRENT_BINARY_DIR}/clang-headers/"
    COMMAND xcodebuild -create-xcframework
            -library "${LLVM_INSTALL_DIR}/lib/libclang.dylib"
            -headers "${CMAKE_CURRENT_BINARY_DIR}/clang-headers"
            -output "${CMAKE_CURRENT_BINARY_DIR}/Clang.xcframework"
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_CURRENT_BINARY_DIR}/clang-headers"
    DEPENDS llvm_project
)

add_custom_target(llvm_frameworks ALL
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/LLVM.xcframework" "${CMAKE_CURRENT_BINARY_DIR}/Clang.xcframework"
)
