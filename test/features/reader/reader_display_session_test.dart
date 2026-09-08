import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';

class _Settings extends Mock implements ReaderSettingsSnapshot {}

class _Display extends ReaderDisplayController {
  _Display() : super(const MethodChannel('test/reader-display'));

  final calls = <String>[];
  final applied = <(bool, bool, bool, double)>[];
  Completer<void>? pending;
  bool failNext = false;

  @override
  Future<void> apply({
    required bool immersiveMode,
    required bool keepScreenOn,
    required bool customBrightness,
    required double brightnessValue,
  }) async {
    calls.add('apply');
    applied.add((
      immersiveMode,
      keepScreenOn,
      customBrightness,
      brightnessValue,
    ));
    if (failNext) {
      failNext = false;
      throw StateError('display failed');
    }
    await pending?.future;
  }

  @override
  Future<void> restore({required String sessionId}) async {
    calls.add('restore:$sessionId');
  }

  @override
  Future<void> syncVolumeButtonPaging({
    required bool enabled,
    required String sessionId,
  }) async {
    calls.add('volume:$sessionId:$enabled');
  }
}

void main() {
  late _Settings settings;
  late _Display display;
  late ReaderDisplaySession session;
  setUp(() {
    settings = _Settings();
    when(() => settings.immersiveMode).thenReturn(true);
    when(() => settings.keepScreenOn).thenReturn(false);
    when(() => settings.customBrightness).thenReturn(true);
    when(() => settings.brightnessValue).thenReturn(0.4);
    when(() => settings.volumeButtonTurnPage).thenReturn(true);
    display = _Display();
    session = ReaderDisplaySession(
      controller: display,
      sessionId: 'reader-1',
      readSettings: () => settings,
    );
  });

  test(
    'serializes display effects and reads settings when execution starts',
    () async {
      final pending = Completer<void>();
      display.pending = pending;
      final first = session.apply();
      await Future<void>.delayed(Duration.zero);
      final second = session.apply();
      expect(display.applied, [(true, false, true, 0.4)]);
      when(() => settings.brightnessValue).thenReturn(0.8);
      display.pending = null;
      pending.complete();
      await Future.wait([first, second]);
      expect(display.applied, [
        (true, false, true, 0.4),
        (true, false, true, 0.8),
      ]);
    },
  );

  test(
    'close skips queued settings but waits for active effect before restore',
    () async {
      final pending = Completer<void>();
      display.pending = pending;
      final active = session.apply();
      await Future<void>.delayed(Duration.zero);
      final queued = session.apply();
      session.close();
      final restored = session.restore();
      expect(display.calls, ['apply']);
      pending.complete();
      await Future.wait([active, queued, restored]);
      expect(display.calls, ['apply', 'restore:reader-1']);
      await session.apply();
      await session.syncVolumeButtonPaging(enabled: true);
      expect(display.calls, ['apply', 'restore:reader-1']);
    },
  );

  test('a failed effect is reported but does not block restore', () async {
    display.failNext = true;
    final applied = session.apply();
    final failure = expectLater(applied, throwsStateError);
    final restored = session.restore();
    await failure;
    await restored;
    expect(display.calls, ['apply', 'restore:reader-1']);
  });

  test(
    'volume paging keeps session identity and supports explicit overrides',
    () async {
      await session.syncVolumeButtonPaging();
      await session.syncVolumeButtonPaging(enabled: false);
      expect(display.calls, ['volume:reader-1:true', 'volume:reader-1:false']);
    },
  );

  test('volume synchronization does not wait for the display queue', () async {
    final pending = Completer<void>();
    display.pending = pending;
    final applied = session.apply();
    await Future<void>.delayed(Duration.zero);
    await session.syncVolumeButtonPaging();
    expect(display.calls, ['apply', 'volume:reader-1:true']);
    pending.complete();
    await applied;
  });
}
