import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/support/reader_callbacks.dart';
import 'package:hazuki/shared/reading/reader_offline_chapter_data.dart';

export 'package:hazuki/shared/reading/reader_offline_chapter_data.dart';

class ReaderPageContext {
  const ReaderPageContext({
    required this.title,
    required this.chapterTitle,
    required this.comicId,
    required this.epId,
    required this.chapterIndex,
    required this.images,
    required this.commentsWidgetBuilder,
    this.sourceKey = '',
    this.comicTheme,
    this.onFavoriteRequested,
    this.offlineMode = false,
    this.offlineChapters = const <ReaderOfflineChapterData>[],
  });

  final String title;
  final String chapterTitle;
  final String comicId;
  final String epId;
  final int chapterIndex;
  final List<String> images;
  final String sourceKey;
  final ThemeData? comicTheme;
  final Future<void> Function(BuildContext)? onFavoriteRequested;
  final ReaderCommentsWidgetBuilder commentsWidgetBuilder;
  final bool offlineMode;
  final List<ReaderOfflineChapterData> offlineChapters;

  ReaderPageContext copyForChapter({
    required String epId,
    required String chapterTitle,
    required int chapterIndex,
    List<String> images = const <String>[],
  }) {
    ReaderOfflineChapterData? offlineChapter;
    for (final chapter in offlineChapters) {
      if (chapter.epId == epId) {
        offlineChapter = chapter;
        break;
      }
    }
    return ReaderPageContext(
      title: title,
      chapterTitle: chapterTitle,
      comicId: comicId,
      epId: epId,
      chapterIndex: chapterIndex,
      images: images.isNotEmpty
          ? images
          : (offlineChapter?.images ?? const <String>[]),
      sourceKey: sourceKey,
      comicTheme: comicTheme,
      onFavoriteRequested: onFavoriteRequested,
      commentsWidgetBuilder: commentsWidgetBuilder,
      offlineMode: offlineMode,
      offlineChapters: offlineChapters,
    );
  }
}
