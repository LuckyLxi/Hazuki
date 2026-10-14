import '../../shared/preferences/hazuki_preference_keys.dart';
import '../comment_filter/comment_filter_sync_store.dart';

export '../comment_filter/comment_filter_sync_store.dart'
    show CommentFilterMergeSnapshot;

class CommentFilterSyncParticipant {
  const CommentFilterSyncParticipant(this._store);

  final CommentFilterSyncStore _store;

  Future<CommentFilterMergeSnapshot> captureMergeSnapshot() =>
      _store.captureMergeSnapshot();

  Future<void> applySyncedPreferences(
    Map<String, Object?> values, {
    bool stringifyUnknown = false,
  }) =>
      _store.applySyncedPreferences(values, stringifyUnknown: stringifyUnknown);

  Future<void> reloadAfterExternalChange() =>
      _store.reloadAfterExternalChange();

  Future<void> mergeRemote(
    Map<dynamic, dynamic> remoteData,
    CommentFilterMergeSnapshot local, {
    required bool remoteSettingsAreNewer,
  }) async {
    final remoteRaw = remoteData[hazukiCommentFilterKeywordsKey];
    if (remoteRaw is! List) return;
    final remoteKeywords = remoteRaw.map((entry) => entry.toString()).toList();
    final remoteUpdatedAtMs =
        (remoteData[hazukiCommentFilterKeywordsUpdatedAtKey] as num?)
            ?.toInt() ??
        0;

    late final List<String> resolved;
    late final int resolvedUpdatedAtMs;
    if (local.updatedAtMs > remoteUpdatedAtMs) {
      resolved = local.keywords;
      resolvedUpdatedAtMs = local.updatedAtMs;
    } else if (remoteUpdatedAtMs > local.updatedAtMs) {
      resolved = remoteKeywords;
      resolvedUpdatedAtMs = remoteUpdatedAtMs;
    } else if (local.updatedAtMs > 0) {
      resolved = remoteSettingsAreNewer ? remoteKeywords : local.keywords;
      resolvedUpdatedAtMs = local.updatedAtMs;
    } else if (!remoteSettingsAreNewer) {
      resolved = local.keywords;
      resolvedUpdatedAtMs = 0;
    } else {
      resolved = [...remoteKeywords, ...local.keywords];
      resolvedUpdatedAtMs = 0;
    }

    final normalized = <String>[];
    final seen = <String>{};
    for (final keyword in resolved) {
      if (keyword.trim().isNotEmpty && seen.add(keyword)) {
        normalized.add(keyword);
      }
    }
    await _store.applyMergedKeywords(
      CommentFilterMergeSnapshot(
        keywords: normalized,
        updatedAtMs: resolvedUpdatedAtMs,
      ),
    );
  }
}
