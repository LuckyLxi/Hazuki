import 'package:flutter/material.dart';

import 'search_history_section.dart';
import 'search_id_extract_pill.dart';

class SearchEntryHistoryEditFab extends StatelessWidget {
  const SearchEntryHistoryEditFab({
    super.key,
    required this.editMode,
    required this.onPressed,
    required this.onLongPress,
  });

  final bool editMode;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: FloatingActionButton(
        onPressed: onPressed,
        child: Icon(editMode ? Icons.done : Icons.delete_outline),
      ),
    );
  }
}

class SearchEntryBody extends StatelessWidget {
  const SearchEntryBody({
    super.key,
    required this.scrollController,
    required this.historyList,
    required this.historyEditMode,
    required this.historyExpanded,
    required this.extractedComicId,
    required this.onKeywordPressed,
    required this.onKeywordLongPressed,
    required this.onKeywordDeleted,
    required this.onHistoryExpandedChanged,
    required this.onApplyExtractedComicId,
  });

  final ScrollController scrollController;
  final List<String> historyList;
  final bool historyEditMode;
  final bool historyExpanded;
  final String? extractedComicId;
  final ValueChanged<String> onKeywordPressed;
  final ValueChanged<String> onKeywordLongPressed;
  final ValueChanged<String> onKeywordDeleted;
  final ValueChanged<bool> onHistoryExpandedChanged;
  final VoidCallback onApplyExtractedComicId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            SearchHistorySection(
              historyList: historyList,
              historyEditMode: historyEditMode,
              historyExpanded: historyExpanded,
              onKeywordPressed: onKeywordPressed,
              onKeywordLongPressed: onKeywordLongPressed,
              onKeywordDeleted: onKeywordDeleted,
              onExpandedChanged: onHistoryExpandedChanged,
              onLayoutChanged: () {},
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: SearchIdExtractPill(
            extractedId: extractedComicId,
            onApply: onApplyExtractedComicId,
          ),
        ),
      ],
    );
  }
}
