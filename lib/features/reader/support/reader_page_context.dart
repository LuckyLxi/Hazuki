import 'package:flutter/material.dart';

import 'package:hazuki/features/reader/support/reader_callbacks.dart';

class ReaderPageContext {
  const ReaderPageContext({
    required this.title,
    required this.chapterTitle,
    required this.comicId,
    required this.epId,
    required this.chapterIndex,
    required this.images,
    this.sourceKey = '',
    this.comicTheme,
    this.onFavoriteRequested,
    this.commentsWidgetBuilder,
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
  final ReaderCommentsWidgetBuilder? commentsWidgetBuilder;

  ReaderPageContext copyForChapter({
    required String epId,
    required String chapterTitle,
    required int chapterIndex,
    List<String> images = const <String>[],
  }) {
    return ReaderPageContext(
      title: title,
      chapterTitle: chapterTitle,
      comicId: comicId,
      epId: epId,
      chapterIndex: chapterIndex,
      images: images,
      sourceKey: sourceKey,
      comicTheme: comicTheme,
      onFavoriteRequested: onFavoriteRequested,
      commentsWidgetBuilder: commentsWidgetBuilder,
    );
  }
}
