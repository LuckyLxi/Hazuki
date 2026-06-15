import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';

class SearchHistoryService extends ChangeNotifier {
  SearchHistoryService({HazukiDatabase? database})
    : _database = database ?? sl<HazukiDatabase>();

  final HazukiDatabase _database;
  Future<void> _migration = Future.value();
  Future<void> _opQueue = Future.value();

  static const _key = 'search_history';
  static const _migrationDoneKey = 'search_history_drift_migrated_v1';
  static const _clearStateId = 'global';

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
      final legacy = prefs.getStringList(_key) ?? const <String>[];
      await _replaceKeywords(legacy, baseUpdatedAtMs: legacy.length);
      await _markMigrated();
    });
    return _migration;
  }

  Future<List<String>> load() async {
    await _ensureMigrated();
    return _loadFromDatabase();
  }

  Future<void> add(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _serialized(() async {
      await _ensureMigrated();
      final rows = await _loadRows();
      final existing = rows
          .where((row) => row.keyword == normalized)
          .firstOrNull;
      final updatedAtMs = await _nextTimestamp(existing?.updatedAtMs ?? 0);
      await _replaceRows([
        _SearchHistoryRecord(keyword: normalized, updatedAtMs: updatedAtMs),
        ...rows
            .where((row) => row.keyword != normalized)
            .map(
              (row) => _SearchHistoryRecord(
                keyword: row.keyword,
                updatedAtMs: row.updatedAtMs,
              ),
            ),
      ]);
      notifyListeners();
    });
  }

  Future<List<String>> remove(String keyword) async {
    return _serialized(() async {
      await _ensureMigrated();
      final normalized = keyword.trim();
      final rows = await _loadRows();
      final removed = rows
          .where((row) => row.keyword == normalized)
          .firstOrNull;
      final deletedAtMs = await _nextTimestamp(removed?.updatedAtMs ?? 0);
      await _database.transaction(() async {
        await (_database.delete(
          _database.searchHistoryEntries,
        )..where((row) => row.keyword.equals(normalized))).go();
        if (normalized.isNotEmpty) {
          await _database
              .into(_database.searchHistoryTombstones)
              .insertOnConflictUpdate(
                SearchHistoryTombstonesCompanion.insert(
                  keyword: normalized,
                  deletedAtMs: deletedAtMs,
                ),
              );
        }
        await _resequenceEntries();
      });
      notifyListeners();
      return _loadFromDatabase();
    });
  }

  Future<void> clear() async {
    await _serialized(() async {
      await _ensureMigrated();
      final clearedAtMs = await _nextTimestamp(0);
      await _database.transaction(() async {
        await _database.delete(_database.searchHistoryEntries).go();
        await _database
            .into(_database.searchHistoryClearStates)
            .insertOnConflictUpdate(
              SearchHistoryClearStatesCompanion.insert(
                id: _clearStateId,
                clearedAtMs: clearedAtMs,
              ),
            );
      });
      notifyListeners();
    });
  }

  Future<void> replace(List<String> keywords) async {
    await _serialized(() async {
      await _ensureMigrated();
      final baseUpdatedAtMs = await _nextTimestamp(0);
      await _replaceKeywords(keywords, baseUpdatedAtMs: baseUpdatedAtMs);
      await _markMigrated();
      notifyListeners();
    });
  }

  Future<void> _markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationDoneKey, true);
  }

  Future<List<String>> _loadFromDatabase() async {
    final rows = await _loadRows();
    return rows.map((entry) => entry.keyword).toList(growable: false);
  }

  Future<List<SearchHistoryEntry>> _loadRows() {
    return (_database.select(
      _database.searchHistoryEntries,
    )..orderBy([(entry) => OrderingTerm.asc(entry.position)])).get();
  }

  Future<void> _replaceKeywords(
    List<String> keywords, {
    required int baseUpdatedAtMs,
  }) async {
    final next = <_SearchHistoryRecord>[];
    final seen = <String>{};
    for (var index = 0; index < keywords.length; index++) {
      final keyword = keywords[index];
      final normalized = keyword.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      next.add(
        _SearchHistoryRecord(
          keyword: normalized,
          updatedAtMs: baseUpdatedAtMs <= 0 ? 0 : baseUpdatedAtMs - index,
        ),
      );
      if (next.length >= hazukiSearchHistoryMaxCount) {
        break;
      }
    }
    await _replaceRows(next);
  }

  Future<void> _replaceRows(List<_SearchHistoryRecord> records) async {
    final next = records.take(hazukiSearchHistoryMaxCount).toList();
    await _database.transaction(() async {
      await _database.delete(_database.searchHistoryEntries).go();
      for (var i = 0; i < next.length; i++) {
        await _database
            .into(_database.searchHistoryEntries)
            .insert(
              SearchHistoryEntriesCompanion.insert(
                keyword: next[i].keyword,
                position: i,
                updatedAtMs: Value(next[i].updatedAtMs),
              ),
            );
      }
    });
  }

  Future<void> _resequenceEntries() async {
    final rows = await _loadRows();
    for (var index = 0; index < rows.length; index++) {
      await (_database.update(_database.searchHistoryEntries)
            ..where((row) => row.keyword.equals(rows[index].keyword)))
          .write(SearchHistoryEntriesCompanion(position: Value(index)));
    }
  }

  Future<int> _nextTimestamp(int afterMs) async {
    final clearState = await (_database.select(
      _database.searchHistoryClearStates,
    )..where((row) => row.id.equals(_clearStateId))).getSingleOrNull();
    final entries = await _database
        .select(_database.searchHistoryEntries)
        .get();
    final tombstones = await _database
        .select(_database.searchHistoryTombstones)
        .get();
    var floor = afterMs > (clearState?.clearedAtMs ?? 0)
        ? afterMs
        : clearState?.clearedAtMs ?? 0;
    for (final entry in entries) {
      if (entry.updatedAtMs > floor) floor = entry.updatedAtMs;
    }
    for (final tombstone in tombstones) {
      if (tombstone.deletedAtMs > floor) floor = tombstone.deletedAtMs;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    return now > floor ? now : floor + 1;
  }

  Future<String> exportSyncJsonl() async {
    await _ensureMigrated();
    final rows = await _loadRows();
    final tombstones = await (_database.select(
      _database.searchHistoryTombstones,
    )..orderBy([(row) => OrderingTerm.desc(row.deletedAtMs)])).get();
    final clearState = await (_database.select(
      _database.searchHistoryClearStates,
    )..where((row) => row.id.equals(_clearStateId))).getSingleOrNull();
    return [
      if ((clearState?.clearedAtMs ?? 0) > 0)
        jsonEncode({'type': 'clear', 'clearedAtMs': clearState!.clearedAtMs}),
      ...rows.map(
        (row) => jsonEncode({
          'type': 'entry',
          'keyword': row.keyword,
          'updatedAtMs': row.updatedAtMs,
        }),
      ),
      ...tombstones.map(
        (row) => jsonEncode({
          'type': 'tombstone',
          'deletedKeyword': row.keyword,
          'deletedAtMs': row.deletedAtMs,
        }),
      ),
    ].join('\n');
  }

  Future<void> mergeSyncJsonl(String content) async {
    await _serialized(() async {
      await _ensureMigrated();
      final local = await _loadSyncState();
      final remote = _decodeSyncState(content, legacyEntriesAreNewest: true);
      await _writeSyncState(_mergeSyncStates(local, remote));
      notifyListeners();
    });
  }

  Future<void> restoreSyncJsonl(String content) async {
    await _serialized(() async {
      await _ensureMigrated();
      await _writeSyncState(
        _decodeSyncState(content, legacyEntriesAreNewest: true),
      );
      notifyListeners();
    });
  }

  Future<_SearchHistorySyncState> _loadSyncState() async {
    final rows = await _loadRows();
    final tombstones = await _database
        .select(_database.searchHistoryTombstones)
        .get();
    final clearState = await (_database.select(
      _database.searchHistoryClearStates,
    )..where((row) => row.id.equals(_clearStateId))).getSingleOrNull();
    return _SearchHistorySyncState(
      entries: [
        for (final row in rows)
          _SearchHistoryRecord(
            keyword: row.keyword,
            updatedAtMs: row.updatedAtMs,
          ),
      ],
      tombstones: {for (final row in tombstones) row.keyword: row.deletedAtMs},
      clearedAtMs: clearState?.clearedAtMs ?? 0,
    );
  }

  _SearchHistorySyncState _decodeSyncState(
    String content, {
    required bool legacyEntriesAreNewest,
  }) {
    final entries = <_SearchHistoryRecord>[];
    final tombstones = <String, int>{};
    var clearedAtMs = 0;
    final legacyBase = DateTime.now().millisecondsSinceEpoch;
    var legacyIndex = 0;
    for (final raw in content.split('\n')) {
      try {
        final decoded = jsonDecode(raw.trim());
        if (decoded is! Map) continue;
        final type = (decoded['type'] ?? 'entry').toString();
        if (type == 'clear') {
          final value = (decoded['clearedAtMs'] as num?)?.toInt() ?? 0;
          if (value > clearedAtMs) clearedAtMs = value;
        } else if (type == 'tombstone') {
          final keyword =
              (decoded['deletedKeyword'] ?? decoded['keyword'] ?? '')
                  .toString()
                  .trim();
          final value = (decoded['deletedAtMs'] as num?)?.toInt() ?? 0;
          if (keyword.isNotEmpty && value > (tombstones[keyword] ?? 0)) {
            tombstones[keyword] = value;
          }
        } else {
          final keyword = (decoded['keyword'] ?? '').toString().trim();
          if (keyword.isEmpty) continue;
          var value = (decoded['updatedAtMs'] as num?)?.toInt() ?? 0;
          if (value <= 0 && legacyEntriesAreNewest) {
            value = legacyBase - legacyIndex++;
          }
          entries.add(
            _SearchHistoryRecord(keyword: keyword, updatedAtMs: value),
          );
        }
      } catch (_) {}
    }
    return _SearchHistorySyncState(
      entries: entries,
      tombstones: tombstones,
      clearedAtMs: clearedAtMs,
    );
  }

  _SearchHistorySyncState _mergeSyncStates(
    _SearchHistorySyncState local,
    _SearchHistorySyncState remote,
  ) {
    final clearedAtMs = local.clearedAtMs > remote.clearedAtMs
        ? local.clearedAtMs
        : remote.clearedAtMs;
    final tombstones = Map<String, int>.from(local.tombstones);
    for (final item in remote.tombstones.entries) {
      if (item.value > (tombstones[item.key] ?? 0)) {
        tombstones[item.key] = item.value;
      }
    }
    final entries = <String, _SearchHistoryRecord>{};
    for (final entry in [...local.entries, ...remote.entries]) {
      final existing = entries[entry.keyword];
      if (existing == null || entry.updatedAtMs > existing.updatedAtMs) {
        entries[entry.keyword] = entry;
      }
    }
    final visible = entries.values.where((entry) {
      return entry.updatedAtMs > clearedAtMs &&
          entry.updatedAtMs > (tombstones[entry.keyword] ?? 0);
    }).toList()..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return _SearchHistorySyncState(
      entries: visible.take(hazukiSearchHistoryMaxCount).toList(),
      tombstones: tombstones,
      clearedAtMs: clearedAtMs,
    );
  }

  Future<void> _writeSyncState(_SearchHistorySyncState state) async {
    final entriesByKeyword = <String, _SearchHistoryRecord>{};
    for (final entry in state.entries) {
      final existing = entriesByKeyword[entry.keyword];
      if (existing == null || entry.updatedAtMs > existing.updatedAtMs) {
        entriesByKeyword[entry.keyword] = entry;
      }
    }
    final visibleEntries = entriesByKeyword.values.where((entry) {
      return entry.updatedAtMs > state.clearedAtMs &&
          entry.updatedAtMs > (state.tombstones[entry.keyword] ?? 0);
    }).toList()..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    final limitedEntries = visibleEntries
        .take(hazukiSearchHistoryMaxCount)
        .toList();
    await _database.transaction(() async {
      await _database.delete(_database.searchHistoryEntries).go();
      await _database.delete(_database.searchHistoryTombstones).go();
      await _database.delete(_database.searchHistoryClearStates).go();
      for (var index = 0; index < limitedEntries.length; index++) {
        final entry = limitedEntries[index];
        await _database
            .into(_database.searchHistoryEntries)
            .insert(
              SearchHistoryEntriesCompanion.insert(
                keyword: entry.keyword,
                position: index,
                updatedAtMs: Value(entry.updatedAtMs),
              ),
            );
      }
      for (final tombstone in state.tombstones.entries) {
        await _database
            .into(_database.searchHistoryTombstones)
            .insert(
              SearchHistoryTombstonesCompanion.insert(
                keyword: tombstone.key,
                deletedAtMs: tombstone.value,
              ),
            );
      }
      if (state.clearedAtMs > 0) {
        await _database
            .into(_database.searchHistoryClearStates)
            .insert(
              SearchHistoryClearStatesCompanion.insert(
                id: _clearStateId,
                clearedAtMs: state.clearedAtMs,
              ),
            );
      }
    });
    await _markMigrated();
  }
}

class _SearchHistoryRecord {
  const _SearchHistoryRecord({
    required this.keyword,
    required this.updatedAtMs,
  });

  final String keyword;
  final int updatedAtMs;
}

class _SearchHistorySyncState {
  const _SearchHistorySyncState({
    required this.entries,
    required this.tombstones,
    required this.clearedAtMs,
  });

  final List<_SearchHistoryRecord> entries;
  final Map<String, int> tombstones;
  final int clearedAtMs;
}
