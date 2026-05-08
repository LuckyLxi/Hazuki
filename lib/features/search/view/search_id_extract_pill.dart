import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';

class SearchIdExtractPill extends StatelessWidget {
  const SearchIdExtractPill({
    super.key,
    required this.extractedId,
    required this.onApply,
  });

  final String? extractedId;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final visible = extractedId != null;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        // 出现时从下方弹入，消失时原地缩小淡出（不再向下滑出）
        offset: visible ? Offset.zero : const Offset(0, 0.3),
        duration: Duration(milliseconds: visible ? 300 : 200),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.82,
          duration: Duration(milliseconds: visible ? 300 : 180),
          curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: Duration(milliseconds: visible ? 220 : 160),
            curve: visible ? Curves.easeOutCubic : Curves.easeInCubic,
            child: _PillContent(
              extractedId: extractedId ?? '',
              onApply: onApply,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillContent extends StatelessWidget {
  const _PillContent({required this.extractedId, required this.onApply});

  final String extractedId;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onApply,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      strings.searchIdExtractHint(extractedId),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
