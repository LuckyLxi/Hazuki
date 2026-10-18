import 'package:flutter/material.dart';
import 'package:hazuki/models/comic_detail_models.dart';

import 'hazuki_frosted_menu.dart';
import 'hazuki_frosted_menu_button.dart';

class ChapterGroupPicker extends StatelessWidget {
  const ChapterGroupPicker({
    super.key,
    required this.details,
    required this.onSelected,
    this.selectedGroupId,
    this.initialChapterId,
  });
  final ComicDetailsData details;
  final ValueChanged<String> onSelected;
  final String? selectedGroupId;
  final String? initialChapterId;

  @override
  Widget build(BuildContext context) {
    final group =
        details.chapterGroups
            .where((g) => g.id == selectedGroupId)
            .firstOrNull ??
        details.groupForChapter(initialChapterId ?? '') ??
        details.chapterGroups.first;
    return HazukiFrostedDropdown<String>(
      selected: group.id,
      options: [
        for (final item in details.chapterGroups)
          HazukiFrostedMenuOption(value: item.id, label: item.title),
      ],
      onSelected: onSelected,
    );
  }
}
