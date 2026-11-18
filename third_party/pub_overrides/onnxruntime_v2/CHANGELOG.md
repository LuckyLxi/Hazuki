## 1.23.2+2
* Fixes Linux and Windows build issues
* Updated dependencies

## 1.23.2+1
* Fix iOS podspec issue

## 1.23.2
* Update ONNX Runtime to v1.23.2.
* Android: remove manual `.so` files from `android/src/main/jniLibs/` and use Gradle dependency `com.microsoft.onnxruntime:onnxruntime-android:1.23.2`.
* iOS: bump `onnxruntime-objc` pod from 1.22.0 to 1.23.2.


## 1.23.1
* add libonnx 16kb compatible for x86 and x64

## 1.23.0
* full GPU and hardware acceleration support, results in speedups on compatible devices


## 1.22.0+1
* compile sdk upgraded

## 1.22.0
* 16Kb page size support for Android
* Updated to ONNX Runtime 1.22.0
* Added support for `setSessionExecutionMode` to control sequential/parallel execution
* Added `OrtSessionExecutionMode` enum with `ortSequential` and `ortParallel` options
* Added `OrtSessionGraphOptimizationLevel` type alias for compatibility
* Enhanced session configuration options for better performance control

## 1.4.1

* Fixes a memory leak when creating tensor.

## 1.4.0

* Fixes a memory leak when creating tensor.

## 1.3.0

* Attempts to support macOS, Windows and Linux.

## 1.2.0

* Compatible with Gradle8.

## 1.1.0

* Exposes some methods of input and output name.
* Adds some documentation comments.

## 1.0.0

* Initial release.
