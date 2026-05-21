import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_preferences.dart';
import '../models/hazuki_models.dart';
import 'hazuki_source_service.dart';
import 'storage/hazuki_database.dart';

class ReadHistoryService extends ChangeNotifier {
  ReadHistoryService({HazukiDatabase? database})
    : _database = database ?? HazukiDatabase();

  final HazukiDatabase _database;
  Future<void> _migration = Future.value();
  Future<void> _opQueue = Future.value();

  static const String _legacyHistoryKey = 'hazuki_read_history';
  static const String _migrationDoneKey = 'hazuki_read_history_drift_migrated_v1';

  Future<T> _serialized<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _opQueue = _opQueue.whenComplete(() async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _ensureMigrated() {
    _migration = _migration.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationDoneKey) == true) {
        return;
      }
      await _importJsonString(prefs.getString(_legacyHistoryKey), replace: false);
      await prefs.setBool(_migrationDoneKey, true);
    });
    return _migration;
  }

  Future<List<ExploreComic>> loadHistory({required String sourceKey}) async {
    await _ensureMigrated();
    final entries = await ((_database.select(_database.readHistoryEntries)
          ..where((entry) => entry.sourceKey.equals(_normalizeSourceKey(sourceKey)))
          ..orderBy([(entry) => OrderingTerm.desc(entry.timestampMs)]))
        .get());
    return entries
        .map(
          (entry) => ExploreComic(
            id: entry.comicId,
            title: entry.title,
            cover: entry.cover,
            subTitle: entry.subTitle,
            sourceKey: entry.sourceKey,
          ),
        )
        .toList(growable: false);
  }

  Future<void> replaceSourceHistory({
    required String sourceKey,
    required List<ExploreComic> history,
  }) {
    return _serialized(() async {
      await _ensureMigrated();
      final normalizedSourceKey = _normalizeSourceKey(sourceKey);
      await _database.transaction(() async {
        await (_database.delete(_database.readHistoryEntries)
          ..where((entry) => entry.sourceKey.equals(normalizedSourceKey))).go();
        var index = 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final comic in history.take(hazukiReadHistoryMaxCount)) {
          final comicId = comic.id.trim();
          if (comicId.isEmpty) {
            continue;
          }
          final scoped = SourceScopedComicId(
            sourceKey: _normalizeSourceKey(comic.sourceKey),
            comicId: comicId,
          );
          await _database.into(_database.readHistoryEntries).insertOnConflictUpdate(
            ReadHistoryEntriesCompanion.insert(
              storageKey: scoped.storageKey,
              comicId: comicId,
              sourceKey: scoped.sourceKey,
              title: comic.title,
              cover: comic.cover,
              subTitle: comic.subTitle,
              timestampMs: now - index,
            ),
          );
          index++;
        }
      });
      notifyListeners();
    });
  }

  Future<void> recordHistory({
    required ExploreComic comic,
    required ComicDetailsData details,
  }) {
    return _serialized(() async {
      await _ensureMigrated();
      final comicId = details.id.trim().isNotEmpty ? details.id.trim() : comic.id.trim();
      if (comicId.isEmpty) {
        return;
      }
      final sourceKey = _normalizeSourceKey(
        details.sourceKey.trim().isNotEmpty ? details.sourceKey : comic.sourceKey,
      );
      final scoped = SourceScopedComicId(sourceKey: sourceKey, comicId: comicId);
      await _database.transaction(() async {
        await _database.into(_database.readHistoryEntries).insertOnConflictUpdate(
          ReadHistoryEntriesCompanion.insert(
            storageKey: scoped.storageKey,
            comicId: comicId,
            sourceKey: sourceKey,
            title: details.title.isNotEmpty ? details.title : comic.title,
            cover: details.cover.trim().isNotEmpty ? details.cover : comic.cover,
            subTitle: details.subTitle.isNotEmpty ? details.subTitle : comic.subTitle,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        await _trimHistoryLocked();
      });
      notifyListeners();
    });
  }

  Future<List<Map<String, dynamic>>> exportJsonList() async {
    await _ensureMigrated();
    final entries = await ((_database.select(_database.readHistoryEntries)
          ..orderBy([(entry) => OrderingTerm.desc(entry.timestampMs)])
          ..limit(hazukiReadHistoryMaxCount))
        .get());
    return entries
        .map(
          (entry) => <String, dynamic>{
            'id': entry.comicId,
            'sourceKey': entry.sourceKey,
            'title': entry.title,
            'cover': entry.cover,
            'subTitle': entry.subTitle,
            'timestamp': entry.timestampMs,
          },
        )
        .toList(growable: false);
  }

  Future<void> importJsonString(String? raw, {required bool replace}) async {
    await _importJsonString(raw, replace: replace);
  }

  Future<void> _importJsonString(String? raw, {required bool replace}) async {
    if (raw == null || raw.trim().isEmpty) {
      if (replace) {
        await _database.delete(_database.readHistoryEntries).go();
        notifyListeners();
      }
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        await importJsonList(
          decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
          replace: replace,
        );
      }
    } catch (_) {}
  }

  Future<void> importJsonList(
    List<Map<String, dynamic>> entries, {
    required bool replace,
  }) {
    return _serialized(() async {
      await _database.transaction(() async {
        if (replace) {
          await _database.delete(_database.readHistoryEntries).go();
        }
        for (final entry in entries) {
          final comicId = (entry['id'] ?? '').toString().trim();
          if (comicId.isEmpty) {
            continue;
          }
          final sourceKey = _normalizeSourceKey(
            (entry['sourceKey'] ?? hazukiDefaultSourceKey).toString(),
          );
          final scoped = SourceScopedComicId(sourceKey: sourceKey, comicId: comicId);
          await _database.into(_database.readHistoryEntries).insertOnConflictUpdate(
            ReadHistoryEntriesCompanion.insert(
              storageKey: scoped.storageKey,
              comicId: comicId,
              sourceKey: sourceKey,
              title: (entry['title'] ?? '').toString(),
              cover: (entry['cover'] ?? '').toString(),
              subTitle: (entry['subTitle'] ?? '').toString(),
              timestampMs: (entry['timestamp'] as num?)?.toInt() ?? 0,
            ),
          );
        }
        await _trimHistoryLocked();
      });
      notifyListeners();
    });
  }

  Future<void> _trimHistoryLocked() async {
    final extra = await ((_database.select(_database.readHistoryEntries)
          ..orderBy([(entry) => OrderingTerm.desc(entry.timestampMs)])
          ..limit(-1, offset: hazukiReadHistoryMaxCount))
        .get());
    for (final entry in extra) {
      await (_database.delete(_database.readHistoryEntries)
        ..where((row) => row.storageKey.equals(entry.storageKey))).go();
    }
  }

  String _normalizeSourceKey(String sourceKey) {
    final normalized = sourceKey.trim();
    return normalized.isEmpty ? hazukiDefaultSourceKey : normalized;
  }
}
