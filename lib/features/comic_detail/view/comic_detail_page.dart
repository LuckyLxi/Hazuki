import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/features/search/search.dart';
import 'package:hazuki/models/hazuki_models.dart';

import 'package:hazuki/features/comic_detail/support/comic_detail_actions_controller.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_session_controller.dart';
import 'package:hazuki/features/comic_detail/support/comic_detail_theme_controller.dart';
import 'package:hazuki/features/reader/view/reader_page.dart';

import 'comic_detail_app_bar.dart';
import 'comic_detail_background.dart';
import 'comic_detail_cover.dart';
import 'comic_detail_favorite_dialog.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_panels.dart';
import 'comic_detail_scaffold.dart';

const MethodChannel _comicDetailMediaChannel = MethodChannel(
  'hazuki.comics/media',
);

class ComicDetailPage extends StatefulWidget {
  const ComicDetailPage({
    super.key,
    required this.comic,
    required this.heroTag,
    this.isDesktopPanel = false,
    this.shouldAnimateInitialRevealOverride,
    this.onCloseRequested,
  });

  final ExploreComic comic;
  final String heroTag;
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

  late final ComicDetailSessionController _sessionController;
  late final ComicDetailThemeController _themeController;
  late final ComicDetailActionsController _actionsController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _sessionController.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _themeController.syncComicDynamicColorSettingFromScope();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  void _updateComicDetailState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  void _initializeControllers() {
    _themeController = ComicDetailThemeController(
      comicCoverUrl: widget.comic.cover,
      contextGetter: () => context,
      isMounted: () => mounted,
      updateState: _updateComicDetailState,
      detailsFutureGetter: () => _sessionController.future,
    );
    _actionsController = ComicDetailActionsController(
      contextGetter: () => context,
      isMounted: () => mounted,
      updateState: _updateComicDetailState,
      comicGetter: () => widget.comic,
      heroTagGetter: () => widget.heroTag,
      detailThemeApplier: _themeController.buildDetailTheme,
      lastReadProgressGetter: () => _sessionController.lastReadProgress,
      reloadReadingProgress: () => _sessionController.loadReadingProgress(),
      coverPreviewPageBuilder:
          ({required imageUrl, required heroTag, required onLongPress}) =>
              ComicCoverPreviewPage(
                imageUrl: imageUrl,
                heroTag: heroTag,
                onLongPress: onLongPress,
              ),
      favoriteDialogBuilder:
          ({
            required details,
            required singleFolderOnly,
            required cloudFavoriteOverride,
            required initialIsFavorite,
            required themedData,
          }) => FavoriteFoldersMorphDialog(
            details: details,
            singleFolderOnly: singleFolderOnly,
            cloudFavoriteOverride: cloudFavoriteOverride,
            initialIsFavorite: initialIsFavorite,
          ),
      chaptersPanelBuilder:
          ({
            required details,
            required themedData,
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
          }) => ReaderPage(
            title: details.title,
            chapterTitle: chapterTitle,
            comicId: details.id,
            epId: epId,
            chapterIndex: chapterIndex,
            images: const [],
            comicTheme: comicTheme,
          ),
      searchPageBuilder: (initialKeyword) => SearchPage(
        initialKeyword: initialKeyword,
        comicDetailPageBuilder: (comic, heroTag) => ComicDetailPage(
          comic: comic,
          heroTag: heroTag,
          isDesktopPanel: widget.isDesktopPanel,
          onCloseRequested: widget.onCloseRequested,
        ),
      ),
      mediaChannel: _comicDetailMediaChannel,
    );
    _sessionController = ComicDetailSessionController(
      comic: widget.comic,
      shouldAnimateInitialRevealOverride:
          widget.shouldAnimateInitialRevealOverride,
      vsync: this,
      scrollController: _scrollController,
      isMounted: () => mounted,
      updateState: _updateComicDetailState,
      applyInitialFavoriteOverrides:
          _actionsController.applyInitialFavoriteOverrides,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeController.buildDetailTheme(Theme.of(context));
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final surface = theme.colorScheme.surface;

    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: Scaffold(
        backgroundColor: surface,
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: false,
        appBar: ComicDetailScrollAwareAppBar(
          collapsedTitleListenable: _sessionController.collapsedTitleNotifier,
          appBarComicTitle: _sessionController.appBarComicTitle,
          appBarUpdateTime: _sessionController.appBarUpdateTime,
          theme: theme,
          isDesktopPanel: widget.isDesktopPanel,
          onCloseRequested: widget.onCloseRequested,
        ),
        body: Stack(
          children: [
            ComicDetailParallaxBackground(
              coverUrl: widget.comic.cover.trim(),
              scrollController: _scrollController,
            ),
            ComicDetailTopSurfaceOverlay(
              progressListenable:
                  _sessionController.appBarSolidProgressNotifier,
              surface: surface,
              height: topInset,
            ),
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: ComicDetailBody(
                tabController: _sessionController.tabController,
                future: _sessionController.future,
                scrollController: _scrollController,
                surface: surface,
                heroTag: widget.heroTag,
                comic: widget.comic,
                headerTitleKey: _headerTitleKey,
                favoriteRowKey: _favoriteRowKey,
                actionButtonsKey: _actionButtonsKey,
                favoriteBusy: _actionsController.favoriteBusy,
                favoriteOverride: _actionsController.favoriteOverride,
                lastReadProgress: _sessionController.lastReadProgress,
                shouldAnimateInitialDetailReveal:
                    _sessionController.shouldAnimateInitialDetailReveal,
                buildViewsText: extractComicViewsText,
                buildMetaSection: (details) => ComicDetailMetaSection(
                  details: details,
                  onCopyId: (id) =>
                      unawaited(_actionsController.copyComicId(id)),
                  onMetaValuePressed: _actionsController.openSearchForKeyword,
                  onMetaValueLongPress: (value) =>
                      unawaited(_actionsController.copyMetaValue(value)),
                ),
                onShowCoverPreview: (imageUrl) =>
                    unawaited(_actionsController.showCoverPreview(imageUrl)),
                onFavoriteTap: _actionsController.toggleFavorite,
                onShowChapters: _actionsController.showChaptersPanel,
                onOpenReader: _actionsController.openReader,
                onDetailsLoaded:
                    _sessionController.markComicDetailRevealHandled,
                onRequestCommentsTabFullscreen:
                    _sessionController.ensureCommentsTabFullscreen,
                buildCommentsTabDebugState:
                    _sessionController.buildCommentsTabDebugState,
                onDetailsResolved: ({required title, required updateTime}) =>
                    _sessionController.updateAppBarMetadata(
                      title: title,
                      updateTime: updateTime,
                    ),
                isDesktopPanel: widget.isDesktopPanel,
                onCloseRequested: widget.onCloseRequested,
                buildComicDetailPage: (comic, heroTag) => ComicDetailPage(
                  comic: comic,
                  heroTag: heroTag,
                  isDesktopPanel: widget.isDesktopPanel,
                  onCloseRequested: widget.onCloseRequested,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
