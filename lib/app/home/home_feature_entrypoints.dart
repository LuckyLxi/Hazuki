import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_dependencies.dart';
import 'package:hazuki/features/comments/comments.dart';
import 'package:hazuki/features/discover/discover.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/features/favorite/favorite.dart';
import 'package:hazuki/features/history/history.dart';
import 'package:hazuki/features/home/support/home_feature_contracts.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/features/search/search.dart';
import 'package:hazuki/features/settings/settings.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';
import 'package:hazuki/shared/reading/reader_offline_chapter_data.dart';
import 'package:hazuki/widgets/widgets.dart';

class _MangaDownloadStatusAdapter implements HomeDownloadStatusListenable {
  const _MangaDownloadStatusAdapter(this._service);

  final MangaDownloadService _service;

  @override
  bool get hasTasks => _service.tasks.isNotEmpty;

  @override
  int get taskCount => _service.tasks.length;

  @override
  void addListener(VoidCallback listener) {
    _service.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _service.removeListener(listener);
  }
}

HomeServices buildHazukiHomeServices() {
  return HomeServices(
    sourceService: sl<SourceHomeGateway>(),
    sourceSwitchService: sl<SourceSwitchGateway>(),
    imageService: sl<SourceImageGateway>(),
    dailyRecommendationService: sl<DiscoverDailyRecommendationService>(),
    downloadStatus: _MangaDownloadStatusAdapter(sl<MangaDownloadService>()),
  );
}

HomeFeatureEntrypoints buildHazukiHomeFeatureEntrypoints() {
  Widget buildComments({
    required String comicId,
    String? subId,
    String? chapterId,
    required String sourceKey,
    ScrollController? scrollController,
    Future<void> Function()? onRequestTabFullscreen,
    bool showAppBar = false,
    bool isTabView = false,
    bool isActiveInTabView = true,
    Map<String, Object?> Function()? debugOuterScrollStateBuilder,
    CommentsInteractionState? interactionState,
  }) {
    return CommentsPage(
      sourceService: sl<SourceCommentsGateway>(),
      filterService: sl<CommentFilterService>(),
      comicId: comicId,
      subId: subId,
      chapterId: chapterId,
      sourceKey: sourceKey,
      showAppBar: showAppBar,
      isTabView: isTabView,
      isActiveInTabView: isActiveInTabView,
      scrollController: scrollController,
      onRequestTabFullscreen: onRequestTabFullscreen,
      debugOuterScrollStateBuilder: debugOuterScrollStateBuilder,
      interactionState: interactionState,
    );
  }

  final readerCommentsBuilder = readerCommentsWidgetBuilderFrom(buildComments);
  final comicDetailDependencies = ComicDetailDependencies(
    source: sl<SourceComicDetailGateway>(),
    localFavorites: sl<LocalFavoritesRepository>(),
    downloader: sl<MangaDownloadService>(),
    readingProgress: sl<ReadingProgressService>(),
    readHistory: sl<ReadHistoryService>(),
    imageGateway: sl<SourceImageGateway>(),
  );
  final settingsCoreDependencies = SettingsCoreDependencies(
    sourceSettings: sl<SourceSettingsGateway>(),
    sourceDebug: sl<SourceDebugGateway>(),
    passwordLock: sl<PasswordLockService>(),
    softwareUpdate: sl<SoftwareUpdateService>(),
    cloudSync: sl<CloudSyncService>(),
    commentFilter: sl<CommentFilterService>(),
    dailyRecommendation: sl<DiscoverDailyRecommendationService>(),
    downloader: sl<MangaDownloadService>(),
    sourceRuntime: sl<SourceRuntimeGateway>(),
    sourceSelection: sl<SourceSelectionGateway>(),
    sourceAdvanced: sl<SourceAdvancedGateway>(),
    sourceScript: sl<SourceScriptGateway>(),
    sourceUpdate: sl<SourceUpdateGateway>(),
  );
  final readerDependencies = ReaderDependencies(
    sourceReader: sl<SourceReaderGateway>(),
    sourceSettings: sl<SourceSettingsGateway>(),
    readingProgressService: sl<ReadingProgressService>(),
    downloader: sl<MangaDownloadService>(),
  );

  Widget buildReaderPage({
    required String title,
    required String chapterTitle,
    required String comicId,
    required String epId,
    required int chapterIndex,
    required List<String> images,
    required String sourceKey,
    String coverUrl = '',
    ThemeData? comicTheme,
    Future<void> Function(BuildContext context)? onFavoriteRequested,
    bool offlineMode = false,
    List<ReaderOfflineChapterData> offlineChapters =
        const <ReaderOfflineChapterData>[],
  }) {
    return ReaderPage(
      title: title,
      chapterTitle: chapterTitle,
      comicId: comicId,
      epId: epId,
      chapterIndex: chapterIndex,
      images: images,
      dependencies: readerDependencies,
      sourceKey: sourceKey,
      coverUrl: coverUrl,
      comicTheme: comicTheme,
      onFavoriteRequested: onFavoriteRequested,
      commentsWidgetBuilder: readerCommentsBuilder,
      offlineMode: offlineMode,
      offlineChapters: offlineChapters,
    );
  }

  late final HomeFeatureEntrypoints entrypoints;
  entrypoints = HomeFeatureEntrypoints(
    buildComicDetailPage:
        (
          comic,
          heroTag, {
          isDesktopPanel = false,
          shouldAnimateInitialRevealOverride,
          onCloseRequested,
        }) {
          return ComicDetailPage(
            comic: comic,
            dependencies: comicDetailDependencies,
            heroTag: heroTag,
            readerWidgetBuilder: buildReaderPage,
            searchPageBuilder: (initialKeyword) => entrypoints.buildSearchPage(
              initialKeyword: initialKeyword,
              autoFocusOnOpen: false,
              comicDetailPageBuilder: (comic, heroTag) =>
                  entrypoints.buildComicDetailPage(comic, heroTag),
            ),
            commentsWidgetBuilder: buildComments,
            categoryPageBuilder:
                ({
                  required title,
                  required viewMoreUrl,
                  required comicDetailPageBuilder,
                }) {
                  return DiscoverSectionPage(
                    sourceService: sl<SourceDiscoverGateway>(),
                    section: ExploreSection(
                      title: title,
                      comics: const <ExploreComic>[],
                      viewMoreUrl: viewMoreUrl,
                    ),
                    comicDetailPageBuilder: comicDetailPageBuilder,
                  );
                },
            isDesktopPanel: isDesktopPanel,
            shouldAnimateInitialRevealOverride:
                shouldAnimateInitialRevealOverride,
            onCloseRequested: onCloseRequested,
          );
        },
    buildReaderPage: buildReaderPage,
    buildSearchPage:
        ({
          initialKeyword,
          autoFocusOnOpen = false,
          required comicDetailPageBuilder,
        }) {
          return SearchPage(
            sourceService: sl<SourceSearchGateway>(),
            historyService: sl<SearchHistoryService>(),
            initialKeyword: initialKeyword,
            autoFocusOnOpen: autoFocusOnOpen,
            comicDetailPageBuilder: comicDetailPageBuilder,
          );
        },
    buildSearchRoute: buildSearchEntryPageRoute,
    prepareSearchPage: () async {
      await sl<SearchHistoryService>().load();
    },
    buildDiscoverTab:
        ({
          required comicDetailPageBuilder,
          required dailyRecommendationState,
          required allowInitialLoad,
          required hideLoadingUntilInitialLoadAllowed,
          required onSearchMorphProgressChanged,
          required onSearchTap,
          required onRequestLogin,
        }) {
          return DiscoverPage(
            sourceService: sl<SourceDiscoverGateway>(),
            recommendationSource: sl<SourceRecommendationGateway>(),
            recommendationService: sl<DiscoverDailyRecommendationService>(),
            comicDetailPageBuilder: comicDetailPageBuilder,
            usePinnedSearchInAppBar: true,
            dailyRecommendationState: dailyRecommendationState,
            allowInitialLoad: allowInitialLoad,
            hideLoadingUntilInitialLoadAllowed:
                hideLoadingUntilInitialLoadAllowed,
            onSearchMorphProgressChanged: onSearchMorphProgressChanged,
            onSearchTap: onSearchTap,
            onRequestLogin: onRequestLogin,
          );
        },
    buildFavoriteTab:
        ({
          required actionsBinding,
          required authVersion,
          required onAppBarActionsChanged,
          required onRequestLogin,
          required onComicTap,
        }) {
          return FavoritePage(
            sourceService: sl<SourceFavoriteGateway>(),
            readerService: sl<SourceReaderGateway>(),
            localFavoritesRepository: sl<LocalFavoritesRepository>(),
            localFavoritesPreferences: sl<LocalFavoritesPreferencesStore>(),
            imageGateway: sl<SourceImageGateway>(),
            actionsBinding: actionsBinding,
            authVersion: authVersion,
            onAppBarActionsChanged: onAppBarActionsChanged,
            onRequestLogin: onRequestLogin,
            onComicTap: onComicTap,
          );
        },
    buildHistoryPage:
        ({required comicDetailPageBuilder, required onFavoriteRequested}) {
          return HistoryPage(
            readHistoryService: sl<ReadHistoryService>(),
            sourceService: sl<SourceSelectionGateway>(),
            readerService: sl<SourceReaderGateway>(),
            imageGateway: sl<SourceImageGateway>(),
            comicDetailPageBuilder: comicDetailPageBuilder,
            onFavoriteRequested: onFavoriteRequested,
          );
        },
    buildCategoriesPage:
        ({required searchPageBuilder, required comicDetailPageBuilder}) {
          return TagCategoryPage(
            categorySource: sl<SourceCategoryGateway>(),
            discoverSource: sl<SourceDiscoverGateway>(),
            searchPageBuilder: (tag) => searchPageBuilder(
              initialKeyword: tag,
              autoFocusOnOpen: false,
              comicDetailPageBuilder: comicDetailPageBuilder,
            ),
            comicDetailPageBuilder: comicDetailPageBuilder,
          );
        },
    buildRankingPage:
        ({
          required useLegacyRankingSection,
          required legacyRankingTitle,
          required comicDetailPageBuilder,
        }) {
          if (useLegacyRankingSection) {
            return DiscoverSectionPage(
              sourceService: sl<SourceDiscoverGateway>(),
              section: ExploreSection(
                title: legacyRankingTitle,
                comics: const <ExploreComic>[],
                viewMoreUrl: 'category:排行@ranking',
              ),
              comicDetailPageBuilder: comicDetailPageBuilder,
            );
          }
          return RankingPage(
            sourceService: sl<SourceCategoryGateway>(),
            comicDetailPageBuilder: comicDetailPageBuilder,
          );
        },
    buildDownloadsPage: ({required readerPageBuilder}) {
      return DownloadsPage(
        readerPageBuilder: readerPageBuilder,
        downloadService: sl<MangaDownloadService>(),
        downloadGroupsService: sl<DownloadGroupsService>(),
      );
    },
    buildSettingsPage:
        ({
          required appearanceSettings,
          required onAppearanceChanged,
          required locale,
          required onLocaleChanged,
        }) {
          return SettingsPage(
            coreDependencies: settingsCoreDependencies,
            appearanceSettings: appearanceSettings,
            onAppearanceChanged: onAppearanceChanged,
            locale: locale,
            onLocaleChanged: onLocaleChanged,
            cloudSyncPageBuilder: (_) =>
                CloudSyncPage(service: settingsCoreDependencies.cloudSync),
            labSettingsPageBuilder: (_) => LabSettingsPage(
              sourceService: settingsCoreDependencies.sourceRuntime,
            ),
            advancedSettingsPageBuilder: (_) => AdvancedSettingsPage(
              sourceService: settingsCoreDependencies.sourceAdvanced,
              softwareUpdateService: settingsCoreDependencies.softwareUpdate,
              logsPageBuilder: (_) =>
                  LogsPage(debugGateway: settingsCoreDependencies.sourceDebug),
              comicSourceEditorPageBuilder: (_) => ComicSourceEditorPage(
                sourceService: settingsCoreDependencies.sourceScript,
              ),
              restoreComicSource: (context) => showComicSourceRestoreDialog(
                context,
                sourceService: settingsCoreDependencies.sourceUpdate,
              ),
            ),
          );
        },
    buildLinesPage: (_) => LineSettingsPage(
      sourceService: settingsCoreDependencies.sourceSettings,
    ),
    onHistoryFavoriteRequested: _toggleFavoriteFromHomeHistory,
  );
  return entrypoints;
}

Future<void> _toggleFavoriteFromHomeHistory(
  BuildContext context,
  ExploreComic comic,
) async {
  final service = sl<SourceSearchGateway>();
  final strings = AppLocalizations.of(context)!;

  try {
    final details = await service.loadComicDetails(
      comic.id,
      sourceKey: comic.sourceKey,
    );
    if (!context.mounted) {
      return;
    }

    await _showFavoriteFoldersPanelFromHistory(context, details);
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        strings.historyFavoriteFailed('$e'),
        isError: true,
      ),
    );
  }
}

Future<void> _showFavoriteFoldersPanelFromHistory(
  BuildContext context,
  ComicDetailsData details,
) async {
  final repository = DefaultFavoriteFoldersRepository(
    source: sl<SourceFavoriteGateway>(),
    local: sl<LocalFavoritesRepository>(),
  );
  final singleFolderOnly = repository.favoriteSingleFolderForSingleComic;
  final viewModel = FavoriteFoldersViewModel(
    repository: repository,
    details: details,
    cloudFavoriteOverride: null,
    initialIsFavorite: details.isFavorite,
    singleFolderOnly: singleFolderOnly,
  );

  final changed = await showGeneralDialog<FavoriteFolderSelectionResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return FavoriteFoldersMorphDialog(viewModel: viewModel);
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      final opacity = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide =
          Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );
      return FadeTransition(
        opacity: opacity,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(scale),
            child: child,
          ),
        ),
      );
    },
  );

  viewModel.dispose();

  if (changed == null || !context.mounted) {
    return;
  }

  if (!changed.hasChanges) {
    return;
  }

  try {
    await applyFavoriteFolderSelectionChanges(
      repository: repository,
      details: details,
      selection: changed,
      singleFolderOnly: singleFolderOnly,
    );

    if (!context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        AppLocalizations.of(context)!.comicDetailFavoriteSettingsUpdated,
      ),
    );
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        AppLocalizations.of(
          context,
        )!.comicDetailFavoriteSettingsUpdateFailed('$e'),
        isError: true,
      ),
    );
  }
}
