cmake_minimum_required(VERSION 3.10)

project(quickjs_engine_native LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(QJS_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx/quickjs/quickjs.c
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx/quickjs/libregexp.c
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx/quickjs/libunicode.c
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx/quickjs/dtoa.c
)

set(BRIDGE_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx/libfastdev_quickjs_runtime.cpp
)

set(BRIDGE_NAME quickjs_c_bridge_plugin)

add_library(${BRIDGE_NAME} SHARED ${BRIDGE_SOURCES} ${QJS_SOURCES})

target_include_directories(${BRIDGE_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx
  ${CMAKE_CURRENT_SOURCE_DIR}/cxx/quickjs
)

target_compile_definitions(${BRIDGE_NAME} PRIVATE
  CONFIG_VERSION="ng-0.14.0"
)

set_target_properties(${BRIDGE_NAME} PROPERTIES
  C_VISIBILITY_PRESET hidden
  CXX_VISIBILITY_PRESET hidden
  OUTPUT_NAME quickjs_c_bridge_plugin
)

if(APPLE)
  target_link_libraries(${BRIDGE_NAME} PRIVATE m)
  set_target_properties(${BRIDGE_NAME} PROPERTIES
    MACOSX_RPATH ON
    INSTALL_NAME_DIR "@rpath"
  )
elseif(UNIX)
  if(ANDROID)
    find_library(log-lib log)
    target_link_libraries(${BRIDGE_NAME} PRIVATE m ${log-lib})
    # NDK r28 and newer use 16 KB ELF LOAD alignment by default. Flutter
    # 3.38 still defaults to NDK r27, where these flags are required for the
    # resulting .so to run natively on Android devices with 16 KB pages.
    if(COMMAND target_link_options)
      target_link_options(${BRIDGE_NAME} PRIVATE
        "-Wl,-z,max-page-size=16384"
        "-Wl,-z,common-page-size=16384"
      )
    else()
      # target_link_options was introduced in CMake 3.13. Keep the plugin's
      # advertised CMake 3.10 minimum working for older host toolchains.
      set_property(TARGET ${BRIDGE_NAME} APPEND_STRING PROPERTY LINK_FLAGS
        " -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
      )
    endif()
  else()
    target_link_libraries(${BRIDGE_NAME} PRIVATE m)
  endif()
elseif(WIN32)
  target_compile_definitions(${BRIDGE_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

# Hint for plugin platform CMakeLists to bundle the produced .so
set(quickjs_engine_bundled_libraries
  $<TARGET_FILE:${BRIDGE_NAME}>
  PARENT_SCOPE
)
