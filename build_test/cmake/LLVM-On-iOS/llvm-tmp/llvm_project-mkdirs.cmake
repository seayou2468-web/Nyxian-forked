# Distributed under the OSI-approved BSD 3-Clause License.  See accompanying
# file Copyright.txt or https://cmake.org/licensing for details.

cmake_minimum_required(VERSION 3.5)

file(MAKE_DIRECTORY
  "/app/build_test/cmake/LLVM-On-iOS/llvm-project-19.1.7.src"
  "/app/build_test/cmake/LLVM-On-iOS/llvm-build"
  "/app/build_test/cmake/LLVM-On-iOS/llvm_project-prefix"
  "/app/build_test/cmake/LLVM-On-iOS/llvm-tmp"
  "/app/build_test/cmake/LLVM-On-iOS/llvm-stamp"
  "/app/build_test/cmake/LLVM-On-iOS/llvm_project-prefix/src"
  "/app/build_test/cmake/LLVM-On-iOS/llvm-stamp"
)

set(configSubDirs )
foreach(subDir IN LISTS configSubDirs)
    file(MAKE_DIRECTORY "/app/build_test/cmake/LLVM-On-iOS/llvm-stamp/${subDir}")
endforeach()
if(cfgdir)
  file(MAKE_DIRECTORY "/app/build_test/cmake/LLVM-On-iOS/llvm-stamp${cfgdir}") # cfgdir has leading slash
endif()
