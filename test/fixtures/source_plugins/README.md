# Source plugin regression fixtures

These scripts are snapshots from the extraction of Hazuki source plugins into
[LuckyLxi/Sources](https://github.com/LuckyLxi/Sources). They exercise the host's
QuickJS runtime, plugin import, account handling, and presentation declarations
without requiring a second repository or network access during Flutter tests.

The relamanhua snapshot also includes anonymous HTML/JSON responses under
`responses/`. Its host tests import the plugin through the manager and execute
the real QuickJS runtime, HTML bridge and application gateways. Image-list
decryption is checked against an independent AES implementation. Account and
favorite responses are synthetic; this is not a live website/account check.

Maintain and publish plugins in Sources. These files are test data, not release
sources. When updating a snapshot, copy Sources' root `<id>.js` to this
directory's `<id>/main.js`, restore its type-reference comment to
`../hazuki-source.d.ts` if needed, and preserve the attribution from
`dev/upstream/<id>/UPSTREAM.md` (or the script's header). Then run:

```powershell
flutter test test/services/source/jm_source_plugin_test.dart test/services/source/migrated_source_plugins_test.dart test/services/source/relamanhua_source_plugin_test.dart test/services/source/source_plugins_test.dart test/services/source/source_plugin_action_locations_test.dart
```

Upstream attribution is retained beside each script. Hazuki integration code is
covered by the project license; see the root `LICENSE` and each `UPSTREAM.md`.
