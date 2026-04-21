import 'package:flutter/material.dart';
import 'package:hazuki/features/comments/support/comments_content_support.dart';
import 'package:hazuki/l10n/l10n.dart';

class CommentsSelectableContent extends StatelessWidget {
  const CommentsSelectableContent({
    super.key,
    required this.content,
    required this.style,
    required this.expansionKey,
  });

  final String content;
  final TextStyle? style;
  final String expansionKey;

  @override
  Widget build(BuildContext context) {
    return _ExpandableCommentContent(
      key: ValueKey<String>(expansionKey),
      spans: buildCommentContentSpans(context, content, style),
      plainText: commentPreviewText(content),
      style: style,
    );
  }
}

class _ExpandableCommentContent extends StatefulWidget {
  const _ExpandableCommentContent({
    super.key,
    required this.spans,
    required this.plainText,
    required this.style,
  });

  static const int collapsedMaxLines = 4;

  final List<InlineSpan> spans;
  final String plainText;
  final TextStyle? style;

  @override
  State<_ExpandableCommentContent> createState() =>
      _ExpandableCommentContentState();
}

class _ExpandableCommentContentState extends State<_ExpandableCommentContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.plainText, style: textStyle),
          maxLines: _ExpandableCommentContent.collapsedMaxLines,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.hardEdge,
              child: SelectionArea(
                child: Builder(
                  builder: (context) {
                    final selectionColor =
                        theme.textSelectionTheme.selectionColor ??
                        theme.colorScheme.primary.withAlpha(56);
                    return RichText(
                      text: TextSpan(style: textStyle, children: widget.spans),
                      maxLines: _expanded || !isOverflowing
                          ? null
                          : _ExpandableCommentContent.collapsedMaxLines,
                      overflow: TextOverflow.clip,
                      selectionRegistrar: SelectionContainer.maybeOf(context),
                      selectionColor: selectionColor,
                    );
                  },
                ),
              ),
            ),
            if (isOverflowing)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded
                                ? l10n(context).comicDetailCollapse
                                : l10n(context).comicDetailExpand,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            turns: _expanded ? 0.5 : 0,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
