import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';
import '../widgets/windows_comic_detail_host.dart';
import 'favorite/favorite.dart';

part 'favorite/favorite_back_to_top_button.dart';
part 'favorite/favorite_content_section.dart';
part 'favorite/favorite_comic_tile.dart';

typedef FavoriteComicTapHandler =
    Future<void> Function(ExploreComic comic, String heroTag);

AppLocalizations _strings(BuildContext context) =>
    AppLocalizations.of(context)!;

String _favoriteComicHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.id;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}

enum FavoriteEntryAnimationStyle { none, staggered }

class FavoritePage extends StatefulWidget {
  const FavoritePage({
    super.key,
    required this.authVersion,
    required this.onComicTap,
    this.onAppBarActionsChanged,
    this.onRequestLogin,
  });

  final int authVersion;
  final FavoriteComicTapHandler onComicTap;
  final ValueChanged<FavoriteAppBarActionsState>? onAppBarActionsChanged;
  final Future<void> Function()? onRequestLogin;

  @override
  State<FavoritePage> createState() => FavoritePageState();
}

class FavoritePageState extends State<FavoritePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final FavoritePageController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  FavoriteAppBarActionsState? _lastReportedAppBarActionsState;
  Map<String, FavoriteEntryAnimationStyle> _comicAnimationStyles =
      <String, FavoriteEntryAnimationStyle>{};
  bool _pendingFreshListEntryAnimation = true;
  int _entryAnimationBatchId = 0;

  @override
  void initState() {
    super.initState();
    _controller = FavoritePageController();
    _controller.addListener(_handleControllerChanged);
    _scrollController.addListener(_onScroll);
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
  void didUpdateWidget(covariant FavoritePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.authVersion != widget.authVersion) {
      if (_controller.mode == FavoritePageMode.local) {
        return;
      }
      if (HazukiSourceService.instance.isLogged) {
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
    widget.onAppBarActionsChanged?.call(
      const FavoriteAppBarActionsState(
        showSort: false,
        showCreateFolder: false,
        currentSortOrder: 'mr',
        showModeToggle: true,
        currentMode: FavoritePageMode.cloud,
      ),
    );
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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
    }
    if (position.pixels >= position.maxScrollExtent - 240) {
      unawaited(_handleLoadMore());
    }
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
    if (HazukiSourceService.instance.sourceRuntimeState.canRetry) {
      HazukiSourceService.instance.logRuntimeRetryRequested('favorite_page');
    }
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

  void _scheduleEntryAnimation(
    List<String> comicIds,
    FavoriteEntryAnimationStyle style,
  ) {
    if (!mounted || comicIds.isEmpty) {
      return;
    }
    final batchId = ++_entryAnimationBatchId;
    _comicAnimationStyles = {for (final id in comicIds) id: style};
    Future<void>.delayed(const Duration(milliseconds: 620), () {
      if (!mounted ||
          _comicAnimationStyles.isEmpty ||
          batchId != _entryAnimationBatchId) {
        return;
      }
      setState(() {
        _comicAnimationStyles = <String, FavoriteEntryAnimationStyle>{};
      });
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
      _pendingFreshListEntryAnimation = false;
      _scheduleEntryAnimation(
        currentIds.take(8).toList(),
        FavoriteEntryAnimationStyle.staggered,
      );
    }
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

  Future<void> _scrollToTop() async {
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
      animation: Listenable.merge([_controller, HazukiSourceService.instance]),
      builder: (context, _) {
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
                  _FavoriteContentSection(
                    comics: _controller.comics,
                    comicAnimationStyles: _comicAnimationStyles,
                    errorMessage: _controller.errorMessage,
                    initialLoading: _controller.initialLoading,
                    refreshing: _controller.refreshing,
                    loadingMore: _controller.loadingMore,
                    sourceRuntimeState:
                        HazukiSourceService.instance.sourceRuntimeState,
                    strings: _strings(context),
                    mode: _controller.mode,
                    showCreateLocalFolderButton:
                        _controller.mode == FavoritePageMode.local &&
                        _controller.folders.isEmpty,
                    onRetry: _handleRefresh,
                    onCreateLocalFolder: createFolder,
                    onComicTap: (comic) {
                      final heroTag = _favoriteComicHeroTag(
                        comic,
                        salt: 'favorite',
                      );
                      unawaited(widget.onComicTap(comic, heroTag));
                    },
                  ),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _FavoriteBackToTopButton(
                  visible: _showBackToTop,
                  onPressed: _scrollToTop,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
