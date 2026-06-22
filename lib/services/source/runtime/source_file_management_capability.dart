part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceSourceFileManagementCapability
    on HazukiSourceService {
  Future<String?> readLocalActiveSourceIfExists() async {
    return readLocalSourceIfExists(activeSourceKey);
  }

  Future<String?> readLocalSourceIfExists(String sourceKey) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final File sourceFile;
    try {
      final sourceDir = await _getSourceStorageDirectory(
        sourceKey: normalizedSourceKey,
      );
      sourceFile = File('${sourceDir.path}/source.js');
    } catch (_) {
      return null;
    }
    if (!await sourceFile.exists()) {
      return null;
    }
    return sourceFile.readAsString();
  }

  Future<String?> readLocalJmSourceIfExists() async {
    return readLocalActiveSourceIfExists();
  }

  Future<String> loadEditableActiveSource() async {
    return loadEditableSource(activeSourceKey);
  }

  Future<String> loadEditableJmSource() async {
    return loadEditableActiveSource();
  }

  Future<void> writeLocalActiveSource(String content) async {
    await writeLocalSource(activeSourceKey, content);
  }

  Future<void> writeLocalJmSource(String content) async {
    await writeLocalActiveSource(content);
  }

  Future<void> saveEditedActiveSource(String content) async {
    await saveEditedSource(activeSourceKey, content);
  }

  Future<void> saveEditedJmSource(String content) async {
    await saveEditedActiveSource(content);
  }

  Future<String> loadEditableSource(String sourceKey) async {
    final handle = _handleFor(sourceKey);
    return handle.runOperation(() async {
      final result = await _downloadOrLoadSourceFiles(handle: handle);
      return result.jmFile.readAsString();
    });
  }

  Future<void> writeLocalSource(String sourceKey, String content) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final sourceDir = await _getSourceStorageDirectory(
      sourceKey: normalizedSourceKey,
    );
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }
    final file = File('${sourceDir.path}/source.js');
    await file.writeAsString(content, flush: true);
    await _setCustomEditedSourceFlag(normalizedSourceKey, true);
  }

  Future<void> saveEditedSource(String sourceKey, String content) async {
    final handle = _handleFor(sourceKey);
    await handle.runOperation(() async {
      final facade = handle.facade;
      final result = await _downloadOrLoadSourceFiles(handle: handle);
      await result.jmFile.writeAsString(content, flush: true);
      await _setCustomEditedSourceFlag(
        handle.sourceKey,
        true,
        targetFacade: facade,
      );
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'local_source_editor',
        'sourceKey': handle.sourceKey,
        'outcome': 'edited_waiting_for_restart',
      };
      _setRuntimeWaitingForRestartState(
        statusText: 'source_edited_waiting_for_restart',
        debugDetail: 'local_source_editor',
        targetFacade: facade,
      );
    });
  }

  Future<bool> hasLocalJmSourceFile() async {
    return hasLocalSourceFile(activeSourceKey);
  }

  Future<bool> hasLocalSourceFile(String sourceKey) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final sourceDir = await _getSourceStorageDirectory(
      sourceKey: normalizedSourceKey,
    );
    final jmFile = File('${sourceDir.path}/source.js');
    if (normalizedSourceKey == hazukiDefaultSourceKey &&
        !await jmFile.exists()) {
      final legacy = File('${sourceDir.parent.path}/jm.js');
      return legacy.exists();
    }
    return jmFile.exists();
  }

  Future<void> deleteLocalSourceFile(String sourceKey) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    if (normalizedSourceKey == activeSourceKey) {
      throw StateError('source_delete_active_not_allowed');
    }

    final sourceDir = await _getSourceStorageDirectory(
      sourceKey: normalizedSourceKey,
    );
    final sourceFile = File('${sourceDir.path}/source.js');
    if (await sourceFile.exists()) {
      await sourceFile.delete();
    }
    await _setCustomEditedSourceFlag(normalizedSourceKey, false);
    _runtimeHandles.remove(normalizedSourceKey)?.requestDispose();
  }

  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final handle = _handleFor(normalizedSourceKey);
    await handle.runOperation(() async {
      final facade = handle.facade;
      facade.lastReloginAt = null;
      handle.exploreCache.clearMemory();
      facade.cache.clearCategoryTagGroupsMemoryCache();
      final result = await _downloadSourceFiles(
        handle: handle,
        onProgress: onProgress,
      );
      await _setCustomEditedSourceFlag(
        handle.sourceKey,
        false,
        targetFacade: facade,
      );
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'manual_source_download',
        'sourceKey': handle.sourceKey,
        'outcome': result.message,
      };
    });
    await activateSource(normalizedSourceKey);
  }

  Future<bool> hasCustomEditedActiveSource() async {
    return hasCustomEditedSource(activeSourceKey);
  }

  Future<bool> hasCustomEditedSource(String sourceKey) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final prefs = await _handleFor(normalizedSourceKey).facade.ensurePrefs();
    final scopedKey = SourcePrefsKeys.customEditedSource(normalizedSourceKey);
    if (prefs.containsKey(scopedKey)) {
      return prefs.getBool(scopedKey) ?? false;
    }
    if (normalizedSourceKey == hazukiDefaultSourceKey) {
      return prefs.getBool(SourcePrefsKeys.customEditedJmSource) ?? false;
    }
    return false;
  }

  Future<bool> hasCustomEditedJmSource() async {
    return hasCustomEditedActiveSource();
  }

  Future<void> _setCustomEditedSourceFlag(
    String sourceKey,
    bool value, {
    HazukiSourceFacade? targetFacade,
  }) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(sourceKey);
    final prefs = await (targetFacade ?? _handleFor(normalizedSourceKey).facade)
        .ensurePrefs();
    await prefs.setBool(
      SourcePrefsKeys.customEditedSource(normalizedSourceKey),
      value,
    );
    if (normalizedSourceKey == hazukiDefaultSourceKey) {
      await prefs.setBool(SourcePrefsKeys.customEditedJmSource, value);
    }
  }

  Future<void> reloadFromLocalSourceFiles() async {
    final handle = _activeHandle;
    await handle.runOperation(() async {
      final facade = handle.facade;
      if (facade.isRefreshingSource) {
        throw Exception('source_reload_in_progress');
      }
      facade.isRefreshingSource = true;
      try {
        _setRuntimeBusyState(
          SourceRuntimePhase.loading,
          SourceRuntimeStep.loadingCache,
          statusText: 'source_reloading_from_local_restore',
          debugDetail: 'cloud_sync_restore',
          targetFacade: facade,
        );
        facade.lastReloginAt = null;
        facade.favoritesDebugCache = null;
        handle.exploreCache.clearMemory();
        facade.cache.clearCategoryTagGroupsMemoryCache();
        final result = await _ensureLocalSourceFiles(handle: handle);
        _setRuntimeBusyState(
          SourceRuntimePhase.loading,
          SourceRuntimeStep.creatingEngine,
          debugDetail: 'creating_engine',
          targetFacade: facade,
        );
        final meta = await _loadSourceMetadata(result.jmFile, handle: handle);
        facade.runtime.sourceMeta = meta;
        _setRuntimeReadyState(result: result, meta: meta, targetFacade: facade);
        if (activeSourceKey == handle.sourceKey && facade.isLogged) {
          await _tryReloginFromStoredAccount(force: true);
        }
      } finally {
        facade.isRefreshingSource = false;
      }
    });
  }

  Future<Directory> _getSourceStorageDirectory({String? sourceKey}) async {
    final normalizedSourceKey = _normalizeAllowedSourceKey(
      sourceKey ?? activeSourceKey,
    );
    if (Platform.isAndroid) {
      final supportDir = await getApplicationSupportDirectory();
      return Directory('${supportDir.path}/comic_source/$normalizedSourceKey');
    }

    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return Directory('$exeDir/comic_source/$normalizedSourceKey');
    }

    if (Platform.isLinux || Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return Directory(
          '${downloadsDir.path}/hazuki_source_test/$normalizedSourceKey',
        );
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return Directory('${documentsDir.path}/comic_source/$normalizedSourceKey');
  }
}
