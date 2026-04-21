# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on device/emulator
flutter run

# Build Android APK
flutter build apk --split-per-abi --target-platform android-arm64

# Analyze
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/test_file.dart
```

## Architecture

Hazuki is a Flutter manga reader app targeting Android. It fetches and renders manga from a third-party JavaScript source script (JMComic via [venera-configs](https://github.com/venera-app/venera-configs/blob/main/jm.js)).

### Core concept: JS source runtime

All manga data (browse, search, favorites, chapters, images) flows through a JavaScript runtime powered by `flutter_qjs` (QuickJS embedded in Flutter, at `third_party/flutter_qjs`). The JS source file is downloaded at first launch and stored locally.

- **`HazukiSourceService`** (`lib/services/hazuki_source_service.dart`) — the central singleton. It owns the JS engine and exposes all capabilities as `part` files under `lib/services/source/`. Each capability (e.g. `favorites_capability.dart`, `image_prepare_capability.dart`) is a `part` of this class.
- **`SourceRuntimeCoordinator`** (`lib/app/source_runtime_coordinator.dart`) — orchestrates bootstrap (downloading/loading the JS file), connectivity recovery, and source update checks.
- **`assets/init.js`** — the JS bridge library injected into the QuickJS runtime before the source script. Provides `sendMessage`, `Convert`, `Network`, etc. to the JS source.

### State & settings

- **`HazukiThemeController`** — `ChangeNotifier` holding current `AppearanceSettingsData`; consumed via `HazukiThemeControllerScope` (InheritedWidget).
- **`HazukiAppSettingsStore`** — serializes/deserializes appearance and locale to `SharedPreferences`.
- App-level preference keys live in `lib/app/app_preferences.dart`.

### Feature modules

The app uses a bottom-nav shell (`HazukiHomePage` → `HomeCoordinator`). Features live under `lib/features/`, each with `view/`, `state/`, and `support/` subdirectories and a public barrel export (e.g. `home.dart`):

| Feature | Purpose |
|---|---|
| `home/` | Shell, nav bar, drawer, profile flow |
| `discover/` | Browse/explore from source |
| `favorite/` | Cloud + local favorites |
| `reader/` | Chapter image reader (zoom, settings, image pipeline) |
| `comic_detail/` | Comic info, chapter list |
| `search/` | Search UI |
| `settings/` | App settings pages |
| `downloads/` | Download queue/history |
| `history/` | Read history |
| `comments/` | Chapter comments |

**State pattern**: feature controllers are `ChangeNotifier`s consumed via `ListenableBuilder` or `AnimatedBuilder`. `HomeCoordinator` owns `HomeShellController` (tab/app bar) and `HomeProfileController` (login/profile). Access services via static singletons: `HazukiSourceService.instance`, `MangaDownloadService.instance`, etc.

### Services

- **`MangaDownloadService`** — download queue, storage layout, recovery on restart.
- **`CloudSyncService`** — syncs favorites/history with the source account.
- **`PasswordLockService`** — app-level PIN lock (blocks the whole UI via an overlay).
- **`SoftwareUpdateService`** / **`SoftwareUpdateDownloadService`** — self-update from `update.json`.

### Theme switching

Light/dark switching uses a circular reveal animation (`_ThemeRevealOverlay` in `main.dart`): the old theme is rasterized into a `ui.Image` via `RepaintBoundary.toImage()`, then a `CustomPainter` clips a growing circle away to reveal the new theme underneath.

### Localization

ARB files live in `lib/l10n/`. Helper: `l10n(context)` from `lib/l10n/l10n.dart` returns `AppLocalizations.of(context)!`.
