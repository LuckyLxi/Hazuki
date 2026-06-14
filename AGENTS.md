# Repository Guidelines

## Project Structure & Module Organization

Hazuki is a Flutter comics application. Application code lives in `lib/`: startup and dependency registration are under `lib/app/`, feature modules under `lib/features/<feature>/`, reusable UI under `lib/widgets/`, services under `lib/services/`, and shared models/helpers under `lib/models/` and `lib/shared/`. Tests mirror this layout in `test/`. Static resources and the JavaScript source bridge live in `assets/`. Platform projects are in `android/`, `windows/`, and the other Flutter platform directories.

`third_party/flutter_qjs` is a separate Flutter package. Run its dependency, format, analysis, and test commands from that directory when modifying it.

## Build, Test, and Development Commands

- `flutter pub get`: install dependencies.
- `flutter gen-l10n`: regenerate localization code after editing `lib/l10n/*.arb`.
- `dart format --output=none --set-exit-if-changed lib test`: verify formatting.
- `flutter analyze`: run Flutter lints and static analysis.
- `flutter test --coverage --reporter expanded`: run the full test suite with coverage.
- `flutter test test/features/search/search_results_controller_test.dart`: run one focused test.
- `flutter build apk --debug` / `flutter build windows --debug`: perform CI smoke builds.
- `dart run build_runner build --delete-conflicting-outputs`: regenerate Drift code after database schema changes.

## Coding Style & Naming Conventions

Use Dart's standard two-space formatting and run `dart format` before submitting. Follow `flutter_lints` from `analysis_options.yaml`. Name files in `snake_case.dart`, classes in `UpperCamelCase`, and variables/methods in `lowerCamelCase`. Keep feature-specific view, state, and support code inside its feature directory; place genuinely shared code in `lib/widgets/` or `lib/shared/`.

Do not hand-edit generated localization files or `lib/services/storage/hazuki_database.g.dart`. Preserve local dependency overrides in `third_party/pub_overrides/`.

## Testing Guidelines

Use `flutter_test`; `mocktail` and `HazukiDatabase.memory()` are available for isolated service tests. Name tests `*_test.dart` and mirror the corresponding source path where practical. Add focused controller/service tests for behavior changes and widget smoke tests for new feature entry points. Run format, analysis, and the full test suite before opening a PR.

## Commit & Pull Request Guidelines

Recent history follows Conventional Commits, for example `feat(settings): allow selecting update source` and `fix(storage): fix database migration crash`. Keep commits scoped and imperative. PRs should explain the behavior change, list verification commands, link relevant issues, and include screenshots for approved visual changes. Call out migrations, generated files, dependency changes, and platform-specific effects.

## Agent-Specific Instructions

Obtain user approval before modifying UI appearance or animation behavior. Avoid unrelated refactors, and never overwrite existing user changes.
