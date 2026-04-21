part of 'search_results_page.dart';

class _SearchResultsTopSearchBox extends StatelessWidget {
  const _SearchResultsTopSearchBox({
    required this.revealProgress,
    required this.showCollapsedSearch,
    required this.flyingSearchToTop,
    required this.searchBar,
  });

  final double revealProgress;
  final bool showCollapsedSearch;
  final bool flyingSearchToTop;
  final Widget searchBar;

  @override
  Widget build(BuildContext context) {
    final hideProgress = Curves.easeOutCubic.transform(revealProgress);
    final visible = !flyingSearchToTop;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: IgnorePointer(
        ignoring: showCollapsedSearch || !visible,
        child: Opacity(
          opacity: visible ? 1 - hideProgress : 0,
          child: Transform.translate(
            offset: Offset(0, -10 * hideProgress),
            child: Transform.scale(
              scale: 1 - 0.04 * hideProgress,
              alignment: Alignment.topCenter,
              child: HeroMode(
                enabled: !showCollapsedSearch && visible,
                child: Hero(tag: discoverSearchHeroTag, child: searchBar),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultsAppBarTitle extends StatelessWidget {
  const _SearchResultsAppBarTitle({
    required this.showCollapsedSearch,
    required this.collapsedSearchExpanded,
    required this.flyingSearchToTop,
    required this.searchKeyword,
    required this.collapsedSearchKey,
    required this.collapsedSearchBar,
    required this.onExpandCollapsedSearch,
  });

  final bool showCollapsedSearch;
  final bool collapsedSearchExpanded;
  final bool flyingSearchToTop;
  final String searchKeyword;
  final GlobalKey collapsedSearchKey;
  final Widget collapsedSearchBar;
  final VoidCallback onExpandCollapsedSearch;

  Widget _buildCollapsedSearchPreview(BuildContext context) {
    final theme = Theme.of(context);
    final text = searchKeyword.isEmpty
        ? AppLocalizations.of(context)!.searchHint
        : searchKeyword;
    final textColor = searchKeyword.isEmpty
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    return Material(
      key: const ValueKey('search-results-collapsed-preview'),
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onExpandCollapsedSearch,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSearchBox(
    BuildContext context, {
    required double collapsedWidth,
    required double expandedWidth,
  }) {
    final visible = showCollapsedSearch && !flyingSearchToTop;
    final currentWidth = collapsedSearchExpanded
        ? expandedWidth
        : collapsedWidth;
    return HeroMode(
      enabled: visible,
      child: Hero(
        tag: discoverSearchHeroTag,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: visible ? currentWidth : 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(-0.08, 0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedScale(
                scale: visible ? 1 : 0.94,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedContainer(
                      key: collapsedSearchKey,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: currentWidth,
                      child: collapsedSearchExpanded
                          ? collapsedSearchBar
                          : _buildCollapsedSearchPreview(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          const preferredCollapsedWidth = 188.0;
          const collapsedGap = 12.0;
          final titlePainter = TextPainter(
            text: TextSpan(
              text: strings.searchTitle,
              style: DefaultTextStyle.of(context).style,
            ),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: maxWidth);
          final reservedTitleWidth = titlePainter.width.ceilToDouble();
          final collapsedWidth = math.min(
            preferredCollapsedWidth,
            math.max(0.0, maxWidth - reservedTitleWidth - collapsedGap),
          );
          final expandedWidth = maxWidth;
          final reserveForCollapsedPreview =
              showCollapsedSearch &&
                  !collapsedSearchExpanded &&
                  !flyingSearchToTop
              ? collapsedWidth + collapsedGap
              : 0.0;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: collapsedSearchExpanded ? 0 : 1,
                child: Padding(
                  padding: EdgeInsets.only(right: reserveForCollapsedPreview),
                  child: Text(
                    strings.searchTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _buildCollapsedSearchBox(
                  context,
                  collapsedWidth: collapsedWidth,
                  expandedWidth: expandedWidth,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _SearchResultsShellWidgetsExtension on _SearchResultsPageState {
  Widget _buildSearchBar({
    Key? key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String clearKey,
    required String submitKey,
    required VoidCallback onClear,
    required ValueChanged<String> onChanged,
    bool compact = false,
  }) {
    return SearchBarShell(
      key: key,
      controller: controller,
      focusNode: focusNode,
      clearKey: clearKey,
      submitKey: submitKey,
      compact: compact,
      onClear: onClear,
      onSubmit: () => unawaited(_submitSearch()),
      onSubmitted: (value) => unawaited(_submitSearch(submittedText: value)),
      onChanged: onChanged,
    );
  }

  Widget _buildTopSearchBox() {
    return _SearchResultsTopSearchBox(
      revealProgress: _searchRevealProgress,
      showCollapsedSearch: _showCollapsedSearch,
      flyingSearchToTop: _flyingSearchToTop,
      searchBar: _buildSearchBar(
        key: const ValueKey('search-results-primary-search-bar'),
        controller: _focusCoordinator.primaryController,
        focusNode: _focusCoordinator.primaryFocusNode,
        clearKey: 'results-clear',
        submitKey: 'results-submit',
        onClear: _clearSearch,
        onChanged: (value) {
          _focusCoordinator.syncText(value, updatePrimary: false);
        },
      ),
    );
  }

  Widget _buildSearchResultsAppBarTitle() {
    return _SearchResultsAppBarTitle(
      showCollapsedSearch: _showCollapsedSearch,
      collapsedSearchExpanded: _collapsedSearchExpanded,
      flyingSearchToTop: _flyingSearchToTop,
      searchKeyword: _searchKeyword,
      collapsedSearchKey: _collapsedSearchKey,
      collapsedSearchBar: _buildSearchBar(
        key: const ValueKey('search-results-collapsed-search-bar'),
        controller: _focusCoordinator.collapsedController,
        focusNode: _focusCoordinator.collapsedFocusNode,
        clearKey: 'results-collapsed-clear',
        submitKey: 'results-collapsed-submit',
        compact: true,
        onClear: _focusCoordinator.clearText,
        onChanged: (value) {
          _focusCoordinator.syncText(value, updateCollapsed: false);
        },
      ),
      onExpandCollapsedSearch: _expandCollapsedSearch,
    );
  }

  Widget _buildSearchResultState() {
    return SearchResultsStateView(
      searchKeyword: _searchKeyword,
      searchLoading: _searchLoading,
      searchComics: _searchComics,
      searchErrorMessage: _searchErrorMessage,
      sourceRuntimeState: HazukiSourceService.instance.sourceRuntimeState,
      onRetry: () {
        if (HazukiSourceService.instance.sourceRuntimeState.canRetry) {
          HazukiSourceService.instance.logRuntimeRetryRequested(
            'search_results_page',
          );
        }
        return _resultsController.search(
          context,
          keyword: _searchKeyword,
          page: 1,
        );
      },
    );
  }

  Widget _buildSearchComicItem(ExploreComic comic, int index) {
    final heroTag = widget.comicCoverHeroTagBuilder(
      comic,
      salt: 'search-results',
    );
    return SearchComicListItem(
      comic: comic,
      heroTag: heroTag,
      index: index,
      onTap: () {
        unawaited(
          openComicDetail(
            context,
            comic: comic,
            heroTag: heroTag,
            pageBuilder: widget.comicDetailPageBuilder,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildSearchResultsAppBar() {
    final orderLabels = searchOrderLabels(context);
    return hazukiFrostedAppBar(
      context: context,
      enableBlur: false,
      title: _buildSearchResultsAppBarTitle(),
      actions: [
        PopupMenuButton<String>(
          tooltip: _currentSearchOrderLabel,
          onSelected: (order) {
            unawaited(_onSearchOrderSelected(order));
          },
          itemBuilder: (context) => [
            for (final entry in orderLabels.entries)
              PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Expanded(child: Text(entry.value)),
                    if (entry.key == _searchOrder)
                      Icon(
                        Icons.check,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSearchOrderLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.swap_vert, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsBody() {
    final strings = AppLocalizations.of(context)!;
    return HazukiPullToRefresh(
      onRefresh: () async {
        if (_searchKeyword.isEmpty) {
          await _submitSearch();
          return;
        }
        await _resultsController.search(
          context,
          keyword: _searchKeyword,
          page: 1,
          silentRefresh: _searchComics.isNotEmpty,
        );
      },
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _buildTopSearchBox(),
          const SizedBox(height: 6),
          if (_searchComics.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchKeyword,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _currentSearchOrderLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          _buildSearchResultState(),
          if (_searchComics.isNotEmpty) ...[
            for (int i = 0; i < _searchComics.length; i++)
              _buildSearchComicItem(_searchComics[i], i),
          ],
          if (_searchLoadingMore) const HazukiLoadMoreFooter(),
          if (_searchErrorMessage != null && _searchComics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchErrorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => unawaited(
                          _resultsController.search(
                            context,
                            keyword: _searchKeyword,
                            page: 1,
                          ),
                        ),
                        child: Text(strings.commonRetry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(height: _searchLoadingMore ? 16 : 80),
        ],
      ),
    );
  }

  Widget _buildSearchBackToTopButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: IgnorePointer(
        ignoring: !_showBackToTop,
        child: AnimatedSlide(
          offset: _showBackToTop ? Offset.zero : const Offset(0, 1.2),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _showBackToTop ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: FloatingActionButton(
              onPressed: () => unawaited(_scrollToTop()),
              child: const Icon(Icons.keyboard_arrow_up),
            ),
          ),
        ),
      ),
    );
  }
}
