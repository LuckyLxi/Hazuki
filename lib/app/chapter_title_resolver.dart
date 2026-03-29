import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';

const hazukiDefaultChapterTitleToken = '__default_chapter_1__';

bool isHazukiDefaultChapterTitle(String rawTitle) {
  return rawTitle.trim() == hazukiDefaultChapterTitleToken;
}

String resolveHazukiChapterTitle(BuildContext context, String rawTitle) {
  final normalized = rawTitle.trim();
  if (normalized.isEmpty) {
    return '';
  }
  if (isHazukiDefaultChapterTitle(normalized)) {
    return l10n(context).comicDetailDefaultChapterTitle;
  }
  return rawTitle;
}
