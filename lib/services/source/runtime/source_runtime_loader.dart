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
import 'source_runtime_metadata.dart';
export 'source_runtime_metadata.dart' show parseSourceSettingsDefaults;
import 'source_script_storage.dart';
import 'source_text_downloader.dart';
import '../interaction/source_ui_scope.dart';
import '../interaction/source_ui_service.dart';

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
    final cancellation = handle.loginCancellation;
    cancellation?.check();

    final initScript = await _loadAssetText(_bundledInitAssetPath);
    final sourceScript = await sourceFile.readAsString();
    final sdk = await _loadAssetText('assets/hazuki_plugin_sdk.js');
    if (handle.isDisposed) throw Exception('source_runtime_disposed');
    cancellation?.check();
    final engine = SourceScriptEngine(
      pluginId: handle.sourceKey,
      timeout: 5000,
      memoryLimit: 64 * 1024 * 1024,
      hostPromiseRejectionHandler: (_) {},
    );
    final oldEngine = facade.runtime.engine;
    final oldHtmlBridge = handle.htmlBridge;
    final htmlBridge = SourceHtmlBridge();
    SourceMeta? candidateMeta;
    engine.operationGuard = (operation) => handle.runOperation(operation);
    // Private login/cloud runtimes can be cancelled before this candidate is
    // published. Track its close so disposal also waits for worker cleanup.
    void cancelCandidate() => handle.closeEngine(engine).ignore();
    cancellation?.addListener(cancelCandidate);
    handle.loadingRuntimeIds.add(engine.runtimeId);
    try {
      engine.setContextMessageHandler(
        (dynamic message, execution) => _jsBridge.handleJsMessageForHandle(
          handle,
          message,
          htmlBridge: htmlBridge,
          execution: execution,
          runtimeId: engine.runtimeId,
          sourceMeta: () => identical(handle.runtime.engine, engine)
              ? handle.runtime.sourceMeta
              : candidateMeta,
        ),
      );
      await engine.setGlobal('appVersion', '1.0.0');

      await engine.execute(initScript, name: 'init.js');
      await engine.execute(sdk, name: 'hazuki_plugin_sdk.js');
      await evaluateSourcePlugin(engine, sourceScript);
      final manifest = await registeredSourcePluginManifest(engine);
      if (manifest.id != handle.sourceKey) {
        throw const SourcePluginException('plugin_identity_mismatch');
      }

      final name = (await engine.evaluate('this.__hazuki_source.name') ?? '')
          .toString();
      final key = (await engine.evaluate('this.__hazuki_source.key') ?? '')
          .toString();
      final version =
          (await engine.evaluate('this.__hazuki_source.version') ?? '')
              .toString();
      final supportsAccount = jsAsBool(
        await engine.evaluate('!!this.__hazuki_source.account?.login'),
      );
      if (name.isEmpty || key.isEmpty || version.isEmpty) {
        throw Exception('source_metadata_incomplete');
      }
      Future<Map<String, dynamic>> readSettings() async =>
          Map<String, dynamic>.from(
            jsonDecode(
                  await engine.evaluate(
                        'JSON.stringify(this.__hazuki_source.settings ?? {})',
                      )
                      as String,
                )
                as Map,
          );
      final settings = await readSettings();

      final meta = SourceMeta(
        translation: manifest.translation,
        name: name,
        key: key,
        version: version,
        supportsAccount: supportsAccount,
        settingsDefaults: parseSourceSettingsDefaults(settings),
        presentation: jsAsMap(
          await engine.evaluate('this.__hazuki_source.presentation ?? {}'),
        ),
        settings: settings,
      );
      if (runSourceInit) {
        _runtimeStateController.setBusy(
          facade,
          facade.runtimeState.phase,
          SourceRuntimeStep.runningSourceInit,
          debugDetail: 'running_source_init',
        );
      }
      candidateMeta = meta;
      if (runSourceInit) {
        await SourceUiScope.timeout(
          engine.evaluate(
            'this.__hazuki_source.init?.()',
            name: 'source_init.js',
          ),
          const Duration(seconds: 90),
        );
      }
      if (handle.isDisposed) throw Exception('source_runtime_disposed');
      final finalSettings = await readSettings();
      final finalSnapshot =
          jsonDecode(engine.cachedValue('__metadata') as String) as Map;
      final finalMeta = SourceMeta(
        translation: jsAsMap(finalSnapshot['translation']),
        name: finalSnapshot['name']?.toString() ?? name,
        key: key,
        version: finalSnapshot['version']?.toString() ?? version,
        supportsAccount: finalSnapshot['supportsAccount'] == true,
        presentation: jsAsMap(finalSnapshot['presentation']),
        settingsDefaults: parseSourceSettingsDefaults(finalSettings),
        settings: finalSettings,
      );
      if (handle.isDisposed) throw Exception('source_runtime_disposed');
      facade.runtime.sourceMeta = finalMeta;
      facade.runtime.engine = engine;
      handle.htmlBridge = htmlBridge;
      if (oldEngine != null) handle.retireEngine(oldEngine);
      oldHtmlBridge.clear();
      return finalMeta;
    } catch (_) {
      // The candidate has not been published. The current runtime may have
      // received live metadata updates or been disposed while init awaited.
      // Restoring a captured state would overwrite either of those outcomes.
      htmlBridge.clear();
      SourceUiService.instance.closeRuntimeInteractions(engine.runtimeId);
      await engine.close();
      rethrow;
    } finally {
      handle.loadingRuntimeIds.remove(engine.runtimeId);
      cancellation?.removeListener(cancelCandidate);
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
