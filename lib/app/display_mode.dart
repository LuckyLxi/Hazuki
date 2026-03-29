import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel hazukiDisplayModeChannel = MethodChannel(
  'hazuki.comics/display_mode',
);

Future<List<Map<String, dynamic>>> fetchHazukiDisplayModes() async {
  final list = await hazukiDisplayModeChannel.invokeMethod<List<dynamic>>(
    'getDisplayModes',
  );
  return (list ?? const <dynamic>[])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<bool> applyHazukiDisplayModeRaw(String raw) async {
  return await hazukiDisplayModeChannel.invokeMethod<bool>(
        'applyDisplayModeRaw',
        {'raw': raw},
      ) ??
      false;
}

Future<void> applyHazukiAutoDisplayMode() {
  return hazukiDisplayModeChannel.invokeMethod<void>('applyAutoDisplayMode');
}

Future<void> applyHazukiPreferredDisplayMode(String displayModeRaw) async {
  if (!Platform.isAndroid) {
    return;
  }
  try {
    final applied = await applyHazukiDisplayModeRaw(displayModeRaw);
    if (!applied) {
      await applyHazukiAutoDisplayMode();
    }
  } catch (_) {}
}
