import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/service_locator.dart';
import '../models/hazuki_models.dart';
import 'hazuki_source_service.dart';
import 'storage/hazuki_database.dart';

class ReadingProgressService {
  ReadingProgressService({HazukiDatabase? database})
    : _database = database ?? sl<HazukiDatabase>();

  final HazukiDatabase _database;
  Future<void> _migration = Future.value();
  Future<void> _opQueue = Future.value();

  static const String _legacyPrefix = 'reading_progress_';
  static const String _migrationDoneKey = 'reading_progress_drift_migrated_v1';

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
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_legacyPrefix)) {
          continue;
        }
        final raw = prefs.getString(key);
        if (raw == null || raw.trim().isEmpty) {
          continue;
        }
        final storageKey = key.substring(_legacyPrefix.length);
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            await _upsertMap(
              storageKey: storageKey,
              data: Map<String, dynamic>.from(decoded),
              fallbackSourceKey: hazukiDefaultSourceKey,
            );
          }
        } catch (_) {}
      }
      await prefs.setBool(_migrationDoneKey, true);
    });
    return _migration;
  }

  Future<Map<String, dynamic>?> load({
    required String comicId,
    required String sourceKey,
  }) async {
    await _ensureMigrated();
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty) {
      return null;
    }
    final scoped = SourceScopedComicId(
      sourceKey: _normalizeSourceKey(sourceKey),
      comicId: normalizedComicId,
    );
    final row = await (_database.select(_database.readingProgressEntries)
          ..where((entry) => entry.storageKey.equals(scoped.storageKey)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _rowToJson(row);
  }

  Future<void> save({
    required String comicId,
    required String sourceKey,
    required String epId,
    required String title,
    required int chapterIndex,
    required int pageIndex,
  }) {
    return _serialized(() async {
      await _ensureMigrated();
      final normalizedComicId = comicId.trim();
      if (normalizedComicId.isEmpty) {
        return;
      }
      final normalizedSourceKey = _normalizeSourceKey(sourceKey);
      final scoped = SourceScopedComicId(
        sourceKey: normalizedSourceKey,
        comicId: normalizedComicId,
      );
      await _database.into(_database.readingProgressEntries).insertOnConflictUpdate(
        ReadingProgressEntriesCompanion.insert(
          storageKey: scoped.storageKey,
          comicId: normalizedComicId,
          sourceKey: normalizedSourceKey,
          epId: epId,
          title: title,
          chapterIndex: chapterIndex,
          pageIndex: Value(pageIndex),
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  Future<List<Map<String, dynamic>>> exportJsonList() async {
    await _ensureMigrated();
    final rows = await (_database.select(_database.readingProgressEntries)).get();
    return rows.map(_rowToCloudJson).toList(growable: false);
  }

  Future<void> replaceFromJsonList(List<Map<String, dynamic>> entries) {
    return _serialized(() async {
      await _database.transaction(() async {
        await _database.delete(_database.readingProgressEntries).go();
        for (final entry in entries) {
          final comicId = (entry['comicId'] ?? '').toString().trim();
          if (comicId.isEmpty) {
            continue;
          }
          final sourceKey = _normalizeSourceKey(
            (entry['sourceKey'] ?? hazukiDefaultSourceKey).toString(),
          );
          final storageKey = SourceScopedComicId(
            sourceKey: sourceKey,
            comicId: comicId,
          ).storageKey;
          await _upsertMap(
            storageKey: storageKey,
            data: entry,
            fallbackSourceKey: sourceKey,
          );
        }
      });
      await _markMigrated();
    });
  }

  Future<void> mergeJsonList(List<Map<String, dynamic>> entries) {
    return _serialized(() async {
      await _ensureMigrated();
      for (final entry in entries) {
        final comicId = (entry['comicId'] ?? '').toString().trim();
        if (comicId.isEmpty) {
          continue;
        }
        final sourceKey = _normalizeSourceKey(
          (entry['sourceKey'] ?? hazukiDefaultSourceKey).toString(),
        );
        final storageKey = SourceScopedComicId(
          sourceKey: sourceKey,
          comicId: comicId,
        ).storageKey;
        final existing = await (_database.select(_database.readingProgressEntries)
              ..where((row) => row.storageKey.equals(storageKey)))
            .getSingleOrNull();
        final incomingTs = (entry['timestamp'] as num?)?.toInt() ?? 0;
        if (existing != null && existing.timestampMs >= incomingTs) {
          continue;
        }
        await _upsertMap(
          storageKey: storageKey,
          data: entry,
          fallbackSourceKey: sourceKey,
        );
      }
    });
  }

  Future<void> _upsertMap({
    required String storageKey,
    required Map<String, dynamic> data,
    required String fallbackSourceKey,
  }) async {
    final scoped = SourceScopedComicId.fromStorageKey(
      storageKey,
      fallbackSourceKey: fallbackSourceKey,
    );
    final sourceKey = _normalizeSourceKey(
      (data['sourceKey'] ?? scoped.sourceKey).toString(),
    );
    final resolved = SourceScopedComicId(
      sourceKey: sourceKey,
      comicId: scoped.comicId,
    );
    await _database.into(_database.readingProgressEntries).insertOnConflictUpdate(
      ReadingProgressEntriesCompanion.insert(
        storageKey: resolved.storageKey,
        comicId: resolved.comicId,
        sourceKey: resolved.sourceKey,
        epId: (data['epId'] ?? '').toString(),
        title: (data['title'] ?? '').toString(),
        chapterIndex: (data['index'] as num?)?.toInt() ?? 0,
        pageIndex: Value((data['pageIndex'] as num?)?.toInt() ?? 0),
        timestampMs: (data['timestamp'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Future<void> _markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationDoneKey, true);
  }

  Map<String, dynamic> _rowToJson(ReadingProgressEntry row) {
    return <String, dynamic>{
      'sourceKey': row.sourceKey,
      'epId': row.epId,
      'title': row.title,
      'index': row.chapterIndex,
      'pageIndex': row.pageIndex,
      'timestamp': row.timestampMs,
    };
  }

  Map<String, dynamic> _rowToCloudJson(ReadingProgressEntry row) {
    return <String, dynamic>{
      'comicId': row.comicId,
      'sourceKey': row.sourceKey,
      'epId': row.epId,
      'title': row.title,
      'index': row.chapterIndex,
      'pageIndex': row.pageIndex,
      'timestamp': row.timestampMs,
    };
  }

  String _normalizeSourceKey(String sourceKey) {
    final normalized = sourceKey.trim();
    return normalized.isEmpty ? hazukiDefaultSourceKey : normalized;
  }
}
