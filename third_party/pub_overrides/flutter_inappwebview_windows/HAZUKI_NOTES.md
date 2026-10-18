# Hazuki authorization lifecycle patch

Based on flutter_inappwebview_windows 0.6.0 (Apache-2.0); upstream files and attribution retained.

- Bind each newly created environment's channel to `env.id`, instead of the static factory's `id`. Otherwise disposal targets a nonexistent channel and the environment remains alive.
- Explicitly close the environment's hidden WebView2 controller before releasing its COM references. Authorization session directories must become removable after all owned views close.
- Complete native disposal after BrowserProcessExited, rather than while that process still holds the data directory. Dispose callbacks retain their own reply lifetime during environment destruction.

- Convert native Cookie expiry seconds to SDK milliseconds and retain null expiry for session cookies. The host reads its owned InPrivate view through the native protocol because the environment-level manager uses a separate regular-profile view.

Hazuki disables browser event debug logging, uses independent environments and InPrivate views, and deletes generated session directories. Re-check these fixes when updating upstream. The host CMake target also opts into the existing experimental-coroutine compatibility mode for MSVC 2026.

Windows build compatibility: remove the unsupported `DEPENDS` argument from the NuGet pre-build command (CMP0175), compile plugin sources as UTF-8, mark WebView2 SDK headers as system includes, and explicitly convert the response status to the SDK's `int` parameter. Plugin source warnings remain enabled.

Verification: host `flutter analyze`, authorization unit/widget tests, Windows debug build and `flutter run -d windows -t test/platform/source_authorization_browser_smoke.dart`. The native smoke test checks Cookie/localStorage/IndexedDB/Cache API isolation, callback interception and directory cleanup with synthetic data.
