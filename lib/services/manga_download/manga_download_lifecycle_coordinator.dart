import 'dart:async';

import 'package:flutter/widgets.dart';

/// Coordinates platform lifecycle effects without owning the download queue.
class MangaDownloadLifecycleCoordinator {
  MangaDownloadLifecycleCoordinator({
    required bool isAndroid,
    required bool Function() hasActiveDownloads,
    required Future<void> Function() startForegroundService,
    required Future<void> Function() stopForegroundService,
    required Future<void> Function() processQueue,
    DateTime Function()? now,
  }) : _isAndroid = isAndroid,
       _hasActiveDownloads = hasActiveDownloads,
       _startForegroundService = startForegroundService,
       _stopForegroundService = stopForegroundService,
       _processQueue = processQueue,
       _now = now ?? DateTime.now;

  final bool _isAndroid;
  final bool Function() _hasActiveDownloads;
  final Future<void> Function() _startForegroundService;
  final Future<void> Function() _stopForegroundService;
  final Future<void> Function() _processQueue;
  final DateTime Function() _now;

  bool _suspended = false;
  bool _disposed = false;
  DateTime? _resumeGraceDeadline;
  Timer? _resumeTimer;

  bool get shouldSuspendDownloads => _suspended;

  bool get shouldRecoverTransientNetworkError {
    if (_suspended) return true;
    final deadline = _resumeGraceDeadline;
    return deadline != null && _now().isBefore(deadline);
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _suspended = false;
      _resumeTimer?.cancel();
      unawaited(_stopForegroundService());
      _resumeGraceDeadline = _now().add(const Duration(seconds: 4));
      _resumeTimer = Timer(const Duration(milliseconds: 1200), () {
        _resumeTimer = null;
        if (_disposed || _suspended) return;
        unawaited(_processQueue());
      });
      return;
    }

    if (_isAndroid) {
      // Android transient background states keep downloads running.
      if (state == AppLifecycleState.paused && _hasActiveDownloads()) {
        unawaited(_startForegroundService());
      }
      if (state != AppLifecycleState.detached) return;
    }

    if (_suspended) return;
    _suspended = true;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _resumeGraceDeadline = null;
  }

  void dispose() {
    _disposed = true;
    _resumeTimer?.cancel();
    _resumeTimer = null;
  }
}
