import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/shared/favorites/favorite_page_actions.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/reading/reader_offline_chapter_data.dart';

abstract class HomeDownloadStatusListenable implements Listenable {
  bool get hasTasks;
  int get taskCount;
}

class HomeServices {
  const HomeServices({
    required this.sourceService,
    required this.sourceSwitchService,
    required this.imageService,
    required this.dailyRecommendationService,
    required this.downloadStatus,
  });

  final SourceHomeGateway sourceService;
  final SourceSwitchGateway sourceSwitchService;
  final SourceImageGateway imageService;
  final DiscoverDailyRecommendationService dailyRecommendationService;
  final HomeDownloadStatusListenable downloadStatus;
}

typedef HomeComicDetailPageBuilder =
    Widget Function(
      ExploreComic comic,
      String heroTag, {
      bool isDesktopPanel,
      bool? shouldAnimateInitialRevealOverride,
      VoidCallback? onCloseRequested,
    });

typedef HomeSearchPageBuilder =
    Widget Function({
      String? initialKeyword,
      bool autoFocusOnOpen,
      required ComicDetailPageBuilder comicDetailPageBuilder,
    });

typedef HomeSearchRouteBuilder =
    Route<T> Function<T>({required WidgetBuilder builder});

typedef HomeDownloadedComicReaderPageBuilder =
    Widget Function(DownloadedMangaComic comic, DownloadedMangaChapter chapter);

typedef HomeReaderPageBuilder =
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

typedef HomeDiscoverTabBuilder =
    Widget Function({
      required ComicDetailPageBuilder comicDetailPageBuilder,
      required DiscoverDailyRecommendationState dailyRecommendationState,
      required bool allowInitialLoad,
      required bool hideLoadingUntilInitialLoadAllowed,
      required ValueChanged<double> onSearchMorphProgressChanged,
      required VoidCallback onSearchTap,
      required Future<void> Function() onRequestLogin,
    });

typedef HomeFavoriteTabBuilder =
    Widget Function({
      required FavoritePageActionsBinding actionsBinding,
      required int authVersion,
      required ValueChanged<FavoriteAppBarActionsState> onAppBarActionsChanged,
      required Future<void> Function() onRequestLogin,
      required Future<void> Function(ExploreComic comic, String heroTag)
      onComicTap,
    });

typedef HomeHistoryPageBuilder =
    Widget Function({
      required ComicDetailPageBuilder comicDetailPageBuilder,
      required Future<void> Function(BuildContext context, ExploreComic comic)
      onFavoriteRequested,
    });

typedef HomeCategoriesPageBuilder =
    Widget Function({
      required HomeSearchPageBuilder searchPageBuilder,
      required ComicDetailPageBuilder comicDetailPageBuilder,
    });

typedef HomeRankingPageBuilder =
    Widget Function({
      required bool useLegacyRankingSection,
      required String legacyRankingTitle,
      required ComicDetailPageBuilder comicDetailPageBuilder,
    });

typedef HomeDownloadsPageBuilder =
    Widget Function({
      required HomeDownloadedComicReaderPageBuilder readerPageBuilder,
    });

typedef HomeSettingsPageBuilder =
    Widget Function({
      required AppearanceSettingsData appearanceSettings,
      required AppearanceSettingsApplyCallback onAppearanceChanged,
      required Locale? locale,
      required Future<void> Function(Locale? locale) onLocaleChanged,
    });

class HomeFeatureEntrypoints {
  const HomeFeatureEntrypoints({
    required this.buildComicDetailPage,
    required this.buildReaderPage,
    required this.buildSearchPage,
    required this.buildSearchRoute,
    required this.buildDiscoverTab,
    required this.buildFavoriteTab,
    required this.buildHistoryPage,
    required this.buildCategoriesPage,
    required this.buildRankingPage,
    required this.buildDownloadsPage,
    required this.buildSettingsPage,
    required this.buildLinesPage,
    required this.onHistoryFavoriteRequested,
  });

  final HomeComicDetailPageBuilder buildComicDetailPage;
  final HomeReaderPageBuilder buildReaderPage;
  final HomeSearchPageBuilder buildSearchPage;
  final HomeSearchRouteBuilder buildSearchRoute;
  final HomeDiscoverTabBuilder buildDiscoverTab;
  final HomeFavoriteTabBuilder buildFavoriteTab;
  final HomeHistoryPageBuilder buildHistoryPage;
  final HomeCategoriesPageBuilder buildCategoriesPage;
  final HomeRankingPageBuilder buildRankingPage;
  final HomeDownloadsPageBuilder buildDownloadsPage;
  final HomeSettingsPageBuilder buildSettingsPage;
  final WidgetBuilder buildLinesPage;
  final Future<void> Function(BuildContext context, ExploreComic comic)
  onHistoryFavoriteRequested;
}
