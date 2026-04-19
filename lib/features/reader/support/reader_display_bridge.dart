import 'package:flutter/services.dart';

import 'package:hazuki/features/reader/state/reader_settings_store.dart';

typedef ReaderVolumeButtonPressed = Future<void> Function(String? direction);

class ReaderDisplayBridge {
  ReaderDisplayBridge({
    required ReaderVolumeButtonPressed onVolumeButtonPressed,
  }) : _onVolumeButtonPressed = onVolumeButtonPressed,
       sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  static const MethodChannel _readerDisplayChannel = MethodChannel(
    'hazuki.comics/reader_display',
  );
  static const ReaderDisplayController controller = ReaderDisplayController(
    _readerDisplayChannel,
  );
  static bool _methodHandlerRegistered = false;
  static ReaderDisplayBridge? _activeBridge;

  final ReaderVolumeButtonPressed _onVolumeButtonPressed;
  final String sessionId;

  void attach() {
    _activeBridge = this;
    if (_methodHandlerRegistered) {
      return;
    }
    _readerDisplayChannel.setMethodCallHandler(_handleMethodCall);
    _methodHandlerRegistered = true;
  }

  void detach() {
    if (identical(_activeBridge, this)) {
      _activeBridge = null;
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onVolumeButtonPressed') {
      return null;
    }
    final arguments = call.arguments;
    final direction = arguments is Map<Object?, Object?>
        ? arguments['direction'] as String?
        : null;
    final sessionId = arguments is Map<Object?, Object?>
        ? arguments['sessionId'] as String?
        : null;
    final activeBridge = _activeBridge;
    if (activeBridge == null || sessionId != activeBridge.sessionId) {
      return null;
    }
    await activeBridge._onVolumeButtonPressed(direction);
    return null;
  }
}
