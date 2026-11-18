import 'dart:ffi';

import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart';

String? _libraryPath;

/// Sets the ONNX Runtime shared library to load in the current isolate.
///
/// Hazuki downloads the library on demand instead of bundling it, so the path
/// must be set before any ONNX Runtime API is used. Each isolate has its own
/// copy of this setting.
void setOnnxRuntimeLibraryPath(String path) {
  if (_libraryPath != null && _libraryPath != path) {
    throw StateError('ONNX Runtime is already configured with $_libraryPath');
  }
  _libraryPath = path;
}

final DynamicLibrary _dylib = () {
  final path = _libraryPath;
  if (path == null) {
    throw StateError('ONNX Runtime library path has not been set');
  }
  return DynamicLibrary.open(path);
}();

/// OnnxRuntime Bindings
final onnxRuntimeBinding = OnnxRuntimeBindings(_dylib);
