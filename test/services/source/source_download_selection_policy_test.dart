import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final inspector = SourcePluginScriptInspector(
    loadAssetText: (path) => File(path).readAsString(),
  );
  String plugin(String presentation) =>
      '''
    Hazuki.registerSource({
      id:'sample', presentation:$presentation,
      search:{load:()=>({comics:[]})},
      comic:{loadInfo:()=>({title:'Sample'}), loadEp:()=>({images:[]})}
    });
  ''';

  test(
    'multi-select declaration is independent of an archive download callback',
    () async {
      for (final presentation in [
        '{}',
        '{downloadMultiSelect:false}',
        '{downloadMultiSelect:true}',
      ]) {
        final manifest = await inspector.inspect(plugin(presentation));
        expect(
          manifest.presentation['downloadMultiSelect'] == true,
          presentation == '{downloadMultiSelect:true}',
        );
        final roundTrip = SourcePluginManifest.fromJson(manifest.toJson());
        expect(roundTrip.presentation, manifest.presentation);
      }
    },
  );

  test(
    'non-boolean multi-select declarations fail plugin validation',
    () async {
      for (final value in ['null', '1', '"true"', '{}', '[]']) {
        await expectLater(
          inspector.inspect(plugin('{downloadMultiSelect:$value}')),
          throwsA(isA<SourcePluginException>()),
        );
      }
    },
  );
}
