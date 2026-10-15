cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "quickjs_engine")
project(${PROJECT_NAME} LANGUAGES CXX C)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../native" "${CMAKE_BINARY_DIR}/quickjs_engine_native")

add_library(${PLUGIN_NAME} SHARED "quickjs_engine_plugin.cpp")
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

set(quickjs_engine_bundled_libraries
  $<TARGET_FILE:quickjs_c_bridge_plugin>
  PARENT_SCOPE
)
