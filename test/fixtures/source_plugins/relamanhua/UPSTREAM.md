# Source attribution

Snapshot of `HazukiSources/relamanhua.js`, API v1, version `1.3.4`.
Includes the author-tag fix: authors are returned in `tags["作者"]`, never in
comic or detail subtitles. Detail rows use the unified `infoFields` contract.
The plugin is an original Hazuki implementation for 热辣漫画, licensed under
the project GPL-3.0 license. Its attribution and algorithm notes remain in
`main.js`; it is not adapted from a venera-configs source.

`responses/` contains the public, anonymous HTML/JSON response fixtures from
`HazukiSources/dev/test/fixtures/relamanhua/`. They are copied unchanged for
offline host tests, including encrypted chapter and image-list payloads.
The tests do not load page scripts or contact the website. Login, profile and
favorite responses are synthetic and contain only test credentials; these
tests do not validate a live account or paid access.

To refresh, copy the current plugin and the response files named in this
directory from Sources, adjust only the type-reference path in `main.js`,
and run `flutter test test/services/source/relamanhua_source_plugin_test.dart`.
