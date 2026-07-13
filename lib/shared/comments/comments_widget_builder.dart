import 'package:flutter/widgets.dart';

typedef CommentsWidgetBuilder =
    Widget Function({
      required String comicId,
      String? subId,
      String? chapterId,
      required String sourceKey,
      ScrollController? scrollController,
      Future<void> Function()? onRequestTabFullscreen,
      bool showAppBar,
      bool isTabView,
      bool isActiveInTabView,
      Map<String, Object?> Function()? debugOuterScrollStateBuilder,
    });

typedef ReaderCommentsWidgetBuilder =
    Widget Function({
      required String comicId,
      String? subId,
      String? chapterId,
      required String sourceKey,
      ScrollController? scrollController,
      Future<void> Function()? onRequestTabFullscreen,
    });

ReaderCommentsWidgetBuilder readerCommentsWidgetBuilderFrom(
  CommentsWidgetBuilder builder,
) {
  return ({
    required comicId,
    subId,
    chapterId,
    required sourceKey,
    scrollController,
    onRequestTabFullscreen,
  }) => builder(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    scrollController: scrollController,
    onRequestTabFullscreen: onRequestTabFullscreen,
  );
}
