import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'search_shared.dart';

class SearchHistorySection extends StatelessWidget {
  const SearchHistorySection({
    super.key,
    required this.historyList,
    required this.historyEditMode,
    required this.historyExpanded,
    required this.onKeywordPressed,
    required this.onKeywordDeleted,
    required this.onExpandedChanged,
    required this.onLayoutChanged,
  });

  final List<String> historyList;
  final bool historyEditMode;
  final bool historyExpanded;
  final ValueChanged<String> onKeywordPressed;
  final ValueChanged<String> onKeywordDeleted;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onLayoutChanged;

  @override
  Widget build(BuildContext context) {
    if (historyList.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsedCount = _computeCollapsedHistoryVisibleCount(
          constraints.maxWidth,
          context,
        );
        final isTooLong = collapsedCount < historyList.length;
        final displayList = (historyExpanded || !isTooLong)
            ? historyList
            : historyList.sublist(0, collapsedCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                AppLocalizations.of(context)!.searchHistoryTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              onEnd: onLayoutChanged,
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: searchHistoryChipSpacing,
                  runSpacing: 8,
                  children: displayList.map((keyword) {
                    if (historyEditMode) {
                      return InputChip(
                        label: Text(keyword),
                        deleteIcon: const Icon(Icons.cancel, size: 18),
                        onDeleted: () => onKeywordDeleted(keyword),
                        onPressed: () => onKeywordDeleted(keyword),
                      );
                    }
                    return ActionChip(
                      label: Text(keyword),
                      onPressed: () => onKeywordPressed(keyword),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (isTooLong)
              Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 8),
                child: IconButton(
                  icon: Icon(
                    historyExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () => onExpandedChanged(!historyExpanded),
                ),
              ),
          ],
        );
      },
    );
  }

  int _computeCollapsedHistoryVisibleCount(
    double maxWidth,
    BuildContext context,
  ) {
    if (historyList.isEmpty || maxWidth <= 0 || maxWidth.isInfinite) {
      return historyList.length;
    }

    var rowCount = 1;
    var rowWidth = 0.0;
    var visibleCount = 0;

    for (final keyword in historyList) {
      final chipWidth = math.min(
        maxWidth,
        _estimateHistoryChipWidth(keyword, context),
      );
      final nextWidth = rowWidth == 0
          ? chipWidth
          : rowWidth + searchHistoryChipSpacing + chipWidth;
      if (rowWidth > 0 && nextWidth > maxWidth) {
        rowCount += 1;
        if (rowCount > searchHistoryCollapsedMaxRows) {
          break;
        }
        rowWidth = chipWidth;
      } else {
        rowWidth = nextWidth;
      }
      visibleCount += 1;
    }

    return visibleCount.clamp(1, historyList.length);
  }

  double _estimateHistoryChipWidth(String keyword, BuildContext context) {
    final chipTheme = ChipTheme.of(context);
    final textStyle =
        chipTheme.labelStyle ??
        Theme.of(context).textTheme.labelLarge ??
        const TextStyle(fontSize: 14);
    final painter = TextPainter(
      text: TextSpan(text: keyword, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final horizontalExtra = historyEditMode ? 72.0 : 40.0;
    return painter.width + horizontalExtra;
  }
}
