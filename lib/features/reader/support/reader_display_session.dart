import 'package:hazuki/shared/reading/reader_settings_store.dart';

/// Serializes display effects and restores them after the reader closes.
class ReaderDisplaySession {
  ReaderDisplaySession({
    required ReaderDisplayController controller,
    required String sessionId,
    required ReaderSettingsSnapshot Function() readSettings,
  }) : _controller = controller,
       _sessionId = sessionId,
       _readSettings = readSettings;

  final ReaderDisplayController _controller;
  final String _sessionId;
  final ReaderSettingsSnapshot Function() _readSettings;
  Future<void> _operation = Future<void>.value();
  bool _closed = false;

  Future<void> apply() => _enqueue(() {
    // Read when execution starts, as settings may change while queued.
    final settings = _readSettings();
    return _controller.apply(
      immersiveMode: settings.immersiveMode,
      keepScreenOn: settings.keepScreenOn,
      customBrightness: settings.customBrightness,
      brightnessValue: settings.brightnessValue,
    );
  });

  Future<void> syncVolumeButtonPaging({bool? enabled}) {
    if (_closed) return Future<void>.value();
    return _controller.syncVolumeButtonPaging(
      enabled: enabled ?? _readSettings().volumeButtonTurnPage,
      sessionId: _sessionId,
    );
  }

  void close() {
    _closed = true;
  }

  Future<void> restore() => _enqueue(
    () => _controller.restore(sessionId: _sessionId),
    allowAfterClosed: true,
  );

  Future<void> _enqueue(
    Future<void> Function() operation, {
    bool allowAfterClosed = false,
  }) {
    final previous = _operation;
    final next = () async {
      try {
        await previous;
      } catch (_) {
        // A failed effect must not prevent subsequent restoration.
      }
      if (_closed && !allowAfterClosed) return;
      await operation();
    }();
    _operation = next;
    return next;
  }
}
