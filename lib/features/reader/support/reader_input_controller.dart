import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/shared/reading/reader_mode.dart';

/// Input state is supplied by the host, so rules do not depend on global
/// keyboard state, the operating system, or a particular page widget.
class ReaderInputState {
  const ReaderInputState({
    required this.readerMode,
    required this.volumeButtonTurnPage,
    required this.isWindows,
    required this.isAltPressed,
    required this.isControlPressed,
    required this.activePointerCount,
  });

  final ReaderMode readerMode;
  final bool volumeButtonTurnPage;
  final bool isWindows;
  final bool isAltPressed;
  final bool isControlPressed;
  final int activePointerCount;

  bool get enableInteractiveScaling =>
      !isWindows || isAltPressed || activePointerCount > 1;
  bool get blockPageScrolling => isWindows && isAltPressed;
}

class ReaderInputController {
  ReaderInputController({
    required this.readState,
    required this.previousPage,
    required this.nextPage,
    required this.jumpToAdjacentChapter,
    required this.onScalingInputChanged,
  });

  final ReaderInputState Function() readState;
  final Future<void> Function(String trigger) previousPage;
  final Future<void> Function(String trigger) nextPage;
  final Future<void> Function(int direction) jumpToAdjacentChapter;
  final VoidCallback onScalingInputChanged;

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    final state = readState();
    final key = event.logicalKey;
    // Both pressing and releasing Alt must refresh the gesture configuration.
    if (state.isWindows &&
        (key == LogicalKeyboardKey.altLeft ||
            key == LogicalKeyboardKey.altRight)) {
      onScalingInputChanged();
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Chapter shortcuts take precedence over ordinary horizontal paging.
    if (state.isControlPressed) {
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        unawaited(
          jumpToAdjacentChapter(key == LogicalKeyboardKey.arrowLeft ? -1 : 1),
        );
        return KeyEventResult.handled;
      }
    }

    final vertical = state.readerMode == ReaderMode.topToBottom;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (vertical && key == LogicalKeyboardKey.arrowUp) {
        unawaited(previousPage('keyboard_arrow_up'));
      } else if (vertical && key == LogicalKeyboardKey.arrowDown) {
        unawaited(nextPage('keyboard_arrow_down'));
      } else if (!vertical && key == LogicalKeyboardKey.arrowLeft) {
        unawaited(previousPage('keyboard_arrow_left'));
      } else if (!vertical && key == LogicalKeyboardKey.arrowRight) {
        unawaited(nextPage('keyboard_arrow_right'));
      }
      // Keep the inactive axis from scrolling another focused widget.
      return KeyEventResult.handled;
    }

    if (state.volumeButtonTurnPage) {
      if (key == LogicalKeyboardKey.audioVolumeUp) {
        unawaited(previousPage('keyboard_volume_up'));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.audioVolumeDown) {
        unawaited(nextPage('keyboard_volume_down'));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
