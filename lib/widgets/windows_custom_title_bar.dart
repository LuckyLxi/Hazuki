import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

const double hazukiWindowsCaptionButtonsWidth = 138;

class HazukiWindowsCustomTitleBar extends StatefulWidget {
  const HazukiWindowsCustomTitleBar({super.key, this.title = 'Hazuki'});

  final String title;

  @override
  State<HazukiWindowsCustomTitleBar> createState() =>
      _HazukiWindowsCustomTitleBarState();
}

class _HazukiWindowsCustomTitleBarState
    extends State<HazukiWindowsCustomTitleBar>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    if (!mounted) {
      return;
    }
    setState(() {
      _isMaximized = isMaximized;
    });
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    await _syncWindowState();
  }

  @override
  void onWindowMaximize() {
    _syncWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _syncWindowState();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: hazukiWindowsCaptionButtonsWidth,
      height: kWindowCaptionHeight,
      child: Row(
        children: [
          WindowCaptionButton.minimize(
            brightness: brightness,
            onPressed: () {
              windowManager.minimize();
            },
          ),
          _isMaximized
              ? WindowCaptionButton.unmaximize(
                  brightness: brightness,
                  onPressed: () {
                    _toggleMaximize();
                  },
                )
              : WindowCaptionButton.maximize(
                  brightness: brightness,
                  onPressed: () {
                    _toggleMaximize();
                  },
                ),
          WindowCaptionButton.close(
            brightness: brightness,
            onPressed: () {
              windowManager.close();
            },
          ),
        ],
      ),
    );
  }
}
