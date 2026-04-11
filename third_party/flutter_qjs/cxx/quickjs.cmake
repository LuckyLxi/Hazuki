cmake_minimum_required(VERSION 3.7 FATAL_ERROR)
set(CXX_LIB_DIR ${CMAKE_CURRENT_LIST_DIR})
project(quickjs LANGUAGES C)

# quickjs
if(MSVC AND EXISTS "${CXX_LIB_DIR}/quickjs_msvc")
    # The latest upstream QuickJS snapshot does not build cleanly with MSVC.
    # Keep the legacy snapshot on Windows while newer toolchains use the
    # refreshed upstream sources.
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
