cmake_minimum_required(VERSION 3.10 FATAL_ERROR)
set(CXX_LIB_DIR ${CMAKE_CURRENT_LIST_DIR})
project(quickjs LANGUAGES C)

# All toolchains (including MSVC) now use the same upstream QuickJS snapshot.
# MSVC compatibility patches are applied directly in the source files via
# #ifdef _MSC_VER guards. The legacy quickjs_msvc/ directory is retained for
# reference but is no longer used by the build.
set(QUICK_JS_LIB_DIR ${CXX_LIB_DIR}/quickjs)
file (STRINGS "${QUICK_JS_LIB_DIR}/VERSION" QUICKJS_VERSION)
set(QUICKJS_SOURCES
    ${QUICK_JS_LIB_DIR}/cutils.c
    ${QUICK_JS_LIB_DIR}/libregexp.c
    ${QUICK_JS_LIB_DIR}/libunicode.c
    ${QUICK_JS_LIB_DIR}/quickjs.c
)
list(APPEND QUICKJS_SOURCES ${QUICK_JS_LIB_DIR}/dtoa.c)
add_library(quickjs STATIC ${QUICKJS_SOURCES})

target_compile_definitions(quickjs PRIVATE CONFIG_VERSION="${QUICKJS_VERSION}")
target_compile_definitions(quickjs PRIVATE $<$<CONFIG:Debug>:DUMP_LEAKS=1>)

if(MSVC)
    # https://github.com/ekibun/flutter_qjs/issues/7
    target_compile_options(quickjs PRIVATE "/Oi-")
endif()
