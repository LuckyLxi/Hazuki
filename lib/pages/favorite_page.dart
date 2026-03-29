import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';
import 'favorite/favorite.dart';

part 'favorite/favorite_back_to_top_button.dart';
part 'favorite/favorite_content_section.dart';
part 'favorite/favorite_comic_tile.dart';

typedef FavoriteDetailRouteBuilder =
    Route<void> Function(ExploreComic comic, String heroTag);

AppLocalizations _strings(BuildContext context) =>
    AppLocalizations.of(context)!;

String _favoriteComicHeroTag(ExploreComic comic, {String? salt}) {
  final key = comic.id.isEmpty ? comic.title : comic.id;
  if (salt == null || salt.isEmpty) {
    return 'comic-cover-$key';
  }
  return 'comic-cover-$key-$salt';
}

class FavoritePage extends StatefulWidget {
  const FavoritePage({
    super.key,
    required this.authVersion,
    required this.detailRouteBuilder,
    this.onAppBarActionsChanged,
    this.onRequestLogin,
  });

  final int authVersion;
  final FavoriteDetailRouteBuilder detailRouteBuilder;
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
      if (HazukiSourceService.instance.isLogged) {
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

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    _notifyAppBarActions();
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
    if (!mounted || error == null) {
      return;
    }
    unawaited(showHazukiPrompt(context, error, isError: true));
  }

  Future<void> _handleRefresh() {
    return _controller.refresh(
      timeoutMessage: _strings(context).favoriteLoadTimeout,
      onFolderLoadError: _showFolderLoadError,
    );
  }

  Future<void> _handleSelectFolder(String folderId) {
    return _controller.selectFolder(
      folderId,
      timeoutMessage: _strings(context).favoriteLoadTimeout,
    );
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
      animation: _controller,
      builder: (context, _) {
        if (!_controller.isLogged) {
          return FavoriteLoginRequiredView(
            onLoginPressed: _buildLoginHandler(),
          );
        }

        return Stack(
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
                    showDeleteAction: _controller.supportsFolderDelete,
                    onDeleteCurrentFolder: _deleteCurrentFolder,
                    onSelectFolder: _handleSelectFolder,
                  ),
                _FavoriteContentSection(
                  comics: _controller.comics,
                  errorMessage: _controller.errorMessage,
                  initialLoading: _controller.initialLoading,
                  loadingMore: _controller.loadingMore,
                  strings: _strings(context),
                  onRetry: _handleRefresh,
                  onComicTap: (comic) {
                    final heroTag = _favoriteComicHeroTag(
                      comic,
                      salt: 'favorite',
                    );
                    Navigator.of(
                      context,
                    ).push(widget.detailRouteBuilder(comic, heroTag));
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
        );
      },
    );
  }
}
