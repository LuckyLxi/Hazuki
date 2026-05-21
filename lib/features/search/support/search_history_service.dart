import 'dart:async';

import 'package:drift/drift.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/app/app_preferences.dart';
import 'package:hazuki/services/storage/hazuki_database.dart';

class SearchHistoryService {
  SearchHistoryService({HazukiDatabase? database})
    : _database = database ?? sl<HazukiDatabase>();

  final HazukiDatabase _database;
  Future<void> _migration = Future.value();
  Future<void> _opQueue = Future.value();

  static const _key = 'search_history';
  static const _migrationDoneKey = 'search_history_drift_migrated_v1';

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
      await _replaceInDatabase(legacy);
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
      final history = await _loadFromDatabase();
      final next = [normalized, ...history.where((e) => e != normalized)];
      await _replaceInDatabase(next);
    });
  }

  Future<List<String>> remove(String keyword) async {
    return _serialized(() async {
      await _ensureMigrated();
      final current = await _loadFromDatabase();
      final next = current.where((e) => e != keyword).toList();
      await _replaceInDatabase(next);
      return next;
    });
  }

  Future<void> clear() async {
    await _serialized(() async {
      await _ensureMigrated();
      await _database.delete(_database.searchHistoryEntries).go();
    });
  }

  Future<void> replace(List<String> keywords) async {
    await _serialized(() async {
      await _replaceInDatabase(keywords);
      await _markMigrated();
    });
  }

  Future<void> _markMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_migrationDoneKey, true);
  }

  Future<List<String>> _loadFromDatabase() async {
    final rows = await ((_database.select(
      _database.searchHistoryEntries,
    )..orderBy([(entry) => OrderingTerm.asc(entry.position)])).get());
    return rows.map((entry) => entry.keyword).toList(growable: false);
  }

  Future<void> _replaceInDatabase(List<String> keywords) async {
    final next = <String>[];
    final seen = <String>{};
    for (final keyword in keywords) {
      final normalized = keyword.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      next.add(normalized);
      if (next.length >= hazukiSearchHistoryMaxCount) {
        break;
      }
    }
    await _database.transaction(() async {
      await _database.delete(_database.searchHistoryEntries).go();
      for (var i = 0; i < next.length; i++) {
        await _database
            .into(_database.searchHistoryEntries)
            .insert(
              SearchHistoryEntriesCompanion.insert(
                keyword: next[i],
                position: i,
              ),
            );
      }
    });
  }
}
