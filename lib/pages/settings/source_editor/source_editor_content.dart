import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'source_editor_controller.dart';

class SourceEditorContent extends StatelessWidget {
  const SourceEditorContent({
    super.key,
    required this.strings,
    required this.controller,
    required this.editorScrollController,
    required this.lineNumberScrollController,
    required this.saving,
    required this.inlineErrorText,
  });

  final AppLocalizations strings;
  final SourceCodeEditingController controller;
  final ScrollController editorScrollController;
  final ScrollController lineNumberScrollController;
  final bool saving;
  final String? inlineErrorText;

  double _measureEditorWidth(String longestLine, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: longestLine.isEmpty ? ' ' : longestLine,
        style: style,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width + 40;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final editorStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13.5,
          height: 1.5,
          letterSpacing: 0.1,
        ) ??
        const TextStyle(fontFamily: 'monospace', fontSize: 13.5, height: 1.5);
    final lineNumberStyle = editorStyle.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<SourceEditorMetrics>(
            valueListenable: controller.metrics,
            builder: (context, metrics, _) {
              return Row(
                children: [
                  const _SourceEditorFileBadge(fileBadge: 'jm.js'),
                  const Spacer(),
                  Text(
                    strings.sourceEditorLineCount(metrics.lineCount),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _SourceEditorNoticeCard(message: strings.sourceEditorHint),
          if (inlineErrorText != null) ...[
            const SizedBox(height: 12),
            _SourceEditorInlineErrorCard(message: inlineErrorText!),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.32,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.52),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ValueListenableBuilder<SourceEditorMetrics>(
                    valueListenable: controller.metrics,
                    builder: (context, metrics, _) {
                      final gutterWidth =
                          22 + (metrics.lineCount.toString().length * 10.0);
                      final editorWidth = math.max(
                        constraints.maxWidth - gutterWidth,
                        _measureEditorWidth(metrics.longestLine, editorStyle),
                      );
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: gutterWidth + editorWidth,
                            height: constraints.maxHeight,
                            child: Row(
                              children: [
                                Container(
                                  width: gutterWidth,
                                  height: constraints.maxHeight,
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    14,
                                    8,
                                    14,
                                  ),
                                  color: colorScheme.surfaceContainerHigh
                                      .withValues(alpha: 0.72),
                                  alignment: Alignment.topRight,
                                  child: SingleChildScrollView(
                                    controller: lineNumberScrollController,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: Text(
                                      metrics.lineNumberText,
                                      textAlign: TextAlign.right,
                                      style: lineNumberStyle,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: editorWidth,
                                  height: constraints.maxHeight,
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    6,
                                    0,
                                    6,
                                  ),
                                  child: Scrollbar(
                                    controller: editorScrollController,
                                    thumbVisibility: true,
                                    child: TextField(
                                      controller: controller,
                                      scrollController: editorScrollController,
                                      enabled: !saving,
                                      expands: true,
                                      minLines: null,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      style: editorStyle.copyWith(
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                      cursorColor: colorScheme.primary,
                                      decoration: const InputDecoration(
                                        isCollapsed: true,
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.fromLTRB(
                                          14,
                                          8,
                                          18,
                                          8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceEditorNoticeCard extends StatelessWidget {
  const _SourceEditorNoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceEditorInlineErrorCard extends StatelessWidget {
  const _SourceEditorInlineErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceEditorFileBadge extends StatelessWidget {
  const _SourceEditorFileBadge({required this.fileBadge});

  final String fileBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.javascript_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            fileBadge,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
