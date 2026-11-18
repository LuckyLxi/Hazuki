import 'package:flutter/widgets.dart';

import '../l10n/l10n.dart';
import '../models/default_chapter_title.dart';

export '../models/default_chapter_title.dart';

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
