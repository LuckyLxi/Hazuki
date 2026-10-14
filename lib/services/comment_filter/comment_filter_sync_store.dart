import '../../shared/preferences/hazuki_preference_keys.dart';

const commentFilterSyncPreferenceKeys = <String>{
  hazukiCommentFilterKeywordsKey,
  hazukiCommentFilterKeywordsUpdatedAtKey,
  hazukiCommentFilterModeKey,
};

class CommentFilterMergeSnapshot {
  const CommentFilterMergeSnapshot({
    required this.keywords,
    required this.updatedAtMs,
  });

  final List<String> keywords;
  final int updatedAtMs;
}

/// Persists sync changes without replacing their timestamps or publishing
/// partially applied settings. The coordinator reloads after a successful apply.
abstract interface class CommentFilterSyncStore {
  Future<CommentFilterMergeSnapshot> captureMergeSnapshot();
  Future<void> applyMergedKeywords(CommentFilterMergeSnapshot snapshot);
  Future<void> applySyncedPreferences(
    Map<String, Object?> values, {
    bool stringifyUnknown = false,
  });
  Future<void> reloadAfterExternalChange();
}
