import 'dart:async';

import 'package:flutter/material.dart';

import 'launch_shortcut_bridge.dart';

typedef HazukiLaunchShortcutActionHandler =
    Future<void> Function(HazukiLaunchShortcutAction action);

class HazukiLaunchShortcutCoordinator {
  HazukiLaunchShortcutCoordinator({
    required GlobalKey<NavigatorState> navigatorKey,
    required HazukiLaunchShortcutActionSource actionSource,
    required bool Function() isMounted,
    required HazukiLaunchShortcutActionHandler handleAction,
  }) : _navigatorKey = navigatorKey,
       _actionSource = actionSource,
       _isMounted = isMounted,
       _handleAction = handleAction;

  final GlobalKey<NavigatorState> _navigatorKey;
  final HazukiLaunchShortcutActionSource _actionSource;
  final bool Function() _isMounted;
  final HazukiLaunchShortcutActionHandler _handleAction;

  StreamSubscription<HazukiLaunchShortcutAction>? _subscription;
  bool _initialized = false;
  bool _actionInProgress = false;
  bool _disposed = false;

  void initialize() {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;
    _subscription = _actionSource.actions.listen((action) {
      unawaited(_dispatchAction(action));
    }, onError: (_, _) {});
    unawaited(_consumeInitialAction());
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  Future<void> _consumeInitialAction() async {
    final HazukiLaunchShortcutAction? action;
    try {
      action = await _actionSource.getInitialAction();
    } catch (_) {
      return;
    }
    if (action == null || _disposed || !_isMounted()) {
      return;
    }
    await _dispatchAction(action);
  }

  Future<void> _dispatchAction(HazukiLaunchShortcutAction action) async {
    if (_disposed ||
        action != HazukiLaunchShortcutAction.search ||
        _actionInProgress) {
      return;
    }
    _actionInProgress = true;
    try {
      await _waitForNavigatorReady();
      if (_disposed || !_isMounted()) {
        return;
      }
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        return;
      }
      try {
        await _handleAction(action);
      } catch (_) {}
    } finally {
      _actionInProgress = false;
    }
  }

  Future<void> _waitForNavigatorReady() async {
    for (var i = 0; i < 24; i++) {
      if (_disposed || !_isMounted()) {
        return;
      }
      if (_navigatorKey.currentState != null) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
