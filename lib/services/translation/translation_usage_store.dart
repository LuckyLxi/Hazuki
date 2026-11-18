import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/translation_models.dart';
import 'translation_file_queue.dart';

class DailyTranslationUsage {
  const DailyTranslationUsage({
    this.pages = 0,
    this.requests = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });
  final int pages, requests, inputTokens, outputTokens;
  Map<String, int> toJson() => {
    'pages': pages,
    'requests': requests,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
  };
  factory DailyTranslationUsage.fromJson(Map<String, dynamic> json) =>
      DailyTranslationUsage(
        pages: json['pages'] as int,
        requests: json['requests'] as int,
        inputTokens: json['inputTokens'] as int,
        outputTokens: json['outputTokens'] as int,
      );
}

class TranslationUsageStore extends ChangeNotifier {
  TranslationUsageStore({
    Future<Directory> Function()? supportDirectory,
    DateTime Function()? now,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;
  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _now;
  final _queue = TranslationFileQueue();

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<File> _file() async => File(
    p.join((await _supportDirectory()).path, 'manga_translation', 'usage.json'),
  );

  Future<Map<String, DailyTranslationUsage>> _read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final now = _now();
    final cutoff = dateKey(DateTime(now.year, now.month, now.day - 399));
    return {
      for (final entry in json.entries)
        if (entry.key.compareTo(cutoff) >= 0)
          entry.key: DailyTranslationUsage.fromJson(
            entry.value as Map<String, dynamic>,
          ),
    };
  }

  Future<Map<String, DailyTranslationUsage>> load() =>
      _queue.run('usage', _read);

  Future<void> record({
    int pages = 0,
    int requests = 0,
    TranslationUsage usage = const TranslationUsage(),
  }) => _queue.run('usage', () async {
    final entries = await _read();
    final key = dateKey(_now());
    final current = entries[key] ?? const DailyTranslationUsage();
    entries[key] = DailyTranslationUsage(
      pages: current.pages + pages,
      requests: current.requests + requests,
      inputTokens: current.inputTokens + usage.inputTokens,
      outputTokens: current.outputTokens + usage.outputTokens,
    );
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(entries.map((key, value) => MapEntry(key, value.toJson()))),
      flush: true,
    );
    notifyListeners();
  });

  Future<void> clear() => _queue.run('usage', () async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    notifyListeners();
  });
}
