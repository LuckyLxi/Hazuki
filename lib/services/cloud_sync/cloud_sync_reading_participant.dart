import 'dart:convert';

import '../../shared/preferences/hazuki_preference_keys.dart';
import '../../models/hazuki_models.dart';
import '../read_history_service.dart';
import '../reading_progress_service.dart';

class CloudSyncReadingMergeSnapshot {
  const CloudSyncReadingMergeSnapshot({
    required this.history,
    required this.progress,
  });

  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> progress;
}

class CloudSyncReadingExport {
  const CloudSyncReadingExport({
    required this.json,
    required this.historyCount,
    required this.progressCount,
  });

  final String json;
  final int historyCount;
  final int progressCount;
}

class CloudSyncReadingParticipant {
  const CloudSyncReadingParticipant({
    required ReadHistoryService readHistory,
    required ReadingProgressService readingProgress,
    required String Function() activeSourceKey,
  }) : _readHistory = readHistory,
       _readingProgress = readingProgress,
       _activeSourceKey = activeSourceKey;

  final ReadHistoryService _readHistory;
  final ReadingProgressService _readingProgress;
  final String Function() _activeSourceKey;

  Future<CloudSyncReadingMergeSnapshot> captureMergeSnapshot() async {
    return CloudSyncReadingMergeSnapshot(
      history: await _readHistory.exportJsonList(),
      progress: await _readingProgress.exportJsonList(),
    );
  }

  Future<void> mergeRemote(
    String content,
    CloudSyncReadingMergeSnapshot local,
  ) async {
    final readingMap = _decodeMap(content);
    if (readingMap == null) return;

    final remoteHistory = _mapList(readingMap['history']);
    final mergedHistory = <String, Map<String, dynamic>>{};
    for (final rawEntry in [...local.history, ...remoteHistory]) {
      final entry = Map<String, dynamic>.from(rawEntry);
      final comicId = (entry['id'] ?? '').toString().trim();
      if (comicId.isEmpty) continue;
      final sourceKey = (entry['sourceKey'] ?? _activeSourceKey())
          .toString()
          .trim();
      entry['sourceKey'] = sourceKey;
      final storageKey = SourceScopedComicId(
        sourceKey: sourceKey,
        comicId: comicId,
      ).storageKey;
      final timestamp = (entry['timestamp'] as num?)?.toInt() ?? 0;
      final existingTimestamp =
          (mergedHistory[storageKey]?['timestamp'] as num?)?.toInt() ?? 0;
      if (!mergedHistory.containsKey(storageKey) ||
          timestamp > existingTimestamp) {
        mergedHistory[storageKey] = entry;
      }
    }
    var history = mergedHistory.values.toList()
      ..sort(
        (a, b) => ((b['timestamp'] as num?)?.toInt() ?? 0).compareTo(
          (a['timestamp'] as num?)?.toInt() ?? 0,
        ),
      );
    if (history.length > hazukiReadHistoryMaxCount) {
      history = history.sublist(0, hazukiReadHistoryMaxCount);
    }
    await _readHistory.importJsonList(history, replace: true);

    final localProgress = _progressByStorageKey(local.progress);
    final remoteProgress = _progressByStorageKey(
      _mapList(readingMap['progress']),
    );
    for (final storageKey in {...localProgress.keys, ...remoteProgress.keys}) {
      final localEntry = localProgress[storageKey];
      final remoteEntry = remoteProgress[storageKey];
      final Map<String, dynamic> winner;
      if (localEntry == null) {
        winner = remoteEntry!;
      } else if (remoteEntry == null) {
        continue;
      } else {
        final localTimestamp = (localEntry['timestamp'] as num?)?.toInt() ?? 0;
        final remoteTimestamp =
            (remoteEntry['timestamp'] as num?)?.toInt() ?? 0;
        if (remoteTimestamp <= localTimestamp) continue;
        winner = remoteEntry;
      }
      final scoped = SourceScopedComicId.fromStorageKey(
        storageKey,
        fallbackSourceKey: (winner['sourceKey'] ?? _activeSourceKey())
            .toString(),
      );
      winner['comicId'] = scoped.comicId;
      winner['sourceKey'] = scoped.sourceKey;
      await _readingProgress.mergeJsonList([winner]);
    }
  }

  Future<CloudSyncReadingExport> exportSnapshot() async {
    var history = await _readHistory.exportJsonList();
    if (history.length > hazukiReadHistoryMaxCount) {
      history = history.sublist(0, hazukiReadHistoryMaxCount);
    }
    final progress = await _readingProgress.exportJsonList();
    return CloudSyncReadingExport(
      json: jsonEncode({
        'version': 1,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'history': history,
        'progress': progress,
      }),
      historyCount: history.length,
      progressCount: progress.length,
    );
  }

  Future<void> restoreSnapshot(String content) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (error) {
      throw Exception('cloud_sync_reading_parse_failed:$error');
    }
    if (decoded is! Map) {
      throw Exception('cloud_sync_reading_invalid_format');
    }
    final map = Map<String, dynamic>.from(decoded);
    final historyRaw = map['history'];
    if (historyRaw is List) {
      final history = _mapList(historyRaw);
      await _readHistory.importJsonList(
        history.length > hazukiReadHistoryMaxCount
            ? history.sublist(0, hazukiReadHistoryMaxCount)
            : history,
        replace: true,
      );
    }

    final progressList = <Map<String, dynamic>>[];
    for (final progress in _mapList(map['progress'])) {
      final comicId = (progress['comicId'] ?? '').toString().trim();
      if (comicId.isEmpty) continue;
      final sourceKey = (progress['sourceKey'] ?? _activeSourceKey())
          .toString()
          .trim();
      progressList.add({
        'comicId': comicId,
        'sourceKey': sourceKey,
        'epId': progress['epId'],
        'title': progress['title'],
        'index': progress['index'],
        'pageIndex': progress['pageIndex'],
        'timestamp': progress['timestamp'],
      });
    }
    await _readingProgress.replaceFromJsonList(progressList);
  }

  Map<String, Map<String, dynamic>> _progressByStorageKey(
    List<Map<String, dynamic>> entries,
  ) {
    final result = <String, Map<String, dynamic>>{};
    for (final rawEntry in entries) {
      final entry = Map<String, dynamic>.from(rawEntry);
      final comicId = (entry['comicId'] ?? '').toString().trim();
      if (comicId.isEmpty) continue;
      final sourceKey = (entry['sourceKey'] ?? _activeSourceKey())
          .toString()
          .trim();
      entry['sourceKey'] = sourceKey;
      result[SourceScopedComicId(
            sourceKey: sourceKey,
            comicId: comicId,
          ).storageKey] =
          entry;
    }
    return result;
  }

  Map<String, dynamic>? _decodeMap(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }
}
