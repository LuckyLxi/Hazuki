import 'cloud_sync_models.dart';
import 'cloud_sync_participant_set.dart';

class CloudSyncRestoreApplier {
  const CloudSyncRestoreApplier({required CloudSyncParticipantSet participants})
    : _participants = participants;

  final CloudSyncParticipantSet _participants;

  Future<CloudSyncApplySettingsResult> applySettingsJson(String content) {
    return _participants.settings.restoreSnapshot(content);
  }

  Future<void> applyReadingSnapshot(String content) {
    return _participants.reading.restoreSnapshot(content);
  }

  Future<void> applySearchHistoryJsonl(String content) {
    return _participants.searchHistory.restoreSnapshot(content);
  }
}
