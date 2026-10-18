import 'dart:convert';

import 'package:flutter/services.dart';
import '../runtime/source_script_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/source_js_bridge_cookie_capability.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_secure_session_storage.dart';
import 'source_plugin_models.dart';
import 'source_plugin_buttons.dart';
import 'source_search_capabilities.dart';
import '../account/source_login_interaction.dart';

/// Reads a plugin's own registration without running init or accessing user data.
class SourcePluginScriptInspector {
  SourcePluginScriptInspector({Future<String> Function(String)? loadAssetText})
    : _loadAssetText = loadAssetText ?? rootBundle.loadString;

  final Future<String> Function(String) _loadAssetText;

  Future<SourcePluginManifest> inspect(String script) async {
    final init = await _loadAssetText('assets/init.js');
    final sdk = await _loadAssetText('assets/hazuki_plugin_sdk.js');
    final handle = SourceRuntimeHandle(
      sourceKey: '_plugin_inspection',
      secureStorage: MemorySourceSecureSessionStorage(),
      ensureInitialized: (_) async {},
      notifyRuntimeStateChanged: (_) {},
    );
    final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
    final engine = SourceScriptEngine(
      timeout: 5000,
      memoryLimit: 64 * 1024 * 1024,
      hostPromiseRejectionHandler: (_) {},
    );
    handle.runtime.engine = engine;
    try {
      // Expose only the app locale; private plugin data remains unavailable below.
      handle.session.prefs = await SharedPreferences.getInstance();
      engine.setMessageHandler((dynamic message) {
        final method = message is Map ? message['method'] : null;
        if (method == 'load_data' ||
            method == 'load_setting' ||
            method == 'secret_get') {
          return null;
        }
        if (method == 'isLogged') return false;
        if (const {
          'html',
          'convert',
          'random',
          'uuid',
          'getLocale',
          'getPlatform',
          'log',
        }.contains(method)) {
          return bridge.handleJsMessageForHandle(handle, message);
        }
        throw const SourcePluginException('plugin_host_call_during_inspection');
      });
      engine.setGlobal('appVersion', '1.0.0');
      engine.evaluate(init, name: 'init.js');
      engine.evaluate(sdk, name: 'hazuki_plugin_sdk.js');
      evaluateSourcePlugin(engine, script);
      return registeredSourcePluginManifest(engine);
    } finally {
      handle.requestDispose();
    }
  }
}

void evaluateSourcePlugin(SourceScriptEngine engine, String script) {
  engine.evaluate(script, name: 'main.js');
  if (engine.evaluate('!!globalThis.__hazuki_source') == true) return;
  final sourceClass = RegExp(
    r'class\s+([A-Za-z_$][A-Za-z0-9_$]*)\s+extends\s+(?:HazukiSource|ComicSource)\b',
  ).firstMatch(script)?.group(1);
  if (sourceClass == null) {
    throw const SourcePluginException('plugin_registration_missing');
  }
  engine.evaluate('Hazuki.registerSource(new $sourceClass())');
}

SourcePluginManifest registeredSourcePluginManifest(SourceScriptEngine engine) {
  if (engine.evaluate(
        'typeof globalThis.__hazuki_source.comic?.loadReadingHistory === "function" && typeof globalThis.__hazuki_source.comic?.loadReadingProgress !== "function"',
      ) ==
      true) {
    throw const SourcePluginException(
      'plugin_history_requires_progress_reader',
    );
  }
  SourceLoginMethod.parse(
    engine.evaluate('globalThis.__hazuki_source.account?.loginMethods'),
  );
  final manifest = SourcePluginManifest.fromJson({
    ...Map<String, dynamic>.from(
      jsonDecode(
            engine.evaluate(
                  'JSON.stringify((({key,name,version,apiVersion,presentation,settings,translation,comic})=>({id:key,name,version,apiVersion,presentation:{...presentation,...(typeof comic?.loadReadingProgress === "function" ? {__hostCloudReading:true} : {})},settings,translation}))(globalThis.__hazuki_source))',
                )
                as String,
          )
          as Map,
    ),
    'entry': 'main.js',
  });
  final recommendation = DailyRecommendationConfig.parse(
    manifest.presentation['dailyRecommendation'],
  );
  if (recommendation?.mode == DailyRecommendationMode.plugin &&
      engine.evaluate(
            'typeof globalThis.__hazuki_source.dailyRecommendation?.load === "function"',
          ) !=
          true) {
    throw const SourcePluginException('plugin_recommendation_callback_missing');
  }
  for (final button in SourcePluginButton.parseList(
    manifest.presentation['buttons'],
  )) {
    final callback = switch (button.id) {
      'checkIn' || 'autoCheckIn' => 'account?.checkIn',
      'copyComicId' || 'relatedComics' => 'comic?.loadInfo',
      'resetDeviceInfo' => 'actions?.[${jsonEncode(button.action)}]',
      _ => null,
    };
    if (callback != null &&
        engine.evaluate(
              'typeof globalThis.__hazuki_source.$callback === "function"',
            ) !=
            true) {
      throw SourcePluginException('plugin_button_callback_missing', button.id);
    }
  }
  return manifest;
}
