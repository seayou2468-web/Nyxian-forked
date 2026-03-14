cmake_minimum_required(VERSION 3.20)
project(TrollStore NONE)

set(TS_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../TrollStore")
set(TS_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/_build")

add_custom_command(
    OUTPUT "${TS_BUILD_DIR}/tshelper"
    COMMAND ${CMAKE_MAKE_PROGRAM} pre_build
    COMMAND ${CMAKE_MAKE_PROGRAM} make_fastPathSign MAKECMDGOALS=
    COMMAND ${CMAKE_MAKE_PROGRAM} make_roothelper MAKECMDGOALS=
    COMMAND ${CMAKE_MAKE_PROGRAM} make_trollstore MAKECMDGOALS=
    COMMAND ${CMAKE_MAKE_PROGRAM} make_trollhelper_embedded MAKECMDGOALS=
    COMMAND cp RootHelper/.theos/obj/trollstorehelper "${TS_BUILD_DIR}/tshelper"
    WORKING_DIRECTORY "${TS_SRC_DIR}"
    COMMENT "Building TrollStore components using make"
)

add_custom_target(trollstore_components ALL
    DEPENDS "${TS_BUILD_DIR}/tshelper"
)
