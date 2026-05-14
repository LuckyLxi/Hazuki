part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceSourceFileManagementCapability
    on HazukiSourceService {
  Future<String?> readLocalJmSourceIfExists() async {
    final File jmFile;
    try {
      final sourceDir = await _getSourceStorageDirectory();
      jmFile = File('${sourceDir.path}/source.js');
    } catch (_) {
      return null;
    }
    if (!await jmFile.exists()) {
      return null;
    }
    return jmFile.readAsString();
  }

  Future<String> loadEditableJmSource() async {
    return loadEditableSource(activeSourceKey);
  }

  Future<void> writeLocalJmSource(String content) async {
    await writeLocalSource(activeSourceKey, content);
  }

  Future<void> saveEditedJmSource(String content) async {
    await saveEditedSource(activeSourceKey, content);
  }

  Future<String> loadEditableSource(String sourceKey) async {
    final previous = activeSourceKey;
    await activateSource(sourceKey);
    try {
      final result = await _downloadOrLoadSourceFiles();
      return result.jmFile.readAsString();
    } finally {
      if (previous != activeSourceKey) {
        await activateSource(previous);
      }
    }
  }

  Future<void> writeLocalSource(String sourceKey, String content) async {
    final sourceDir = await _getSourceStorageDirectory(sourceKey: sourceKey);
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }
    final file = File('${sourceDir.path}/source.js');
    await file.writeAsString(content, flush: true);
  }

  Future<void> saveEditedSource(String sourceKey, String content) async {
    final previous = activeSourceKey;
    await activateSource(sourceKey);
    try {
      final facade = this.facade;
      final result = await _downloadOrLoadSourceFiles();
      await result.jmFile.writeAsString(content, flush: true);
      final prefs = await facade.ensurePrefs();
      await prefs.setBool(SourcePrefsKeys.customEditedJmSource, true);
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'local_source_editor',
        'sourceKey': activeSourceKey,
        'outcome': 'edited_waiting_for_restart',
      };
      _setRuntimeWaitingForRestartState(
        statusText: 'source_edited_waiting_for_restart',
        debugDetail: 'local_source_editor',
      );
    } finally {
      if (previous != activeSourceKey) {
        await activateSource(previous);
      }
    }
  }

  Future<bool> hasLocalJmSourceFile() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/source.js');
    if (activeSourceKey == hazukiDefaultSourceKey && !await jmFile.exists()) {
      final legacy = File('${sourceDir.parent.path}/jm.js');
      return legacy.exists();
    }
    return jmFile.exists();
  }

  Future<bool> hasCustomEditedJmSource() async {
    final prefs = await facade.ensurePrefs();
    return prefs.getBool(SourcePrefsKeys.customEditedJmSource) ?? false;
  }

  Future<void> reloadFromLocalSourceFiles() async {
    final facade = this.facade;
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
      );
      facade.lastReloginAt = null;
      facade.favoritesDebugCache = null;
      exploreCache.clearMemory();
      facade.cache.clearCategoryTagGroupsMemoryCache();
      final result = await _ensureLocalSourceFiles();
      _setRuntimeBusyState(
        SourceRuntimePhase.loading,
        SourceRuntimeStep.creatingEngine,
        debugDetail: 'creating_engine',
      );
      final meta = await _loadSourceMetadata(result.jmFile);
      facade.runtime.sourceMeta = meta;
      _setRuntimeReadyState(result: result, meta: meta);
      if (isLogged) {
        await _tryReloginFromStoredAccount(force: true);
      }
    } finally {
      facade.isRefreshingSource = false;
    }
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
