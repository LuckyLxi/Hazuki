import 'package:flutter/widgets.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';

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
      CommentsInteractionState? interactionState,
    });

typedef ReaderCommentsWidgetBuilder =
    Widget Function({
      required String comicId,
      String? subId,
      String? chapterId,
      required String sourceKey,
      ScrollController? scrollController,
      Future<void> Function()? onRequestTabFullscreen,
      CommentsInteractionState? interactionState,
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
    interactionState,
  }) => builder(
    comicId: comicId,
    subId: subId,
    chapterId: chapterId,
    sourceKey: sourceKey,
    scrollController: scrollController,
    onRequestTabFullscreen: onRequestTabFullscreen,
    interactionState: interactionState,
  );
}
