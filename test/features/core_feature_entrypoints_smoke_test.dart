import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/app/app.dart';
import 'package:hazuki/app/home/home_feature_entrypoints.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/features/comments/comments.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_page.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_dependencies.dart';
import 'package:hazuki/features/downloads/downloads.dart';
import 'package:hazuki/features/favorite/view/favorite_page.dart';
import 'package:hazuki/features/history/history.dart';
import 'package:hazuki/features/home/view/home_page.dart';
import 'package:hazuki/features/reader/support/reader_dependencies.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';
import 'package:hazuki/features/search/search.dart';
import 'package:hazuki/features/settings/settings.dart';
import 'package:hazuki/features/settings/support/settings_core_dependencies.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';
import 'package:hazuki/services/password_lock_service.dart';
import 'package:hazuki/services/comment_filter_service.dart';
import 'package:hazuki/services/cloud_sync_service.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/read_history_service.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/software_update/software_update_service.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';
import 'package:hazuki/shared/comments/comments_interaction_state.dart';
import 'package:hazuki/shared/navigation_tags.dart';

Widget _buildComments({
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
  return const SizedBox.shrink();
}

final ReaderCommentsWidgetBuilder _buildReaderComments =
    readerCommentsWidgetBuilderFrom(_buildComments);

ReaderDependencies _readerDependencies() {
  return ReaderDependencies(
    sourceReader: sl<SourceReaderGateway>(),
    sourceSettings: sl<SourceSettingsGateway>(),
    readingProgressService: sl<ReadingProgressService>(),
    downloader: sl<MangaDownloadService>(),
  );
}

ComicDetailDependencies _comicDetailDependencies() {
  return ComicDetailDependencies(
    source: sl<SourceComicDetailGateway>(),
    localFavorites: sl<LocalFavoritesRepository>(),
    downloader: sl<MangaDownloadService>(),
    readingProgress: sl<ReadingProgressService>(),
    readHistory: sl<ReadHistoryService>(),
    imageGateway: sl<SourceImageGateway>(),
  );
}

void main() {
  test('feature-first entry widgets are constructible from public paths', () {
    registerServices();
    final readerDependencies = _readerDependencies();
    final homeFeatureEntrypoints = buildHazukiHomeFeatureEntrypoints();
    final home = HazukiHomePage(
      initialTabIndex: 1,
      appearanceSettings: const AppearanceSettingsData(
        themeMode: ThemeMode.system,
        oledPureBlack: false,
        dynamicColor: false,
        presetIndex: hazukiDefaultAppearancePresetIndex,
        displayModeRaw: 'system',
        comicDetailDynamicColor: false,
        useSystemFont: true,
      ),
      onAppearanceChanged: (_, {revealOrigin, revealSyncRegion}) async {},
      locale: const Locale('en'),
      onLocaleChanged: (_) async {},
      featureEntrypoints: homeFeatureEntrypoints,
      services: buildHazukiHomeServices(),
    );
    const comic = ExploreComic(
      id: 'comic-id',
      title: 'Hazuki',
      subTitle: 'Smoke',
      cover: '',
    );
    final detail = ComicDetailPage(
      comic: comic,
      dependencies: _comicDetailDependencies(),
      heroTag: 'hero',
      readerWidgetBuilder:
          ({
            required title,
            required chapterTitle,
            required comicId,
            required epId,
            required chapterIndex,
            required images,
            required sourceKey,
            coverUrl = '',
            comicTheme,
            onFavoriteRequested,
          }) => ReaderPage(
            title: title,
            chapterTitle: chapterTitle,
            comicId: comicId,
            epId: epId,
            chapterIndex: chapterIndex,
            images: images,
            dependencies: readerDependencies,
            sourceKey: sourceKey,
            coverUrl: coverUrl,
            commentsWidgetBuilder: _buildReaderComments,
          ),
      searchPageBuilder: (_) => const SizedBox.shrink(),
      commentsWidgetBuilder: _buildComments,
    );
    Widget buildDetail(ExploreComic comic, String heroTag) => ComicDetailPage(
      comic: comic,
      dependencies: _comicDetailDependencies(),
      heroTag: heroTag,
      readerWidgetBuilder:
          ({
            required title,
            required chapterTitle,
            required comicId,
            required epId,
            required chapterIndex,
            required images,
            required sourceKey,
            coverUrl = '',
            comicTheme,
            onFavoriteRequested,
          }) => ReaderPage(
            title: title,
            chapterTitle: chapterTitle,
            comicId: comicId,
            epId: epId,
            chapterIndex: chapterIndex,
            images: images,
            dependencies: readerDependencies,
            sourceKey: sourceKey,
            coverUrl: coverUrl,
            commentsWidgetBuilder: _buildReaderComments,
          ),
      searchPageBuilder: (_) => const SizedBox.shrink(),
      commentsWidgetBuilder: _buildComments,
    );
    final search = SearchPage(
      sourceService: sl<SourceSearchGateway>(),
      historyService: sl<SearchHistoryService>(),
      initialKeyword: comic.title,
      comicDetailPageBuilder: buildDetail,
    );
    final favorite = FavoritePage(
      sourceService: sl<SourceFavoriteGateway>(),
      localFavoritesRepository: sl<LocalFavoritesRepository>(),
      localFavoritesPreferences: sl<LocalFavoritesPreferencesStore>(),
      imageGateway: sl<SourceImageGateway>(),
      authVersion: 1,
      onComicTap: (comic, heroTag) async {},
    );
    final comments = CommentsPage(
      sourceService: sl<SourceCommentsGateway>(),
      filterService: sl<CommentFilterService>(),
      comicId: 'comic-id',
    );
    final downloads = DownloadsPage(
      downloadService: sl<MangaDownloadService>(),
      downloadGroupsService: sl<DownloadGroupsService>(),
      readerPageBuilder: (comic, chapter) => const SizedBox.shrink(),
    );
    final history = HistoryPage(
      readHistoryService: sl<ReadHistoryService>(),
      sourceService: sl<SourceSelectionGateway>(),
      imageGateway: sl<SourceImageGateway>(),
      comicDetailPageBuilder: buildDetail,
      onFavoriteRequested: (_, _) async {},
    );
    final settings = SettingsPage(
      coreDependencies: SettingsCoreDependencies(
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
      ),
      appearanceSettings: const AppearanceSettingsData(
        themeMode: ThemeMode.system,
        oledPureBlack: false,
        dynamicColor: false,
        presetIndex: hazukiDefaultAppearancePresetIndex,
        displayModeRaw: 'system',
        comicDetailDynamicColor: false,
        useSystemFont: true,
      ),
      onAppearanceChanged: (_, {revealOrigin, revealSyncRegion}) async {},
      locale: const Locale('en'),
      onLocaleChanged: (_) async {},
      cloudSyncPageBuilder: (_) =>
          CloudSyncPage(service: sl<CloudSyncService>()),
      labSettingsPageBuilder: (_) =>
          LabSettingsPage(sourceService: sl<SourceRuntimeGateway>()),
      advancedSettingsPageBuilder: (_) => AdvancedSettingsPage(
        sourceService: sl<SourceAdvancedGateway>(),
        softwareUpdateService: sl<SoftwareUpdateService>(),
        logsPageBuilder: (_) =>
            LogsPage(debugGateway: sl<SourceDebugGateway>()),
        comicSourceEditorPageBuilder: (_) =>
            ComicSourceEditorPage(sourceService: sl<SourceScriptGateway>()),
        restoreComicSource: (_) async => false,
      ),
    );
    final reader = ReaderPage(
      title: 'Hazuki',
      chapterTitle: 'Chapter 1',
      comicId: 'comic-id',
      epId: 'ep-id',
      chapterIndex: 0,
      images: const ['a', 'b'],
      dependencies: readerDependencies,
      comicTheme: ThemeData.light(),
      commentsWidgetBuilder: _buildReaderComments,
    );

    expect(home.initialTabIndex, 1);
    expect(detail.comic, comic);
    expect(detail.heroTag, 'hero');
    expect(search.initialKeyword, comic.title);
    expect(favorite.authVersion, 1);
    expect(comments.comicId, 'comic-id');
    expect(downloads.readerPageBuilder, isNotNull);
    expect(history.comicCoverHeroTagBuilder(comic), comicCoverHeroTag(comic));
    expect(
      comicCoverHeroTag(
        const ExploreComic(
          id: 'same-id',
          title: 'JM',
          subTitle: '',
          cover: '',
          sourceKey: 'jm',
        ),
        salt: 'history',
      ),
      isNot(
        comicCoverHeroTag(
          const ExploreComic(
            id: 'same-id',
            title: 'Copy',
            subTitle: '',
            cover: '',
            sourceKey: 'copy_manga',
          ),
          salt: 'history',
        ),
      ),
    );
    expect(settings.appearanceSettings.themeMode, ThemeMode.system);
    expect(reader.images, const ['a', 'b']);
    expect(reader.chapterIndex, 0);
  });
}
