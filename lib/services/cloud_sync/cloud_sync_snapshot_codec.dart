import 'cloud_sync_config_store.dart';
import 'cloud_sync_models.dart';
import 'cloud_sync_participant_set.dart';
import 'cloud_sync_remote_client.dart';

/// Coordinates remote files while each participant owns its data format and
/// conflict rules.
class CloudSyncSnapshotCodec {
  const CloudSyncSnapshotCodec({required CloudSyncParticipantSet participants})
    : _participants = participants;

  final CloudSyncParticipantSet _participants;

  Future<void> mergeRemoteIntoLocal(
    CloudSyncRemoteClient client, {
    bool applyRemoteSettings = false,
  }) async {
    // Fetch first, then capture local state. This preserves user changes made
    // during the network round-trip.
    final readingText = await client.tryGetBackupFile(
      CloudSyncConfigStore.readingFileName,
    );
    final searchText = await client.tryGetBackupFile(
      CloudSyncConfigStore.searchHistoryFileName,
    );
    final settingsText = await client.tryGetBackupFile(
      CloudSyncConfigStore.settingsFileName,
    );

    final readingLocal = await _participants.reading.captureMergeSnapshot();
    final settingsLocal = await _participants.settings.captureMergeSnapshot();

    if (readingText != null) {
      await _participants.reading.mergeRemote(readingText, readingLocal);
    }
    await _participants.searchHistory.mergeRemote(
      jsonl: searchText,
      legacySettingsJson: settingsText,
    );
    if (settingsText != null) {
      await _participants.settings.mergeRemote(
        settingsText,
        settingsLocal,
        applyRemoteSettings: applyRemoteSettings,
      );
    }
  }

  Future<CloudSyncLocalSnapshot> buildLocalSnapshotFiles() async {
    final settings = await _participants.settings.exportSnapshot();
    final reading = await _participants.reading.exportSnapshot();
    final searchCount = await _participants.searchHistory.exportCount();
    final searchHistoryJsonl = await _participants.searchHistory
        .exportSnapshot();
    final source = await _participants.source.exportSnapshot();

    return CloudSyncLocalSnapshot(
      settings: settings,
      reading: reading.json,
      searchHistoryJsonl: searchHistoryJsonl,
      historyCount: reading.historyCount,
      progressCount: reading.progressCount,
      searchCount: searchCount,
      jmSource: source,
    );
  }
}
