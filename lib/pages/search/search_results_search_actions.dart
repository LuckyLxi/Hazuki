part of 'search_results_page.dart';

extension _SearchResultsSearchActionsExtension on _SearchResultsPageState {
  String? _normalizeComicIdKeyword(String keyword) {
    final normalized = keyword.trim().toLowerCase();
    if (RegExp(r'^\d{2,}$').hasMatch(normalized)) {
      return normalized;
    }
    if (RegExp(r'^jm\d{2,}$').hasMatch(normalized)) {
      return normalized;
    }
    return null;
  }

  Future<bool> _tryOpenComicDetailByKeywordId(String keyword) async {
    final comicId = _normalizeComicIdKeyword(keyword);
    if (comicId == null) {
      return false;
    }

    try {
      final details = await HazukiSourceService.instance
          .loadComicDetails(comicId)
          .timeout(const Duration(seconds: 25));
      if (!mounted) {
        return true;
      }

      final comic = ExploreComic(
        id: details.id,
        title: details.title.trim().isEmpty ? keyword.trim() : details.title,
        subTitle: details.subTitle,
        cover: details.cover,
      );
      await addSearchHistory(keyword);
      if (!mounted) {
        return true;
      }
      await openComicDetail(
        context,
        comic: comic,
        heroTag: widget.comicCoverHeroTagBuilder(
          comic,
          salt: 'search-id-direct',
        ),
        pageBuilder: widget.comicDetailPageBuilder,
        replaceCurrentRoute: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _submitSearch({String? submittedText}) async {
    final activeController = _focusCoordinator.activeController;
    final rawKeyword = submittedText ?? activeController.text;
    _focusCoordinator.syncText(rawKeyword);
    final keyword = await normalizeSubmittedKeyword(
      rawKeyword,
      controller: activeController,
    );

    _focusCoordinator.syncText(keyword);

    final submittedFromCollapsed = _focusCoordinator.collapsedSearchExpanded;
    _focusCoordinator.exitCollapsedMode();
    if (submittedFromCollapsed) {
      _animateSearchFlyToTop();
    }

    if (!mounted) {
      return;
    }

    if (keyword.isEmpty) {
      _clearSearch();
      return;
    }

    final idKeyword = _normalizeComicIdKeyword(keyword);
    final requestToken = idKeyword != null
        ? _resultsController.prepareDirectIdLookup(keyword)
        : -1;

    final openedById = await _tryOpenComicDetailByKeywordId(keyword);
    if (!openedById) {
      await addSearchHistory(keyword);
    }

    if (!mounted ||
        (requestToken != -1 &&
            !_resultsController.isCurrentRequest(requestToken))) {
      return;
    }

    if (openedById) {
      if (requestToken != -1) {
        _resultsController.finishDirectIdLookup(requestToken);
      }
      return;
    }

    await _resultsController.search(context, keyword: keyword, page: 1);
  }

  void _animateSearchFlyToTop() {
    final collapsedBox =
        _collapsedSearchKey.currentContext?.findRenderObject() as RenderBox?;
    if (collapsedBox == null || !collapsedBox.attached) {
      unawaited(_scrollToTop());
      return;
    }

    final startOffset = collapsedBox.localToGlobal(Offset.zero);
    final startSize = collapsedBox.size;

    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = kToolbarHeight + mediaQuery.padding.top;
    const targetLeft = 16.0;
    final targetTop = appBarHeight + 14.0;
    final targetWidth = mediaQuery.size.width - 32.0;
    const targetHeight = 56.0;

    final bgColor = Theme.of(context).colorScheme.surfaceContainerHigh;
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final searchText = _focusCoordinator.text;

    _updateSearchResultsState(() {
      _flyingSearchToTop = true;
    });

    _flyController?.dispose();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _flyOverlay?.remove();
    _flyOverlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _flyController!,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_flyController!.value);
          final left = lerpDouble(startOffset.dx, targetLeft, t)!;
          final top = lerpDouble(startOffset.dy, targetTop, t)!;
          final width = lerpDouble(startSize.width, targetWidth, t)!;
          final height = lerpDouble(startSize.height, targetHeight, t)!;
          final radius = lerpDouble(14, 16, t)!;
          final padding = lerpDouble(12, 16, t)!;
          final iconSize = lerpDouble(18, 24, t)!;

          return Positioned(
            left: left,
            top: top,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
                padding: EdgeInsets.symmetric(horizontal: padding),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.search, size: iconSize, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        searchText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    Overlay.of(context).insert(_flyOverlay!);
    unawaited(_scrollToTop());

    _flyController!.forward().then((_) {
      _flyOverlay?.remove();
      _flyOverlay = null;
      if (mounted) {
        _updateSearchResultsState(() {
          _flyingSearchToTop = false;
        });
      }
    });
  }
}
