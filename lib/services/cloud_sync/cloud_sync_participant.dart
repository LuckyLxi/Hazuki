import 'dart:convert';

import '../../shared/preferences/hazuki_preference_keys.dart';
import '../search_history_service.dart';
import '../download_groups_service.dart';

/// Keeps the search-history JSONL format and merge rules inside its owner.
class SearchHistorySyncParticipant {
  const SearchHistorySyncParticipant(this._service);

  final SearchHistoryService _service;

  Future<String> exportSnapshot() => _service.exportSyncJsonl();

  Future<List<String>> exportLegacyKeywords() => _service.load();

  Future<int> exportCount() async {
    return (await _service.load()).take(hazukiSearchHistoryMaxCount).length;
  }

  Future<void> mergeRemote({
    required String? jsonl,
    required String? legacySettingsJson,
  }) async {
    if (jsonl != null) {
      await mergeSnapshot(jsonl);
      return;
    }
    if (legacySettingsJson == null) return;
    try {
      final decoded = jsonDecode(legacySettingsJson);
      if (decoded is! Map || decoded['data'] is! Map) return;
      final raw = (decoded['data'] as Map)['search_history'];
      if (raw is! List) return;
      await mergeSnapshot(
        raw.map((keyword) => jsonEncode({'keyword': keyword})).join('\n'),
      );
    } catch (_) {}
  }

  Future<void> mergeSnapshot(String snapshot) =>
      _service.mergeSyncJsonl(snapshot);

  Future<void> restoreSnapshot(String snapshot) =>
      _service.restoreSyncJsonl(snapshot);
}

class DownloadGroupsSyncParticipant {
  const DownloadGroupsSyncParticipant(this._service);

  final DownloadGroupsService _service;

  Future<String> exportJsonString() => _service.exportJsonString();
  Future<void> importJsonString(String? snapshot) =>
      _service.importJsonString(snapshot);

  Future<String> exportSnapshot() => exportJsonString();

  Future<void> mergeSnapshot(String? snapshot) => importJsonString(snapshot);

  Future<void> restoreSnapshot(String? snapshot) =>
      _service.importJsonString(snapshot, replace: true);
}
