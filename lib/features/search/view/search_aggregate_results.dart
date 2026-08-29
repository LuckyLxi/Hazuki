import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

import '../state/aggregate_search_results_controller.dart';
import '../support/search_shared.dart';
import 'search_results_page_widgets.dart';

class SearchAggregateResultsBody extends StatelessWidget {
  const SearchAggregateResultsBody({
    super.key,
    required this.scrollController,
    required this.sections,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.onRetry,
    required this.onLoadMore,
    required this.onComicTap,
    required this.onViewMore,
    required this.heroTagBuilder,
  });

  final ScrollController scrollController;
  final List<AggregateSearchSectionState> sections;
  final Future<void> Function() onRefresh;
  final bool Function(ScrollNotification notification) onScrollNotification;
  final ValueChanged<AggregateSearchSectionState> onRetry;
  final ValueChanged<AggregateSearchSectionState> onLoadMore;
  final Future<void> Function(ExploreComic comic, String heroTag) onComicTap;
  final ValueChanged<AggregateSearchSectionState> onViewMore;
  final String Function(ExploreComic comic, String salt) heroTagBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView.builder(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: sections.length,
          itemBuilder: (context, index) {
            final section = sections[index];
            return _AggregateSourceSection(
              key: ValueKey('aggregate-search-${section.source.key}'),
              section: section,
              sectionIndex: index,
              onRetry: () => onRetry(section),
              onLoadMore: () => onLoadMore(section),
              onComicTap: onComicTap,
              onViewMore: () => onViewMore(section),
              heroTagBuilder: heroTagBuilder,
            );
          },
        ),
      ),
    );
  }
}

class _AggregateSourceSection extends StatefulWidget {
  const _AggregateSourceSection({
    super.key,
    required this.section,
    required this.sectionIndex,
    required this.onRetry,
    required this.onLoadMore,
    required this.onComicTap,
    required this.onViewMore,
    required this.heroTagBuilder,
  });

  final AggregateSearchSectionState section;
  final int sectionIndex;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Future<void> Function(ExploreComic comic, String heroTag) onComicTap;
  final VoidCallback onViewMore;
  final String Function(ExploreComic comic, String salt) heroTagBuilder;

  @override
  State<_AggregateSourceSection> createState() =>
      _AggregateSourceSectionState();
}

class _AggregateSourceSectionState extends State<_AggregateSourceSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        widget.section.loading ||
        widget.section.loadingMore ||
        !widget.section.hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.section.source.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (widget.section.comics.isNotEmpty)
                  TextButton(
                    key: ValueKey(
                      'aggregate-search-more-${widget.section.source.key}',
                    ),
                    onPressed: widget.onViewMore,
                    child: Text(AppLocalizations.of(context)!.discoverMore),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final section = widget.section;
    if (section.loading && section.comics.isEmpty) {
      return const SizedBox(
        key: ValueKey('loading'),
        height: 228,
        child: Center(
          child: SizedBox.square(dimension: 52, child: LoadingIndicatorM3E()),
        ),
      );
    }
    if (section.errorMessage != null && section.comics.isEmpty) {
      return _AggregateSectionMessage(
        key: const ValueKey('error'),
        icon: Icons.error_outline_rounded,
        message: section.errorMessage!,
        actionLabel: AppLocalizations.of(context)!.commonRetry,
        onAction: widget.onRetry,
      );
    }
    if (section.comics.isEmpty) {
      return _AggregateSectionMessage(
        key: const ValueKey('empty'),
        icon: Icons.search_off_rounded,
        message: AppLocalizations.of(context)!.searchEmpty,
      );
    }

    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();
    return SizedBox(
      key: const ValueKey('results'),
      height: 228,
      child: ListView.separated(
        controller: _scrollController,
        key: PageStorageKey<String>(
          'aggregate-search-section-${section.source.normalizedKey}',
        ),
        scrollDirection: Axis.horizontal,
        itemCount: section.comics.length + (section.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index >= section.comics.length) {
            return const SizedBox(
              width: 64,
              child: Padding(
                padding: EdgeInsets.only(bottom: 56),
                child: Center(
                  child: SizedBox.square(
                    dimension: 48,
                    child: LoadingIndicatorM3E(),
                  ),
                ),
              ),
            );
          }
          final comic = section.comics[index];
          final heroTag = widget.heroTagBuilder(
            comic,
            'aggregate-search-${section.source.normalizedKey}-$index',
          );
          return SizedBox(
            width: 130,
            child: ComicCoverTile(
              comic: comic,
              heroTag: heroTag,
              coverCacheWidth: coverCacheWidth,
              placeholderColor: placeholderColor,
              onTap: () => widget.onComicTap(comic, heroTag),
            ),
          );
        },
      ),
    );
  }
}

class SearchAggregateSectionPage extends StatefulWidget {
  const SearchAggregateSectionPage({
    super.key,
    required this.controller,
    required this.section,
    required this.onComicTap,
    required this.heroTagBuilder,
  });

  final AggregateSearchResultsController controller;
  final AggregateSearchSectionState section;
  final Future<void> Function(ExploreComic comic, String heroTag) onComicTap;
  final String Function(ExploreComic comic, String salt) heroTagBuilder;

  @override
  State<SearchAggregateSectionPage> createState() =>
      _SearchAggregateSectionPageState();
}

class _SearchAggregateSectionPageState
    extends State<SearchAggregateSectionPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        widget.section.loadingMore ||
        !widget.section.hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      widget.controller.loadMore(context, widget.section);
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    return WindowsComicDetailHost(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final orderLabels = searchOrderLabels(
            context,
            sourceKey: section.source.normalizedKey,
          );
          return Scaffold(
            appBar: SearchResultsAppBar(
              title: Text(section.source.name),
              orderLabels: orderLabels,
              currentOrderLabel: orderLabels[section.order] ?? section.order,
              searchOrder: section.order,
              onOrderMenuOpened: () {},
              onOrderSelected: (order) {
                unawaited(
                  widget.controller.changeOrder(context, section, order),
                );
              },
            ),
            body: _buildBody(context),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final section = widget.section;
    final colorScheme = Theme.of(context).colorScheme;
    if (section.loading && section.comics.isEmpty) {
      return const Center(
        child: SizedBox.square(dimension: 52, child: LoadingIndicatorM3E()),
      );
    }
    if (section.errorMessage != null && section.comics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _AggregateSectionMessage(
            icon: Icons.error_outline_rounded,
            message: section.errorMessage!,
            actionLabel: AppLocalizations.of(context)!.commonRetry,
            onAction: () => widget.controller.retry(context, section),
          ),
        ),
      );
    }
    if (section.comics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _AggregateSectionMessage(
            icon: Icons.search_off_rounded,
            message: AppLocalizations.of(context)!.searchEmpty,
          ),
        ),
      );
    }
    return Stack(
      children: [
        GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: section.comics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.57,
          ),
          itemBuilder: (context, index) {
            final comic = section.comics[index];
            final heroTag = widget.heroTagBuilder(
              comic,
              'aggregate-search-more-${section.source.normalizedKey}-$index',
            );
            final contentWidth = MediaQuery.sizeOf(context).width - 52;
            final coverCacheWidth =
                (contentWidth / 3 * MediaQuery.devicePixelRatioOf(context))
                    .round();
            return ComicCoverTile(
              comic: comic,
              heroTag: heroTag,
              coverCacheWidth: coverCacheWidth,
              placeholderColor: colorScheme.surfaceContainerHighest,
              onTap: () => widget.onComicTap(comic, heroTag),
            );
          },
        ),
        if (section.loadingMore)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: HazukiLoadMoreFooter(verticalPadding: 4),
            ),
          ),
        if (section.errorMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.controller.loadMore(context, section),
                      child: Text(AppLocalizations.of(context)!.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AggregateSectionMessage extends StatelessWidget {
  const _AggregateSectionMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 132,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
