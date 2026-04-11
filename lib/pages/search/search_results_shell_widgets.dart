part of 'search_results_page.dart';

extension _SearchResultsShellWidgetsExtension on _SearchResultsPageState {
  Widget _buildSearchBar({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String clearKey,
    required String submitKey,
    required VoidCallback onClear,
    required ValueChanged<String> onChanged,
    bool compact = false,
  }) {
    final strings = AppLocalizations.of(context)!;
    final searchBar = SearchBar(
      focusNode: focusNode,
      controller: controller,
      hintText: strings.searchHint,
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
        ),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      ),
      leading: Icon(Icons.search, size: compact ? 20 : 24),
      trailing: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
                reverseCurve: Curves.easeInCubic,
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: controller.text.isNotEmpty
              ? IconButton(
                  key: ValueKey(clearKey),
                  tooltip: strings.searchClearTooltip,
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                )
              : IconButton(
                  key: ValueKey(submitKey),
                  tooltip: strings.searchSubmitTooltip,
                  onPressed: () => unawaited(_submitSearch()),
                  icon: const Icon(Icons.arrow_forward),
                ),
        ),
      ],
      onSubmitted: (value) => unawaited(_submitSearch(submittedText: value)),
      onChanged: onChanged,
    );

    if (!compact) {
      return SizedBox(height: 56, child: searchBar);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 40),
      child: searchBar,
    );
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchRevealProgress);
    final visible = !_flyingSearchToTop;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: IgnorePointer(
        ignoring: _showCollapsedSearch || !visible,
        child: Opacity(
          opacity: visible ? 1 - hideProgress : 0,
          child: Transform.translate(
            offset: Offset(0, -10 * hideProgress),
            child: Transform.scale(
              scale: 1 - 0.04 * hideProgress,
              alignment: Alignment.topCenter,
              child: HeroMode(
                enabled: !_showCollapsedSearch && visible,
                child: Hero(
                  tag: discoverSearchHeroTag,
                  child: _buildSearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    clearKey: 'results-clear',
                    submitKey: 'results-submit',
                    onClear: () {
                      _clearSearch();
                      _updateSearchResultsState(() {});
                    },
                    onChanged: (value) {
                      _syncSearchText(value, updateExpanded: false);
                      _updateSearchResultsState(() {});
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSearchPreview() {
    final theme = Theme.of(context);
    final text = _searchKeyword.isEmpty
        ? AppLocalizations.of(context)!.searchHint
        : _searchKeyword;
    final textColor = _searchKeyword.isEmpty
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _expandCollapsedSearch,
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

  Widget _buildCollapsedSearchBox({
    required double collapsedWidth,
    required double expandedWidth,
  }) {
    final visible = _showCollapsedSearch && !_flyingSearchToTop;
    final currentWidth = _collapsedSearchExpanded
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
                      key: _collapsedSearchKey,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: currentWidth,
                      child: _collapsedSearchExpanded
                          ? _buildSearchBar(
                              controller: _collapsedSearchController,
                              focusNode: _collapsedSearchFocusNode,
                              clearKey: 'results-collapsed-clear',
                              submitKey: 'results-collapsed-submit',
                              compact: true,
                              onClear: () {
                                _collapsedSearchController.clear();
                                _syncSearchText('', updateCollapsed: false);
                                _updateSearchResultsState(() {});
                              },
                              onChanged: (value) {
                                _syncSearchText(value, updateCollapsed: false);
                                _updateSearchResultsState(() {});
                              },
                            )
                          : _buildCollapsedSearchPreview(),
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

  Widget _buildSearchResultsAppBarTitle() {
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
              _showCollapsedSearch &&
                  !_collapsedSearchExpanded &&
                  !_flyingSearchToTop
              ? collapsedWidth + collapsedGap
              : 0.0;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: _collapsedSearchExpanded ? 0 : 1,
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

  Widget _buildSearchResultState() {
    return SearchResultsStateView(
      searchKeyword: _searchKeyword,
      searchLoading: _searchLoading,
      searchComics: _searchComics,
      searchErrorMessage: _searchErrorMessage,
      onRetry: () =>
          _resultsController.search(context, keyword: _searchKeyword, page: 1),
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
