import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const int _maxLogsHistoryEntries = 20;

class LogsHistoryEntry {
  const LogsHistoryEntry({
    required this.id,
    required this.generatedAt,
    required this.logsByType,
  });

  final String id;
  final String generatedAt;
  final Map<String, Map<String, dynamic>> logsByType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'generatedAt': generatedAt,
      'logsByType': logsByType,
    };
  }

  static LogsHistoryEntry? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(value);
    final id = map['id']?.toString();
    final generatedAt = map['generatedAt']?.toString();
    final logsByTypeRaw = map['logsByType'];
    if (id == null ||
        id.isEmpty ||
        generatedAt == null ||
        generatedAt.isEmpty ||
        logsByTypeRaw is! Map) {
      return null;
    }

    final logsByType = <String, Map<String, dynamic>>{};
    for (final entry in logsByTypeRaw.entries) {
      final value = entry.value;
      if (value is Map) {
        logsByType[entry.key.toString()] = Map<String, dynamic>.from(value);
      }
    }
    return LogsHistoryEntry(
      id: id,
      generatedAt: generatedAt,
      logsByType: logsByType,
    );
  }
}

class LogsHistoryStore {
  const LogsHistoryStore();

  Future<List<LogsHistoryEntry>> load() async {
    final file = await _historyFile();
    if (!await file.exists()) {
      return const <LogsHistoryEntry>[];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) {
        return const <LogsHistoryEntry>[];
      }
      return _normalizeEntries(
        decoded
            .map(LogsHistoryEntry.fromJson)
            .whereType<LogsHistoryEntry>()
            .toList(),
      );
    } catch (_) {
      return const <LogsHistoryEntry>[];
    }
  }

  Future<List<LogsHistoryEntry>> add(LogsHistoryEntry entry) async {
    final entries = await load();
    final normalized = _normalizeEntries([entry, ...entries]);
    final file = await _historyFile();
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(normalized), flush: true);
    return normalized;
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(
      '${dir.path}${Platform.pathSeparator}logs'
      '${Platform.pathSeparator}history_v1.json',
    );
  }

  List<LogsHistoryEntry> _normalizeEntries(List<LogsHistoryEntry> entries) {
    final byId = <String, LogsHistoryEntry>{};
    for (final entry in entries) {
      byId[entry.id] = entry;
    }
    final normalized = byId.values.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    if (normalized.length <= _maxLogsHistoryEntries) {
      return normalized;
    }
    return normalized.take(_maxLogsHistoryEntries).toList();
  }
}
