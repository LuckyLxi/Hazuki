import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String script({String? location, bool setting = false}) =>
      '''
Hazuki.registerSource({
  id: 'placement',
  search: {load: async () => ({comics: []})},
  comic: {loadInfo: async () => ({}), loadEp: async () => ({images: []})},
  presentation: {actions: [{id: 'run', title: 'Run'${!setting && location != null ? ", location: '$location'" : ''}}]},
  settings: {option: {type: 'switch', default: false${setting && location != null ? ", location: '$location'" : ''}}}
});
''';

  test('old actions default to the plugin page', () async {
    final manifest = await SourcePluginScriptInspector().inspect(script());
    expect(
      SourcePluginAction.parseList(
        manifest.presentation['actions'],
      ).single.location,
      SourcePluginActionLocation.plugin,
    );
  });

  test('all allowed action locations survive manifest serialization', () async {
    for (final location in SourcePluginActionLocation.values) {
      final manifest = await SourcePluginScriptInspector().inspect(
        script(location: location.name),
      );
      final restored = SourcePluginManifest.fromJson(manifest.toJson());
      expect(
        SourcePluginAction.parseList(
          restored.presentation['actions'],
        ).single.location,
        location,
      );
    }
  });

  test(
    'excluded pages and unknown locations are rejected during inspection',
    () async {
      for (final location in [
        'settings',
        'about',
        'privacy',
        'storage',
        'cache',
        'cloudSync',
        'display',
        'unknown',
      ]) {
        await expectLater(
          SourcePluginScriptInspector().inspect(script(location: location)),
          throwsA(
            isA<SourcePluginException>().having(
              (e) => e.code,
              'code',
              'plugin_invalid_action_location',
            ),
          ),
        );
      }
    },
  );

  test('setting controls support only plugin and lines placement', () async {
    for (final location in ['plugin', 'lines']) {
      expect(
        (await SourcePluginScriptInspector().inspect(
          script(location: location, setting: true),
        )).id,
        'placement',
      );
    }
    await expectLater(
      SourcePluginScriptInspector().inspect(
        script(location: 'reading', setting: true),
      ),
      throwsA(
        isA<SourcePluginException>().having(
          (e) => e.code,
          'code',
          'plugin_invalid_setting_location',
        ),
      ),
    );
  });

  test('existing source plugins retain valid declarations', () async {
    for (final id in ['example', 'jm', 'copy_manga', 'picacg']) {
      expect(
        (await SourcePluginScriptInspector().inspect(
          await File('test/fixtures/source_plugins/$id/main.js').readAsString(),
        )).id,
        id,
      );
    }
  });
}
