import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models/translation_models.dart';
import 'translation_file_queue.dart';

class TranslationGlossaryEntry {
  const TranslationGlossaryEntry({
    required this.source,
    required this.target,
    required this.addedAt,
    required this.lastSeenAt,
  });

  final String source;
  final String target;
  final DateTime addedAt;
  final DateTime lastSeenAt;

  TranslationTerm get term => TranslationTerm(source: source, target: target);
  Map<String, dynamic> toJson() => {
    'src': source,
    'dst': target,
    'addedAt': addedAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
  };
  factory TranslationGlossaryEntry.fromJson(Map<String, dynamic> json) =>
      TranslationGlossaryEntry(
        source: json['src'] as String,
        target: json['dst'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
      );
}

class TranslationGlossaryStore {
  TranslationGlossaryStore({
    Future<Directory> Function()? supportDirectory,
    DateTime Function()? now,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _supportDirectory;
  final DateTime Function() _now;
  final _queue = TranslationFileQueue();

  Future<File> _file(String sourceKey, String comicId) async => File(
    p.join(
      (await _supportDirectory()).path,
      'manga_translation',
      'glossary',
      sha1.convert(utf8.encode(sourceKey)).toString(),
      '${sha1.convert(utf8.encode(comicId))}.json',
    ),
  );

  String _lockKey(String sourceKey, String comicId) =>
      jsonEncode([sourceKey, comicId]);

  Future<List<TranslationGlossaryEntry>> _read(File file) async {
    if (!await file.exists()) return [];
    return (jsonDecode(await file.readAsString()) as List)
        .map(
          (value) =>
              TranslationGlossaryEntry.fromJson(value as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _write(
    File file,
    Iterable<TranslationGlossaryEntry> entries,
  ) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      flush: true,
    );
  }

  Future<List<TranslationGlossaryEntry>> load(
    String sourceKey,
    String comicId,
  ) => _queue.run(
    _lockKey(sourceKey, comicId),
    () async => _read(await _file(sourceKey, comicId)),
  );

  Future<void> merge(
    String sourceKey,
    String comicId,
    List<TranslationTerm> terms,
  ) => _queue.run(_lockKey(sourceKey, comicId), () async {
    final file = await _file(sourceKey, comicId);
    final entries = {
      for (final entry in await _read(file)) entry.source: entry,
    };
    final now = _now();
    for (final term in terms) {
      final source = term.source.trim();
      if (source.isEmpty || term.target.trim().isEmpty) continue;
      final previous = entries[source];
      entries[source] = TranslationGlossaryEntry(
        source: source,
        target: previous?.target ?? term.target.trim(),
        addedAt: previous?.addedAt ?? now,
        lastSeenAt: now,
      );
    }
    final sorted = entries.values.toList()
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    await _write(file, sorted.take(150));
  });

  Future<void> removeEntry(String sourceKey, String comicId, String source) =>
      _queue.run(_lockKey(sourceKey, comicId), () async {
        final file = await _file(sourceKey, comicId);
        final entries = await _read(file);
        await _write(file, entries.where((entry) => entry.source != source));
      });

  Future<void> clear(String sourceKey, String comicId) =>
      _queue.run(_lockKey(sourceKey, comicId), () async {
        final file = await _file(sourceKey, comicId);
        if (await file.exists()) await file.delete();
      });
}
