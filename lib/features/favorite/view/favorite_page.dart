import 'package:hazuki/shared/source_presentation.dart';
import 'package:hazuki/services/source/plugins/source_presentation_metadata.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/shared/favorites/favorite_app_bar_actions_state.dart';
import 'package:hazuki/shared/favorites/favorite_page_actions.dart';
import 'package:hazuki/features/favorite/state/favorite_page_controller.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';
import 'package:hazuki/shared/comic_cover_prefetcher.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:hazuki/shared/appearance/appearance_settings_scope.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'favorite_page_content.dart';
import 'favorite_view_support.dart';
import '../support/favorite_dialogs.dart';
import 'favorite_folder_header.dart';
import 'favorite_login_required_view.dart';
import '../support/favorite_entry_animation_queue.dart';

typedef FavoriteComicTapHandler =
    Future<void> Function(ExploreComic comic, String heroTag);

AppLocalizations _strings(BuildContext context) =>
    AppLocalizations.of(context)!;

class FavoritePage extends StatefulWidget {
  const FavoritePage({
    super.key,
    required this.sourceService,
    this.readerService,
    required this.localFavoritesRepository,
    required this.localFavoritesPreferences,
    required this.imageGateway,
    required this.authVersion,
    required this.onComicTap,
    this.onAppBarActionsChanged,
    this.onRequestLogin,
    this.actionsBinding,
  });

  final SourceFavoriteGateway sourceService;
  final SourceReaderGateway? readerService;
  final LocalFavoritesRepository localFavoritesRepository;
  final LocalFavoritesPreferencesStore localFavoritesPreferences;
  final SourceImageGateway imageGateway;
  final int authVersion;
  final FavoriteComicTapHandler onComicTap;
  final ValueChanged<FavoriteAppBarActionsState>? onAppBarActionsChanged;
  final Future<void> Function()? onRequestLogin;
  final FavoritePageActionsBinding? actionsBinding;

  @override
  State<FavoritePage> createState() => FavoritePageState();
}

class FavoritePageState extends State<FavoritePage>
    with AutomaticKeepAliveClientMixin
    implements FavoritePageActions {
  @override
  bool get wantKeepAlive => true;

  late final FavoritePageController _controller;
  late final ComicCoverPrefetcher _coverPrefetcher;
  final ScrollController _scrollController = ScrollController();
  final FavoriteEntryAnimationQueue _entryAnimationQueue =
      FavoriteEntryAnimationQueue();
  bool _showBackToTop = false;
  FavoriteAppBarActionsState? _lastReportedAppBarActionsState;
  Map<String, FavoriteEntryAnimationStyle> _comicAnimationStyles =
      <String, FavoriteEntryAnimationStyle>{};
  bool _pendingFreshListEntryAnimation = true;
  FavoriteLayout _favoriteLayout = FavoriteLayout.list;

  @override
  bool get backToTopVisible => _showBackToTop;

  @override
  void initState() {
    super.initState();
    _controller = FavoritePageController(
      sourceService: widget.sourceService,
      readerService: widget.readerService,
      presentationFor:
          SourcePresentationScope.read(context)?.presentationFor ??
          emptySourcePresentation,
      localFavoritesRepository: widget.localFavoritesRepository,
      localFavoritesPreferences: widget.localFavoritesPreferences,
    );
    _coverPrefetcher = ComicCoverPrefetcher(imageGateway: widget.imageGateway);
    _controller.addListener(_handleControllerChanged);
    _scrollController.addListener(_onScroll);
    widget.actionsBinding?.attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        _controller.loadInitial(
          timeoutMessage: _strings(context).favoriteLoadTimeout,
          onFolderLoadError: _showFolderLoadError,
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final layout =
        HazukiThemeControllerScope.maybeOf(context)?.settings.favoriteLayout ??
        FavoriteLayout.list;
    if (_favoriteLayout != layout) {
      _favoriteLayout = layout;
      _scheduleCoverPrefetch();
    }
  }

  @override
  void didUpdateWidget(covariant FavoritePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.actionsBinding, widget.actionsBinding)) {
      oldWidget.actionsBinding?.detach(this);
      widget.actionsBinding?.attach(this);
    }

    if (oldWidget.authVersion != widget.authVersion) {
      if (_controller.mode == FavoritePageMode.local) {
        return;
      }
      if (_controller.isLogged) {
        _pendingFreshListEntryAnimation = true;
        _controller.resetForReload();
        _notifyAppBarActions();
        unawaited(
          _controller.loadInitial(
            timeoutMessage: _strings(context).favoriteLoadTimeout,
            onFolderLoadError: _showFolderLoadError,
          ),
        );
      } else {
        _controller.resetLoggedOut();
        _notifyAppBarActions();
      }
    }
  }

  @override
  void dispose() {
    widget.actionsBinding?.detach(this);
    widget.onAppBarActionsChanged?.call(
      const FavoriteAppBarActionsState(
        showSort: false,
        showCreateFolder: false,
        currentSortOrder: '',
        showModeToggle: true,
        currentMode: FavoritePageMode.cloud,
      ),
    );
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _coverPrefetcher.dispose();
    _entryAnimationQueue.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Future<void> createFolder() async {
    final strings = _strings(context);
    final name = await showFavoriteCreateFolderDialog(context);
    if (name == null || name.isEmpty) {
      return;
    }

    final error = await _controller.createFolder(
      name,
      timeoutMessage: strings.favoriteLoadTimeout,
      onFolderLoadError: _showFolderLoadError,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      unawaited(
        showHazukiPrompt(
          context,
          strings.favoriteCreateFailed(error),
          isError: true,
        ),
      );
      return;
    }
    unawaited(showHazukiPrompt(context, strings.favoriteCreated(name)));
  }

  @override
  Future<void> changeSortOrder(String order) async {
    _pendingFreshListEntryAnimation = true;
    final error = await _controller.changeSortOrder(
      order,
      timeoutMessage: _strings(context).favoriteLoadTimeout,
      onFolderLoadError: _showFolderLoadError,
    );
    if (!mounted || error == null) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        _strings(context).favoriteSortChangeFailed(error),
        isError: true,
      ),
    );
  }

  @override
  Future<void> toggleMode() {
    _pendingFreshListEntryAnimation = true;
    return _controller.toggleMode(
      timeoutMessage: _strings(context).favoriteLoadTimeout,
      onFolderLoadError: _showFolderLoadError,
    );
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    _notifyAppBarActions();
    _syncEntryAnimationTargets();
    _scheduleCoverPrefetch();
  }

  void _notifyAppBarActions() {
    final nextState = _controller.appBarActionsState;
    if (nextState == _lastReportedAppBarActionsState) {
      return;
    }
    _lastReportedAppBarActionsState = nextState;
    widget.onAppBarActionsChanged?.call(nextState);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final nextShowBackToTop = position.pixels > 520;
    if (nextShowBackToTop != _showBackToTop && mounted) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
      widget.actionsBinding?.updateBackToTopVisibility(
        this,
        visible: nextShowBackToTop,
      );
    }
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_handleLoadMore());
    }
    _prefetchVisibleCovers();
  }

  Future<void> _deleteCurrentFolder() async {
    final strings = _strings(context);
    final currentId = _controller.selectedFolderId;
    if (currentId == '0') {
      return;
    }

    final current = _controller.folders
        .where((folder) => folder.id == currentId)
        .firstOrNull;
    final ok = await showFavoriteDeleteFolderDialog(
      context,
      folderName: current?.name ?? currentId,
    );
    if (!ok) {
      return;
    }

    final error = await _controller.deleteCurrentFolder(
      timeoutMessage: strings.favoriteLoadTimeout,
    );
    if (!mounted || error == null) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        strings.favoriteDeleteFailed(error),
        isError: true,
      ),
    );
  }

  Future<void> _handleLoadMore() async {
    final error = await _controller.loadMore(
      timeoutMessage: _strings(context).favoriteLoadTimeout,
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      return;
    }
    unawaited(showHazukiPrompt(context, error, isError: true));
  }

  Future<void> _renameLocalFolder(FavoriteFolder folder) async {
    if (_controller.mode != FavoritePageMode.local || folder.isAllFolder) {
      return;
    }

    unawaited(HapticFeedback.lightImpact());
    final strings = _strings(context);
    final renamed = await showFavoriteRenameFolderDialog(
      context,
      initialName: folder.name,
    );
    if (renamed == null) {
      return;
    }

    final normalized = renamed.trim();
    if (normalized.isEmpty || normalized == folder.name.trim()) {
      return;
    }

    final error = await _controller.renameLocalFolder(folder.id, normalized);
    if (!mounted || error == null) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        strings.favoriteRenameFailed(error),
        isError: true,
      ),
    );
  }

  Future<void> _handleRefresh() {
    _controller.retrySourceRuntime();
    _pendingFreshListEntryAnimation = true;
    _clearEntryAnimationTargets();
    return _controller.refresh(
      timeoutMessage: _strings(context).favoriteLoadTimeout,
      onFolderLoadError: _showFolderLoadError,
    );
  }

  Future<void> _handleSelectFolder(String folderId) {
    _pendingFreshListEntryAnimation = true;
    _clearEntryAnimationTargets();
    return _controller.selectFolder(
      folderId,
      timeoutMessage: _strings(context).favoriteLoadTimeout,
    );
  }

  void _clearEntryAnimationTargets() {
    if (_comicAnimationStyles.isEmpty) {
      return;
    }
    setState(() {
      _comicAnimationStyles = <String, FavoriteEntryAnimationStyle>{};
    });
  }

  void _syncEntryAnimationTargets() {
    if (_controller.initialLoading ||
        _controller.refreshing ||
        _controller.loadingMore) {
      return;
    }
    final currentIds = _controller.comics
        .map((comic) => comic.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (currentIds.isEmpty) {
      return;
    }
    if (_pendingFreshListEntryAnimation) {
      _comicAnimationStyles = <String, FavoriteEntryAnimationStyle>{};
      _pendingFreshListEntryAnimation = false;
    }
    _comicAnimationStyles = {
      for (final id in currentIds)
        id: _comicAnimationStyles[id] ?? FavoriteEntryAnimationStyle.staggered,
    };
  }

  void _showFolderLoadError(String rawError) {
    if (!mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        _strings(context).favoriteFoldersLoadFailed(rawError),
        isError: true,
      ),
    );
  }

  void _scheduleCoverPrefetch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefetchVisibleCovers();
    });
  }

  void _prefetchVisibleCovers() {
    if (_controller.mode != FavoritePageMode.local) {
      return;
    }
    var estimatedItemExtent = 122.0;
    if (_favoriteLayout != FavoriteLayout.list) {
      final columns = _favoriteLayout.columns;
      final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
      final coverWidth = (width - 32 - (columns - 1) * 10) / columns;
      final titleHeight = _favoriteLayout == FavoriteLayout.coverOnly
          ? 0.0
          : 6 +
                MediaQuery.textScalerOf(
                      context,
                    ).scale(Theme.of(context).textTheme.bodyMedium!.fontSize!) *
                    1.3 *
                    2;
      estimatedItemExtent =
          (coverWidth * 102 / 72 + titleHeight + 10) / columns;
    }
    _coverPrefetcher.prefetchAroundScroll(
      comics: _controller.comics,
      scrollController: _scrollController,
      estimatedItemExtent: estimatedItemExtent,
      extraBefore: 6,
      extraAfter: 30,
      maxRequests: 30,
    );
  }

  @override
  Future<void> scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  VoidCallback? _buildLoginHandler() {
    if (widget.onRequestLogin == null) {
      return null;
    }
    return () {
      unawaited(widget.onRequestLogin!());
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.showSourceRequired) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _strings(context).sourceInstallRequired,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          );
        }

        if (_controller.showLoginRequired) {
          return FavoriteLoginRequiredView(
            onLoginPressed: _buildLoginHandler(),
          );
        }

        return WindowsComicDetailHost(
          child: Stack(
            children: [
              ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                children: [
                  if (_controller.supportsFolderLoad)
                    FavoriteFolderHeader(
                      folders: _controller.folders,
                      selectedFolderId: _controller.selectedFolderId,
                      loadingFolders: _controller.loadingFolders,
                      showDeleteActionSlot: _controller.supportsFolderDelete,
                      enableDeleteAction: _controller.canDeleteSelectedFolder,
                      onDeleteCurrentFolder: _deleteCurrentFolder,
                      onSelectFolder: _handleSelectFolder,
                      onLongPressFolder:
                          _controller.mode == FavoritePageMode.local
                          ? _renameLocalFolder
                          : null,
                    ),
                  FavoritePageContentSection(
                    layout: _favoriteLayout,
                    entryScrollController: _scrollController,
                    entryAnimationQueue: _entryAnimationQueue,
                    comics: _controller.comics,
                    comicAnimationStyles: _comicAnimationStyles,
                    errorMessage: _controller.errorMessage,
                    initialLoading: _controller.initialLoading,
                    refreshing: _controller.refreshing,
                    loadingMore: _controller.loadingMore,
                    sourceRuntimeState: _controller.sourceRuntimeState,
                    strings: _strings(context),
                    mode: _controller.mode,
                    showCreateLocalFolderButton:
                        _controller.mode == FavoritePageMode.local &&
                        _controller.folders.isEmpty,
                    onRetry: _handleRefresh,
                    onCreateLocalFolder: createFolder,
                    onComicTap: (comic) {
                      final heroTag = favoriteComicHeroTag(
                        comic,
                        salt: 'favorite',
                      );
                      unawaited(widget.onComicTap(comic, heroTag));
                    },
                  ),
                ],
              ),
              if (!HazukiLiquidGlass.isAvailable)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FavoriteBackToTopButton(
                    visible: _showBackToTop,
                    onPressed: scrollToTop,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
