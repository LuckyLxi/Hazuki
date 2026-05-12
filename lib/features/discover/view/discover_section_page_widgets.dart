import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../state/discover_section_page_controller.dart';
import 'discover_comic_tile.dart';

class DiscoverSectionSortBar extends StatelessWidget {
  const DiscoverSectionSortBar({
    super.key,
    required this.sortOptions,
    required this.selectedSortValue,
    required this.onSelectSortOption,
  });

  final List<CategoryRankingOption> sortOptions;
  final String? selectedSortValue;
  final ValueChanged<String> onSelectSortOption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in sortOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: selectedSortValue == option.value,
                    onSelected: (_) => onSelectSortOption(option.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverSectionContent extends StatelessWidget {
  const DiscoverSectionContent({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.section,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  static const int _gridCrossAxisCount = 3;
  static const double _gridSpacing = 10;

  final DiscoverSectionPageController controller;
  final ScrollController scrollController;
  final ExploreSection section;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: controller.comics.isEmpty
          ? (controller.loadingMore || controller.sortLoading)
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HazukiSandyLoadingIndicator(size: 168),
                        const SizedBox(height: 10),
                        Text(strings.commonLoading),
                      ],
                    ),
                  )
                : Center(child: Text(strings.discoverSectionEmpty))
          : LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = constraints.maxWidth - 32;
                final coverWidth =
                    (contentWidth - (_gridCrossAxisCount - 1) * _gridSpacing) /
                    _gridCrossAxisCount;
                final coverCacheWidth =
                    (coverWidth * MediaQuery.devicePixelRatioOf(context))
                        .round();

                return GridView.builder(
                  controller: scrollController,
                  addAutomaticKeepAlives: false,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: controller.comics.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridCrossAxisCount,
                    mainAxisSpacing: _gridSpacing,
                    crossAxisSpacing: _gridSpacing,
                    childAspectRatio: 0.57,
                  ),
                  itemBuilder: (context, index) {
                    final comic = controller.comics[index];
                    final heroTag = comicCoverHeroTagBuilder(
                      comic,
                      salt: 'discover-more-${section.title}-$index',
                    );
                    final entryKey = _comicEntryKey(comic, index);
                    return DiscoverComicCoverTile(
                      key: ValueKey<String>('tile-$entryKey'),
                      comic: comic,
                      heroTag: heroTag,
                      coverCacheWidth: coverCacheWidth,
                      placeholderColor: colorScheme.surfaceContainerHighest,
                      onTap: () => openComicDetail(
                        context,
                        comic: comic,
                        heroTag: heroTag,
                        pageBuilder: comicDetailPageBuilder,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class DiscoverSectionLoadMoreFooterOverlay extends StatelessWidget {
  const DiscoverSectionLoadMoreFooterOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: 8,
      child: IgnorePointer(child: HazukiLoadMoreFooter(verticalPadding: 4)),
    );
  }
}

class DiscoverSectionErrorOverlay extends StatelessWidget {
  const DiscoverSectionErrorOverlay({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  final String errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    errorMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  child: Text(strings.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoverSectionBackToTopButton extends StatelessWidget {
  const DiscoverSectionBackToTopButton({
    super.key,
    required this.showBackToTop,
    required this.onPressed,
  });

  final bool showBackToTop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: RepaintBoundary(
        child: AnimatedSlide(
          offset: showBackToTop ? Offset.zero : const Offset(0, 0.24),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedScale(
            scale: showBackToTop ? 1 : 0.86,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: showBackToTop ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !showBackToTop,
                child: FloatingActionButton(
                  heroTag: 'discover_section_back_to_top',
                  onPressed: onPressed,
                  child: const Icon(Icons.vertical_align_top_rounded),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _comicEntryKey(ExploreComic comic, int index) {
  final comicId = comic.id.trim();
  if (comicId.isNotEmpty) return 'comic:$comicId';
  final cover = comic.cover.trim();
  if (cover.isNotEmpty) return 'cover:$cover';
  return 'fallback:${comic.title}|$index';
}
