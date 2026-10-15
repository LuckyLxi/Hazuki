# quickjs_engine

A self-contained, up-to-date QuickJS runtime for Flutter — bundles
[**QuickJS-NG 0.14.0**][qjsng] (2026 release) directly into your app, so
every platform runs the **same** modern JavaScript engine. No
JavaScriptCore fallback. No 5-year-old vendored copy of QuickJS. No
mystery platform divergence.

[qjsng]: https://github.com/quickjs-ng/quickjs

> A fork of [`flutter_js`][upstream] by Ábner Oliveira, with the JS engine
> replaced by `quickjs-ng` and the FFI bridge patched against its new API.
> Born out of debugging an SVGator player that produced different numeric
> output on iOS (JSC) vs Android (old QuickJS) vs Chrome (V8) — see the
> "Why" section below.

[upstream]: https://pub.dev/packages/flutter_js

## Features

- 🌍 **Single JS engine on every platform** — macOS, iOS, Android, Linux,
  Windows. No more "works on Android, broken on iOS" QuickJS-vs-JSC bugs.
- 🚀 **Modern QuickJS-NG** — Symbol.iterator, Proxy, async/await, Promise,
  WeakMap/WeakSet, BigInt, regex named groups — all the ES2020+ features
  the 2021-vintage upstream QuickJS doesn't have.
- 🔌 **API-compatible drop-in** for projects already using `flutter_js`
  (`getJavascriptRuntime()`, `evaluate()`, `onMessage()`,
  `enableFetch()`, `enableHandlePromises()`).
- 🧰 **No native toolchain required for typical use** — `flutter pub get`
  + `flutter run` does everything. The plugin compiles the bridge for
  Android/iOS/Linux/Windows, and ships a prebuilt dylib for macOS so
  CocoaPods doesn't need to compile C++ for that target.
- 📦 **Swift Package Manager and CocoaPods** on iOS and macOS — works
  with Flutter's default Swift Package Manager integration, and still
  supports projects that use CocoaPods.

## Quick start

```yaml
dependencies:
  quickjs_engine: ^0.1.6
```

```dart
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  final js = getJavascriptRuntime(xhr: false);

  // Evaluate.
  final r = js.evaluate('2 + 2');
  print(r.stringResult); // 4

  // Bidirectional messaging — call back into Dart from JS.
  js.onMessage('myChannel', (dynamic args) {
    print('JS sent: $args');
    return 'pong';
  });
  js.evaluate('sendMessage("myChannel", JSON.stringify({hello: "world"}))');

  js.dispose();
}
```

## Why a fork?

The published `flutter_js` package uses QuickJS dated **2021-03-27** on
Android/Windows/Linux, and **JavaScriptCore** on macOS/iOS. Two
consequences matter for anyone running a non-trivial JS workload (e.g.
SVG animation players, custom expression engines, JSON-schema validators,
sandboxed user scripts):

1. **Engine divergence per platform.** JSC and QuickJS-2021 have
   different numeric edge cases, garbage-collection timings, and
   proxy/iterator semantics. Code that works on Android may misbehave on
   iOS without warning.
2. **Old engine, old bugs.** QuickJS-NG has had ~5 years of fixes since
   2021 (codegen, regex, arithmetic, GC). Most are silent — but if your
   JS uses Proxy traps, Symbol iteration, async/await, or arc-length-style
   bezier math (we hit this one), the diff is real.

This package bundles **one** engine — QuickJS-NG 0.14.0, same on every
platform — and ships a patched FFI bridge that compiles against the new
QuickJS-NG API (`JS_NewClassID(rt, &id)`, `JS_IsPromise(val)`,
`JS_IsArray(val)`, etc.).

## Platform support

| Platform | How the library is produced | Action required from you |
|----------|-----------------------------|--------------------------|
| **Android** | Built from source by the NDK CMake pipeline (driven by `android/build.gradle` → `native/CMakeLists.txt`). 4 ABIs (`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`), with 16 KB ELF page alignment. The Android plugin class is Java and the plugin does not apply the Kotlin Gradle Plugin, so it builds with AGP 8 and AGP 9 (built-in Kotlin on or off). | None — `flutter run -d android` handles it. Apps that package uncompressed native libraries should use Android Gradle Plugin 8.5.1 or newer for 16 KB ZIP alignment. |
| **iOS** | **Swift Package Manager:** `ios/quickjs_engine/Package.swift` compiles the bridge + QuickJS sources into a small dynamic framework, `quickjs-engine-native.framework`, embedded in your app. **CocoaPods:** the podspec compiles the same sources into the plugin framework, which has to be a dynamic framework (Flutter's default `use_frameworks!`). | None — `flutter run -d ios` handles it with either dependency manager. See [Swift Package Manager](#swift-package-manager), and [this workaround](#ios-with-cocoapods-failed-to-lookup-symbol-jsnewruntime) if your Podfile links pods statically. |
| **macOS** | **Swift Package Manager:** `macos/quickjs_engine/Package.swift` compiles the bridge + QuickJS sources into `quickjs-engine-native.framework` (universal `arm64` + `x86_64` in release builds). **CocoaPods:** a prebuilt `libquickjs_c_bridge_plugin.dylib` ships with the package under `macos/Frameworks/` and is bundled as `vendored_libraries`. | None for app builds. For unit tests run via `flutter test`, see [Tests can't find the dylib](#tests-cant-find-the-dylib) below. |
| **Linux** | Plugin CMake (`linux/CMakeLists.txt`) does `add_subdirectory(../native)`, compiling the bridge alongside your app. | None — `flutter run -d linux` handles it. |
| **Windows** | Plugin CMake (`windows/CMakeLists.txt`) does `add_subdirectory(../native)`, same as Linux. | None — `flutter run -d windows` handles it (Visual Studio Build Tools required). |

JavaScriptCore bindings inherited from the upstream package are kept in
`lib/javascriptcore/` for ABI compatibility but unused at runtime — the
runtime selector (`getJavascriptRuntime()`) always returns the QuickJS
path.

## Swift Package Manager

`quickjs_engine` supports Flutter's
[Swift Package Manager integration][flutter-swiftpm] on iOS and macOS, so
Flutter no longer reports it under "The following plugins do not support
Swift Package Manager" or falls back to CocoaPods because of it. SwiftPM
is on by default in recent stable Flutter releases (for example 3.47). On
older releases, enable it:

- **Flutter 3.35 and later** — per project, in the app's `pubspec.yaml`:

  ```yaml
  flutter:
    config:
      enable-swift-package-manager: true
  ```

- **Flutter 3.32 – 3.34** — these releases do not support the `config:`
  key in `pubspec.yaml`; enable SwiftPM for your Flutter installation
  instead with `flutter config --enable-swift-package-manager`.

Nothing else is required — there is no Podfile to edit and no native build
step.

How it is put together, for maintainers and the curious:

- `ios/quickjs_engine/Package.swift` and `macos/quickjs_engine/Package.swift`
  define the plugin package (product `quickjs-engine`, Swift target
  `quickjs_engine`). The Swift plugin class lives in
  `<platform>/quickjs_engine/Sources/quickjs_engine/` and is shared with the
  podspec.
- QuickJS-NG and the Dart FFI bridge are a nested package,
  `<platform>/quickjs_engine/quickjs_engine_native/`, with a **dynamic**
  library product. Dart finds the bridge with `DynamicLibrary.process()`;
  a statically linked bridge would end up in the `Runner` executable, whose
  exported symbols Xcode strips when archiving (`flutter build ipa`), so
  every lookup would fail in release builds. An embedded framework keeps
  its exports.
- The C/C++ files in that package are tiny forwarders that `#include` the
  shared sources in `native/cxx/` (also used by the podspec and the
  Android/Linux/Windows CMake builds), so nothing is duplicated.
- The dependency on Flutter's generated `FlutterFramework` package (and the
  iOS 13 / macOS 10.15 minimum it requires) is only declared when Flutter
  generates that package (Flutter 3.41 and later), so the same manifest
  also works with Flutter 3.38 and older.
- No privacy manifest is shipped: the compiled code uses none of Apple's
  required-reason APIs and collects no data.

[flutter-swiftpm]: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers

## When you might need to rebuild the native library

For the **vast majority of app-development workflows you do not need to
touch native code**. Just `flutter run` / `flutter build`. The two cases
where you do need to rebuild:

1. **You modified `native/cxx/libfastdev_quickjs_runtime.cpp` or the
   bundled `native/cxx/quickjs/*.c` sources.**
   App builds for iOS / Android / Linux / Windows, and macOS builds that
   use Swift Package Manager, pick up the change automatically
   (CMake/CocoaPods/SwiftPM recompile). For **macOS with CocoaPods**, you
   need to refresh the prebuilt `libquickjs_c_bridge_plugin.dylib` under
   `macos/Frameworks/` — that's what the build scripts below do.

2. **You're running unit tests on a desktop platform (`flutter test`
   on macOS/Linux/Windows).**
   The Dart-side FFI loader looks for the library by file name. If the
   plugin pipeline hasn't produced one yet, point it at a manually built
   copy (see [Tests can't find the dylib](#tests-cant-find-the-dylib)).

## Building the native library from source

The package ships two equivalent build scripts under `tool/`:

| Host OS | Script | Run with |
|---------|--------|----------|
| macOS, Linux | `tool/build_native.sh` | `sh tool/build_native.sh` |
| Windows (PowerShell) | `tool/build_native.ps1` | `pwsh tool/build_native.ps1`  *or*  `powershell.exe -ExecutionPolicy Bypass -File tool/build_native.ps1` |

Both scripts:

1. Run a Release CMake build. On macOS, the default is a universal
   `arm64;x86_64` bridge with the package's declared macOS deployment target;
   set `CMAKE_OSX_ARCHITECTURES` or `CMAKE_OSX_DEPLOYMENT_TARGET` to override
   either value when maintaining a platform-specific build.
2. Build with `cmake --build native/build -j`
3. Copy the resulting library into the host's plugin output folder:
   - macOS → `macos/Frameworks/libquickjs_c_bridge_plugin.dylib`
   - Linux → `native/build/libquickjs_c_bridge_plugin.so` *(local-only;
     consumer apps still rebuild it from source via the plugin's
     CMakeLists)*
   - Windows → `native/build/Release/quickjs_c_bridge_plugin.dll`

**Prerequisites:**

| Tool | macOS | Linux | Windows |
|------|-------|-------|---------|
| CMake ≥ 3.10 | `brew install cmake` | `apt install cmake` / `dnf install cmake` | [`winget install Kitware.CMake`][winget-cmake] or [cmake.org](https://cmake.org/download) |
| C/C++17 compiler | Xcode CLT (`xcode-select --install`) | GCC ≥ 7 / Clang ≥ 5 (`apt install build-essential`) | Visual Studio Build Tools 2019+ with the **"Desktop development with C++"** workload ([download][vs-bt]) |
| (optional) `ninja` for faster builds | `brew install ninja` | `apt install ninja-build` | `winget install Ninja-build.Ninja` |

[winget-cmake]: https://winstall.app/apps/Kitware.CMake
[vs-bt]: https://aka.ms/vs/17/release/vs_BuildTools.exe

Pass `-G Ninja` (or whatever generator you prefer) by exporting
`CMAKE_GENERATOR` before invoking the scripts.

## Troubleshooting

### Tests can't find the dylib

```
Invalid argument(s): Failed to load dynamic library 'libquickjs_c_bridge_plugin.dylib':
  dlopen(libquickjs_c_bridge_plugin.dylib, ...): tried: ... no such file
```

`flutter test` runs in a Dart VM that doesn't go through the platform
plugin pipeline, so the macOS plugin's prebuilt dylib isn't auto-linked
into the test process. Two fixes:

```bash
# Option A: build it once. The Dart-side ffi.dart loader looks under
#   packages/quickjs_engine/native/build/  next to your project.
sh tool/build_native.sh

# Option B: point at an arbitrary copy via env var.
LIBQUICKJSC_TEST_PATH=/abs/path/to/libquickjs_c_bridge_plugin.dylib flutter test
```

Same applies on Linux / Windows — substitute `.so` / `.dll` for `.dylib`
and run `tool/build_native.sh` or `tool/build_native.ps1`.

### "ld: warning: building for macOS-11.0, but linking with dylib which was built for newer version"

The prebuilt macOS dylib in an older package may have been built with the
host's default `MACOSX_DEPLOYMENT_TARGET`. If your app targets an older macOS than the
build host, rebuild the bridge with an explicit target using the current
script:

```bash
MACOSX_DEPLOYMENT_TARGET=10.13 sh tool/build_native.sh
```

### Android: undefined symbol errors

Make sure your `android/app/build.gradle` doesn't pin the NDK to an old
version that's missing C++17 support. Required: NDK r21 or later (most
modern Flutter projects use r25+).

### Windows: CMake "Could not find compiler set in environment variable CC"

Open the **"Developer Command Prompt for VS 2022"** (or run `vcvarsall.bat`
in your terminal) before invoking the build script. Alternatively, point
CMake at MSVC explicitly:

```powershell
$env:CMAKE_C_COMPILER  = 'cl'
$env:CMAKE_CXX_COMPILER = 'cl'
.\tool\build_native.ps1
```

### macOS: `pod install` complains about missing dylib

The vendored dylib lives at `macos/Frameworks/libquickjs_c_bridge_plugin.dylib`.
If you pulled the package from pub.dev it's already there. If you're
working off `path:` source and accidentally deleted `native/build/`, the
file may be missing — run `sh tool/build_native.sh` to regenerate it.

### iOS with CocoaPods: "Failed to lookup symbol 'jsNewRuntime'"

```
Invalid argument(s): Failed to lookup symbol 'jsNewRuntime':
  dlsym(RTLD_DEFAULT, jsNewRuntime): symbol not found
```

With CocoaPods, the plugin has to be a **dynamic framework**, which is what
Flutter's default iOS `Podfile` (`use_frameworks!`) produces. Dart looks the
bridge up at runtime with `DynamicLibrary.process()` and nothing references
the C functions at link time, so with `use_frameworks! :linkage => :static`
or without `use_frameworks!` the linker drops them from the app.

Either move the app to [Swift Package Manager](#swift-package-manager),
which always embeds the bridge as a dynamic framework, or keep the static
linkage for your other pods and add this to `ios/Podfile`:

```ruby
# quickjs_engine: Dart finds the QuickJS bridge with DynamicLibrary.process(),
# so the pod must be a dynamic framework even when other pods are static.
# Flutter (a prebuilt dynamic framework) is marked dynamic as well, because
# CocoaPods rejects a dynamic pod that depends on a pod it treats as static.
pre_install do |installer|
  installer.pod_targets.each do |pod|
    next unless %w[Flutter quickjs_engine].include?(pod.name)
    def pod.build_type
      Pod::BuildType.dynamic_framework
    end
  end
end
```

With the default `use_frameworks!`, this error means quickjs_engine 0.1.5
or older: those versions compiled none of the bridge sources into the iOS
pod. Upgrade to 0.1.6 or later.

### Swift Package Manager: "FlutterFramework cannot be accessed" after switching Flutter versions

`ios/quickjs_engine/Package.swift` and `macos/quickjs_engine/Package.swift`
only depend on Flutter's generated `FlutterFramework` package when the
Flutter version in use generates it (3.41 and later). SwiftPM caches the
evaluated manifest, so after switching Flutter versions Xcode can keep using
the previous evaluation and fail with an error such as
`.../Flutter/ephemeral/Packages/.packages/FlutterFramework cannot be
accessed`. Clear the SwiftPM manifest cache and rebuild:

```bash
rm -rf ~/Library/Caches/org.swift.swiftpm/manifests
flutter clean
flutter run
```

## Acknowledgements

- [`flutter_js`][upstream] by Ábner Oliveira — the bridge architecture,
  message-channel design, and JSC bindings come straight from upstream.
- [`quickjs-ng`][qjsng] — the actively-maintained QuickJS fork
  (Fabrice Bellard, Charlie Gordon, Ben Noordhuis, Saúl Ibarra Corretgé).
- Bridge cpp porting pattern from the upstream
  [`native/cxx/libfastdev_quickjs_runtime.cpp`][bridge] in flutter_js.

[bridge]: https://github.com/abner/flutter_js/tree/master/native/cxx

## License

MIT — see [LICENSE](LICENSE). Bundled upstream sources are also MIT
(Ábner Oliveira for `flutter_js`; Fabrice Bellard et al. for QuickJS-NG).
The full text of each upstream license is reproduced in `LICENSE`.
