# Hazuki Notes

This vendored `flutter_qjs` copy is maintained for Hazuki. All platforms
(Android, Windows/MSVC, and others) now share a single QuickJS snapshot:

- `cxx/quickjs`: upstream QuickJS `2025-09-13` — used by all toolchains.

The legacy `cxx/quickjs_msvc/` directory (QuickJS `2021-03-27`) is retained
for reference but is no longer included in any build.

As of May 2, 2026, the official QuickJS site still lists `2025-09-13` as the
latest upstream release.

## MSVC compatibility patches in cxx/quickjs/

The upstream `2025-09-13` snapshot was patched with minimal `#ifdef _MSC_VER`
guards so it compiles cleanly with MSVC:

- **`cutils.h`**: Added `_MSC_VER` block for `likely/unlikely`, `force_inline`,
  `no_inline`, `__maybe_unused`, `__attribute__(...)` macros; replaced
  `__builtin_clz/ctz` with `_BitScanReverse/Forward` intrinsics; replaced
  `struct __attribute__((packed))` with `#pragma pack(push,1)` / `pop`.
- **`quickjs.c`**: Added `gettimeofday` implementation for MSVC via
  `WinSock2.h`; disabled `DIRECT_DISPATCH` on MSVC (computed-goto not
  supported); disabled `CONFIG_ATOMICS` on MSVC (`<stdatomic.h>` unavailable);
  replaced `__builtin_frame_address(0)` with a volatile local variable address
  for accurate current-RSP measurement; replaced `1.0/0.0` with `INFINITY`
  (C2124 compile-time divide-by-zero); removed all `(JSValue)` / `(JSValueConst)`
  identity struct casts (C2440 not allowed on aggregate types in MSVC C mode).
- **`quickjs.h`**: Added MSVC inline-function replacements for `JS_MKVAL`,
  `JS_MKPTR`, `JS_NAN` (C99 compound literals not valid in C++ mode via
  ffi.cpp); fixed `return (JSValue)v` in `JS_DupValue`/`JS_DupValueRT`; fixed
  designated initializer in `JS_NewCFunctionMagic` (requires C++20 in MSVC);
  added `#include <math.h>` for `NAN`; reduced `JS_DEFAULT_STACK_SIZE` to 256KB
  on MSVC to leave C-frame headroom (new QuickJS uses larger alloca frames than
  2021 version; 1MB consumed the entire OS stack before overflow was detected).
- **`cutils.h`**: Added `#define __attribute(...)` (single-pair underscores)
  alongside `__attribute__(...)` to handle GCC's alternative attribute syntax.
- **`dtoa.c`**: Guarded `#include <sys/time.h>` with `#ifndef _MSC_VER`
  (used only by the disabled `JS_DTOA_DUMP_STATS` path).

## Maintenance boundary

- Treat `cxx/quickjs` as the source of truth for all builds.
- Keep exported FFI symbol names stable so Hazuki's Dart layer does not need
  API changes when the runtime is refreshed.
- Prefer compatibility shims in `cxx/ffi.cpp` over Dart API changes when
  upstream QuickJS behavior shifts.

## Current local changes

- Debug-only leak instrumentation instead of always-on `DUMP_LEAKS`.
- Dart 3 package constraints and explicit Dart 3 language mode in FFI code.
- Promise detection compatibility for newer QuickJS via `JS_PromiseState`.
- Isolate module loading now has a bounded wait with timeout protection.
- Example app dependencies were updated so `flutter pub get` succeeds again.

## Validation

The current maintenance baseline was verified with:

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

Run `flutter test` from `third_party/flutter_qjs`, and run the APK build from
the repository root.

## If you upgrade again

1. Refresh `cxx/quickjs` from upstream.
2. Re-check whether the official latest upstream release has changed.
3. Re-run `flutter test` on Windows and `flutter build apk --debug`.
4. If upstream still fails on MSVC, either keep `quickjs_msvc` or invest in a
   dedicated MSVC compatibility pass before deleting it.
5. Keep `cxx/prebuild.sh`, Apple podspecs, and `cxx/ffi.cpp` in sync with any
   upstream API changes.
