# Local re_editor patch

Based on Kindness-Kismet/re-editor commit
`10fdbc13ac96600f63ea16cebda5799771bdb898` (version 0.8.0).
The library, package manifest and MIT license are retained locally so the patch
is reproducible without changing the shared Pub cache.

Mobile long-press selection requests editor focus without opening the software
keyboard. `ensureInput(showKeyboard: false)` consumes the keyboard token for a
new focus request and leaves an existing input connection alone. Normal taps
continue to call `ensureInput()` and open the keyboard for editing.

Regression coverage lives in
`test/features/settings/view/source_editor/source_editor_content_test.dart`.
