import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

class ComicDetailExpandableDescription extends StatefulWidget {
  const ComicDetailExpandableDescription({super.key, required this.text});
  final String text;

  @override
  State<ComicDetailExpandableDescription> createState() =>
      _ComicDetailExpandableDescriptionState();
}

class _ComicDetailExpandableDescriptionState
    extends State<ComicDetailExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = DefaultTextStyle.of(context).style;
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: 6,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              clipBehavior: Clip.hardEdge,
              child: SelectionArea(
                child: Text(
                  widget.text,
                  style: textStyle,
                  maxLines: _expanded ? null : (isOverflowing ? 6 : null),
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.clip,
                ),
              ),
            ),
            if (isOverflowing)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _expanded = !_expanded;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _expanded
                            ? l10n(context).comicDetailCollapse
                            : l10n(context).comicDetailExpand,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
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
          ],
        );
      },
    );
  }
}
