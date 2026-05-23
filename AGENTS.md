# AGENTS.md

Compact guidance for future OpenCode sessions in this repository.

## Commands

```bash
# First setup / after dependency changes
flutter pub get
flutter gen-l10n

# CI app quality path
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage --reporter expanded

# Focused test
flutter test test/path/to/test_file.dart

# App smoke builds used by CI
flutter build apk --debug
flutter build windows --debug

# Android release shape used by release CI
flutter build apk --release --split-per-abi --target-platform android-arm64

# Drift codegen when lib/services/storage/hazuki_database.dart changes
dart run build_runner build --delete-conflicting-outputs
```

`third_party/flutter_qjs` is a separate Flutter package with its own `pubspec.yaml`; run its quality checks from that directory: `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test --reporter expanded`.

## Build And Tooling Notes

- CI uses Flutter stable. Android jobs use Java 17 for app quality/CI and Java 21 for debug smoke/release builds.
- Localization is generated from `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`; run `flutter gen-l10n` after ARB changes. Generated `lib/l10n/app_localizations*.dart` files are present in the tree.
- Drift generates `lib/services/storage/hazuki_database.g.dart` from `lib/services/storage/hazuki_database.dart`; bump migrations/schema deliberately when changing tables.
- `analysis_options.yaml` excludes `third_party/flutter_qjs/**` and `third_party/pub_overrides/**` from the app analyzer; check `flutter_qjs` separately when touching it.
- `pubspec.yaml` uses local dependency overrides under `third_party/pub_overrides/`; do not replace them with hosted packages unless the override is intentionally removed.

## Architecture

- Entry point: `lib/main.dart` calls `bootstrapApp()` in `lib/app/startup/app_bootstrap.dart`, which registers `get_it` services, loads source/runtime preferences, initializes downloads/password-lock/comment filters, then builds `HazukiApp`.
- App-level services are registered in `lib/app/service_locator.dart` through `sl`; many services still expose or rely on singleton-style access, so keep service registration order in mind during tests/startup changes.
- Manga content comes from JavaScript source scripts from `venera-configs` (`jm`, `copy_manga`, `picacg`) executed through QuickJS via `flutter_qjs`.
- `HazukiSourceService` (`lib/services/hazuki_source_service.dart`) owns the source runtime. Closely coupled source capabilities are `part` files under `lib/services/source/`; newer decoupled capabilities live as normal classes under the same tree.
- `SourceRuntimeCoordinator` (`lib/app/source_runtime/source_runtime_coordinator.dart`) handles first-run source download/load, network recovery, and source update prompts.
- `assets/init.js` is the JS bridge injected before source scripts; source-runtime changes often need Dart and JS bridge changes together.
- Persistent app data uses Drift in `HazukiDatabase`; runtime/source preferences and settings use `SharedPreferences`, with keys centralized in `lib/app/app_preferences.dart` and `lib/services/source/common/source_prefs_keys.dart`.

## Feature Structure

- Features live under `lib/features/<feature>/` with `view/`, `state/`, and/or `support/` code plus a public barrel such as `features/search/search.dart`.
- State is plain Flutter: controllers extend `ChangeNotifier`, expose immutable-ish state snapshots, and are consumed with `ListenableBuilder`/`AnimatedBuilder`; no Provider/Riverpod/GetX is used.
- Main shell is `HazukiHomePage`/`HomeCoordinator`; platform navigation differs: Android uses bottom/drawer-style UI, Windows has sidebar/title-bar adaptations.
- Shared non-feature UI/helpers belong in `lib/widgets/` or `lib/shared/`; shared models belong in `lib/models/`.

## Testing Conventions

- Tests under `test/` mirror `lib/` where practical. Common patterns are smoke construction tests for feature entry widgets and controller/service unit tests with mocked preferences or in-memory database state.
- For service tests that touch Drift, prefer `HazukiDatabase.memory()` rather than the real app database.

## Release Notes

- Release workflow requires annotated `v*` tags; tag annotation text becomes GitHub release notes and `update.json` changelog.
- `update.json` is generated and committed by release CI after tagged releases; avoid hand-editing it unless intentionally overriding release metadata.
