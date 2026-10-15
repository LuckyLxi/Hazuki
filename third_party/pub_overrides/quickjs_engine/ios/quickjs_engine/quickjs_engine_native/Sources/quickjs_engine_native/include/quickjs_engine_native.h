// Public headers of the quickjs_engine_native Swift Package Manager target.
//
// Xcode requires every C-family package target to have a public headers
// ("include") directory. The bridge's C API (native/cxx/
// libfastdev_quickjs_runtime.cpp) is consumed from Dart through dart:ffi and
// DynamicLibrary.process(), not from Swift or Objective-C, so nothing is
// declared here on purpose.
#ifndef QUICKJS_ENGINE_NATIVE_H
#define QUICKJS_ENGINE_NATIVE_H
#endif  // QUICKJS_ENGINE_NATIVE_H
