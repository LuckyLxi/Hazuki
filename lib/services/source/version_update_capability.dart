part of '../hazuki_source_service.dart';

extension HazukiSourceServiceVersionUpdateCapability on HazukiSourceService {
  Future<SourceVersionCheckResult?> checkJmSourceVersionFromCloud() async {
    final sourceDir = await _getSourceStorageDirectory();
    final jmFile = File('${sourceDir.path}/jm.js');
    if (!await jmFile.exists()) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': false,
        'outcome': 'local_jm_missing',
      };
      return null;
    }

    final localVersion = await _readJmVersionFromFile(jmFile);
    final remoteVersionDirect = await _resolveRemoteJmVersion();
    if (remoteVersionDirect != null && remoteVersionDirect.isNotEmpty) {
      final hasUpdate = _isVersionGreater(remoteVersionDirect, localVersion);
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'remoteVersion': remoteVersionDirect,
        'hasUpdate': hasUpdate,
        'remoteVersionSource':
            _lastSourceVersionDebugInfo?['resolvedFrom'] ?? 'unknown',
        'outcome': hasUpdate ? 'update_available' : 'no_update',
      };
      return SourceVersionCheckResult(
        localVersion: localVersion,
        remoteVersion: remoteVersionDirect,
        hasUpdate: hasUpdate,
      );
    }

    final indexRaw = await _downloadFromUrls(_sourceIndexUrls);
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
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
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_decode_failed',
      };
      return null;
    }
    if (decoded is! List) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
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
      final name = map['name']?.toString().trim();
      final key = map['key']?.toString().trim().toLowerCase();
      final fileName = map['fileName']?.toString().trim().toLowerCase();
      final isTarget = name == '绂佹极澶╁爞' || key == 'jm' || fileName == 'jm.js';
      if (!isTarget) {
        continue;
      }
      remoteVersion = map['version']?.toString().trim();
      break;
    }

    if (remoteVersion == null || remoteVersion.isEmpty) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'remote_version_not_found_in_index',
      };
      return null;
    }

    final hasUpdate = _isVersionGreater(remoteVersion, localVersion);
    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'sourceDir': sourceDir.path,
      'localJmExists': true,
      'localVersion': localVersion,
      'remoteVersion': remoteVersion,
      'hasUpdate': hasUpdate,
      'remoteVersionSource': 'index_fallback_parse',
      'outcome': hasUpdate ? 'update_available' : 'no_update',
    };

    return SourceVersionCheckResult(
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      hasUpdate: hasUpdate,
    );
  }

  Future<bool> downloadJmSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) async {
    final sourceDir = await _getSourceStorageDirectory();
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }
    final initFile = File('${sourceDir.path}/init.js');
    final jmFile = File('${sourceDir.path}/jm.js');

    if (!await initFile.exists()) {
      final bundledInit = await rootBundle.loadString(_bundledInitAssetPath);
      await initFile.writeAsString(bundledInit);
    }

    final jmScript = await _downloadFromUrlsWithProgress(
      _jmSourceUrls,
      onProgress: onProgress,
    );
    if (jmScript == null || jmScript.trim().isEmpty) {
      return false;
    }

    final downloadedVersion = _extractSourceVersion(jmScript);
    await jmFile.writeAsString(jmScript);
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(HazukiSourceService._customEditedJmSourceKey, false);

    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'downloaded_jm_script',
      'remoteVersion': downloadedVersion,
      'outcome': 'downloaded_waiting_for_restart',
    };
    _statusText = 'source_downloaded_waiting_for_restart|$downloadedVersion';
    return true;
  }

  Future<bool> refreshSourceOnNetworkRecovery() async {
    if (_isRefreshingSource) {
      return false;
    }
    _isRefreshingSource = true;
    try {
      _lastReloginAt = null;
      _favoritesDebugCache = null;
      _exploreSectionsMemoryCache = null;
      _exploreSectionsMemoryCachedAt = null;
      _sourceMeta = null;
      final result = await _downloadOrLoadSourceFiles();
      final meta = await _loadSourceMetadata(result.initFile, result.jmFile);
      _sourceMeta = meta;
      _statusText =
          '${result.message}|${meta.name}|${meta.key}|${meta.version}';
      if (isLogged) {
        await _tryReloginFromStoredAccount(force: true);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshingSource = false;
    }
  }

  Future<String> _readJmVersionFromFile(File jmFile) async {
    final content = await jmFile.readAsString();
    return _extractSourceVersion(content);
  }

  Future<String?> _resolveRemoteJmVersion() async {
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
            if (key != 'jm' && fileName != 'jm.js') {
              continue;
            }
            final version = map['version']?.toString().trim();
            if (version != null && version.isNotEmpty) {
              _lastSourceVersionDebugInfo = {
                'checkedAt': DateTime.now().toIso8601String(),
                'resolvedFrom': 'index_json',
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
      _jmSourceUrls,
      source: 'source_version_jm_script',
    );
    if (remoteScript == null || remoteScript.trim().isEmpty) {
      _lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'failed',
        'outcome': 'remote_script_empty',
      };
      return null;
    }
    final version = _extractSourceVersion(remoteScript);
    _lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      'resolvedFrom': 'jm_script',
      'remoteVersion': version,
    };
    return version;
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
    required this.localVersion,
    required this.remoteVersion,
    required this.hasUpdate,
  });

  final String localVersion;
  final String remoteVersion;
  final bool hasUpdate;
}
