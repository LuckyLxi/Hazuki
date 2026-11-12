import 'package:flutter/material.dart';

import 'reader_offline_chapter_data.dart';

typedef ReaderPageBuilder =
    Widget Function({
      required String title,
      required String chapterTitle,
      required String comicId,
      required String epId,
      required int chapterIndex,
      required List<String> images,
      required String sourceKey,
      String coverUrl,
      ThemeData? comicTheme,
      Future<void> Function(BuildContext context)? onFavoriteRequested,
      bool offlineMode,
      List<ReaderOfflineChapterData> offlineChapters,
    });
