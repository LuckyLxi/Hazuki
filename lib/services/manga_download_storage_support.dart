import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manga_download_models.dart';

typedef MangaDownloadLogCallback =
    void Function(String title, {Object? content, String level});

class MangaDownloadPersistedState {
  const MangaDownloadPersistedState({
    required this.tasks,
    required this.downloaded,
  });

  final List<MangaDownloadTask> tasks;
  final List<DownloadedMangaComic> downloaded;
}

class MangaDownloadStateStore {
  MangaDownloadStateStore({required MangaDownloadLogCallback logScan})
    : _logScan = logScan;

  static const String _statePrefsKey = 'manga_download_service_state_v2';

  final MangaDownloadLogCallback _logScan;

  Future<MangaDownloadPersistedState> restore(SharedPreferences? prefs) async {
    final tasks = <MangaDownloadTask>[];
    final downloaded = <DownloadedMangaComic>[];
    final raw = prefs?.getString(_statePrefsKey);

    _logScan(
      'Downloads state bootstrap',
      content: {'hasPersistedState': raw != null && raw.isNotEmpty},
    );

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final tasksRaw = map['tasks'];
          if (tasksRaw is List) {
            for (final item in tasksRaw) {
              if (item is Map) {
                var task = MangaDownloadTask.fromJson(
                  Map<String, dynamic>.from(item),
                );
                if (task.status == MangaDownloadTaskStatus.downloading) {
                  task = task.copyWith(
                    status: MangaDownloadTaskStatus.queued,
                    clearErrorMessage: true,
                  );
                }
                tasks.add(task);
              }
            }
          }

          final downloadedRaw = map['downloaded'];
          if (downloadedRaw is List) {
            for (final item in downloadedRaw) {
              if (item is Map) {
                downloaded.add(
                  DownloadedMangaComic.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                );
              }
            }
          }

          _logScan(
            'Restored persisted download state',
            content: {
              'taskCount': tasks.length,
              'downloadedCount': downloaded.length,
            },
          );
        }
      } catch (e) {
        _logScan(
          'Failed to parse persisted download state',
          level: 'warning',
          content: {'error': e.toString()},
        );
      }
    }

    tasks.sort((a, b) => a.createdAtMillis.compareTo(b.createdAtMillis));
    downloaded.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));

    _logScan(
      'Downloads state restore finished',
      content: {
        'taskCount': tasks.length,
        'downloadedCount': downloaded.length,
      },
    );

    return MangaDownloadPersistedState(tasks: tasks, downloaded: downloaded);
  }

  Future<void> persist({
    required SharedPreferences? prefs,
    required List<MangaDownloadTask> tasks,
    required List<DownloadedMangaComic> downloaded,
  }) async {
    if (prefs == null) {
      _logScan(
        'Skipping download state persist: SharedPreferences not available',
        level: 'warning',
      );
      return;
    }
    final payload = {
      'tasks': tasks.map((e) => e.toJson()).toList(),
      'downloaded': downloaded.map((e) => e.toJson()).toList(),
    };
    await prefs.setString(_statePrefsKey, jsonEncode(payload));
  }
}

class MangaDownloadAccess {
  MangaDownloadAccess({required MangaDownloadLogCallback logScan})
    : _logScan = logScan;

  static const String _androidDefaultDownloadsRootPath =
      '/storage/emulated/0/Download/Hazuki_Manga';
  static const String _downloadsFolderName = 'Hazuki_Manga';
  static const String _downloadsRootPathPrefsKey =
      'manga_download_root_path_v1';
  static const MethodChannel _mediaChannel = MethodChannel(
    'hazuki.comics/media',
  );

  final MangaDownloadLogCallback _logScan;

  static String get defaultDownloadsRootPath {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE']?.trim();
      if (userProfile != null && userProfile.isNotEmpty) {
        return '$userProfile/Downloads/$_downloadsFolderName'.replaceAll(
          '\\',
          '/',
        );
      }
      return 'C:/Users/Public/Downloads/$_downloadsFolderName';
    }
    return _androidDefaultDownloadsRootPath;
  }

  static String normalizeDownloadsRootPath(String? rawPath) {
    final trimmed = rawPath?.trim() ?? '';
    if (trimmed.isEmpty) {
      return defaultDownloadsRootPath;
    }
    var normalized = trimmed.replaceAll('\\', '/');
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.isEmpty ? defaultDownloadsRootPath : normalized;
  }

  static Future<String> loadDownloadsRootPath({
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    return normalizeDownloadsRootPath(
      resolvedPrefs.getString(_downloadsRootPathPrefsKey),
    );
  }

  static Future<void> saveDownloadsRootPath(
    String path, {
    SharedPreferences? prefs,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final normalized = normalizeDownloadsRootPath(path);
    if (normalized == defaultDownloadsRootPath) {
      await resolvedPrefs.remove(_downloadsRootPathPrefsKey);
      return;
    }
    await resolvedPrefs.setString(_downloadsRootPathPrefsKey, normalized);
  }

  static Future<void> ensureNoMediaMarkerForPath(String dirPath) async {
    final normalized = normalizeDownloadsRootPath(dirPath);
    if (normalized.trim().isEmpty) {
      return;
    }
    try {
      final dir = Directory(normalized);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final noMediaFile = File('${dir.path}/.nomedia');
      if (!await noMediaFile.exists()) {
        await noMediaFile.writeAsString('', flush: true);
      }
    } catch (_) {}
  }

  static Future<String?> pickDownloadsRootPath({String? currentPath}) async {
    if (Platform.isWindows) {
      final pickedPath = await getDirectoryPath(
        initialDirectory: normalizeDownloadsRootPath(currentPath),
      );
      if (pickedPath == null || pickedPath.trim().isEmpty) {
        return null;
      }
      return normalizeDownloadsRootPath(pickedPath);
    }

    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Directory picking is not supported on this platform',
      );
    }

    try {
      final pickedPath = await _mediaChannel.invokeMethod<String>(
        'pickDownloadsDirectory',
        <String, Object?>{
          'currentPath': normalizeDownloadsRootPath(currentPath),
        },
      );
      if (pickedPath == null || pickedPath.trim().isEmpty) {
        return null;
      }
      return normalizeDownloadsRootPath(pickedPath);
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> ensureAndroidDownloadsAccess() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final rootPath = await loadDownloadsRootPath();

    try {
      final hasAccess =
          await _mediaChannel.invokeMethod<bool>('hasStorageAccess') ?? false;
      if (hasAccess) {
        return true;
      }

      _logScan(
        'Requesting Android downloads access',
        level: 'warning',
        content: {'path': rootPath},
      );

      final granted =
          await _mediaChannel.invokeMethod<bool>('requestStorageAccess') ??
          false;
      _logScan(
        granted
            ? 'Granted Android downloads access'
            : 'Android downloads access not granted',
        level: granted ? 'info' : 'warning',
        content: {'path': rootPath, 'granted': granted},
      );
      return granted;
    } on MissingPluginException catch (e) {
      _logScan(
        'Android downloads access channel unavailable',
        level: 'warning',
        content: {'error': e.toString()},
      );
      return false;
    } catch (e) {
      _logScan(
        'Android downloads access request failed',
        level: 'warning',
        content: {'error': e.toString()},
      );
      return false;
    }
  }

  Future<Directory> ensureRootDir() async {
    final dir = Directory(await loadDownloadsRootPath());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      _logScan('Created downloads root directory', content: {'path': dir.path});
    }
    return dir;
  }

  Future<void> startDownloadForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _mediaChannel.invokeMethod<void>('startDownloadForegroundService');
    } catch (_) {}
  }

  Future<void> stopDownloadForegroundService() async {
    if (!Platform.isAndroid) return;
    try {
      await _mediaChannel.invokeMethod<void>('stopDownloadForegroundService');
    } catch (_) {}
  }
}
