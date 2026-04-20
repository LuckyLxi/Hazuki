import 'package:flutter/material.dart';

import 'package:hazuki/models/hazuki_models.dart';

typedef ComicDetailContextGetter = BuildContext Function();
typedef ComicDetailIsMounted = bool Function();
typedef ComicDetailStateUpdate = void Function(VoidCallback update);
typedef ComicDetailDetailsFutureGetter = Future<ComicDetailsData> Function();
typedef ComicDetailPageBuilder =
    Widget Function(ExploreComic comic, String heroTag);
typedef ComicDetailThemeApplier = ThemeData Function(ThemeData baseTheme);
typedef ComicDetailCoverPreviewPageBuilder =
    Widget Function({
      required String imageUrl,
      required String heroTag,
      required VoidCallback onLongPress,
    });
typedef ComicDetailFavoriteDialogBuilder =
    Widget Function({
      required ComicDetailsData details,
      required bool singleFolderOnly,
      required bool? cloudFavoriteOverride,
      required bool initialIsFavorite,
      required ThemeData themedData,
    });
typedef ComicDetailChaptersPanelBuilder =
    Widget Function({
      required ComicDetailsData details,
      required ThemeData themedData,
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
