import 'dart:async';
import 'dart:convert';

import 'cloud_sync/cloud_sync_config_store.dart';
import 'cloud_sync/cloud_sync_models.dart';
import 'cloud_sync/cloud_sync_remote_client.dart';
import 'cloud_sync/cloud_sync_restore_applier.dart';
import 'cloud_sync/cloud_sync_snapshot_codec.dart';

export 'cloud_sync/cloud_sync_models.dart';

class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  final CloudSyncConfigStore _configStore = CloudSyncConfigStore();
  late final CloudSyncSnapshotCodec _snapshotCodec = CloudSyncSnapshotCodec(
    configStore: _configStore,
  );
  late final CloudSyncRestoreApplier _restoreApplier =
      CloudSyncRestoreApplier();
  late final CloudSyncFacade facade = CloudSyncFacade._(
    configStore: _configStore,
    snapshotCodec: _snapshotCodec,
    restoreApplier: _restoreApplier,
    remoteClientFactory: (config) =>
        CloudSyncRemoteClient(config, configStore: _configStore),
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

      final client = facade.remoteClient(config);
      final remoteManifestText = await client.tryGetBackupFile(
        CloudSyncConfigStore.manifestFileName,
      );

      if (remoteManifestText != null) {
        int remoteUpdatedAtMs = 0;
        try {
          final decoded = jsonDecode(remoteManifestText);
          if (decoded is Map) {
            remoteUpdatedAtMs = (decoded['updatedAtMs'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}

        final lastSyncedRemoteTs = await _configStore.loadLastSyncedRemoteTs();
        if (remoteUpdatedAtMs > lastSyncedRemoteTs) {
          await _snapshotCodec.mergeRemoteIntoLocal(client);
        }
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await uploadBackup(configOverride: config, uploadAtMs: nowMs);
      await _configStore.saveLastSyncedRemoteTs(nowMs);
    } catch (_) {
      // Background sync is best-effort and should not interrupt app startup.
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

    final nowMs = uploadAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final manifest = {
      'version': 2,
      'updatedAtMs': nowMs,
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
