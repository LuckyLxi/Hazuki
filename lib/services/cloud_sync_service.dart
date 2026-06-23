import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'cloud_sync/cloud_sync_config_store.dart';
import 'cloud_sync/cloud_sync_models.dart';
import 'cloud_sync/cloud_sync_remote_client.dart';
import 'cloud_sync/cloud_sync_restore_applier.dart';
import 'cloud_sync/cloud_sync_snapshot_codec.dart';
import 'comment_filter_service.dart';
import 'local_favorites_service.dart';
import 'download_groups_service.dart';
import 'hazuki_source_service.dart';
import 'reading_progress_service.dart';
import 'read_history_service.dart';
import 'search_history_service.dart';

export 'cloud_sync/cloud_sync_models.dart';

class CloudSyncService {
  CloudSyncService({
    required LocalFavoritesService localFavorites,
    required CommentFilterService commentFilter,
    required DownloadGroupsService downloadGroups,
    required HazukiSourceService sourceService,
    required ReadHistoryService readHistoryService,
    required ReadingProgressService readingProgressService,
    required SearchHistoryService searchHistoryService,
    CloudSyncRemoteClient Function(
      CloudSyncConfig config,
      CloudSyncConfigStore configStore,
    )?
    remoteClientFactory,
    Duration syncLockStaleAfter = const Duration(minutes: 2),
    Duration syncLockRenewInterval = const Duration(seconds: 30),
  }) : _localFavorites = localFavorites,
       _commentFilter = commentFilter,
       _downloadGroups = downloadGroups,
       _sourceService = sourceService,
       _readHistoryService = readHistoryService,
       _readingProgressService = readingProgressService,
       _searchHistoryService = searchHistoryService,
       _syncLockStaleAfter = syncLockStaleAfter,
       _syncLockRenewInterval = syncLockRenewInterval,
       _remoteClientFactory =
           remoteClientFactory ??
           ((config, configStore) =>
               CloudSyncRemoteClient(config, configStore: configStore));

  final LocalFavoritesService _localFavorites;
  final CommentFilterService _commentFilter;
  final DownloadGroupsService _downloadGroups;
  final HazukiSourceService _sourceService;
  final ReadHistoryService _readHistoryService;
  final ReadingProgressService _readingProgressService;
  final SearchHistoryService _searchHistoryService;
  final Duration _syncLockStaleAfter;
  final Duration _syncLockRenewInterval;
  final CloudSyncRemoteClient Function(
    CloudSyncConfig config,
    CloudSyncConfigStore configStore,
  )
  _remoteClientFactory;
  final CloudSyncConfigStore _configStore = CloudSyncConfigStore();
  late final CloudSyncSnapshotCodec _snapshotCodec = CloudSyncSnapshotCodec(
    configStore: _configStore,
    localFavoritesService: _localFavorites,
    downloadGroupsService: _downloadGroups,
    sourceService: _sourceService,
    readHistoryService: _readHistoryService,
    readingProgressService: _readingProgressService,
    searchHistoryService: _searchHistoryService,
  );
  late final CloudSyncRestoreApplier _restoreApplier = CloudSyncRestoreApplier(
    localFavoritesService: _localFavorites,
    sourceService: _sourceService,
    readHistoryService: _readHistoryService,
    readingProgressService: _readingProgressService,
    searchHistoryService: _searchHistoryService,
  );
  late final CloudSyncFacade facade = CloudSyncFacade._(
    configStore: _configStore,
    snapshotCodec: _snapshotCodec,
    restoreApplier: _restoreApplier,
    remoteClientFactory: (config) => _remoteClientFactory(config, _configStore),
  );

  bool _autoSyncRunning = false;

  Future<CloudSyncConfig> loadConfig() => _configStore.loadConfig();

  Future<void> saveConfig(CloudSyncConfig config) =>
      _configStore.saveConfig(config);

  Future<void> autoSyncOnce() async {
    if (_autoSyncRunning) {
      return;
    }
    _autoSyncRunning = true;
    try {
      final config = await loadConfig();
      if (!config.enabled || !config.isComplete) {
        return;
      }

      await uploadBackup(configOverride: config);
    } catch (e, st) {
      // Background sync is best-effort and should not interrupt app startup.
      debugPrint('autoSyncOnce error: $e\n$st');
    } finally {
      _autoSyncRunning = false;
    }
  }

  Future<CloudSyncConnectionStatus> testConnection({
    CloudSyncConfig? configOverride,
  }) async {
    final config = configOverride ?? await loadConfig();
    if (!config.isComplete) {
      return CloudSyncConnectionStatus(
        ok: false,
        message: 'cloud_sync_config_incomplete',
        checkedAt: DateTime.now(),
      );
    }
    return facade.remoteClient(config).testConnection();
  }

  Future<void> uploadBackup({
    CloudSyncConfig? configOverride,
    int? uploadAtMs,
  }) async {
    final config = configOverride ?? await loadConfig();
    if (!config.isComplete) {
      throw Exception('cloud_sync_config_incomplete');
    }

    final client = facade.remoteClient(config);
    await client.ensureRootDir();
    await client.ensureBackupDirs();

    await _withSyncLock(client, () async {
      final remoteManifestText = await client.tryGetBackupFile(
        CloudSyncConfigStore.manifestFileName,
      );
      final remoteUpdatedAtMs = _manifestUpdatedAtMs(remoteManifestText);
      if (remoteManifestText != null) {
        final lastSyncedRemoteTs = await _configStore.loadLastSyncedRemoteTs(
          config,
        );
        await _snapshotCodec.mergeRemoteIntoLocal(
          client,
          applyRemoteSettings: remoteUpdatedAtMs > lastSyncedRemoteTs,
        );
        _localFavorites.onExternalDataChanged();
        await _commentFilter.load(notify: true);
        await _downloadGroups.reload();
      }

      final requestedUploadAtMs =
          uploadAtMs ?? DateTime.now().millisecondsSinceEpoch;
      final committedAtMs = requestedUploadAtMs > remoteUpdatedAtMs
          ? requestedUploadAtMs
          : remoteUpdatedAtMs + 1;
      await _uploadSnapshot(client, committedAtMs);
      await _configStore.saveLastSyncedRemoteTs(committedAtMs, config);
    });
  }

  Future<void> _uploadSnapshot(
    CloudSyncRemoteClient client,
    int uploadAtMs,
  ) async {
    final snapshot = await _snapshotCodec.buildLocalSnapshotFiles();
    await client.putBackupFile(
      CloudSyncConfigStore.settingsFileName,
      snapshot.settings,
    );
    await client.putBackupFile(
      CloudSyncConfigStore.readingFileName,
      snapshot.reading,
    );
    await client.putBackupFile(
      CloudSyncConfigStore.searchHistoryFileName,
      snapshot.searchHistoryJsonl,
    );

    if (snapshot.jmSource != null && snapshot.jmSource!.trim().isNotEmpty) {
      await client.putSourceFile(
        CloudSyncConfigStore.sourceFileName,
        snapshot.jmSource!,
      );
    }

    final manifest = {
      'version': 2,
      'updatedAtMs': uploadAtMs,
      'historyCount': snapshot.historyCount,
      'progressCount': snapshot.progressCount,
      'searchCount': snapshot.searchCount,
      'sourcePlatform': _configStore.currentPlatformName,
      'hasSourceFile': snapshot.jmSource?.trim().isNotEmpty == true,
    };
    await client.putBackupFile(
      CloudSyncConfigStore.manifestFileName,
      jsonEncode(manifest),
    );
  }

  int _manifestUpdatedAtMs(String? content) {
    if (content == null) {
      return 0;
    }
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        return (decoded['updatedAtMs'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<T> _withSyncLock<T>(
    CloudSyncRemoteClient client,
    Future<T> Function() action,
  ) async {
    const retryDelay = Duration(milliseconds: 250);
    const maxAttempts = 80;
    final token = jsonEncode({
      'id':
          '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    var acquired = false;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (await client.tryAcquireSyncLock(token)) {
        acquired = true;
        break;
      }
      final existing = await client.readSyncLock();
      if (_isStaleSyncLock(existing, _syncLockStaleAfter)) {
        await client.deleteStaleSyncLock(existing ?? '');
        continue;
      }
      await Future<void>.delayed(retryDelay);
    }
    if (!acquired) {
      throw Exception('cloud_sync_lock_timeout');
    }
    final stopRenewal = Completer<void>();
    Object? renewalError;
    StackTrace? renewalStackTrace;
    final renewalDone = Completer<void>();
    unawaited(() async {
      try {
        while (!stopRenewal.isCompleted) {
          await Future.any([
            Future<void>.delayed(_syncLockRenewInterval),
            stopRenewal.future,
          ]);
          if (stopRenewal.isCompleted) {
            return;
          }
          if (!await client.renewSyncLock(token)) {
            throw Exception('cloud_sync_lock_lost');
          }
        }
      } catch (error, stackTrace) {
        renewalError = error;
        renewalStackTrace = stackTrace;
      } finally {
        renewalDone.complete();
      }
    }());
    try {
      final result = await action();
      if (!stopRenewal.isCompleted) {
        stopRenewal.complete();
      }
      await renewalDone.future;
      if (renewalError != null) {
        Error.throwWithStackTrace(renewalError!, renewalStackTrace!);
      }
      return result;
    } finally {
      if (!stopRenewal.isCompleted) {
        stopRenewal.complete();
      }
      await renewalDone.future;
      await client.releaseSyncLock(token);
    }
  }

  bool _isStaleSyncLock(String? content, Duration staleAfter) {
    if (content == null || content.trim().isEmpty) {
      return true;
    }
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final createdAtMs = (decoded['createdAtMs'] as num?)?.toInt() ?? 0;
        return createdAtMs <=
            DateTime.now().millisecondsSinceEpoch - staleAfter.inMilliseconds;
      }
    } catch (_) {}
    return true;
  }

  Future<CloudSyncRestoreResult> restoreLatestBackup({
    CloudSyncConfig? configOverride,
  }) async {
    final config = configOverride ?? await loadConfig();
    if (!config.isComplete) {
      throw Exception('cloud_sync_config_incomplete');
    }

    final client = facade.remoteClient(config);
    final manifest = await client.loadManifest();
    final settingsText = await client.getBackupFile(
      CloudSyncConfigStore.settingsFileName,
    );
    final readingText = await client.loadReadingSnapshotText();
    final searchHistoryText = await client.getBackupFile(
      CloudSyncConfigStore.searchHistoryFileName,
    );
    final sourceText = await client.tryGetSourceFile(
      CloudSyncConfigStore.sourceFileName,
    );

    final settingsResult = await _restoreApplier.applySettingsJson(
      settingsText,
    );
    final settingsDecoded = jsonDecode(settingsText);
    if (settingsDecoded is Map && settingsDecoded['data'] is Map) {
      final data = settingsDecoded['data'] as Map;
      final downloadGroupsRaw = data[CloudSyncConfigStore.downloadGroupsKey];
      await _downloadGroups.importJsonString(
        downloadGroupsRaw is String ? downloadGroupsRaw : null,
        replace: true,
      );
    }
    await _commentFilter.load(notify: true);
    await _restoreApplier.applyReadingSnapshot(readingText);
    await _restoreApplier.applySearchHistoryJsonl(searchHistoryText);

    final restoredSourceFile = await _restoreApplier.applySourceFile(
      sourceText: sourceText,
      manifestHasSource: manifest['hasSourceFile'] == true,
    );

    return CloudSyncRestoreResult(
      restoredSettings: true,
      restoredReading: true,
      restoredSearchHistory: true,
      restoredSourceFile: restoredSourceFile,
      appliedPlatformFilteredKeys: settingsResult.appliedPlatformFilteredKeys,
      skippedKeys: settingsResult.skippedKeys,
    );
  }
}

class CloudSyncFacade {
  CloudSyncFacade._({
    required this.configStore,
    required this.snapshotCodec,
    required this.restoreApplier,
    required CloudSyncRemoteClient Function(CloudSyncConfig config)
    remoteClientFactory,
  }) : _remoteClientFactory = remoteClientFactory;

  final CloudSyncConfigStore configStore;
  final CloudSyncSnapshotCodec snapshotCodec;
  final CloudSyncRestoreApplier restoreApplier;
  final CloudSyncRemoteClient Function(CloudSyncConfig config)
  _remoteClientFactory;

  CloudSyncRemoteClient remoteClient(CloudSyncConfig config) {
    return _remoteClientFactory(config);
  }
}
