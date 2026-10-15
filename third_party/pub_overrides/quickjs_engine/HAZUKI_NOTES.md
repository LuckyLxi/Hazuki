# Hazuki patches to quickjs_engine 0.1.6

Base: the published [quickjs_engine 0.1.6](https://pub.dev/packages/quickjs_engine/versions/0.1.6) archive, including QuickJS-NG 0.14.0 and its original licenses.

- The native bridge accepts the timeout already passed by Dart and installs a monotonic-clock interrupt handler. Evaluation, direct function calls, and Promise jobs each start a new execution deadline. This preserves Hazuki's existing five-second script execution limit; waiting for HTTP or other Dart Futures does not consume that limit.
- The Dart FFI bridge removes freed runtimes from `runtimeOpaques`, so reloading or inspecting plugins does not retain the old engine and callbacks.
- String conversion handles both flat strings and QuickJS-NG rope strings, preserving long concatenated values in evaluations, Promise results, and host messages.
- `executePendingJob()` drains synchronously and reports native job errors to its caller. Hazuki can then fail pending operations after an interrupted Promise job instead of leaving them waiting indefinitely.
- macOS CocoaPods compiles the same patched native sources as iOS, SwiftPM, Android, Linux, and Windows. The upstream prebuilt macOS dylib is omitted because it lacks the timeout patch.

Hazuki's `SourceScriptEngine` adapts `JsEvalResult`, drives the runtime's message port, installs the source SDK's host APIs, and defers native disposal until outstanding host Futures have released their callbacks. Regression tests are in `test/services/source/source_script_engine_test.dart` in the application.

From the application root, run `dart run tool/build_quickjs_test_library.dart` before `flutter test`. It resolves this package from the active package configuration and builds the native library at a location supported by the package's test loader. CMake and a C++17 compiler are required.
