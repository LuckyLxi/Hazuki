cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
set(CXX_LIB_DIR ${CMAKE_CURRENT_LIST_DIR})
project(quickjs LANGUAGES C)

# QuickJS source selection
#
# Hazuki intentionally keeps two source snapshots:
# - quickjs: current upstream for Android and non-MSVC toolchains
# - quickjs_msvc: pinned legacy fallback for MSVC-based local development
#
# The goal is to keep the shipping Android path on the newest upstream runtime
# without blocking Windows development when upstream QuickJS changes break the
# existing MSVC plugin build.
if(MSVC AND EXISTS "${CXX_LIB_DIR}/quickjs_msvc")
    # Keep the legacy snapshot only for MSVC until the newer upstream sources
    # build cleanly in this plugin layout.
    set(QUICK_JS_LIB_DIR ${CXX_LIB_DIR}/quickjs_msvc)
else()
    set(QUICK_JS_LIB_DIR ${CXX_LIB_DIR}/quickjs)
endif()
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
set(QUICKJS_SOURCES
    ${QUICK_JS_LIB_DIR}/cutils.c
    ${QUICK_JS_LIB_DIR}/libregexp.c
    ${QUICK_JS_LIB_DIR}/libunicode.c
    ${QUICK_JS_LIB_DIR}/quickjs.c
)
if(NOT MSVC)
    list(APPEND QUICKJS_SOURCES ${QUICK_JS_LIB_DIR}/dtoa.c)
endif()
add_library(quickjs STATIC ${QUICKJS_SOURCES})

target_compile_definitions(quickjs PRIVATE CONFIG_VERSION="${QUICKJS_VERSION}")
target_compile_definitions(quickjs PRIVATE $<$<CONFIG:Debug>:DUMP_LEAKS=1>)

if(MSVC)
    # https://github.com/ekibun/flutter_qjs/issues/7
    target_compile_options(quickjs PRIVATE "/Oi-")
endif()
