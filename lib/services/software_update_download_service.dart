import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'software_update_service.dart';

enum SoftwareUpdateDownloadStage { idle, downloading, failed }

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
  double _progress = 0;
  bool _indeterminate = true;
  double _speedBytesPerSecond = 0;

  SoftwareUpdateDownloadStage get stage => _stage;
  SoftwareUpdateDownloadFailureKind get failureKind => _failureKind;
  String? get failureDetail => _failureDetail;
  String? get targetVersion => _targetVersion;
  String? get apkPath => _apkPath;
  double get progress => _progress;
  bool get indeterminate => _indeterminate;
  double get speedBytesPerSecond => _speedBytesPerSecond;
  bool get isDownloading => _stage == SoftwareUpdateDownloadStage.downloading;
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
    final apkUrl = check.apkUrl?.trim();
    if (!Platform.isAndroid || apkUrl == null || apkUrl.isEmpty) {
      _setFailure(
        apkUrl == null || apkUrl.isEmpty
            ? SoftwareUpdateDownloadFailureKind.apkUnavailable
            : SoftwareUpdateDownloadFailureKind.downloadFailed,
      );
      return false;
    }

    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    _targetVersion = check.latestVersion;
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
        apkUrl: apkUrl,
      );
      _apkPath = targetFile.path;

      final stopwatch = Stopwatch()..start();
      var lastTickMillis = 0;
      var lastReceivedBytes = 0;

      await _dio.download(
        apkUrl,
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

      final launchedInstaller =
          await _mediaChannel.invokeMethod<bool>('installApk', {
            'path': file.path,
          }) ??
          false;

      if (!launchedInstaller) {
        _setFailure(SoftwareUpdateDownloadFailureKind.installerLaunchFailed);
        return false;
      }

      _stage = SoftwareUpdateDownloadStage.idle;
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
    required String apkUrl,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final updatesDir = Directory('${cacheDir.path}/software_updates');
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }

    final uri = Uri.tryParse(apkUrl);
    var fileName = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'hazuki-$latestVersion.apk';
    fileName = fileName.trim();
    if (fileName.isEmpty) {
      fileName = 'hazuki-$latestVersion.apk';
    }
    fileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (!fileName.toLowerCase().endsWith('.apk')) {
      fileName = '$fileName.apk';
    }

    final file = File('${updatesDir.path}/$fileName');
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
