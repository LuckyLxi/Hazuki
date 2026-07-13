import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'search_id_extract_pill.dart';

class SearchResultsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SearchResultsAppBar({
    super.key,
    required this.title,
    required this.orderLabels,
    required this.currentOrderLabel,
    required this.searchOrder,
    required this.onOrderMenuOpened,
    required this.onOrderSelected,
    this.showOrderControl = true,
  });

  final Widget title;
  final Map<String, String> orderLabels;
  final String currentOrderLabel;
  final String searchOrder;
  final VoidCallback onOrderMenuOpened;
  final ValueChanged<String> onOrderSelected;
  final bool showOrderControl;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return hazukiFrostedAppBar(
      context: context,
      enableBlur: false,
      title: title,
      actions: [
        if (showOrderControl)
          PopupMenuButton<String>(
            tooltip: currentOrderLabel,
            onOpened: onOrderMenuOpened,
            onSelected: onOrderSelected,
            itemBuilder: (context) => [
              for (final entry in orderLabels.entries)
                PopupMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.value)),
                      if (entry.key == searchOrder)
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
                    currentOrderLabel,
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
}

class SearchResultsBody extends StatelessWidget {
  const SearchResultsBody({
    super.key,
    required this.scrollController,
    required this.searchComics,
    required this.searchLoadingMore,
    required this.searchErrorMessage,
    required this.resultState,
    required this.onRefresh,
    required this.onScrollNotification,
    required this.itemBuilder,
    required this.onRetryPartialError,
  });

  final ScrollController scrollController;
  final List<ExploreComic> searchComics;
  final bool searchLoadingMore;
  final String? searchErrorMessage;
  final Widget resultState;
  final Future<void> Function() onRefresh;
  final bool Function(ScrollNotification notification) onScrollNotification;
  final Widget Function(ExploreComic comic, int index) itemBuilder;
  final Future<void> Function() onRetryPartialError;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return HazukiPullToRefresh(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: onScrollNotification,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            resultState,
            if (searchComics.isNotEmpty) ...[
              for (int i = 0; i < searchComics.length; i++)
                itemBuilder(searchComics[i], i),
            ],
            if (searchLoadingMore) const HazukiLoadMoreFooter(),
            if (searchErrorMessage != null && searchComics.isNotEmpty)
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
                          searchErrorMessage!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => unawaited(onRetryPartialError()),
                          child: Text(strings.commonRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SizedBox(height: searchLoadingMore ? 16 : 80),
          ],
        ),
      ),
    );
  }
}

class SearchResultsBackToTopButton extends StatelessWidget {
  const SearchResultsBackToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.2),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: FloatingActionButton(
              onPressed: onPressed,
              child: const Icon(Icons.keyboard_arrow_up),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchResultsIdExtractPill extends StatelessWidget {
  const SearchResultsIdExtractPill({
    super.key,
    required this.extractedId,
    required this.onApply,
  });

  final String? extractedId;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 12,
      child: SearchIdExtractPill(extractedId: extractedId, onApply: onApply),
    );
  }
}
