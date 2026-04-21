import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import 'source_editor_search_support.dart';

class SourceSearchHighlightCodeLineController
    extends CodeLineEditingControllerDelegate {
  SourceSearchHighlightCodeLineController({
    required super.delegate,
    required this.highlightGetter,
    required this.highlightOpacityGetter,
  });

  final SourceSearchHighlight? Function() highlightGetter;
  final double Function() highlightOpacityGetter;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final highlightedSpan = super.buildTextSpan(
      context: context,
      index: index,
      textSpan: textSpan,
      style: style,
    );
    final highlight = highlightGetter();
    if (highlight == null || highlight.lineIndex != index) {
      return highlightedSpan;
    }
    final opacity = highlightOpacityGetter();
    if (opacity <= 0) {
      return highlightedSpan;
    }
    final colorScheme = Theme.of(context).colorScheme;
    final lineHighlightColor = colorScheme.tertiaryContainer.withValues(
      alpha: 0.22 * opacity,
    );
    final keywordHighlightColor = colorScheme.primary.withValues(
      alpha: 0.28 * opacity,
    );
    return _applyBackgroundHighlight(
      highlightedSpan,
      startOffset: highlight.startOffset,
      endOffset: highlight.endOffset,
      lineHighlightColor: lineHighlightColor,
      keywordHighlightColor: keywordHighlightColor,
    );
  }

  TextSpan _applyBackgroundHighlight(
    TextSpan textSpan, {
    required int startOffset,
    required int endOffset,
    required Color lineHighlightColor,
    required Color keywordHighlightColor,
  }) {
    final segments = <_StyledTextSegment>[];
    _collectTextSegments(textSpan, textSpan.style, segments);
    if (segments.isEmpty || startOffset >= endOffset) {
      return textSpan;
    }

    final rebuiltChildren = <InlineSpan>[];
    var cursor = 0;
    for (final segment in segments) {
      final segmentStart = cursor;
      final segmentEnd = cursor + segment.text.length;
      cursor = segmentEnd;

      if (segmentEnd <= startOffset || segmentStart >= endOffset) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text,
            style: _withBackgroundColor(segment.style, lineHighlightColor),
          ),
        );
        continue;
      }

      final localStart = (startOffset - segmentStart).clamp(
        0,
        segment.text.length,
      );
      final localEnd = (endOffset - segmentStart).clamp(0, segment.text.length);

      if (localStart > 0) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text.substring(0, localStart),
            style: _withBackgroundColor(segment.style, lineHighlightColor),
          ),
        );
      }

      if (localEnd > localStart) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text.substring(localStart, localEnd),
            style: _withBackgroundColor(segment.style, keywordHighlightColor),
          ),
        );
      }

      if (localEnd < segment.text.length) {
        rebuiltChildren.add(
          TextSpan(
            text: segment.text.substring(localEnd),
            style: _withBackgroundColor(segment.style, lineHighlightColor),
          ),
        );
      }
    }

    return TextSpan(style: textSpan.style, children: rebuiltChildren);
  }

  TextStyle _withBackgroundColor(TextStyle? style, Color backgroundColor) {
    return (style ?? const TextStyle()).copyWith(
      backgroundColor: backgroundColor,
    );
  }

  void _collectTextSegments(
    InlineSpan span,
    TextStyle? inheritedStyle,
    List<_StyledTextSegment> segments,
  ) {
    if (span is! TextSpan) {
      return;
    }
    final effectiveStyle = inheritedStyle?.merge(span.style) ?? span.style;
    final text = span.text;
    if (text != null && text.isNotEmpty) {
      segments.add(_StyledTextSegment(text: text, style: effectiveStyle));
    }
    final children = span.children;
    if (children == null || children.isEmpty) {
      return;
    }
    for (final child in children) {
      _collectTextSegments(child, effectiveStyle, segments);
    }
  }
}

class SourceEditorToolbarController implements SelectionToolbarController {
  const SourceEditorToolbarController();

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    final localizations = MaterialLocalizations.of(context);
    final items = <PopupMenuEntry<void>>[
      if (!controller.selection.isCollapsed)
        PopupMenuItem<void>(
          onTap: controller.cut,
          child: Text(localizations.cutButtonLabel),
        ),
      if (!controller.selection.isCollapsed)
        PopupMenuItem<void>(
          onTap: controller.copy,
          child: Text(localizations.copyButtonLabel),
        ),
      PopupMenuItem<void>(
        onTap: controller.paste,
        child: Text(localizations.pasteButtonLabel),
      ),
      PopupMenuItem<void>(
        onTap: controller.selectAll,
        child: Text(localizations.selectAllButtonLabel),
      ),
    ];

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        anchors.primaryAnchor.dx,
        anchors.primaryAnchor.dy,
        MediaQuery.sizeOf(context).width - anchors.primaryAnchor.dx,
        MediaQuery.sizeOf(context).height - anchors.primaryAnchor.dy,
      ),
      items: items,
    );
  }
}

class SourceEditorInlineErrorCard extends StatelessWidget {
  const SourceEditorInlineErrorCard({super.key, required this.message});

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

class SourceEditorFileBadge extends StatelessWidget {
  const SourceEditorFileBadge({super.key, required this.fileBadge});

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

class _StyledTextSegment {
  const _StyledTextSegment({required this.text, required this.style});

  final String text;
  final TextStyle? style;
}
