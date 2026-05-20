part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceVersionUpdateCapability on HazukiSourceService {
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() async {
    return checkJmSourceVersionFromCloud();
  }

  Future<SourceVersionCheckResult?> checkJmSourceVersionFromCloud() async {
    final facade = this.facade;
    final sourceKey = activeSourceKey;
    final sourceDefinition = _definitionForSourceKey(sourceKey);
    final sourceName = _sourceUpdateDisplayName(sourceDefinition);
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/source.js');
    if (!await jmFile.exists()) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': false,
        'outcome': 'local_jm_missing',
      };
      return null;
    }

    final localVersion = await _readJmVersionFromFile(jmFile);
    final remoteVersionDirect = await _resolveRemoteJmVersion(
      sourceKey: sourceKey,
      sourceName: sourceName,
      sourceDefinition: sourceDefinition,
    );
    if (remoteVersionDirect != null && remoteVersionDirect.isNotEmpty) {
      final hasUpdate = _isVersionGreater(remoteVersionDirect, localVersion);
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'remoteVersion': remoteVersionDirect,
        'hasUpdate': hasUpdate,
        'remoteVersionSource':
            facade.lastSourceVersionDebugInfo?['resolvedFrom'] ?? 'unknown',
        'outcome': hasUpdate ? 'update_available' : 'no_update',
      };
      return SourceVersionCheckResult(
        sourceKey: sourceKey,
        sourceName: sourceName,
        localVersion: localVersion,
        remoteVersion: remoteVersionDirect,
        hasUpdate: hasUpdate,
      );
    }

    final indexRaw = await _downloadFromUrls(_sourceIndexUrls);
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_download_empty',
      };
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(indexRaw);
    } catch (_) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_decode_failed',
      };
      return null;
    }
    if (decoded is! List) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_not_list',
      };
      return null;
    }

    String? remoteVersion;
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(item);
      if (!sourceDefinition.matchesIndexEntry(map)) {
        continue;
      }
      remoteVersion = map['version']?.toString().trim();
      break;
    }

    if (remoteVersion == null || remoteVersion.isEmpty) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'remote_version_not_found_in_index',
      };
      return null;
    }

    final hasUpdate = _isVersionGreater(remoteVersion, localVersion);
    facade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'sourceKey': sourceKey,
      'sourceName': sourceName,
      'sourceDir': sourceDir.path,
      'localJmExists': true,
      'localVersion': localVersion,
      'remoteVersion': remoteVersion,
      'hasUpdate': hasUpdate,
      'remoteVersionSource': 'index_fallback_parse',
      'outcome': hasUpdate ? 'update_available' : 'no_update',
    };

    return SourceVersionCheckResult(
      sourceKey: sourceKey,
      sourceName: sourceName,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      hasUpdate: hasUpdate,
    );
  }

  Future<bool> downloadJmSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) async {
    final facade = this.facade;
    final sourceDir = await _getSourceStorageDirectory();
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }
    final jmFile = File('${sourceDir.path}/source.js');

    final jmScript = await _downloadFromUrlsWithProgress(
      await _resolveActiveSourceDownloadUrls(),
      onProgress: onProgress,
    );
    if (jmScript == null || jmScript.trim().isEmpty) {
      return false;
    }

    final downloadedVersion = _extractSourceVersion(jmScript);
    await jmFile.writeAsString(jmScript);
    final prefs = await facade.ensurePrefs();
    await prefs.setBool(SourcePrefsKeys.customEditedJmSource, false);

    facade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'downloaded_jm_script',
      'remoteVersion': downloadedVersion,
      'outcome': 'downloaded_waiting_for_restart',
    };
    _setRuntimeWaitingForRestartState(
      statusText: 'source_downloaded_waiting_for_restart|$downloadedVersion',
      debugDetail: 'downloaded_jm_script',
    );
    return true;
  }

  Future<bool> refreshSourceOnNetworkRecovery() async {
    final facade = this.facade;
    if (facade.isRefreshingSource) {
      return false;
    }
    facade.isRefreshingSource = true;
    try {
      _setRuntimeBusyState(
        facade.runtimeState.hasFailure
            ? SourceRuntimePhase.retrying
            : SourceRuntimePhase.loading,
        SourceRuntimeStep.downloadingSource,
        statusText: 'source_refreshing_after_network_recovery',
        debugDetail: 'network_recovery',
      );
      facade.lastReloginAt = null;
      facade.favoritesDebugCache = null;
      exploreCache.clearMemory();
      facade.cache.clearCategoryTagGroupsMemoryCache();
      facade.runtime.sourceMeta = null;
      final result = await _downloadOrLoadSourceFiles();
      final meta = await _loadSourceMetadata(result.jmFile);
      facade.runtime.sourceMeta = meta;
      _setRuntimeReadyState(result: result, meta: meta);
      if (isLogged) {
        await _tryReloginFromStoredAccount(force: true);
      }
      return true;
    } catch (e) {
      _setRuntimeFailedState(e);
      return false;
    } finally {
      facade.isRefreshingSource = false;
    }
  }

  Future<String> _readJmVersionFromFile(File jmFile) async {
    final content = await jmFile.readAsString();
    return _extractSourceVersion(content);
  }

  Future<String?> _resolveRemoteJmVersion({
    required String sourceKey,
    required String sourceName,
    required SourceCatalogEntry sourceDefinition,
  }) async {
    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_version_index',
    );
    if (indexRaw != null && indexRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(indexRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) {
              continue;
            }
            final map = Map<String, dynamic>.from(item);
            final key = map['key']?.toString().trim().toLowerCase();
            final fileName = map['fileName']?.toString().trim().toLowerCase();
            final normalizedMap = <String, dynamic>{
              ...map,
              'key': key,
              'fileName': fileName,
            };
            if (!sourceDefinition.matchesIndexEntry(normalizedMap)) {
              continue;
            }
            final version = map['version']?.toString().trim();
            if (version != null && version.isNotEmpty) {
              facade.lastSourceVersionDebugInfo = {
                'checkedAt': DateTime.now().toIso8601String(),
                'resolvedFrom': 'index_json',
                'sourceKey': sourceKey,
                'sourceName': sourceName,
                'matchedKey': key,
                'matchedFileName': fileName,
                'remoteVersion': version,
              };
              return version;
            }
          }
        }
      } catch (_) {}
    }

    final remoteScript = await _downloadFromUrls(
      await _resolveSourceVersionDownloadUrls(sourceDefinition),
      source: 'source_version_script',
    );
    if (remoteScript == null || remoteScript.trim().isEmpty) {
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'failed',
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'outcome': 'remote_script_empty',
      };
      return null;
    }
    final version = _extractSourceVersion(remoteScript);
    facade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'source_script',
      'sourceKey': sourceKey,
      'sourceName': sourceName,
      'remoteVersion': version,
    };
    return version;
  }

  Future<List<String>> _resolveSourceVersionDownloadUrls(
    SourceCatalogEntry definition,
  ) async {
    final directUrls = definition.directUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (directUrls.isNotEmpty) {
      return directUrls;
    }

    final indexRaw = await _downloadFromUrls(
      _sourceIndexUrls,
      source: 'source_version_download_index',
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

  String _sourceUpdateDisplayName(SourceCatalogEntry definition) {
    final metaName = sourceMeta?.name.trim() ?? '';
    if (metaName.isNotEmpty) {
      return metaName;
    }
    return definition.name;
  }

  String _extractSourceVersion(String script) {
    final match = RegExp(
      "version\\s*=\\s*['\\\"]([^'\\\"]+)['\\\"]",
    ).firstMatch(script);
    return match?.group(1) ?? '0.0.0';
  }

  bool _isVersionGreater(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va > vb) {
        return true;
      }
      if (va < vb) {
        return false;
      }
    }
    return false;
  }
}

class SourceVersionCheckResult {
  const SourceVersionCheckResult({
    required this.sourceKey,
    required this.sourceName,
    required this.localVersion,
    required this.remoteVersion,
    required this.hasUpdate,
  });

  final String sourceKey;
  final String sourceName;
  final String localVersion;
  final String remoteVersion;
  final bool hasUpdate;
}
