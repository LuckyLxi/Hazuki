import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/source_prefs_keys.dart';

/// Persists source scripts and their edit state without owning a runtime.
class SourceScriptStorage {
  SourceScriptStorage({
    required String defaultSourceKey,
    required String Function(String sourceKey) normalizeSourceKey,
    required Future<SharedPreferences> Function(String sourceKey)
    ensurePreferences,
  }) : _defaultSourceKey = defaultSourceKey,
       _normalizeSourceKey = normalizeSourceKey,
       _ensurePreferences = ensurePreferences;

  final String _defaultSourceKey;
  final String Function(String sourceKey) _normalizeSourceKey;
  final Future<SharedPreferences> Function(String sourceKey) _ensurePreferences;

  Future<Directory> directoryFor(String sourceKey) async {
    final normalized = _normalizeSourceKey(sourceKey);
    if (Platform.isAndroid) {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}/comic_source/$normalized');
    }
    if (Platform.isWindows) {
      return Directory(
        '${File(Platform.resolvedExecutable).parent.path}/comic_source/$normalized',
      );
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return Directory('${downloads.path}/hazuki_source_test/$normalized');
      }
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/comic_source/$normalized');
  }

  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) async {
    final directory = await directoryFor(sourceKey);
    if (ensureDirectory && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/source.js');
  }

  Future<File> ensureLocalSourceFile(String sourceKey) async {
    final normalized = _normalizeSourceKey(sourceKey);
    final file = await sourceFileFor(normalized, ensureDirectory: true);
    if (normalized == _defaultSourceKey && !await file.exists()) {
      final legacy = File('${file.parent.parent.path}/jm.js');
      if (await legacy.exists()) await legacy.copy(file.path);
    }
    return file;
  }

  Future<String?> readIfExists(String sourceKey) async {
    try {
      final file = await sourceFileFor(sourceKey);
      return await file.exists() ? file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String sourceKey, String content) async {
    final file = await sourceFileFor(sourceKey, ensureDirectory: true);
    await file.writeAsString(content, flush: true);
  }

  Future<bool> exists(String sourceKey) async {
    final normalized = _normalizeSourceKey(sourceKey);
    final file = await sourceFileFor(normalized);
    if (await file.exists()) return true;
    return normalized == _defaultSourceKey &&
        await File('${file.parent.parent.path}/jm.js').exists();
  }

  Future<void> delete(String sourceKey) async {
    final file = await sourceFileFor(sourceKey);
    if (await file.exists()) await file.delete();
  }

  Future<bool> isCustomEdited(String sourceKey) async {
    final normalized = _normalizeSourceKey(sourceKey);
    final prefs = await _ensurePreferences(normalized);
    final key = SourcePrefsKeys.customEditedSource(normalized);
    if (prefs.containsKey(key)) return prefs.getBool(key) ?? false;
    return normalized == _defaultSourceKey &&
        (prefs.getBool(SourcePrefsKeys.customEditedJmSource) ?? false);
  }

  Future<void> setCustomEdited(String sourceKey, bool value) async {
    final normalized = _normalizeSourceKey(sourceKey);
    final prefs = await _ensurePreferences(normalized);
    await prefs.setBool(SourcePrefsKeys.customEditedSource(normalized), value);
    if (normalized == _defaultSourceKey) {
      await prefs.setBool(SourcePrefsKeys.customEditedJmSource, value);
    }
  }
}
