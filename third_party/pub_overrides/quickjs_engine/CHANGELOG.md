# Changelog

## 0.1.6

- Android: the plugin no longer applies the Kotlin Gradle Plugin. The plugin
  class is now Java, so apps on Android Gradle Plugin 9 build with built-in
  Kotlin on or off, instead of failing with "The
  'org.jetbrains.kotlin.android' plugin is no longer required" or warning
  that the plugin applies KGP
  ([#52](https://github.com/denisnadey/flutter_full_svg_support/issues/52)).
  `compileSdk` follows the app's `flutter.compileSdkVersion`, and the plugin
  compiles with Java 17.
- iOS and macOS: added Swift Package Manager support, so Flutter no longer
  lists `quickjs_engine` under "The following plugins do not support Swift
  Package Manager" and falls back to CocoaPods
  ([#55](https://github.com/denisnadey/flutter_full_svg_support/issues/55)).
  The bridge is embedded as a dynamic framework, so its exports survive
  `flutter build ipa` and macOS archives. One manifest works with Flutter
  3.38 (no generated `FlutterFramework` package) as well as 3.41 and later.
- iOS with CocoaPods: fixed the pod framework exporting none of the FFI
  bridge. CocoaPods silently ignored the podspec's `../native/cxx` sources,
  so on 0.1.5 and earlier every `evaluate()` on iOS failed with
  "Failed to lookup symbol 'jsNewRuntime'". The pod now compiles them.
- Fixed `QuickJsRuntime2(memoryLimit: ...)` with a positive limit throwing
  "Failed to lookup symbol 'jsSetMemoryLimit'" on every platform: the
  bridge now exports `jsSetMemoryLimit`. The prebuilt macOS bridge is
  rebuilt with it (still universal `arm64` + `x86_64`).
- Optimized iOS and macOS builds (Swift Package Manager release builds and
  the CocoaPods iOS Profile/Release configurations) define `NDEBUG`, like the
  CMake Release builds on the other platforms, so QuickJS assertions and
  debug dump code are no longer compiled in.
- Documented the Swift Package Manager opt-in per Flutter version, a Podfile
  workaround for apps that link pods statically, and the SwiftPM manifest
  cache after switching Flutter versions.
- CI: an Android Gradle Plugin 9 job builds a fresh app on the latest stable
  Flutter with built-in Kotlin on and off; a Darwin Swift Package Manager
  workflow (Flutter 3.38.1, 3.41.6, 3.47.4) builds iOS simulator, iOS
  archive and macOS release apps, checks that every bridge function and every
  symbol the Dart side looks up is exported, runs the macOS app, and guards
  the CocoaPods iOS pod exports; the macOS workflow also runs the package's
  unit tests.
- Thanks to [@sufiyansayyed](https://github.com/sufiyansayyed) for reporting
  the Android Gradle Plugin 9 issue and for the initial built-in Kotlin
  migration in [#53](https://github.com/denisnadey/flutter_full_svg_support/pull/53),
  and to [@DomingoMG](https://github.com/DomingoMG) for reporting the missing
  Swift Package Manager support.

## 0.1.5

- Fixed the macOS prebuilt bridge so it contains both arm64 and x86_64
  slices and is built with an explicit deployment target.
- Updated the native build script to produce a universal macOS bridge by
  default while preserving architecture and deployment-target overrides.
- Added a clean macOS release-build workflow that verifies the shipped and
  rebuilt bridge, the universal app executable, and the embedded dylib.
- Thanks to [@OrPudding](https://github.com/OrPudding) for contributing the
  universal macOS bridge fix in
  [#40](https://github.com/denisnadey/flutter_full_svg_support/pull/40).

## 0.1.4

- Fixed Windows builds by declaring the exported C API plugin class in the
  Flutter manifest, so generated registrants call
  `QuickjsEnginePluginCApiRegisterWithRegistrar` instead of the missing
  `QuickjsEnginePluginRegisterWithRegistrar` symbol.
- Added the canonical `quickjs_engine_plugin_c_api.h` public header expected by
  Flutter's Windows tooling while preserving the previous header as a
  compatibility include.
- Added a clean Windows release-build workflow to catch plugin registration,
  header, and native-link regressions.

## 0.1.3

- Linked Android native libraries with 16 KB ELF `LOAD` segment alignment so
  apps run natively on 16 KB page-size devices when built with NDK r27.
- Added release APK checks for both ELF segment alignment and ZIP alignment.
- Preserved compatibility with the package's CMake 3.10 minimum.

## 0.1.2

- Fixed Android release builds by linking the native QuickJS bridge with the
  Android `log` system library used by `__android_log_print`.
- Aligned the Android plugin Java/Kotlin JVM target settings so clean release
  builds complete on modern Flutter/Gradle toolchains.

## 0.1.1

Documentation + tooling additions, no engine changes.

- Rewrote `README.md` with explicit per-platform tables (Android / iOS / macOS / Linux / Windows) covering how the library is produced and what action is required from package consumers (usually: none).
- Added a **When you might need to rebuild** section so it's clear that typical app development needs no native toolchain.
- Added a **Troubleshooting** section: macOS "tests can't find dylib", deployment-target warnings, Android NDK requirements, Windows `cl.exe` environment, missing-dylib after fresh checkout.
- New `tool/build_native.ps1` — PowerShell version of the build script for Windows hosts. Handles MSVC's `Release\` config subdirectory.
- `tool/build_native.sh` is now platform-aware (detects macOS vs Linux via `uname -s`) and stages the output appropriately on macOS, while leaving the Linux build under `native/build/` since the consumer's plugin CMake rebuilds anyway.

## 0.1.0

Initial release.

- Forked from `flutter_js` 0.8.7 (MIT, by Ábner Oliveira). Dart-side API
  surface is API-compatible: `getJavascriptRuntime()`, `evaluate()`,
  `onMessage()`, `enableFetch()`, `enableHandlePromises()`,
  `QuickJsRuntime2`, `JavascriptRuntime` all work as upstream.
- **Replaced bundled JS engine** with [QuickJS-NG 0.14.0][qjsng] (May 2026).
  Same engine on every platform — Android, iOS, macOS, Linux, Windows. No
  more JavaScriptCore fallback on Apple targets.
- Patched the FFI bridge (`native/cxx/libfastdev_quickjs_runtime.cpp`)
  against QuickJS-NG's updated API:
    - `JS_NewClassID(rt, &id)` takes an explicit runtime
    - `JS_IsPromise`, `JS_IsArray`, `JS_IsError` are single-argument
    - `JS_BOOL` → `bool`
- Native build wiring:
    - Android: NDK CMake driven from `android/build.gradle` →
      `native/CMakeLists.txt` (armeabi-v7a, arm64-v8a, x86, x86_64).
    - iOS: podspec compiles bridge + QuickJS sources into the plugin
      framework via `source_files`.
    - macOS: podspec vendors a prebuilt
      `libquickjs_c_bridge_plugin.dylib`; rebuild via
      `tools/build_native.sh`.
    - Linux/Windows: plugin CMakeLists pulls in `native/CMakeLists.txt`
      via `add_subdirectory`.
- Runtime selector (`getJavascriptRuntime()`) always returns the QuickJS
  path on every platform; the `JavascriptCoreRuntime` bindings are kept
  in `lib/javascriptcore/` for ABI compatibility but unused.

[qjsng]: https://github.com/quickjs-ng/quickjs
