import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/view/reader_control_surface.dart';
import 'package:hazuki/features/reader/view/reader_overlay_layout.dart';

class ReaderTopControls extends StatelessWidget {
  const ReaderTopControls({
    super.key,
    required this.readerTheme,
    required this.title,
    required this.settingsTooltip,
    required this.onBackPressed,
    required this.onOpenSettingsDrawer,
  });

  final ThemeData readerTheme;
  final String title;
  final String settingsTooltip;
  final VoidCallback onBackPressed;
  final VoidCallback onOpenSettingsDrawer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReaderOverlayLayout.edgePadding,
          ReaderOverlayLayout.topControlsTopPadding,
          ReaderOverlayLayout.edgePadding,
          0,
        ),
        child: ReaderControlSurface(
          borderRadius: 24,
          fallbackColor: Colors.black.withValues(alpha: 0.64),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              IconButton(
                onPressed: onBackPressed,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: readerTheme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: settingsTooltip,
                onPressed: onOpenSettingsDrawer,
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
