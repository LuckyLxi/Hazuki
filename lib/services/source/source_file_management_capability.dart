part of '../hazuki_source_service.dart';

extension HazukiSourceServiceSourceFileManagementCapability
    on HazukiSourceService {
  Future<String?> readLocalJmSourceIfExists() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/jm.js');
    if (!await jmFile.exists()) {
      return null;
    }
    return jmFile.readAsString();
  }

  Future<String> loadEditableJmSource() async {
    final result = await _downloadOrLoadSourceFiles();
    return result.jmFile.readAsString();
  }

  Future<void> writeLocalJmSource(String content) async {
    final result = await _ensureLocalSourceFiles(requireJmFile: false);
    await result.jmFile.writeAsString(content, flush: true);
  }

  Future<void> saveEditedJmSource(String content) async {
    final result = await _downloadOrLoadSourceFiles();
    await result.jmFile.writeAsString(content, flush: true);
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(HazukiSourceService._customEditedJmSourceKey, true);
    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'local_source_editor',
      'outcome': 'edited_waiting_for_restart',
    };
    _setRuntimeWaitingForRestartState(
      statusText: 'source_edited_waiting_for_restart',
      debugDetail: 'local_source_editor',
    );
  }

  Future<bool> hasLocalJmSourceFile() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/jm.js');
    return jmFile.exists();
  }

  Future<bool> hasCustomEditedJmSource() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs.getBool(HazukiSourceService._customEditedJmSourceKey) ?? false;
  }

  Future<void> reloadFromLocalSourceFiles() async {
    if (_isRefreshingSource) {
      throw Exception('source_reload_in_progress');
    }
    _isRefreshingSource = true;
    try {
      _setRuntimeBusyState(
        SourceRuntimePhase.loading,
        SourceRuntimeStep.loadingCache,
        statusText: 'source_reloading_from_local_restore',
        debugDetail: 'cloud_sync_restore',
      );
      _lastReloginAt = null;
      _favoritesDebugCache = null;
      _exploreSectionsMemoryCache = null;
      _exploreSectionsMemoryCachedAt = null;
      _categoryTagGroupsMemoryCache = null;
      _categoryTagGroupsMemoryCachedAt = null;
      final result = await _ensureLocalSourceFiles();
      _setRuntimeBusyState(
        SourceRuntimePhase.loading,
        SourceRuntimeStep.creatingEngine,
        debugDetail: 'creating_engine',
      );
      final meta = await _loadSourceMetadata(result.initFile, result.jmFile);
      _sourceMeta = meta;
      _setRuntimeReadyState(result: result, meta: meta);
      if (isLogged) {
        await _tryReloginFromStoredAccount(force: true);
      }
    } finally {
      _isRefreshingSource = false;
    }
  }

  Future<Directory> _getSourceStorageDirectory() async {
    if (Platform.isAndroid) {
      final supportDir = await getApplicationSupportDirectory();
      return Directory('${supportDir.path}/comic_source');
    }

    if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      return Directory('$exeDir/comic_source');
    }

    if (Platform.isLinux || Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        return Directory('${downloadsDir.path}/hazuki_source_test');
      }
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    return Directory('${documentsDir.path}/comic_source');
  }
}
