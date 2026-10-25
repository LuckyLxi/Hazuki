import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'window_title_bar_control.dart';

const double hazukiWindowsCaptionButtonsWidth = 138;

bool _shouldUseCustomWindowsTitleBar(BuildContext context) {
  final titleBarController = HazukiWindowsTitleBarScope.maybeOf(context);
  return Theme.of(context).platform == TargetPlatform.windows &&
      titleBarController?.shouldShowCustomTitleBar == true;
}

/// Adds native window dragging behind an app bar's interactive toolbar.
///
/// Place this in [AppBar.flexibleSpace]. The toolbar is painted and hit-tested
/// above the flexible space, so buttons and fields keep their full hit area
/// while blank space can still move or maximize the window.
class HazukiWindowsAppBarDragArea extends StatelessWidget {
  const HazukiWindowsAppBarDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!_shouldUseCustomWindowsTitleBar(context)) {
      return child;
    }
    return DragToMoveArea(child: child);
  }
}

/// Keeps app bar actions clear of the overlaid Windows caption buttons.
class HazukiWindowsCaptionButtonSpacer extends StatelessWidget {
  const HazukiWindowsCaptionButtonSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_shouldUseCustomWindowsTitleBar(context)) {
      return const SizedBox.shrink();
    }
    return const SizedBox(width: hazukiWindowsCaptionButtonsWidth);
  }
}
