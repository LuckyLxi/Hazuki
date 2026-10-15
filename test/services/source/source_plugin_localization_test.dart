import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_localization.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_script_inspector.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_localization_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/source_catalog_fixtures.dart';

const _translation = {
  'zh_CN': {'Greeting': '你好', 'Language only': '语言翻译'},
  'zh': {'Greeting': '语言级翻译'},
  'en_US': {'Greeting': 'Hello'},
  'en': {'Language only': 'Language fallback'},
};

SourceRuntimeHandle _handle() {
  final handle = SourceRuntimeHandle(
    sourceKey: 'localized',
    secureStorage: MemorySourceSecureSessionStorage(),
    ensureInitialized: (_) async {},
    notifyRuntimeStateChanged: (_) {},
  );
  addTearDown(handle.requestDispose);
  return handle;
}

Future<SourceScriptEngine> _installRuntime(SourceRuntimeHandle handle) async {
  await handle.session.ensurePrefs();
  final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
  final engine = SourceScriptEngine(
    timeout: 5000,
    hostPromiseRejectionHandler: (_) {},
  );
  handle.runtime.engine = engine;
  engine.setMessageHandler(
    (dynamic message) => bridge.handleJsMessageForHandle(handle, message),
  );
  engine.evaluate(await File('assets/init.js').readAsString());
  engine.evaluate(await File('assets/hazuki_plugin_sdk.js').readAsString());
  engine.evaluate('''
Hazuki.registerSource({
  id: ${jsonEncode(handle.sourceKey)}, translation: ${jsonEncode(_translation)},
  search: {load: async () => ({comics: []})},
  comic: {loadInfo: async () => ({}), loadEp: async () => ({images: []})}
});
const legacy = new HazukiSource();
legacy.translation = ${jsonEncode(_translation)};
''');
  return engine;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Dart and JavaScript share locale aliases and fallback rules', () async {
    final engine = await _installRuntime(_handle());
    final cases = <(Object, String, String)>[
      ('Greeting', 'zh', '你好'),
      ('Greeting', 'zh-CN', '你好'),
      ('Greeting', 'en_US', 'Hello'),
      ('Language only', 'en-US', 'Language fallback'),
      ('Unknown', 'zh', 'Unknown'),
      (' Unknown ', 'en', ' Unknown '),
      ({'zh_CN': '区域', 'zh': '语言', 'en': 'English'}, 'zh', '区域'),
      ({'en': 'English'}, 'zh', 'English'),
      ({'zh': '中文'}, 'en', '中文'),
      ({'zh': '  ', 'en': 'English'}, 'zh', 'English'),
      ({'en': '  ', 'ja': '日本語'}, 'zh', '日本語'),
      ({'fr': 'Français', 'en': 'English'}, 'fr', 'Français'),
      ({}, 'en', ''),
    ];
    for (final (text, locale, expected) in cases) {
      expect(
        localizeSourcePluginText(text, locale, translation: _translation),
        expected,
      );
      expect(
        engine.evaluate(
          '__hazukiLocalizeText(${jsonEncode(text)}, ${jsonEncode(_translation)}, ${jsonEncode(locale)})',
        ),
        expected,
      );
    }
    expect(
      localizeSourcePluginText({}, 'zh', fallback: 'Fallback'),
      'Fallback',
    );
    expect(
      localizeSourcePluginText(
        'Greeting',
        'en',
        translation: {
          'en_US': {'Greeting': ' '},
          'en': {'Greeting': 'Fallback'},
        },
      ),
      'Fallback',
    );
  });

  test(
    'SDK and class sources read language changes without reloading',
    () async {
      final handle = _handle();
      final engine = await _installRuntime(handle);
      final prefs = handle.session.prefs!;
      for (final (language, tag, greeting, fallback) in [
        ('zh', 'zh_CN', '你好', '语言翻译'),
        ('en', 'en_US', 'Hello', 'Language fallback'),
        ('zh', 'zh_CN', '你好', '语言翻译'),
      ]) {
        await prefs.setString(hazukiLocalePreferenceKey, language);
        expect(engine.evaluate('Hazuki.locale'), tag);
        expect(engine.evaluate('APP.locale'), tag);
        expect(engine.evaluate("Hazuki.translate('Greeting')"), greeting);
        expect(engine.evaluate("legacy.translate('Greeting')"), greeting);
        expect(engine.evaluate("Hazuki.translate('Language only')"), fallback);
        expect(
          engine.evaluate("Hazuki.translate({zh:'中文',en:'English'})"),
          language == 'zh' ? '中文' : 'English',
        );
      }
    },
  );

  test(
    'system language follows the same supported-locale fallback as the app',
    () async {
      final prefs = await SharedPreferences.getInstance();
      addTearDown(binding.platformDispatcher.clearLocalesTestValue);
      binding.platformDispatcher.localesTestValue = const [Locale('zh', 'TW')];
      expect(sourcePluginLocaleTag(prefs), 'zh_CN');
      await prefs.setString(hazukiLocalePreferenceKey, 'en');
      expect(sourcePluginLocaleTag(prefs), 'en_US');
      await prefs.setString(hazukiLocalePreferenceKey, 'system');
      expect(sourcePluginLocaleTag(prefs), 'zh_CN');
      binding.platformDispatcher.localesTestValue = const [Locale('fr')];
      expect(sourcePluginLocaleTag(prefs), 'en_US');
      binding.platformDispatcher.localesTestValue = const [
        Locale('fr'),
        Locale('zh'),
      ];
      expect(sourcePluginLocaleTag(prefs), 'zh_CN');
    },
  );

  test(
    'inspection persists raw multilingual declarations and current app locale',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(hazukiLocalePreferenceKey, 'en');
      final manifest = await SourcePluginScriptInspector().inspect('''
Hazuki.registerSource({
  id: 'localized', name: Hazuki.locale,
  translation: ${jsonEncode(_translation)},
  presentation: {actions: [{id: 'run', title: {zh: '执行', en: 'Run'}}]},
  search: {load: async () => ({comics: []})},
  comic: {loadInfo: async () => ({}), loadEp: async () => ({images: []})}
});
''');
      expect(manifest.name, 'en_US');
      final restored = SourcePluginManifest.fromJson(manifest.toJson());
      expect(restored.translation, _translation);
      expect(
        SourcePluginAction.parseList(
          restored.presentation['actions'],
        ).single.title,
        {'zh': '执行', 'en': 'Run'},
      );
      expect(
        SourcePluginManifest.fromJson(
          {...manifest.toJson()}..remove('translation'),
        ).translation,
        isEmpty,
      );
    },
  );

  test(
    'source translations support English and invalidate inactive source caches',
    () async {
      final host = SourceRuntimeHost(
        catalog: hazukiAllowedSourceCatalog,
        defaultSourceKey: 'jm',
        secureSessionStorage: MemorySourceSecureSessionStorage(),
        ensureSourceInitialized: (_) async {},
        currentAccountForSource: (_) => null,
        isLoggedForSource: (_) => false,
      );
      addTearDown(host.dispose);
      final handle = host.handleFor('jm');
      await _installRuntime(handle);
      final localization = SourceLocalizationOperations(host);
      await handle.session.prefs!.setString(hazukiLocalePreferenceKey, 'en');
      expect(localization.translateSourceText('Greeting'), 'Hello');
      await handle.session.prefs!.setString(hazukiLocalePreferenceKey, 'zh');
      expect(localization.translateSourceText('Greeting'), '你好');
      expect(localization.translateSourceText('Unknown'), 'Unknown');
      expect(
        localization.translateSourceText('Greeting', sourceKey: 'missing'),
        'Greeting',
      );
      final inactive = host.handleFor('picacg');
      for (final current in [handle, inactive]) {
        current.cache.exploreSectionsMemoryCache = [];
        current.cache.categoryTagGroupsMemoryCache = [];
      }
      expect(host.existingHandles, hasLength(2));
      localization.clearLocalizedSourceTextCaches();
      for (final current in [handle, inactive]) {
        expect(current.cache.exploreSectionsMemoryCache, isNull);
        expect(current.cache.categoryTagGroupsMemoryCache, isNull);
      }
      expect(host.existingHandles, hasLength(2));
    },
  );
}
