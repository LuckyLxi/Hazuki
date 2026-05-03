import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'software_update_service.dart';

enum SoftwareUpdateDownloadStage { idle, downloading, success, failed }

enum SoftwareUpdateDownloadFailureKind {
  none,
  apkUnavailable,
  downloadFailed,
  fileInvalid,
  installerLaunchFailed,
}

class SoftwareUpdateDownloadService extends ChangeNotifier {
  SoftwareUpdateDownloadService._();

  static final SoftwareUpdateDownloadService instance =
      SoftwareUpdateDownloadService._();

  static const MethodChannel _mediaChannel = MethodChannel(
    'hazuki.comics/media',
  );

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(minutes: 20),
      sendTimeout: const Duration(seconds: 12),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 400,
    ),
  );

  Future<bool>? _activeTask;
  CancelToken? _cancelToken;
  SoftwareUpdateDownloadStage _stage = SoftwareUpdateDownloadStage.idle;
  SoftwareUpdateDownloadFailureKind _failureKind =
      SoftwareUpdateDownloadFailureKind.none;
  String? _failureDetail;
  String? _targetVersion;
  String? _apkPath;
  bool _isZipMode = false;
  String? _downloadedDir;
  double _progress = 0;
  bool _indeterminate = true;
  double _speedBytesPerSecond = 0;

  SoftwareUpdateDownloadStage get stage => _stage;
  SoftwareUpdateDownloadFailureKind get failureKind => _failureKind;
  String? get failureDetail => _failureDetail;
  String? get targetVersion => _targetVersion;
  String? get apkPath => _apkPath;
  bool get isZipMode => _isZipMode;
  String? get downloadedDir => _downloadedDir;
  double get progress => _progress;
  bool get indeterminate => _indeterminate;
  double get speedBytesPerSecond => _speedBytesPerSecond;
  bool get isDownloading => _stage == SoftwareUpdateDownloadStage.downloading;
  bool get isSuccess => _stage == SoftwareUpdateDownloadStage.success;
  bool get hasFailure => _stage == SoftwareUpdateDownloadStage.failed;

  Future<bool> startDownload(SoftwareUpdateCheckResult check) {
    final inFlight = _activeTask;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _startDownload(check);
    _activeTask = future;
    future.whenComplete(() {
      if (identical(_activeTask, future)) {
        _activeTask = null;
      }
    });
    return future;
  }

  void clearFailure() {
    if (!hasFailure) {
      return;
    }
    _stage = SoftwareUpdateDownloadStage.idle;
    _failureKind = SoftwareUpdateDownloadFailureKind.none;
    _failureDetail = null;
    notifyListeners();
  }

  Future<bool> _startDownload(SoftwareUpdateCheckResult check) async {
    final downloadUrl = Platform.isWindows
        ? check.windowsUrl?.trim()
        : check.apkUrl?.trim();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      _setFailure(
        Platform.isAndroid
            ? SoftwareUpdateDownloadFailureKind.apkUnavailable
            : SoftwareUpdateDownloadFailureKind.downloadFailed,
      );
      return false;
    }

    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _targetVersion = check.latestVersion;
    _isZipMode =
        Platform.isWindows && downloadUrl.toLowerCase().endsWith('.zip');
    _downloadedDir = null;
    _failureKind = SoftwareUpdateDownloadFailureKind.none;
    _failureDetail = null;
    _progress = 0;
    _indeterminate = true;
    _speedBytesPerSecond = 0;
    _stage = SoftwareUpdateDownloadStage.downloading;
    notifyListeners();

    try {
      final targetFile = await _prepareTargetFile(
        latestVersion: check.latestVersion,
        downloadUrl: downloadUrl,
      );
      _apkPath = targetFile.path;
      if (_isZipMode) {
        _downloadedDir = targetFile.parent.path;
      }

      final stopwatch = Stopwatch()..start();
      var lastTickMillis = 0;
      var lastReceivedBytes = 0;

      await _dio.download(
        downloadUrl,
        targetFile.path,
        cancelToken: _cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          final elapsedMillis = stopwatch.elapsedMilliseconds;
          if (elapsedMillis - lastTickMillis >= 260 ||
              (total > 0 && received >= total)) {
            final deltaMillis = math.max(elapsedMillis - lastTickMillis, 1);
            final deltaBytes = math.max(received - lastReceivedBytes, 0);
            _speedBytesPerSecond = deltaBytes * 1000 / deltaMillis;
            lastTickMillis = elapsedMillis;
            lastReceivedBytes = received;
          }

          _indeterminate = total <= 0;
          _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
          notifyListeners();
        },
      );

      final file = File(targetFile.path);
      if (!await file.exists() || await file.length() <= 0) {
        _setFailure(SoftwareUpdateDownloadFailureKind.fileInvalid);
        return false;
      }

      _progress = 1;
      _indeterminate = false;
      _speedBytesPerSecond = 0;
      notifyListeners();

      if (Platform.isAndroid) {
        final launchedInstaller =
            await _mediaChannel.invokeMethod<bool>('installApk', {
              'path': file.path,
            }) ??
            false;

        if (!launchedInstaller) {
          _setFailure(SoftwareUpdateDownloadFailureKind.installerLaunchFailed);
          return false;
        }
      } else if (Platform.isWindows && !_isZipMode) {
        Process.run('explorer.exe', [file.path]);
      }

      _stage = _isZipMode
          ? SoftwareUpdateDownloadStage.success
          : SoftwareUpdateDownloadStage.idle;
      _failureKind = SoftwareUpdateDownloadFailureKind.none;
      _failureDetail = null;
      notifyListeners();
      return true;
    } on DioException catch (error) {
      _setFailure(
        SoftwareUpdateDownloadFailureKind.downloadFailed,
        _describeDioError(error),
      );
      return false;
    } catch (error) {
      _setFailure(
        SoftwareUpdateDownloadFailureKind.downloadFailed,
        error.toString(),
      );
      return false;
    }
  }

  Future<File> _prepareTargetFile({
    required String latestVersion,
    required String downloadUrl,
  }) async {
    final Directory baseDir;
    if (Platform.isWindows) {
      baseDir =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      final cacheDir = await getTemporaryDirectory();
      baseDir = Directory('${cacheDir.path}/software_updates');
    }

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final uri = Uri.tryParse(downloadUrl);
    var fileName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'hazuki-$latestVersion${_isZipMode ? ".zip" : (Platform.isWindows ? ".exe" : ".apk")}';
    fileName = fileName.trim();
    if (fileName.isEmpty) {
      fileName =
          'hazuki-$latestVersion${_isZipMode ? ".zip" : (Platform.isWindows ? ".exe" : ".apk")}';
    }

    // Windows allows some chars, but let's be safe.
    if (!Platform.isWindows) {
      fileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (!fileName.toLowerCase().endsWith('.apk')) {
        fileName = '$fileName.apk';
      }
    } else {
      // Basic sanitization
      fileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    }

    final file = File('${baseDir.path}/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
    return file;
  }

  void _setFailure(SoftwareUpdateDownloadFailureKind kind, [String? detail]) {
    _stage = SoftwareUpdateDownloadStage.failed;
    _failureKind = kind;
    _failureDetail = detail?.trim().isNotEmpty == true ? detail!.trim() : null;
    _speedBytesPerSecond = 0;
    notifyListeners();
  }

  String _describeDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return 'HTTP $statusCode';
    }
    return error.message?.trim().isNotEmpty == true
        ? error.message!.trim()
        : error.type.name;
  }
}
