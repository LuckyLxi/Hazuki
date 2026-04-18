# Hazuki Notes

This vendored `flutter_qjs` copy is maintained for Hazuki and currently uses a
split QuickJS strategy:

- `cxx/quickjs`: upstream QuickJS `2025-09-13` for Android and other non-MSVC
  toolchains.
- `cxx/quickjs_msvc`: legacy QuickJS `2021-03-27` kept only for MSVC builds.

As of April 18, 2026, the official QuickJS site still lists `2025-09-13` as
the latest upstream release. Hazuki is therefore already current on the
shipping Android/non-MSVC runtime, and the maintenance focus is keeping the
bridge layer and build split explicit and testable.

## Why two snapshots exist

The current upstream QuickJS snapshot does not build cleanly with MSVC in this
plugin layout, while Hazuki still needs Windows-side development and plugin
tests to keep working. The plugin therefore selects the legacy snapshot only on
MSVC in [cxx/quickjs.cmake](/d:/Project/Hazuki/third_party/flutter_qjs/cxx/quickjs.cmake:6).

This keeps the Android shipping path on a modern QuickJS release without
breaking Windows development workflows.

## Maintenance boundary

- Treat `cxx/quickjs` as the source of truth for Android and non-MSVC builds.
- Treat `cxx/quickjs_msvc` as a compatibility fallback only. Do not update it
  unless the Windows/MSVC build is being intentionally revalidated.
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
