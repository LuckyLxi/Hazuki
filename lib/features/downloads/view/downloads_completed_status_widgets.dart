import 'package:flutter/material.dart';

class DownloadedComicIntegrityWarningBanner extends StatelessWidget {
  const DownloadedComicIntegrityWarningBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: const Color(0xFFB71C1C),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadedComicSelectionSlot extends StatelessWidget {
  const DownloadedComicSelectionSlot({
    super.key,
    required this.visible,
    required this.selected,
  });

  final bool visible;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.45, 0),
                end: Offset.zero,
              ).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.78, end: 1).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: visible
            ? Padding(
                key: const ValueKey<String>(
                  'downloaded_selection_indicator_visible',
                ),
                padding: const EdgeInsets.only(left: 8),
                child: DownloadedComicSelectionIndicator(selected: selected),
              )
            : const SizedBox.shrink(
                key: ValueKey<String>('downloaded_selection_indicator_hidden'),
              ),
      ),
    );
  }
}

class DownloadedComicSelectionIndicator extends StatelessWidget {
  const DownloadedComicSelectionIndicator({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 42,
      height: 42,
      child: Center(
        child: AnimatedContainer(
          key: const ValueKey<String>('downloaded_selection_indicator'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outline,
              width: selected ? 1 : 1.6,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey<String>('downloaded_selection_check'),
                    size: 19,
                    color: colorScheme.onPrimary,
                  )
                : const SizedBox.shrink(
                    key: ValueKey<String>('downloaded_selection_empty'),
                  ),
          ),
        ),
      ),
    );
  }
}
