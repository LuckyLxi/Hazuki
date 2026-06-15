part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceSourceLoaderCapability on HazukiSourceService {
  Future<_SourceLoadResult> _ensureLocalSourceFiles({
    bool requireJmFile = true,
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final sourceDir = await _getSourceStorageDirectory(
      sourceKey: targetHandle.sourceKey,
    );
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }

    final jmFile = File('${sourceDir.path}/source.js');
    if (targetHandle.sourceKey == hazukiDefaultSourceKey &&
        !await jmFile.exists()) {
      final legacy = File('${sourceDir.parent.path}/jm.js');
      if (await legacy.exists()) {
        await legacy.copy(jmFile.path);
      }
    }

    if (requireJmFile && !await jmFile.exists()) {
      throw Exception('source_local_jm_missing');
    }

    return _SourceLoadResult(
      jmFile: jmFile,
      message: 'source_loaded_from_local_cache',
    );
  }

  Future<_SourceLoadResult> _downloadOrLoadSourceFiles({
    void Function(int received, int total)? onProgress,
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final localFiles = await _ensureLocalSourceFiles(
      requireJmFile: false,
      handle: targetHandle,
    );
    final jmFile = localFiles.jmFile;

    if (await jmFile.exists()) {
      return _SourceLoadResult(
        jmFile: jmFile,
        message: 'source_loaded_from_local_cache',
      );
    }

    final jmScript = await _downloadFromUrlsWithProgress(
      await _resolveActiveSourceDownloadUrls(handle: targetHandle),
      onProgress: onProgress,
      targetFacade: targetHandle.facade,
    );
    if (jmScript != null && jmScript.trim().isNotEmpty) {
      await jmFile.writeAsString(jmScript);
      return _SourceLoadResult(
        jmFile: jmFile,
        message: 'source_downloaded_on_first_launch',
      );
    }

    throw Exception('source_download_failed_without_cache');
  }

  Future<_SourceLoadResult> _downloadSourceFiles({
    void Function(int received, int total)? onProgress,
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final localFiles = await _ensureLocalSourceFiles(
      requireJmFile: false,
      handle: targetHandle,
    );
    final jmFile = localFiles.jmFile;

    final jmScript = await _downloadFromUrlsWithProgress(
      await _resolveActiveSourceDownloadUrls(handle: targetHandle),
      onProgress: onProgress,
      targetFacade: targetHandle.facade,
    );
    if (jmScript != null && jmScript.trim().isNotEmpty) {
      await jmFile.writeAsString(jmScript, flush: true);
      return _SourceLoadResult(
        jmFile: jmFile,
        message: 'source_downloaded_manually',
      );
    }

    throw Exception('source_download_failed_without_cache');
  }

  Future<SourceMeta> _loadSourceMetadata(
    File jmFile, {
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final facade = targetHandle.facade;
    if (facade.handle.isDisposed) {
      throw Exception('source_runtime_disposed');
    }
    final initScript = await rootBundle.loadString(_bundledInitAssetPath);
    final jmScript = await jmFile.readAsString();
    final className = _extractSourceClassName(jmScript);

    final engine = FlutterQjs(hostPromiseRejectionHandler: (_) {});
    try {
      engine.dispatch();

      final setGlobal =
          engine.evaluate('(k, v) => { this[k] = v; }') as JSInvokable;
      setGlobal.invoke([
        'sendMessage',
        (dynamic message) => _handleJsMessageForHandle(targetHandle, message),
      ]);
      setGlobal.invoke(['appVersion', '1.0.0']);
      setGlobal.free();

      engine.evaluate(initScript, name: 'init.js');
      engine.evaluate(jmScript, name: 'jm.js');
      engine.evaluate(
        "this.__hazuki_source = new $className();",
        name: 'create_source.js',
      );

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
      final settingsDefaults = _parseSettingsDefaultMap(
        engine.evaluate('this.__hazuki_source.settings ?? {}'),
      );

      final meta = SourceMeta(
        name: name,
        key: key,
        version: version,
        supportsAccount: supportsAccount,
        settingsDefaults: settingsDefaults,
      );

      _setRuntimeBusyState(
        facade.runtimeState.phase,
        SourceRuntimeStep.runningSourceInit,
        debugDetail: 'running_source_init',
        targetFacade: facade,
      );
      final oldMeta = facade.sourceMeta;
      facade.runtime.sourceMeta = meta;
      try {
        final initResult = engine.evaluate(
          'this.__hazuki_source.init?.()',
          name: 'source_init.js',
        );
        if (initResult is Future) {
          await initResult;
        }
        if (facade.handle.isDisposed) {
          throw Exception('source_runtime_disposed');
        }
      } catch (_) {
        facade.runtime.sourceMeta = oldMeta;
        rethrow;
      }
      final oldEngine = facade.runtime.engine;
      facade.runtime.engine = engine;
      oldEngine?.close();
      return meta;
    } catch (_) {
      engine.close();
      rethrow;
    }
  }

  Future<List<String>> _resolveActiveSourceDownloadUrls({
    SourceRuntimeHandle? handle,
  }) async {
    final targetHandle = handle ?? _activeHandle;
    final definition = _definitionForSourceKey(targetHandle.sourceKey);
    final directUrls = definition.directUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (directUrls.isNotEmpty) {
      return directUrls;
    }

    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_catalog_index',
      targetFacade: targetHandle.facade,
    );
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      return definition.fallbackUrls();
    }

    try {
      final decoded = jsonDecode(indexRaw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) {
            continue;
          }
          final map = Map<String, dynamic>.from(item);
          if (!definition.matchesIndexEntry(map)) {
            continue;
          }
          final rawUrl = map['url']?.toString().trim();
          if (rawUrl != null && rawUrl.isNotEmpty) {
            return [rawUrl];
          }
          final fileName =
              map['fileName']?.toString().trim() ?? definition.fileName;
          if (fileName.isNotEmpty) {
            return [
              'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/$fileName',
            ];
          }
        }
      }
    } catch (_) {}

    return definition.fallbackUrls();
  }
}
