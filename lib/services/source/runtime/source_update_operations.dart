import 'dart:convert';
import 'dart:io';

import '../models/source_contract_models.dart';
import 'source_catalog_resolver.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_editing_operations.dart';
import 'source_script_storage.dart';
import 'source_text_downloader.dart';

/// Owns source catalog resolution, version checks, and online source updates.
class SourceUpdateOperations {
  SourceUpdateOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceScriptStore scriptStore,
    required SourceScriptEditingOperations scriptEditing,
    required SourceRuntimeStateController runtimeStateController,
    required SourceTextDownloadClient downloader,
    required SourceCatalogResolver urlResolver,
    required List<String> sourceIndexUrls,
  }) : _runtimeHost = runtimeHost,
       _scriptStore = scriptStore,
       _scriptEditing = scriptEditing,
       _runtimeStateController = runtimeStateController,
       _downloader = downloader,
       _urlResolver = urlResolver,
       _sourceIndexUrls = List.unmodifiable(sourceIndexUrls);

  final SourceRuntimeHost _runtimeHost;
  final SourceScriptStore _scriptStore;
  final SourceScriptEditingOperations _scriptEditing;
  final SourceRuntimeStateController _runtimeStateController;
  final SourceTextDownloadClient _downloader;
  final SourceCatalogResolver _urlResolver;
  final List<String> _sourceIndexUrls;

  Future<SourceVersionCheckResult?> checkActiveSourceVersion() {
    final handle = _runtimeHost.activeHandle;
    return handle.runOperation(() => _checkSourceVersion(handle));
  }

  Future<SourceVersionCheckResult?> _checkSourceVersion(
    SourceRuntimeHandle handle,
  ) async {
    final facade = handle.facade;
    final sourceKey = handle.sourceKey;
    final definition = _runtimeHost.definitionFor(sourceKey);
    final sourceName = _displayName(definition, facade);
    final sourceFile = await _scriptStore.sourceFileFor(sourceKey);
    final sourceDir = sourceFile.parent;
    if (!await sourceFile.exists()) {
      _setVersionDebugInfo(facade, {
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': false,
        'outcome': 'local_jm_missing',
      });
      return null;
    }

    final localVersion = await _readVersion(sourceFile);
    final directVersion = await _resolveRemoteVersion(
      sourceKey: sourceKey,
      sourceName: sourceName,
      definition: definition,
      facade: facade,
    );
    if (directVersion != null && directVersion.isNotEmpty) {
      return _versionResult(
        facade: facade,
        sourceKey: sourceKey,
        sourceName: sourceName,
        sourceDir: sourceDir,
        localVersion: localVersion,
        remoteVersion: directVersion,
        remoteVersionSource:
            facade.lastSourceVersionDebugInfo?['resolvedFrom']?.toString() ??
            'unknown',
      );
    }

    final indexRaw = await _downloader.firstAvailable(
      _sourceIndexUrls,
      facade: facade,
    );
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      _setVersionDebugInfo(facade, {
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_download_empty',
      });
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(indexRaw);
    } catch (_) {
      _setVersionDebugInfo(facade, {
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_decode_failed',
      });
      return null;
    }
    if (decoded is! List) {
      _setVersionDebugInfo(facade, {
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'index_json_not_list',
      });
      return null;
    }

    String? remoteVersion;
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      if (!definition.matchesIndexEntry(map)) continue;
      remoteVersion = map['version']?.toString().trim();
      break;
    }
    if (remoteVersion == null || remoteVersion.isEmpty) {
      _setVersionDebugInfo(facade, {
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'sourceDir': sourceDir.path,
        'localJmExists': true,
        'localVersion': localVersion,
        'outcome': 'remote_version_not_found_in_index',
      });
      return null;
    }

    return _versionResult(
      facade: facade,
      sourceKey: sourceKey,
      sourceName: sourceName,
      sourceDir: sourceDir,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      remoteVersionSource: 'index_fallback_parse',
    );
  }

  Future<bool> downloadActiveSource({
    void Function(int received, int total)? onProgress,
  }) {
    final handle = _runtimeHost.activeHandle;
    return handle.runOperation(
      () => _downloadSourceAndMarkForRestart(handle, onProgress: onProgress),
    );
  }

  Future<bool> _downloadSourceAndMarkForRestart(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    final facade = handle.facade;
    await _scriptStore.ensureLocalSourceFile(handle.sourceKey);
    final sourceScript = await _downloader.sequential(
      await _urlResolver.resolve(handle),
      facade: facade,
      onProgress: onProgress,
    );
    if (sourceScript == null || sourceScript.trim().isEmpty) return false;

    final downloadedVersion = extractSourceVersion(sourceScript);
    await _scriptStore.write(handle.sourceKey, sourceScript);
    await _scriptEditing.setCustomEditedSourceFlag(
      handle.sourceKey,
      false,
      targetFacade: facade,
    );
    _setVersionDebugInfo(facade, {
      'resolvedFrom': 'downloaded_jm_script',
      'remoteVersion': downloadedVersion,
      'outcome': 'downloaded_waiting_for_restart',
    });
    _runtimeStateController.setWaitingForRestart(
      facade,
      statusText: 'source_downloaded_waiting_for_restart|$downloadedVersion',
      debugDetail: 'downloaded_jm_script',
    );
    return true;
  }

  Future<String> _readVersion(File sourceFile) async =>
      extractSourceVersion(await sourceFile.readAsString());

  Future<String?> _resolveRemoteVersion({
    required String sourceKey,
    required String sourceName,
    required SourceCatalogEntry definition,
    required HazukiSourceFacade facade,
  }) async {
    final indexRaw = await _downloader.firstAvailable(
      _sourceIndexUrls,
      facade: facade,
      source: 'source_version_index',
    );
    if (indexRaw != null && indexRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(indexRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final key = map['key']?.toString().trim().toLowerCase();
            final fileName = map['fileName']?.toString().trim().toLowerCase();
            final normalizedMap = <String, dynamic>{
              ...map,
              'key': key,
              'fileName': fileName,
            };
            if (!definition.matchesIndexEntry(normalizedMap)) continue;
            final version = map['version']?.toString().trim();
            if (version != null && version.isNotEmpty) {
              _setVersionDebugInfo(facade, {
                'resolvedFrom': 'index_json',
                'sourceKey': sourceKey,
                'sourceName': sourceName,
                'matchedKey': key,
                'matchedFileName': fileName,
                'remoteVersion': version,
              });
              return version;
            }
          }
        }
      } catch (_) {}
    }

    final remoteScript = await _downloader.firstAvailable(
      await _urlResolver.resolveDefinition(
        definition,
        facade,
        indexLogSource: 'source_version_download_index',
      ),
      facade: facade,
      source: 'source_version_script',
    );
    if (remoteScript == null || remoteScript.trim().isEmpty) {
      _setVersionDebugInfo(facade, {
        'resolvedFrom': 'failed',
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'outcome': 'remote_script_empty',
      });
      return null;
    }
    final version = extractSourceVersion(remoteScript);
    _setVersionDebugInfo(facade, {
      'resolvedFrom': 'source_script',
      'sourceKey': sourceKey,
      'sourceName': sourceName,
      'remoteVersion': version,
    });
    return version;
  }

  SourceVersionCheckResult _versionResult({
    required HazukiSourceFacade facade,
    required String sourceKey,
    required String sourceName,
    required Directory sourceDir,
    required String localVersion,
    required String remoteVersion,
    required String remoteVersionSource,
  }) {
    final hasUpdate = isSourceVersionGreater(remoteVersion, localVersion);
    _setVersionDebugInfo(facade, {
      'sourceKey': sourceKey,
      'sourceName': sourceName,
      'sourceDir': sourceDir.path,
      'localJmExists': true,
      'localVersion': localVersion,
      'remoteVersion': remoteVersion,
      'hasUpdate': hasUpdate,
      'remoteVersionSource': remoteVersionSource,
      'outcome': hasUpdate ? 'update_available' : 'no_update',
    });
    return SourceVersionCheckResult(
      sourceKey: sourceKey,
      sourceName: sourceName,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      hasUpdate: hasUpdate,
    );
  }

  String _displayName(
    SourceCatalogEntry definition,
    HazukiSourceFacade facade,
  ) {
    final metaName = facade.sourceMeta?.name.trim() ?? '';
    return metaName.isNotEmpty ? metaName : definition.name;
  }

  void _setVersionDebugInfo(
    HazukiSourceFacade facade,
    Map<String, dynamic> values,
  ) {
    facade.lastSourceVersionDebugInfo = {
      'checkedAt': DateTime.now().toIso8601String(),
      ...values,
    };
  }
}

String extractSourceVersion(String script) {
  final match = RegExp(
    "version\\s*=\\s*['\"]([^'\"]+)['\"]",
  ).firstMatch(script);
  return match?.group(1) ?? '0.0.0';
}

bool isSourceVersionGreater(String candidate, String current) {
  final candidateParts = candidate
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final currentParts = current
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;
  for (var index = 0; index < length; index++) {
    final candidatePart = index < candidateParts.length
        ? candidateParts[index]
        : 0;
    final currentPart = index < currentParts.length ? currentParts[index] : 0;
    if (candidatePart > currentPart) return true;
    if (candidatePart < currentPart) return false;
  }
  return false;
}
