import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_input_controller.dart';
import 'package:hazuki/shared/reading/reader_mode.dart';

void main() {
  ReaderInputState state({
    ReaderMode mode = ReaderMode.rightToLeft,
    bool windows = true,
    bool control = false,
    bool alt = false,
    bool volume = false,
    int pointers = 0,
  }) => ReaderInputState(
    readerMode: mode,
    isWindows: windows,
    isControlPressed: control,
    isAltPressed: alt,
    volumeButtonTurnPage: volume,
    activePointerCount: pointers,
  );

  late ReaderInputState current;
  late ReaderInputController controller;
  late FocusNode focus;
  late List<String> calls;

  setUp(() {
    current = state();
    calls = [];
    focus = FocusNode();
    controller = ReaderInputController(
      readState: () => current,
      previousPage: (trigger) async => calls.add('previous:$trigger'),
      nextPage: (trigger) async => calls.add('next:$trigger'),
      jumpToAdjacentChapter: (direction) async =>
          calls.add('chapter:$direction'),
      onScalingInputChanged: () => calls.add('scaling'),
    );
  });
  tearDown(() => focus.dispose());

  KeyEventResult press(
    LogicalKeyboardKey key, {
    bool repeat = false,
    bool up = false,
  }) {
    final KeyEvent event = up
        ? KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: key,
            timeStamp: Duration.zero,
          )
        : repeat
        ? KeyRepeatEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: key,
            timeStamp: Duration.zero,
          )
        : KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: key,
            timeStamp: Duration.zero,
          );
    return controller.handleKeyEvent(focus, event);
  }

  test('Ctrl takes precedence over page turns on both platforms and modes', () {
    for (final windows in [true, false]) {
      for (final mode in ReaderMode.values) {
        current = state(windows: windows, mode: mode, control: true);
        calls.clear();
        expect(press(LogicalKeyboardKey.arrowLeft), KeyEventResult.handled);
        expect(
          press(LogicalKeyboardKey.arrowRight, repeat: true),
          KeyEventResult.handled,
        );
        expect(
          press(LogicalKeyboardKey.arrowRight, up: true),
          KeyEventResult.ignored,
        );
        expect(calls, ['chapter:-1', 'chapter:1']);
      }
    }
  });

  test(
    'paging preserves direction, repeat handling and inactive axis consumption',
    () {
      press(LogicalKeyboardKey.arrowLeft);
      press(LogicalKeyboardKey.arrowRight, repeat: true);
      expect(press(LogicalKeyboardKey.arrowDown), KeyEventResult.handled);
      expect(calls, [
        'previous:keyboard_arrow_left',
        'next:keyboard_arrow_right',
      ]);
      calls.clear();
      current = state(mode: ReaderMode.topToBottom, control: true);
      press(LogicalKeyboardKey.arrowUp);
      press(LogicalKeyboardKey.arrowDown, repeat: true);
      expect(calls, ['previous:keyboard_arrow_up', 'next:keyboard_arrow_down']);
      calls.clear();
      current = state(mode: ReaderMode.topToBottom);
      expect(press(LogicalKeyboardKey.arrowLeft), KeyEventResult.handled);
      expect(press(LogicalKeyboardKey.arrowRight), KeyEventResult.handled);
      expect(calls, isEmpty);
    },
  );

  test(
    'volume setting gates volume keys, not arrows; releases and unknown keys are ignored',
    () {
      expect(press(LogicalKeyboardKey.audioVolumeUp), KeyEventResult.ignored);
      current = state(volume: true);
      press(LogicalKeyboardKey.audioVolumeUp);
      press(LogicalKeyboardKey.audioVolumeDown, repeat: true);
      expect(
        press(LogicalKeyboardKey.audioVolumeDown, up: true),
        KeyEventResult.ignored,
      );
      expect(press(LogicalKeyboardKey.keyA), KeyEventResult.ignored);
      expect(calls, [
        'previous:keyboard_volume_up',
        'next:keyboard_volume_down',
      ]);
    },
  );

  test(
    'both Alt keys refresh scaling on press and release only on Windows',
    () {
      for (final key in [
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.altRight,
      ]) {
        expect(press(key), KeyEventResult.handled);
        expect(press(key, up: true), KeyEventResult.handled);
      }
      expect(calls, ['scaling', 'scaling', 'scaling', 'scaling']);
      calls.clear();
      current = state(windows: false);
      expect(press(LogicalKeyboardKey.altLeft), KeyEventResult.ignored);
      expect(
        press(LogicalKeyboardKey.altLeft, up: true),
        KeyEventResult.ignored,
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'scaling and scrolling depend on platform, Alt and multiple pointers',
    () {
      for (final windows in [true, false]) {
        for (final alt in [true, false]) {
          for (final pointers in [0, 1, 2]) {
            final input = state(windows: windows, alt: alt, pointers: pointers);
            if (!windows) {
              expect(input.enableInteractiveScaling, isTrue);
              expect(input.blockPageScrolling, isFalse);
            } else if (alt) {
              expect(input.enableInteractiveScaling, isTrue);
              expect(input.blockPageScrolling, isTrue);
            } else {
              expect(input.enableInteractiveScaling, pointers == 2);
              expect(input.blockPageScrolling, isFalse);
            }
          }
        }
      }
    },
  );
}
