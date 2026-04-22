import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hazuki/app/navigation_tags.dart';
import 'package:hazuki/l10n/app_localizations.dart';

class SearchResultsTopSearchBox extends StatelessWidget {
  const SearchResultsTopSearchBox({
    super.key,
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

class SearchResultsAppBarTitle extends StatelessWidget {
  const SearchResultsAppBarTitle({
    super.key,
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
