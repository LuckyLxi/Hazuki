# Local dependency overrides

Keep these path overrides when updating dependencies. The Android packages use
Hazuki's AGP 9.1.1 built-in Kotlin configuration rather than applying a legacy
Kotlin Android plugin. Their standalone Gradle settings retain plugin
repositories and the matching Android library plugin version; their Android
builds use compile SDK 36.

The following packages were refreshed from their published pub.dev archives:

| Package | Version |
| --- | --- |
| `device_info_plus` | 13.3.0 |
| `package_info_plus` | 10.2.2 |
| `shared_preferences_android` | 2.4.28 |
| `file_selector_android` | 0.5.2+11 |
| `url_launcher_android` | 6.3.33 |

For those packages, local changes are confined to `android/build.gradle.kts`
and `android/settings.gradle.kts`. The first two packages now use upstream's
Kotlin Gradle scripts instead of the old Groovy files. The URL launcher's SDK
minimum override is now included upstream.

`liquid_glass_widgets` documents its gesture and morph patches in its own
README. `re_editor` and `dynamic_color` retain their existing local patches.

The root project keeps these compatibility limits:

- `build_runner` 2.16.2: 2.17.1 needs `build` 5, while `drift_dev` 2.35.1 needs
  `build <5`. Do not force a dependency override to bypass that constraint.
- `dynamic_color` 1.8.1: newer versions change color generation and introduce
  `material_ui`; upgrading needs a separate appearance review.
- `flutter_secure_storage` 10.3.4: version 11 removes legacy storage formats.
  Validate existing-account upgrades on Android before migrating.

SQLite is supplied by `sqlite3` 3.x native build hooks. The obsolete
`sqlite3_flutter_libs` Flutter plugin is no longer needed.

The upstream `device_info_plus` Windows integration test assumes the registry's
`BuildLab` begins with the build number reported by `RtlGetVersion`. On the
current Windows host these are `26100.ge_release.240331-1435` and `26300`, so
that assertion fails. Both the test and Windows implementation are unchanged
from 13.1.0; this is a pre-existing host-dependent test limitation.
