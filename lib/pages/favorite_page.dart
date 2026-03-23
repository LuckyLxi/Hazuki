part of '../main.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({
    super.key,
    required this.authVersion,
    this.onAppBarActionsChanged,
    this.onRequestLogin,
  });

  final int authVersion;
  final ValueChanged<FavoriteAppBarActionsState>? onAppBarActionsChanged;
  final Future<void> Function()? onRequestLogin;

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class FavoriteAppBarActionsState {
  const FavoriteAppBarActionsState({
    required this.showSort,
    required this.showCreateFolder,
    required this.currentSortOrder,
  });

  final bool showSort;
  final bool showCreateFolder;
  final String currentSortOrder;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FavoriteAppBarActionsState &&
        other.showSort == showSort &&
        other.showCreateFolder == showCreateFolder &&
        other.currentSortOrder == currentSortOrder;
  }

  @override
  int get hashCode => Object.hash(showSort, showCreateFolder, currentSortOrder);
}

class _FavoritePageState extends State<FavoritePage>
    with AutomaticKeepAliveClientMixin {
  // 保持页面状态不被销毁
  @override
  bool get wantKeepAlive => true;

  // 收藏加载超时设为 90 秒，与 Dio 内部超时配合
  static const _favoriteLoadTimeout = Duration(seconds: 90);

  final ScrollController _scrollController = ScrollController();

  List<ExploreComic> _comics = const [];
  List<FavoriteFolder> _folders = const [
    FavoriteFolder(id: '0', name: '__favorite_all__'),
  ];
  String _selectedFolderId = '0';
  String? _errorMessage;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadingFolders = false;
  bool _showBackToTop = false;
  int _currentPage = 1;
  int _listRequestVersion = 0;
  String _favoriteSortOrder = 'mr';
  FavoriteAppBarActionsState? _lastReportedAppBarActionsState;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitial());
  }

  @override
  void didUpdateWidget(covariant FavoritePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authVersion != widget.authVersion) {
      if (HazukiSourceService.instance.isLogged) {
        setState(() {
          _initialLoading = true;
          _refreshing = false;
          _loadingMore = false;
          _errorMessage = null;
          _comics = const [];
          _currentPage = 1;
          _hasMore = true;
        });
        _notifyAppBarActions();
        unawaited(_loadInitial());
      } else {
        setState(() {
          _comics = const [];
          _folders = const [FavoriteFolder(id: '0', name: '__favorite_all__')];
          _selectedFolderId = '0';
          _errorMessage = null;
          _initialLoading = false;
          _refreshing = false;
          _loadingMore = false;
          _hasMore = true;
          _currentPage = 1;
          _loadingFolders = false;
        });
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _notifyAppBarActions() {
    final service = HazukiSourceService.instance;
    final canOperate = service.isLogged;
    final nextState = FavoriteAppBarActionsState(
      showSort: canOperate && service.supportFavoriteSortOrder,
      showCreateFolder: canOperate && service.supportFavoriteFolderAdd,
      currentSortOrder: _favoriteSortOrder,
    );
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
      unawaited(_loadMore());
    }
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

  Future<FavoriteComicsResult> _loadFavoritesPage(
    int page, {
    String? folderId,
  }) {
    final targetFolderId = (folderId ?? _selectedFolderId).trim();
    final timeoutMessage = l10n(context).favoriteLoadTimeout;
    return HazukiSourceService.instance
        .loadFavoriteComics(page: page, folderId: targetFolderId)
        .timeout(
          _favoriteLoadTimeout,
          onTimeout: () => FavoriteComicsResult.error(timeoutMessage),
        );
  }

  List<ExploreComic> _mergeComics(
    List<ExploreComic> existing,
    List<ExploreComic> incoming,
  ) {
    final merged = <String, ExploreComic>{};
    for (final comic in existing) {
      if (comic.id.isNotEmpty) {
        merged[comic.id] = comic;
      }
    }
    for (final comic in incoming) {
      if (comic.id.isNotEmpty) {
        merged[comic.id] = comic;
      }
    }
    return merged.values.toList();
  }

  Future<void> _loadInitial() async {
    try {
      await HazukiSourceService.instance.ensureInitialized();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _errorMessage = e.toString();
        });
      }
      return;
    }

    final service = HazukiSourceService.instance;
    if (service.supportFavoriteSortOrder) {
      _favoriteSortOrder = service.favoriteSortOrder;
    }
    _notifyAppBarActions();

    if (!service.isLogged) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
      return;
    }

    final requestVersion = ++_listRequestVersion;
    final targetFolderId = _selectedFolderId;

    await _reloadFolders();

    final result = await _loadFavoritesPage(1, folderId: targetFolderId);
    if (!mounted || requestVersion != _listRequestVersion) {
      return;
    }
    setState(() {
      if (result.errorMessage == null) {
        _comics = result.comics;
        _errorMessage = null;
        _currentPage = 1;
        if (result.maxPage != null) {
          _hasMore = _currentPage < result.maxPage!;
        } else {
          _hasMore = result.comics.isNotEmpty;
        }
      } else {
        _errorMessage = result.errorMessage;
      }
      _initialLoading = false;
    });
  }

  Future<void> _reloadFolders() async {
    final service = HazukiSourceService.instance;
    if (!service.supportFavoriteFolderLoad) {
      if (mounted) {
        setState(() {
          _folders = const [FavoriteFolder(id: '0', name: '__favorite_all__')];
          _selectedFolderId = '0';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingFolders = true;
      });
    }

    final result = await service.loadFavoriteFolders();
    if (!mounted) {
      return;
    }

    if (result.errorMessage != null) {
      setState(() {
        _loadingFolders = false;
      });
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).favoriteFoldersLoadFailed(result.errorMessage!),
          isError: true,
        ),
      );
      return;
    }

    final folders = result.folders.isEmpty
        ? const [FavoriteFolder(id: '0', name: '__favorite_all__')]
        : result.folders;
    final selectedExists = folders.any((e) => e.id == _selectedFolderId);

    setState(() {
      _folders = folders;
      if (!selectedExists) {
        _selectedFolderId = folders.first.id;
      }
      _loadingFolders = false;
    });
  }

  Future<void> _loadMore() async {
    if (!mounted ||
        _initialLoading ||
        _refreshing ||
        _loadingMore ||
        !_hasMore ||
        !HazukiSourceService.instance.isLogged) {
      return;
    }

    final requestVersion = _listRequestVersion;
    final targetFolderId = _selectedFolderId;

    setState(() {
      _loadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await _loadFavoritesPage(
        nextPage,
        folderId: targetFolderId,
      );
      if (!mounted || requestVersion != _listRequestVersion) {
        return;
      }

      if (result.errorMessage != null) {
        unawaited(
          showHazukiPrompt(
            context,
            result.errorMessage!,
            isError: true,
          ),
        );
        setState(() {
          _loadingMore = false;
        });
        return;
      }

      final incoming = result.comics;
      setState(() {
        _comics = _mergeComics(_comics, incoming);
        _currentPage = nextPage;
        if (result.maxPage != null) {
          _hasMore = _currentPage < result.maxPage!;
        } else {
          _hasMore = incoming.isNotEmpty;
        }
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && requestVersion == _listRequestVersion) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (!HazukiSourceService.instance.isLogged || _refreshing) {
      return;
    }

    final requestVersion = ++_listRequestVersion;
    final targetFolderId = _selectedFolderId;

    setState(() {
      _refreshing = true;
      _loadingMore = false;
    });

    try {
      await _reloadFolders();
      final result = await _loadFavoritesPage(1, folderId: targetFolderId);
      if (!mounted || requestVersion != _listRequestVersion) {
        return;
      }
      setState(() {
        if (result.errorMessage == null) {
          _comics = result.comics;
          _errorMessage = null;
          _currentPage = 1;
          if (result.maxPage != null) {
            _hasMore = _currentPage < result.maxPage!;
          } else {
            _hasMore = result.comics.isNotEmpty;
          }
        } else {
          _errorMessage = result.errorMessage;
        }
      });
    } finally {
      if (mounted && requestVersion == _listRequestVersion) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _selectFolder(String folderId) async {
    if (_selectedFolderId == folderId || _initialLoading || _refreshing) {
      return;
    }

    final requestVersion = ++_listRequestVersion;

    setState(() {
      _selectedFolderId = folderId;
      _initialLoading = true;
      _errorMessage = null;
      _comics = const [];
      _currentPage = 1;
      _hasMore = true;
      _loadingMore = false;
    });

    final result = await _loadFavoritesPage(1, folderId: folderId);
    if (!mounted || requestVersion != _listRequestVersion) {
      return;
    }

    setState(() {
      if (result.errorMessage == null) {
        _comics = result.comics;
        _currentPage = 1;
        if (result.maxPage != null) {
          _hasMore = _currentPage < result.maxPage!;
        } else {
          _hasMore = result.comics.isNotEmpty;
        }
      } else {
        _errorMessage = result.errorMessage;
      }
      _initialLoading = false;
    });
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        // 用 StatefulBuilder 维护本地错误提示状态
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final strings = l10n(dialogContext);
            return AlertDialog(
              title: Text(strings.favoriteCreateFolderTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: strings.favoriteCreateFolderHint,
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                // 输入时清除错误提示
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.commonCancel),
                ),
                FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    // 输入为空时显示错误，不关闭弹窗
                    if (text.isEmpty) {
                      setDialogState(
                        () => errorText =
                            strings.favoriteCreateFolderNameRequired,
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, text);
                  },
                  child: Text(strings.commonConfirm),
                ),
              ],
            );
          },
        );
      },
    );

    if (name == null || name.isEmpty) {
      return;
    }

    try {
      await HazukiSourceService.instance.addFavoriteFolder(name);
      await _reloadFolders();
      if (!mounted) {
        return;
      }
      // 新建成功后显示 SnackBar 提示
      unawaited(showHazukiPrompt(context, l10n(context).favoriteCreated(name)));
      final created = _folders.where((e) => e.name == name).toList();
      if (created.isNotEmpty) {
        await _selectFolder(created.first.id);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).favoriteCreateFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _changeSortOrder(String order) async {
    final normalized = order == 'mp' ? 'mp' : 'mr';
    if (normalized == _favoriteSortOrder) {
      return;
    }
    try {
      await HazukiSourceService.instance.setFavoriteSortOrder(normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _favoriteSortOrder = normalized;
        _initialLoading = true;
        _refreshing = false;
        _loadingMore = false;
        _errorMessage = null;
        _comics = const [];
        _currentPage = 1;
        _hasMore = true;
      });
      _notifyAppBarActions();
      await _loadInitial();
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).favoriteSortChangeFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Future<void> _deleteCurrentFolder() async {
    final currentId = _selectedFolderId;
    if (currentId == '0') {
      return;
    }

    final current = _folders.where((e) => e.id == currentId).firstOrNull;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final strings = l10n(dialogContext);
        return AlertDialog(
          title: Text(strings.favoriteDeleteFolderTitle),
          content: Text(
            strings.favoriteDeleteFolderContent(current?.name ?? currentId),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(strings.comicDetailDelete),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      return;
    }

    try {
      await HazukiSourceService.instance.deleteFavoriteFolder(currentId);
      if (!mounted) {
        return;
      }

      // 乐观更新：直接从本地列表移除已删文件夹，避免服务器缓存导致重新出现
      final updatedFolders = _folders.where((e) => e.id != currentId).toList();
      setState(() {
        _folders = updatedFolders.isEmpty
            ? const [FavoriteFolder(id: '0', name: '__favorite_all__')]
            : updatedFolders;
      });

      // 切换到"全部"文件夹并刷新漫画列表
      await _selectFolder('0');

      // 静默从服务器同步一次，修正本地数据（不影响已呈现的 UI）
      unawaited(_reloadFolders());
    } catch (e) {
      if (!mounted) {
        return;
      }
      unawaited(
        showHazukiPrompt(
          context,
          l10n(context).favoriteDeleteFailed('$e'),
          isError: true,
        ),
      );
    }
  }

  Widget _buildFolderHeader() {
    final service = HazukiSourceService.instance;
    if (!service.supportFavoriteFolderLoad) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n(context).favoriteFolderHeader,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (service.supportFavoriteFolderDelete &&
                  _selectedFolderId != '0')
                IconButton(
                  tooltip: l10n(context).favoriteDeleteCurrentFolderTooltip,
                  onPressed: _deleteCurrentFolder,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (_loadingFolders)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _folders
                    .map(
                      (folder) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            folder.id == '0'
                                ? l10n(context).favoriteAllFolder
                                : folder.name,
                          ),
                          selected: _selectedFolderId == folder.id,
                          onSelected: (_) => _selectFolder(folder.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComicTile(ExploreComic comic) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final heroTag = _comicCoverHeroTag(comic, salt: 'favorite');
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ComicDetailPage(comic: comic, heroTag: heroTag),
          ),
        );
      },
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Hero(
              tag: _comicCoverHeroTag(comic, salt: 'favorite'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: comic.cover.isEmpty
                    ? Container(
                        width: 72,
                        height: 102,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : HazukiCachedImage(
                        url: comic.cover,
                        width: 72,
                        height: 102,
                        fit: BoxFit.cover,
                        loading: Container(
                          width: 72,
                          height: 102,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        error: Container(
                          width: 72,
                          height: 102,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (comic.subTitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      comic.subTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 必需调用
    final strings = l10n(context);
    final isLogged = HazukiSourceService.instance.isLogged;
    if (!isLogged) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  size: 34,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                strings.favoriteLoginRequired,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                strings.historyLoginRequired,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 52),
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: widget.onRequestLogin == null
                    ? null
                    : () {
                        unawaited(widget.onRequestLogin!());
                      },
                icon: const Icon(Icons.login_rounded, size: 22),
                label: Text(strings.homeLoginTitle),
              ),
            ],
          ),
        ),
      );
    }

    Widget content;
    if (_initialLoading) {
      content = SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HazukiStickerLoadingIndicator(size: 120),
              const SizedBox(height: 10),
              Text(strings.commonLoading),
            ],
          ),
        ),
      );
    } else if (_errorMessage != null && _comics.isEmpty) {
      content = SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refresh,
                child: Text(strings.commonRetry),
              ),
            ],
          ),
        ),
      );
    } else if (_comics.isEmpty) {
      content = SizedBox(
        height: 220,
        child: Center(child: Text(strings.favoriteEmpty)),
      );
    } else {
      content = ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        itemCount: _comics.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildComicTile(_comics[index]),
      );
    }

    final loadMoreFooter = _loadingMore
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HazukiStickerLoadingIndicator(size: 72),
                  const SizedBox(height: 8),
                  Text(strings.commonLoading),
                ],
              ),
            ),
          )
        : const SizedBox(height: 8);

    // 仅保留上拉加载更多，移除下拉刷新
    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          children: [_buildFolderHeader(), content, loadMoreFooter],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: AnimatedSlide(
            offset: _showBackToTop ? Offset.zero : const Offset(0, 0.24),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: _showBackToTop ? 1 : 0.86,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _showBackToTop ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: IgnorePointer(
                  ignoring: !_showBackToTop,
                  child: FloatingActionButton.small(
                    heroTag: 'favorite_back_to_top',
                    onPressed: _scrollToTop,
                    child: const Icon(Icons.vertical_align_top_rounded),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
