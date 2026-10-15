// Swift Package Manager forwarder. Do not add code here.
//
// SwiftPM targets cannot list sources outside their package, but the
// QuickJS-NG sources and the Dart FFI bridge live in the plugin's shared
// native/cxx/ tree, which the podspec and the Android / Linux / Windows CMake
// build (native/CMakeLists.txt) compile too. This translation unit includes
// the shared file by relative path instead of duplicating it. Quoted
// #includes inside it resolve against the included file's own directory, so
// no extra header search paths are needed.
//
// Keep the settings below in sync with native/CMakeLists.txt (which also
// builds the prebuilt dylib that macos/quickjs_engine.podspec vendors). The
// C11 / C++17 standards are set in Package.swift.
#ifndef CONFIG_VERSION
#define CONFIG_VERSION "ng-0.14.0"
#endif
#pragma clang diagnostic ignored "-Wunused-function"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-but-set-variable"

#include "../../../../../native/cxx/libfastdev_quickjs_runtime.cpp"
