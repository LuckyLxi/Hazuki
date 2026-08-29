# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run on device/emulator
flutter run

# Build Android APK (release, arm64)
flutter build apk --split-per-abi --target-platform android-arm64

# Analyze / test
flutter analyze
flutter test
flutter test test/path/to/test_file.dart            # single test file

# Regenerate localization code after editing lib/l10n/*.arb
flutter gen-l10n

# Regenerate Drift code after changing the database schema
dart run build_runner build --delete-conflicting-outputs

# Verify formatting (CI uses this exact form)
dart format --output=none --set-exit-if-changed lib test
```

`third_party/flutter_qjs` and each package under `third_party/pub_overrides/` are **separate packages** — run their `flutter pub get` / `dart format` / `flutter analyze` / `flutter test` from that directory, not the repo root. Do not overwrite the local `dependency_overrides` in `pubspec.yaml` (they patch upstream bugs).

## Architecture

Hazuki is a Flutter manga reader targeting Android. It fetches and renders manga from third-party JavaScript source scripts (JMComic / CopyManga / Picacg via [venera-configs](https://github.com/venera-app/venera-configs)). No Provider/GetX/Riverpod — state is `ChangeNotifier` controllers consumed via `ListenableBuilder`/`AnimatedBuilder`.

### JS source runtime

All manga data (browse, search, favorites, chapters, images) flows through a JavaScript runtime powered by `flutter_qjs` (QuickJS, at `third_party/flutter_qjs`). The JS source script is downloaded at first launch and stored locally. `assets/init.js` is the bridge library injected into the runtime before the source script (provides `sendMessage`, `Convert`, `Network`, etc.).

The source service is a decomposed subsystem under `lib/services/source/`, layered as:

- **`SourceRuntimeAssembly`** ([source_runtime_assembly.dart](lib/services/source/runtime/source_runtime_assembly.dart)) — internal composition root. Wires the state stores, per-domain capabilities, and the gateway set together. Application code never depends on it directly.
- **`SourceRuntimeHost`** ([source_runtime_host.dart](lib/services/source/runtime/source_runtime_host.dart)) — owns source selection and the lifetime of per-source `SourceRuntimeHandle`s. Each handle bundles the `HazukiSourceFacade`, JS kernel, cache/cookie/session stores, and image cache for one source. A generic `SourceRuntimeCoordinator<T>` ([source_runtime_coordinator.dart](lib/services/source/runtime/source_runtime_coordinator.dart)) manages the handle map + active-source selection.
- **`SourceGatewaySet`** ([source_gateway_set.dart](lib/services/source/gateways/source_gateway_set.dart)) — produces the **focused gateway contracts** that features actually consume (`SourceSearchGateway`, `SourceReaderGateway`, `SourceDiscoverGateway`, `SourceFavoriteGateway`, `SourceSyncGateway`, …). Each gateway is an *Adapter* over the operations/capabilities.
- **`HazukiSourceFacade`** ([source_runtime_facade.dart](lib/services/source/runtime/source_runtime_facade.dart)) — the per-source contract capabilities depend on (JS bridge, session, cache, debug log, http gateway).
- **Capabilities** live under domain subdirs (`account/`, `comic/`, `comments/`, `favorites/`, `image/`, `debug/`, `content/`, `category/`, `runtime/`); state stores and shared helpers live in `runtime/` and `common/`.

The app-level **`SourceRuntimeCoordinator`** ([lib/app/source_runtime/source_runtime_coordinator.dart](lib/app/source_runtime/source_runtime_coordinator.dart)) is a separate UI orchestrator: bootstrap overlay, connectivity recovery, and source-update checks. Do not confuse it with the generic handle-lifecycle coordinator above.

### Dependency injection

Pure `get_it`. `lib/app/service_locator.dart` exposes `final GetIt sl` and `registerServices()`, which delegates to `registerSourceServices` + `registerApplicationServices` in [lib/app/di/](lib/app/di/). Resolve **everything** via `sl<T>()` (e.g. `sl<SourceReaderGateway>()`, `sl<MangaDownloadService>()`). There are no `.instance` static singletons. Registrars accept an optional `GetIt` so tests can build an isolated graph.

### Startup

`main()` → `bootstrapApp()` ([app_bootstrap.dart](lib/app/startup/app_bootstrap.dart)) → `runApp`. Bootstrap calls `registerServices()`, loads active-source preference and UI flags, then initializes `MangaDownloadService`, `PasswordLockService`, `CommentFilterService`, etc. `HazukiAppStartupCoordinator` ([app_startup_coordinator.dart](lib/app/app_startup_coordinator.dart)) orchestrates source bootstrap and the source/software update dialogs post-run.

### State pattern

Feature controllers are `ChangeNotifier`s that hold a private `_state` snapshot and call `notifyListeners()`. They accept **callbacks** injected at construction (e.g. reader update/log callbacks) to stay testable without widget dependencies. Views resolve gateways via `sl<T>()` and pass them into controllers, which take them as constructor parameters.

### Feature modules

The bottom-nav shell (`HazukiHomePage` → `HomeCoordinator`) hosts features under `lib/features/`, each with `view/`, `state/`, and `support/` subdirs plus a public barrel export (e.g. `home.dart`):

| Feature | Purpose |
| --- | --- |
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

`support/` holds controllers, async action flows, and utilities factored out of views (the reader feature alone has ~7 support controllers). Cross-feature helpers live in `lib/shared/` (e.g. `navigation_tags.dart`, `reading/`, `favorites/`, `source_account/`, `preferences/`); shared UI widgets live in `lib/widgets/`; shared models in `lib/models/`.

### Storage

`lib/services/storage/hazuki_database.dart` is the Drift database (tables for read history, reading progress, search history, download groups), with generated code in `hazuki_database.g.dart` (never hand-edit). Tests use `HazukiDatabase.memory()`. App-level preference keys live in `lib/app/app_preferences.dart` and `lib/shared/preferences/hazuki_preference_keys.dart`.

### Navigation & theme

Navigation uses hero animations for comic-cover transitions; helpers live in [lib/shared/navigation_tags.dart](lib/shared/navigation_tags.dart) (`comicCoverHeroTag()`, `buildComicCoverHeroFlightShuttle()`, `comicCoverHeroBorderRadius()`). Android uses a bottom drawer; Windows gets a sidebar layout. Light/dark switching uses a circular reveal animation (`_ThemeRevealOverlay` in `main.dart`).

### Localization

ARB files in `lib/l10n/`. Use `l10n(context)` from `lib/l10n/l10n.dart` to get `AppLocalizations`.

### Tests

Tests mirror the `lib/` structure under `test/`. Two patterns: **smoke tests** (instantiate controllers/pages to verify construction) and **controller unit tests** (drive state transitions directly on the `ChangeNotifier`). Use `mocktail` for fakes and `HazukiDatabase.memory()` for isolated storage.

## Conventions

- **Code comments must be written in Simplified Chinese** — docstrings and inline comments explaining *why/how*, kept concise and professional.
- **Strict scope**: touch only the lines/functions required for the task; do not refactor unrelated code or delete existing behavior without asking first.
- **Commits**: Conventional Commits, imperative and scoped (e.g. `feat(settings): …`, `fix(storage): …`). No casual/playful language.
- **Release notes / `update.json` `log` field / git tag descriptions**: list items start with `- ` (never numeric ordering), separated by `\n`. Release tags must be annotated (`git tag -a`).
