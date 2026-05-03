import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'software_update_dialog_support.dart';
import 'source_runtime_coordinator.dart';
import 'source_runtime_widgets.dart';
import 'source_update_dialog_support.dart';
import 'windows_adaptation_notice_dialog_support.dart';

class HazukiAppStartupCoordinator extends ChangeNotifier {
  HazukiAppStartupCoordinator({
    required GlobalKey<NavigatorState> navigatorKey,
    required SourceRuntimeCoordinator sourceRuntimeCoordinator,
    required SourceUpdateDialogSupport sourceUpdateDialogSupport,
    required SoftwareUpdateDialogSupport softwareUpdateDialogSupport,
    WindowsAdaptationNoticeDialogSupport windowsAdaptationNoticeDialogSupport =
        const WindowsAdaptationNoticeDialogSupport(),
    required bool Function() isMounted,
  }) : _navigatorKey = navigatorKey,
       _sourceRuntimeCoordinator = sourceRuntimeCoordinator,
       _sourceUpdateDialogSupport = sourceUpdateDialogSupport,
       _softwareUpdateDialogSupport = softwareUpdateDialogSupport,
       _windowsAdaptationNoticeDialogSupport =
           windowsAdaptationNoticeDialogSupport,
       _isMounted = isMounted;

  static const _sourceUpdateSkipDateKey = 'source_update_skip_date';
  static const _softwareUpdateSkipDateKey = 'software_update_skip_date';

  final GlobalKey<NavigatorState> _navigatorKey;
  final SourceRuntimeCoordinator _sourceRuntimeCoordinator;
  final SourceUpdateDialogSupport _sourceUpdateDialogSupport;
  final SoftwareUpdateDialogSupport _softwareUpdateDialogSupport;
  final WindowsAdaptationNoticeDialogSupport
  _windowsAdaptationNoticeDialogSupport;
  final bool Function() _isMounted;

  int _homeRefreshTick = 0;
  bool _allowDiscoverInitialLoad = false;
  SourceBootstrapState _bootstrapState = const SourceBootstrapState.idle();
  bool _autoSourceUpdateCheckEnabled = true;
  bool _autoSoftwareUpdateCheckEnabled = true;
  bool _didAttemptAutoSourceUpdateCheck = false;
  bool _didAttemptAutoSoftwareUpdateCheck = false;

  int get homeRefreshTick => _homeRefreshTick;
  bool get allowDiscoverInitialLoad => _allowDiscoverInitialLoad;
  SourceBootstrapState get bootstrapState => _bootstrapState;

  void initialize() {
    unawaited(_loadAutoUpdateCheckSettings());
    unawaited(
      _sourceRuntimeCoordinator.initConnectivityWatcher(
        scheduleSourceRecovery: _scheduleSourceRecovery,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) {
        return;
      }
      unawaited(
        _sourceRuntimeCoordinator.bootstrapSourceRuntime(
          isMounted: _isMounted,
          onBootstrapStateChanged: _updateBootstrapState,
          onSourceReady: _handleSourceRuntimeReady,
          scheduleSourceUpdateDialogCheck: _scheduleAutomaticSourceUpdateCheck,
        ),
      );
    });
  }

  void refreshHome() {
    if (!_isMounted()) {
      return;
    }
    _homeRefreshTick++;
    notifyListeners();
  }

  Future<void> close() async {
    await _sourceRuntimeCoordinator.dispose();
  }

  void _scheduleSourceRecovery() {
    _sourceRuntimeCoordinator.scheduleSourceRecovery(
      isMounted: _isMounted,
      scheduleSourceUpdateDialogCheck: _scheduleAutomaticSourceUpdateCheck,
    );
  }

  Future<void> _loadAutoUpdateCheckSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceEnabled =
        prefs.getBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey) ?? true;
    final softwareEnabled =
        prefs.getBool(hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey) ??
        true;
    _autoSourceUpdateCheckEnabled = sourceEnabled;
    _autoSoftwareUpdateCheckEnabled = softwareEnabled;
    if (_isMounted()) {
      notifyListeners();
    }
  }

  void _scheduleAutomaticSourceUpdateCheck() {
    if (_didAttemptAutoSourceUpdateCheck || !_autoSourceUpdateCheckEnabled) {
      return;
    }
    _didAttemptAutoSourceUpdateCheck = true;
    _scheduleSourceUpdateDialogCheck();
  }

  void _scheduleAutomaticSoftwareUpdateCheck() {
    if (_didAttemptAutoSoftwareUpdateCheck ||
        !_autoSoftwareUpdateCheckEnabled) {
      return;
    }
    _didAttemptAutoSoftwareUpdateCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runSoftwareUpdateDialogCheckWhenIdle());
    });
  }

  Future<void> _runSoftwareUpdateDialogCheckWhenIdle() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!_isMounted()) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (!(navigator?.canPop() ?? false)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    if (!_isMounted()) {
      return;
    }

    await _softwareUpdateDialogSupport.showIfNeeded(
      navigatorKey: _navigatorKey,
      isMounted: _isMounted,
      skipPrefsKey: _softwareUpdateSkipDateKey,
    );
  }

  void _scheduleSourceUpdateDialogCheck() {
    _sourceRuntimeCoordinator.scheduleSourceUpdateDialogCheck(
      isMounted: _isMounted,
      showDialogIfNeeded: _showSourceUpdateDialogIfNeeded,
      onSourceDownloaded: _handleSourceUpdateDownloaded,
    );
  }

  Future<SourceUpdateDialogAction?> _showSourceUpdateDialogIfNeeded() {
    return _sourceUpdateDialogSupport.showIfNeeded(
      navigatorKey: _navigatorKey,
      isMounted: _isMounted,
      skipPrefsKey: _sourceUpdateSkipDateKey,
    );
  }

  void _handleSourceRuntimeReady() {
    if (!_isMounted()) {
      return;
    }
    _allowDiscoverInitialLoad = true;
    _homeRefreshTick++;
    notifyListeners();
    unawaited(_showWindowsAdaptationNoticeThenCheckSoftwareUpdate());
  }

  Future<void> _showWindowsAdaptationNoticeThenCheckSoftwareUpdate() async {
    await _windowsAdaptationNoticeDialogSupport.showIfNeeded(
      navigatorKey: _navigatorKey,
      isMounted: _isMounted,
    );
    if (!_isMounted()) {
      return;
    }
    _scheduleAutomaticSoftwareUpdateCheck();
  }

  void _handleSourceUpdateDownloaded() {
    refreshHome();
  }

  void _updateBootstrapState(SourceBootstrapState state) {
    if (!_isMounted()) {
      return;
    }
    if (state.showOverlay || state.showIntro) {
      _allowDiscoverInitialLoad = false;
    }
    _bootstrapState = state;
    notifyListeners();
  }
}
