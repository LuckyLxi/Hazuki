import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_preferences.dart';

class CommentFilterMergeSnapshot {
  const CommentFilterMergeSnapshot({
    required this.keywords,
    required this.updatedAtMs,
  });

  final List<String> keywords;
  final int updatedAtMs;
}

class CommentFilterSyncParticipant {
  const CommentFilterSyncParticipant();

  Future<CommentFilterMergeSnapshot> captureMergeSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return CommentFilterMergeSnapshot(
      keywords: prefs.getStringList(hazukiCommentFilterKeywordsKey) ?? const [],
      updatedAtMs: prefs.getInt(hazukiCommentFilterKeywordsUpdatedAtKey) ?? 0,
    );
  }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(hazukiCommentFilterKeywordsKey, normalized);
    if (resolvedUpdatedAtMs > 0) {
      await prefs.setInt(
        hazukiCommentFilterKeywordsUpdatedAtKey,
        resolvedUpdatedAtMs,
      );
    } else {
      await prefs.remove(hazukiCommentFilterKeywordsUpdatedAtKey);
    }
  }
}
