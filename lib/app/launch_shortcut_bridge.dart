import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum HazukiLaunchShortcutAction { search }

abstract class HazukiLaunchShortcutActionSource {
  Stream<HazukiLaunchShortcutAction> get actions;

  Future<HazukiLaunchShortcutAction?> getInitialAction();
}

final class HazukiLaunchShortcutProtocol {
  const HazukiLaunchShortcutProtocol._();

  static const methodChannelName = 'hazuki.comics/launch_shortcut';
  static const eventChannelName = 'hazuki.comics/launch_shortcut_events';
  static const getInitialLaunchActionMethod = 'getInitialLaunchAction';
  static const searchAction = 'search';
}

class HazukiLaunchShortcutBridge implements HazukiLaunchShortcutActionSource {
  HazukiLaunchShortcutBridge({@visibleForTesting bool? supportsLaunchShortcuts})
    : _supportsLaunchShortcuts = supportsLaunchShortcuts ?? Platform.isAndroid;

  static const MethodChannel _methodChannel = MethodChannel(
    HazukiLaunchShortcutProtocol.methodChannelName,
  );
  static const EventChannel _eventChannel = EventChannel(
    HazukiLaunchShortcutProtocol.eventChannelName,
  );

  final bool _supportsLaunchShortcuts;

  @override
  Stream<HazukiLaunchShortcutAction> get actions => _eventChannel
      .receiveBroadcastStream()
      .handleError((_) {})
      .map((dynamic value) => _parseAction(value))
      .where((action) => action != null)
      .cast<HazukiLaunchShortcutAction>()
      .takeIfSupported(_supportsLaunchShortcuts);

  @override
  Future<HazukiLaunchShortcutAction?> getInitialAction() async {
    if (!_supportsLaunchShortcuts) {
      return null;
    }
    try {
      final value = await _methodChannel.invokeMethod<Object?>(
        HazukiLaunchShortcutProtocol.getInitialLaunchActionMethod,
      );
      return _parseAction(value);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  HazukiLaunchShortcutAction? _parseAction(Object? value) {
    return switch (value) {
      HazukiLaunchShortcutProtocol.searchAction =>
        HazukiLaunchShortcutAction.search,
      _ => null,
    };
  }
}

extension on Stream<HazukiLaunchShortcutAction> {
  Stream<HazukiLaunchShortcutAction> takeIfSupported(bool supported) {
    return supported ? this : const Stream<HazukiLaunchShortcutAction>.empty();
  }
}
