import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

import '../repository/comic_detail_repository.dart';
import '../support/comic_detail_actions_controller.dart';
import '../support/comic_detail_controller_support.dart';
import '../support/comic_detail_favorite_controller.dart';
import '../support/comic_detail_scope.dart';
import '../support/comic_detail_session_controller.dart';
import '../support/comic_detail_theme_controller.dart';
import '../support/comic_detail_ui_state_controller.dart';
import 'comic_detail_app_bar.dart';
import 'package:hazuki/features/favorite/favorite.dart';

import 'comic_detail_background.dart';
import 'comic_detail_cover.dart';
import 'comic_detail_scaffold.dart';
import 'package:hazuki/widgets/chapters_panel_sheet.dart';

const MethodChannel _comicDetailMediaChannel = MethodChannel(
  'hazuki.comics/media',
);

class ComicDetailPage extends StatefulWidget {
  const ComicDetailPage({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.readerWidgetBuilder,
    required this.searchPageBuilder,
    this.isDesktopPanel = false,
    this.shouldAnimateInitialRevealOverride,
    this.onCloseRequested,
  });

  final ExploreComic comic;
  final String heroTag;
  final ReaderWidgetBuilder readerWidgetBuilder;
  final ComicDetailSearchPageBuilder searchPageBuilder;
  final bool isDesktopPanel;
  final bool? shouldAnimateInitialRevealOverride;
  final VoidCallback? onCloseRequested;

  @override
  State<ComicDetailPage> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _actionButtonsKey = GlobalKey();
  final GlobalKey _favoriteRowKey = GlobalKey();
  final GlobalKey _headerTitleKey = GlobalKey();

  late final ComicDetailRepository _repository;
  late final ComicDetailSessionController _sessionController;
  late final ComicDetailUiStateController _uiStateController;
  late final ComicDetailThemeController _themeController;
  late final ComicDetailActionsController _actionsController;
  late final ComicDetailFavoriteController _favoriteController;
  late final bool _supportsJmExclusiveActions;
  late final bool _supportsComicLikeAction;

  @override
  void initState() {
    super.initState();
    _repository = ComicDetailRepository(
      source: sl<HazukiSourceService>(),
      local: sl<LocalFavoritesService>(),
      downloader: sl<MangaDownloadService>(),
    );
    final comicSourceKey = widget.comic.sourceKey.trim().isNotEmpty
        ? widget.comic.sourceKey
        : sl<HazukiSourceService>().activeSourceKey;
    _supportsJmExclusiveActions = isHazukiJmSourceKey(comicSourceKey);
    _supportsComicLikeAction =
        isHazukiJmSourceKey(comicSourceKey) ||
        isHazukiPicacgSourceKey(comicSourceKey);
    _initializeControllers();
    _uiStateController.initialize(initialAppBarTitle: widget.comic.title);
    _sessionController.initialize();
    _themeController.addListener(_rebuildPage);
    _sessionController.addListener(_rebuildPage);
    _uiStateController.addListener(_rebuildPage);
    _favoriteController.addListener(_rebuildPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeController.syncComicDynamicColorSettingFromScope();
  }

  @override
  void dispose() {
    _themeController.removeListener(_rebuildPage);
    _sessionController.removeListener(_rebuildPage);
    _uiStateController.removeListener(_rebuildPage);
    _favoriteController.removeListener(_rebuildPage);
    _sessionController.dispose();
    _uiStateController.dispose();
    _themeController.dispose();
    _actionsController.dispose();
    _favoriteController.dispose();
    super.dispose();
  }

  void _rebuildPage() {
    if (mounted) setState(() {});
  }

  void _initializeControllers() {
    _favoriteController = ComicDetailFavoriteController(
      repository: _repository,
    );
    _themeController = ComicDetailThemeController(
      repository: _repository,
      comicCoverUrl: widget.comic.cover,
      contextGetter: () => context,
      detailsFutureGetter: () => _sessionController.future,
    );
    _actionsController = ComicDetailActionsController(
      repository: _repository,
      comic: widget.comic,
      heroTag: widget.heroTag,
      detailThemeApplier: _themeController.buildDetailTheme,
      lastReadProgressGetter: () => _sessionController.lastReadProgress,
      reloadReadingProgress: () => _sessionController.loadReadingProgress(),
      coverPreviewPageBuilder:
          ({
            required imageUrl,
            required sourceKey,
            required heroTag,
            required onLongPress,
          }) => ComicCoverPreviewPage(
            imageUrl: imageUrl,
            sourceKey: sourceKey,
            heroTag: heroTag,
            onLongPress: onLongPress,
          ),
      chaptersPanelBuilder:
          ({
            required details,
            required onDownloadConfirm,
            required onChapterTap,
          }) => ChaptersPanelSheet(
            details: details,
            onDownloadConfirm: onDownloadConfirm,
            onChapterTap: onChapterTap,
          ),
      readerPageBuilder:
          ({
            required details,
            required chapterTitle,
            required epId,
            required chapterIndex,
            required comicTheme,
          }) => widget.readerWidgetBuilder(
            title: details.title,
            chapterTitle: chapterTitle,
            comicId: details.id,
            epId: epId,
            chapterIndex: chapterIndex,
            images: const [],
            sourceKey: details.sourceKey,
            comicTheme: comicTheme,
            onFavoriteRequested: (ctx) => _favoriteController.showFoldersDialog(
              ctx,
              details,
              (vm) => Theme(
                data: comicTheme,
                child: FavoriteFoldersMorphDialog(viewModel: vm),
              ),
            ),
          ),
      searchPageBuilder: widget.searchPageBuilder,
      comicDetailPageBuilder: (comic, heroTag) => ComicDetailPage(
        comic: comic,
        heroTag: heroTag,
        readerWidgetBuilder: widget.readerWidgetBuilder,
        searchPageBuilder: widget.searchPageBuilder,
        isDesktopPanel: widget.isDesktopPanel,
        onCloseRequested: widget.onCloseRequested,
      ),
      mediaChannel: _comicDetailMediaChannel,
    );
    _sessionController = ComicDetailSessionController(
      repository: _repository,
      comic: widget.comic,
      sourceKey: widget.comic.sourceKey,
      applyInitialFavoriteOverrides: _favoriteController.applyInitialOverrides,
    );
    _uiStateController = ComicDetailUiStateController(
      comicId: widget.comic.id,
      shouldAnimateInitialRevealOverride:
          widget.shouldAnimateInitialRevealOverride,
      vsync: this,
      scrollController: _scrollController,
      includeRelatedTab: _supportsJmExclusiveActions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeController.buildDetailTheme(Theme.of(context));
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final surface = theme.colorScheme.surface;

    return ComicDetailScope(
      session: _sessionController,
      uiState: _uiStateController,
      theme: _themeController,
      actions: _actionsController,
      favorite: _favoriteController,
      supportsJmExclusiveActions: _supportsJmExclusiveActions,
      supportsComicLikeAction: _supportsComicLikeAction,
      child: AnimatedTheme(
        data: theme,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: Scaffold(
          backgroundColor: surface,
          extendBodyBehindAppBar: true,
          resizeToAvoidBottomInset: false,
          appBar: ComicDetailScrollAwareAppBar(
            collapsedTitleListenable: _uiStateController.collapsedTitleNotifier,
            appBarComicTitle: _uiStateController.appBarComicTitle,
            appBarUpdateTime: _uiStateController.appBarUpdateTime,
            theme: theme,
            isDesktopPanel: widget.isDesktopPanel,
            onCloseRequested: widget.onCloseRequested,
          ),
          body: Stack(
            children: [
              ComicDetailParallaxBackground(
                coverUrl: widget.comic.cover.trim(),
                sourceKey: widget.comic.sourceKey,
                scrollController: _scrollController,
              ),
              ComicDetailTopSurfaceOverlay(
                progressListenable:
                    _uiStateController.appBarSolidProgressNotifier,
                surface: surface,
                height: topInset,
              ),
              Padding(
                padding: EdgeInsets.only(top: topInset),
                child: ComicDetailBody(
                  scrollController: _scrollController,
                  heroTag: widget.heroTag,
                  comic: widget.comic,
                  headerTitleKey: _headerTitleKey,
                  favoriteRowKey: _favoriteRowKey,
                  actionButtonsKey: _actionButtonsKey,
                  isDesktopPanel: widget.isDesktopPanel,
                  onCloseRequested: widget.onCloseRequested,
                  buildComicDetailPage: (comic, heroTag) => ComicDetailPage(
                    comic: comic,
                    heroTag: heroTag,
                    readerWidgetBuilder: widget.readerWidgetBuilder,
                    searchPageBuilder: widget.searchPageBuilder,
                    isDesktopPanel: widget.isDesktopPanel,
                    onCloseRequested: widget.onCloseRequested,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
