import 'dart:async';

import 'package:flutter/services.dart';

enum HazukiLaunchShortcutAction { search }

class HazukiLaunchShortcutBridge {
  const HazukiLaunchShortcutBridge();

  static const MethodChannel _methodChannel = MethodChannel(
    'hazuki.comics/launch_shortcut',
  );
  static const EventChannel _eventChannel = EventChannel(
    'hazuki.comics/launch_shortcut_events',
  );

  Stream<HazukiLaunchShortcutAction> get actions => _eventChannel
      .receiveBroadcastStream()
      .map((dynamic value) => _parseAction(value))
      .where((action) => action != null)
      .cast<HazukiLaunchShortcutAction>();

  Future<HazukiLaunchShortcutAction?> getInitialAction() async {
    final value = await _methodChannel.invokeMethod<Object?>(
      'getInitialLaunchAction',
    );
    return _parseAction(value);
  }

  HazukiLaunchShortcutAction? _parseAction(Object? value) {
    return switch (value) {
      'search' => HazukiLaunchShortcutAction.search,
      _ => null,
    };
  }
}
