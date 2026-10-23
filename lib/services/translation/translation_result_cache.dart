import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'manga_translation_settings_store.dart';
import 'models/translation_models.dart';
import 'translation_file_queue.dart';
import 'translation_prompt.dart';

/// 本地检测前后处理的版本；改动检测参数或框编号规则时递增。
const kDetectorProcessingVersion = 1;

/// 本地检测模式下参与缓存键的模型信息。
class TranslationDetectorCacheKey {
  const TranslationDetectorCacheKey({
    required this.modelId,
    required this.modelSha256,
  });

  final String modelId;
  final String modelSha256;
}

class TranslationResultCache {
  TranslationResultCache({
    Future<Directory> Function()? supportDirectory,
    this.maximumBytes = 50 * 1024 * 1024,
    this.targetBytes = 40 * 1024 * 1024,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;
  final int maximumBytes;
  final int targetBytes;
  final _queue = TranslationFileQueue();

  static Future<String> keyFor({
    required Uint8List imageBytes,
    required String targetLanguage,
    required TranslationProviderPreset providerPreset,
    required String model,
    required bool translateSfx,
    TranslationReasoningEffort reasoningEffort =
        TranslationReasoningEffort.providerDefault,
    String customSystemPrompt = '',
    TranslationDetectorCacheKey? detector,
  }) {
    final modelId = detector?.modelId;
    final modelSha256 = detector?.modelSha256;
    return Isolate.run(
      () => sha1
          .convert(
            utf8.encode(
              jsonEncode([
                sha1.convert(imageBytes).toString(),
                targetLanguage,
                providerPreset.name,
                model,
                translateSfx,
                modelId == null
                    ? kTranslationPromptVersion
                    : kDetectorTranslationPromptVersion,
                reasoningEffort.name,
                customSystemPrompt.trim(),
                // AI 定位不追加任何字段，保证第一版缓存键不变。
                if (modelId != null) ...[
                  'detector',
                  modelId,
                  modelSha256,
                  kDetectorProcessingVersion,
                ],
              ]),
            ),
          )
          .toString(),
    );
  }

  Future<Directory> _directory() async => Directory(
    p.join((await _supportDirectory()).path, 'manga_translation', 'cache'),
  );

  Future<File> _file(String key) async {
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key');
    }
    return File(p.join((await _directory()).path, '$key.json'));
  }

  Future<PageTranslationResult?> read(String key) =>
      _queue.run('cache', () async {
        final file = await _file(key);
        if (!await file.exists()) return null;
        try {
          final result = PageTranslationResult.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
          return PageTranslationResult(
            regions: result.regions,
            terms: result.terms,
          );
        } on FormatException {
          await file.delete();
          return null;
        } on TypeError {
          await file.delete();
          return null;
        } on ArgumentError {
          await file.delete();
          return null;
        }
      });

  Future<void> write(String key, PageTranslationResult result) async {
    await _queue.run('cache', () async {
      final file = await _file(key);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(result.toJson()), flush: true);
    });
    unawaited(
      _queue.run('cache', _prune).catchError((Object error) {
        debugPrint('翻译缓存清理失败：${error.runtimeType}');
      }),
    );
  }

  Future<void> remove(String key) => _queue.run('cache', () async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  });

  Future<void> clear() => _queue.run('cache', () async {
    for (final file in await _files()) {
      await file.delete();
    }
  });

  Future<int> sizeBytes() => _queue.run('cache', () async {
    var total = 0;
    for (final file in await _files()) {
      total += await file.length();
    }
    return total;
  });

  Future<List<File>> _files() async {
    final directory = await _directory();
    if (!await directory.exists()) return [];
    return directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.json'))
        .cast<File>()
        .toList();
  }

  Future<void> _prune() async {
    final entries = <(File, FileStat)>[];
    var total = 0;
    for (final file in await _files()) {
      final stat = await file.stat();
      entries.add((file, stat));
      total += stat.size;
    }
    if (total <= maximumBytes) return;
    entries.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final entry in entries) {
      await entry.$1.delete();
      total -= entry.$2.size;
      if (total < targetBytes) break;
    }
  }
}
