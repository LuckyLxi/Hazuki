import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';

typedef ComicDetailCoverPreviewPageBuilder =
    Widget Function({
      required String imageUrl,
      required String heroTag,
      required VoidCallback onLongPress,
    });

typedef ComicDetailChaptersPanelBuilder =
    Widget Function({
      required ComicDetailsData details,
      required ValueChanged<Set<String>> onDownloadConfirm,
      required void Function(String epId, String chapterTitle, int index)
      onChapterTap,
    });

typedef ComicDetailReaderPageBuilder =
    Widget Function({
      required ComicDetailsData details,
      required String chapterTitle,
      required String epId,
      required int chapterIndex,
      required ThemeData comicTheme,
    });

typedef ComicDetailSearchPageBuilder = Widget Function(String initialKeyword);
