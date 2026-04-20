import 'package:flutter/material.dart';

class ReaderTopControls extends StatelessWidget {
  const ReaderTopControls({
    super.key,
    required this.controlsVisible,
    required this.readerTheme,
    required this.title,
    required this.settingsTooltip,
    required this.onBackPressed,
    required this.onOpenSettingsDrawer,
  });

  final bool controlsVisible;
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: IgnorePointer(
          ignoring: !controlsVisible,
          child: AnimatedSlide(
            offset: controlsVisible ? Offset.zero : const Offset(0, -0.32),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: AnimatedScale(
              scale: controlsVisible ? 1.0 : 0.96,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.64),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onBackPressed,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
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
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
