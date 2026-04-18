import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    return Material(
      color: colorScheme.surface,
      child: Container(
        height: kWindowCaptionHeight,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _toggleMaximize,
                child: DragToMoveArea(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      end: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'H',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
      ),
    );
  }
}
