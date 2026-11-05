import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_entry_restore_state.dart';

void main() {
  int? target(
    ReaderEntryRestoreState state, {
    int imageCount = 8,
    int spreadSize = 1,
  }) => state.takeTarget(
    epId: 'chapter',
    imageCount: imageCount,
    spreadSize: spreadSize,
  );

  for (final settingsFirst in [true, false]) {
    test(
      'waits for settings and position in either order ($settingsFirst)',
      () {
        final state = ReaderEntryRestoreState();
        const position = {'epId': 'chapter', 'imagePage': 5, 'pageIndex': 1};
        if (settingsFirst) {
          state.settingsReady = true;
        } else {
          state.resolvePosition(position);
        }
        expect(target(state), isNull);
        expect(state.started, isFalse);
        state
          ..settingsReady = true
          ..resolvePosition(position);
        expect(target(state), isNull);
        state.restorePagePosition = true;
        expect(target(state, imageCount: 0), isNull);
        expect(state.canReportVisibleRange(0, 0), isFalse);
        expect(target(state, spreadSize: 2), 4);
        expect(target(state), isNull);
        expect(state.canReportVisibleRange(0, 1), isFalse);
        expect(state.canReportVisibleRange(4, 5), isTrue);
        expect(state.canReportVisibleRange(6, 7), isTrue);
      },
    );
  }

  test(
    'disabled restore and a different chapter allow immediate reporting',
    () {
      for (final (enabled, chapter) in [(false, 'chapter'), (true, 'other')]) {
        final state = ReaderEntryRestoreState()
          ..settingsReady = true
          ..restorePagePosition = enabled
          ..resolvePosition({'epId': chapter, 'imagePage': 5});
        expect(target(state), isNull);
        expect(state.started, isTrue);
        expect(state.canReportVisibleRange(0, 0), isTrue);
      }
    },
  );

  test('converts legacy spread indices and bounds saved image pages', () {
    for (final (spread, fields, expected) in [
      (1, {'pageIndex': 2}, 2),
      (2, {'pageIndex': 2}, 4),
      (2, {'pageIndex': 99}, 7),
      (1, {'imagePage': 0}, 0),
      (1, {'imagePage': 99}, 7),
    ]) {
      final state = ReaderEntryRestoreState()
        ..settingsReady = true
        ..restorePagePosition = true
        ..resolvePosition({'epId': 'chapter', ...fields});
      expect(target(state, spreadSize: spread), expected);
    }
  });

  test('user navigation cancels pending and in-flight restores', () {
    for (final alreadyRestoring in [true, false]) {
      final state = ReaderEntryRestoreState()
        ..settingsReady = true
        ..restorePagePosition = true;
      const position = {'epId': 'chapter', 'imagePage': 5};
      if (alreadyRestoring) {
        state.resolvePosition(position);
        expect(target(state), 4);
        expect(state.canReportVisibleRange(0, 0), isFalse);
      }
      state.cancel();
      state.resolvePosition(position);
      expect(target(state), isNull);
      expect(state.canReportVisibleRange(0, 0), isTrue);
    }
  });
}
