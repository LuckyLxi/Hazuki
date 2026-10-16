import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'source_script_engine.dart';

import '../../../models/source_meta.dart';
import '../common/source_json_coerce.dart';
import '../models/source_contract_models.dart';
import '../plugins/source_plugin_models.dart';
import '../plugins/source_plugin_script_inspector.dart';
import 'source_catalog_resolver.dart';
import 'source_js_bridge_cookie_capability.dart';
import 'source_html_bridge.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_storage.dart';
import 'source_text_downloader.dart';

abstract interface class SourceRuntimeLoadClient {
  Future<SourceRuntimeLoadResult> ensureLocalSource(
    SourceRuntimeHandle handle, {
    bool requireFile = true,
  });
  Future<SourceRuntimeLoadResult> downloadOrLoad(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  });
  Future<SourceRuntimeLoadResult> download(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  });
  Future<SourceMeta> loadMetadata(SourceRuntimeHandle handle, File sourceFile);
}

/// Prepares source scripts and builds their JavaScript runtime engines.
class SourceRuntimeLoader implements SourceRuntimeLoadClient {
  SourceRuntimeLoader({
    required SourceScriptStore scriptStore,
    required SourceCatalogResolver catalogResolver,
    required SourceTextDownloadClient downloader,
    required SourceJsBridgeCookieCapability jsBridge,
    required SourceRuntimeStateController runtimeStateController,
    required String bundledInitAssetPath,
    Future<String> Function(String path)? loadAssetText,
  }) : _scriptStore = scriptStore,
       _catalogResolver = catalogResolver,
       _downloader = downloader,
       _jsBridge = jsBridge,
       _runtimeStateController = runtimeStateController,
       _bundledInitAssetPath = bundledInitAssetPath,
       _loadAssetText = loadAssetText ?? rootBundle.loadString;

  final SourceScriptStore _scriptStore;
  final SourceCatalogResolver _catalogResolver;
  final SourceTextDownloadClient _downloader;
  final SourceJsBridgeCookieCapability _jsBridge;
  final SourceRuntimeStateController _runtimeStateController;
  final String _bundledInitAssetPath;
  final Future<String> Function(String path) _loadAssetText;

  @override
  Future<SourceRuntimeLoadResult> ensureLocalSource(
    SourceRuntimeHandle handle, {
    bool requireFile = true,
  }) async {
    final sourceFile = await _scriptStore.ensureLocalSourceFile(
      handle.sourceKey,
    );
    if (requireFile && !await sourceFile.exists()) {
      throw Exception('source_local_jm_missing');
    }
    return SourceRuntimeLoadResult(
      sourceFile: sourceFile,
      message: 'source_loaded_from_local_cache',
    );
  }

  @override
  Future<SourceRuntimeLoadResult> downloadOrLoad(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    final local = await ensureLocalSource(handle, requireFile: false);
    if (await local.sourceFile.exists()) return local;
    throw const SourcePluginException('plugin_not_installed');
  }

  @override
  Future<SourceRuntimeLoadResult> download(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    final local = await ensureLocalSource(handle, requireFile: false);
    final sourceScript = await _downloader.sequential(
      await _catalogResolver.resolve(handle),
      onProgress: onProgress,
      facade: handle.facade,
    );
    if (sourceScript != null && sourceScript.trim().isNotEmpty) {
      await _scriptStore.write(handle.sourceKey, sourceScript);
      return SourceRuntimeLoadResult(
        sourceFile: local.sourceFile,
        message: 'source_downloaded_manually',
      );
    }
    throw Exception('source_download_failed_without_cache');
  }

  @override
  Future<SourceMeta> loadMetadata(
    SourceRuntimeHandle handle,
    File sourceFile,
  ) => _loadMetadata(handle, sourceFile, runSourceInit: true);

  /// Loads local declarations and callbacks without invoking network startup.
  Future<SourceMeta> loadLocalMetadata(
    SourceRuntimeHandle handle,
    File sourceFile,
  ) => _loadMetadata(handle, sourceFile, runSourceInit: false);

  Future<SourceMeta> _loadMetadata(
    SourceRuntimeHandle handle,
    File sourceFile, {
    required bool runSourceInit,
  }) async {
    final facade = handle.facade;
    if (handle.isDisposed) throw Exception('source_runtime_disposed');

    final initScript = await _loadAssetText(_bundledInitAssetPath);
    final sourceScript = await sourceFile.readAsString();
    final sdk = await _loadAssetText('assets/hazuki_plugin_sdk.js');
    final engine = SourceScriptEngine(
      timeout: 5000,
      memoryLimit: 64 * 1024 * 1024,
      hostPromiseRejectionHandler: (_) {},
    );
    final oldEngine = facade.runtime.engine;
    final oldMeta = facade.sourceMeta;
    final oldHtmlBridge = handle.htmlBridge;
    final htmlBridge = SourceHtmlBridge();
    try {
      engine.setMessageHandler(
        (dynamic message) => _jsBridge.handleJsMessageForHandle(
          handle,
          message,
          htmlBridge: htmlBridge,
        ),
      );
      engine.setGlobal('appVersion', '1.0.0');

      engine.evaluate(initScript, name: 'init.js');
      engine.evaluate(sdk, name: 'hazuki_plugin_sdk.js');
      evaluateSourcePlugin(engine, sourceScript);
      final manifest = registeredSourcePluginManifest(engine);
      if (manifest.id != handle.sourceKey) {
        throw const SourcePluginException('plugin_identity_mismatch');
      }

      final name = (engine.evaluate('this.__hazuki_source.name') ?? '')
          .toString();
      final key = (engine.evaluate('this.__hazuki_source.key') ?? '')
          .toString();
      final version = (engine.evaluate('this.__hazuki_source.version') ?? '')
          .toString();
      final supportsAccount = jsAsBool(
        engine.evaluate('!!this.__hazuki_source.account?.login'),
      );
      if (name.isEmpty || key.isEmpty || version.isEmpty) {
        throw Exception('source_metadata_incomplete');
      }

      final meta = SourceMeta(
        translation: manifest.translation,
        name: name,
        key: key,
        version: version,
        supportsAccount: supportsAccount,
        settingsDefaults: parseSourceSettingsDefaults(
          engine.evaluate('this.__hazuki_source.settings ?? {}'),
        ),
        presentation: jsAsMap(
          engine.evaluate('this.__hazuki_source.presentation ?? {}'),
        ),
        settings: Map<String, dynamic>.from(
          jsonDecode(
                engine.evaluate(
                      'JSON.stringify(this.__hazuki_source.settings ?? {})',
                    )
                    as String,
              )
              as Map,
        ),
      );
      if (runSourceInit) {
        _runtimeStateController.setBusy(
          facade,
          facade.runtimeState.phase,
          SourceRuntimeStep.runningSourceInit,
          debugDetail: 'running_source_init',
        );
      }
      facade.runtime.sourceMeta = meta;
      facade.runtime.engine = engine;
      handle.htmlBridge = htmlBridge;
      try {
        if (runSourceInit) {
          final initResult = engine.evaluate(
            'this.__hazuki_source.init?.()',
            name: 'source_init.js',
          );
          if (initResult is Future) {
            await initResult.timeout(const Duration(seconds: 90));
          }
        }
        if (handle.isDisposed) throw Exception('source_runtime_disposed');
      } catch (_) {
        facade.runtime.sourceMeta = oldMeta;
        facade.runtime.engine = oldEngine;
        rethrow;
      }
      facade.runtime.engine = engine;
      final finalMeta = SourceMeta(
        translation: jsAsMap(
          engine.evaluate('this.__hazuki_source.translation ?? {}'),
        ),
        name: name,
        key: key,
        version: version,
        supportsAccount: supportsAccount,
        presentation: meta.presentation,
        settingsDefaults: parseSourceSettingsDefaults(
          engine.evaluate('this.__hazuki_source.settings ?? {}'),
        ),
        settings: Map<String, dynamic>.from(
          jsonDecode(
                engine.evaluate(
                      'JSON.stringify(this.__hazuki_source.settings ?? {})',
                    )
                    as String,
              )
              as Map,
        ),
      );
      facade.runtime.sourceMeta = finalMeta;
      oldEngine?.close();
      oldHtmlBridge.clear();
      return finalMeta;
    } catch (_) {
      facade.runtime.engine = oldEngine;
      facade.runtime.sourceMeta = oldMeta;
      htmlBridge.clear();
      handle.htmlBridge = oldHtmlBridge;
      if (handle.isDisposed) oldHtmlBridge.clear();
      engine.close();
      rethrow;
    }
  }
}

class SourceRuntimeLoadResult {
  const SourceRuntimeLoadResult({
    required this.sourceFile,
    required this.message,
  });

  final File sourceFile;
  final String message;
}

String extractSourceClassName(String script) {
  final match = RegExp(
    r'class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+ComicSource',
  ).firstMatch(script);
  if (match == null) throw Exception('source_class_not_found');
  return match.group(1)!;
}

Map<String, dynamic> parseSourceSettingsDefaults(dynamic raw) {
  if (raw is! Map) return {};
  final defaults = <String, dynamic>{};
  for (final entry in Map<String, dynamic>.from(raw).entries) {
    final value = entry.value;
    if (value is Map && value.containsKey('default')) {
      defaults[entry.key] = value['default'];
    }
  }
  return defaults;
}
