import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/hazuki_source_service.dart';
import 'source_runtime_widgets.dart';

class SourceBootstrapState {
  const SourceBootstrapState({
    required this.showOverlay,
    required this.showIntro,
    required this.indeterminate,
    required this.progress,
    this.errorText,
  });

  const SourceBootstrapState.idle()
    : this(
        showOverlay: false,
        showIntro: false,
        indeterminate: true,
        progress: 0,
      );

  final bool showOverlay;
  final bool showIntro;
  final bool indeterminate;
  final double progress;
  final String? errorText;

  SourceBootstrapState copyWith({
    bool? showOverlay,
    bool? showIntro,
    bool? indeterminate,
    double? progress,
    String? errorText,
    bool clearErrorText = false,
  }) {
    return SourceBootstrapState(
      showOverlay: showOverlay ?? this.showOverlay,
      showIntro: showIntro ?? this.showIntro,
      indeterminate: indeterminate ?? this.indeterminate,
      progress: progress ?? this.progress,
      errorText: clearErrorText ? null : (errorText ?? this.errorText),
    );
  }
}

class SourceRuntimeCoordinator {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasConnectivity = true;
  bool _isCheckingSourceUpdate = false;
  bool _isShowingSourceUpdateDialog = false;

  Future<void> bootstrapSourceRuntime({
    required bool Function() isMounted,
    required void Function(SourceBootstrapState state) onBootstrapStateChanged,
    required VoidCallback onSourceReady,
    required VoidCallback scheduleSourceUpdateDialogCheck,
  }) async {
    final hasLocalSource = await HazukiSourceService.instance
        .hasLocalJmSourceFile();
    if (!isMounted()) {
      return;
    }

    if (!hasLocalSource) {
      var bootstrapSucceeded = false;
      onBootstrapStateChanged(
        const SourceBootstrapState(
          showOverlay: false,
          showIntro: true,
          indeterminate: true,
          progress: 0,
        ),
      );
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!isMounted()) {
          return;
        }
        onBootstrapStateChanged(
          const SourceBootstrapState(
            showOverlay: true,
            showIntro: false,
            indeterminate: true,
            progress: 0,
          ),
        );
      }());
      try {
        await HazukiSourceService.instance.init(
          onSourceDownloadProgress: (received, total) {
            if (!isMounted()) {
              return;
            }
            onBootstrapStateChanged(
              SourceBootstrapState(
                showOverlay: true,
                showIntro: false,
                indeterminate: total <= 0,
                progress: total > 0 ? (received / total).clamp(0.0, 1.0) : 0,
              ),
            );
          },
        );
        await HazukiSourceService.instance.ensureInitialized();
        bootstrapSucceeded = true;
      } catch (e) {
        if (!isMounted()) {
          return;
        }
        onBootstrapStateChanged(
          SourceBootstrapState(
            showOverlay: true,
            showIntro: false,
            indeterminate: false,
            progress: 1,
            errorText: '$e',
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (!isMounted() || !bootstrapSucceeded) {
        return;
      }
      onBootstrapStateChanged(const SourceBootstrapState.idle());
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!isMounted()) {
        return;
      }
      onSourceReady();
      return;
    }

    if (!isMounted()) {
      return;
    }
    onSourceReady();
    scheduleSourceUpdateDialogCheck();
  }

  Future<void> initConnectivityWatcher({
    required void Function() scheduleSourceRecovery,
  }) async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _hasConnectivity = initial.any(
        (result) => result != ConnectivityResult.none,
      );
    } catch (_) {
      _hasConnectivity = true;
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final hasNetwork = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (_hasConnectivity == hasNetwork) {
        return;
      }
      _hasConnectivity = hasNetwork;
      if (_hasConnectivity) {
        scheduleSourceRecovery();
      }
    });
  }

  void scheduleSourceRecovery({
    required bool Function() isMounted,
    required VoidCallback scheduleSourceUpdateDialogCheck,
  }) {
    unawaited(
      _runSourceRecovery(
        isMounted: isMounted,
        scheduleSourceUpdateDialogCheck: scheduleSourceUpdateDialogCheck,
      ),
    );
  }

  void scheduleSourceUpdateDialogCheck({
    required bool Function() isMounted,
    required Future<SourceUpdateDialogAction?> Function() showDialogIfNeeded,
    required VoidCallback onSourceDownloaded,
  }) {
    if (_isCheckingSourceUpdate || _isShowingSourceUpdateDialog) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted() ||
          _isCheckingSourceUpdate ||
          _isShowingSourceUpdateDialog) {
        return;
      }
      unawaited(
        _runSourceUpdateDialogCheck(
          isMounted: isMounted,
          showDialogIfNeeded: showDialogIfNeeded,
          onSourceDownloaded: onSourceDownloaded,
        ),
      );
    });
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }

  Future<void> _runSourceRecovery({
    required bool Function() isMounted,
    required VoidCallback scheduleSourceUpdateDialogCheck,
  }) async {
    final refreshed = await HazukiSourceService.instance
        .refreshSourceOnNetworkRecovery();
    if (!isMounted() || !refreshed) {
      return;
    }
    scheduleSourceUpdateDialogCheck();
  }

  Future<void> _runSourceUpdateDialogCheck({
    required bool Function() isMounted,
    required Future<SourceUpdateDialogAction?> Function() showDialogIfNeeded,
    required VoidCallback onSourceDownloaded,
  }) async {
    if (_isCheckingSourceUpdate || _isShowingSourceUpdateDialog) {
      return;
    }

    _isCheckingSourceUpdate = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!isMounted()) {
        return;
      }
      _isShowingSourceUpdateDialog = true;
      final result = await showDialogIfNeeded();
      if (!isMounted()) {
        return;
      }
      if (result == SourceUpdateDialogAction.downloaded) {
        onSourceDownloaded();
      }
    } finally {
      _isShowingSourceUpdateDialog = false;
      _isCheckingSourceUpdate = false;
    }
  }
}
