import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../state/discover_section_page_controller.dart';
import 'discover_section_date_selector.dart';

/// 专栏筛选栏：每组一行可横向滑动的紧凑胶囊，放在列表头部随内容滚动
class DiscoverSectionSortBar extends StatelessWidget {
  const DiscoverSectionSortBar({
    super.key,
    required this.sortOptions,
    this.sortOptionGroups = const <List<CategoryRankingOption>>[],
    this.useDateMorphSelector = false,
    required this.selectedSortValue,
    this.selectedSortValues = const <String>[],
    required this.onSelectSortOption,
    this.onSelectSortOptionInGroup,
  });

  final List<CategoryRankingOption> sortOptions;
  final List<List<CategoryRankingOption>> sortOptionGroups;
  final bool useDateMorphSelector;
  final String? selectedSortValue;
  final List<String> selectedSortValues;
  final ValueChanged<String> onSelectSortOption;
  final void Function(int groupIndex, String value)? onSelectSortOptionInGroup;

  @override
  Widget build(BuildContext context) {
    final groups = sortOptionGroups.isEmpty
        ? <List<CategoryRankingOption>>[sortOptions]
        : sortOptionGroups;
    final dateGroupIndex = useDateMorphSelector
        ? groups.indexWhere((group) => group.isNotEmpty)
        : -1;
    // 胶囊行横向贴边滚动，左右留白放在行内而不是外层
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
            if (groups[groupIndex].isNotEmpty && groupIndex != dateGroupIndex)
              Padding(
                padding: EdgeInsets.only(
                  bottom: groupIndex == groups.length - 1 ? 0 : 8,
                ),
                child: _DiscoverSectionChipGroup(
                  groupIndex: groupIndex,
                  options: groups[groupIndex],
                  selectedValue: selectedSortValues.length > groupIndex
                      ? selectedSortValues[groupIndex]
                      : selectedSortValue,
                  onSelected: (value) {
                    final handler = onSelectSortOptionInGroup;
                    if (handler != null) {
                      handler(groupIndex, value);
                      return;
                    }
                    onSelectSortOption(value);
                  },
                ),
              ),
          if (dateGroupIndex >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DiscoverSectionDateSelector(
                options: groups[dateGroupIndex],
                selectedValue: selectedSortValues.length > dateGroupIndex
                    ? selectedSortValues[dateGroupIndex]
                    : selectedSortValue,
                onSelected: (value) {
                  final handler = onSelectSortOptionInGroup;
                  if (handler != null) {
                    handler(dateGroupIndex, value);
                    return;
                  }
                  onSelectSortOption(value);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoverSectionChipGroup extends StatelessWidget {
  const _DiscoverSectionChipGroup({
    required this.groupIndex,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  static const double _height = 34;

  final int groupIndex;
  final List<CategoryRankingOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // 选中值不在选项中时沿用首项高亮，与插件默认排序保持一致
    final selectedIndex = math.max(
      0,
      options.indexWhere((option) => option.value == selectedValue),
    );
    return SizedBox(
      key: ValueKey<String>('discover_section_sort_group_$groupIndex'),
      height: _height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < options.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              _DiscoverSectionChip(
                key: ValueKey<String>(
                  'discover_section_sort_option_${groupIndex}_${options[index].value}',
                ),
                label: options[index].label,
                selected: index == selectedIndex,
                onTap: () => onSelected(options[index].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiscoverSectionChip extends StatelessWidget {
  const _DiscoverSectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // 选中与未选中使用相同字重，避免切换时胶囊宽度跳动
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  style: (theme.textTheme.labelLarge ?? const TextStyle())
                      .copyWith(
                        color: selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ),
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
    this.topPadding = 16,
    this.scrollHeader,
  });

  static const int _gridCrossAxisCount = 3;
  static const double _gridSpacing = 10;
  static const double _windowsMaxCoverExtent = 170;

  final DiscoverSectionPageController controller;
  final ScrollController scrollController;
  final ExploreSection section;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final double topPadding;
  final Widget? scrollHeader;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final emptyContent = (controller.loadingMore || controller.sortLoading)
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
        : Center(child: Text(strings.discoverSectionEmpty));
    if (controller.comics.isEmpty && scrollHeader == null) {
      return emptyContent;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useWindowsLayout =
            Theme.of(context).platform == TargetPlatform.windows;
        final contentWidth = constraints.maxWidth - 32;
        final coverWidth = useWindowsLayout
            ? _windowsMaxCoverExtent
            : (contentWidth - (_gridCrossAxisCount - 1) * _gridSpacing) /
                  _gridCrossAxisCount;
        final coverCacheWidth =
            (coverWidth * MediaQuery.devicePixelRatioOf(context)).round();
        final SliverGridDelegate gridDelegate = useWindowsLayout
            ? const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _windowsMaxCoverExtent,
                mainAxisSpacing: _gridSpacing,
                crossAxisSpacing: _gridSpacing,
                childAspectRatio: 0.57,
              )
            : const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridCrossAxisCount,
                mainAxisSpacing: _gridSpacing,
                crossAxisSpacing: _gridSpacing,
                childAspectRatio: 0.57,
              );

        final childrenDelegate = SliverChildBuilderDelegate(
          (context, index) {
            final comic = controller.comics[index];
            final heroTag = comicCoverHeroTagBuilder(
              comic,
              salt: 'discover-more-${section.title}-$index',
            );
            final entryKey = _comicEntryKey(comic, index);
            return ComicCoverTile(
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
          childCount: controller.comics.length,
          addAutomaticKeepAlives: false,
        );
        // 加载更多指示器作为网格之后的独立 sliver，排在漫画下方而不是叠在封面上
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            if (scrollHeader != null) SliverToBoxAdapter(child: scrollHeader),
            if (controller.comics.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: emptyContent)
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, topPadding, 16, 12),
                sliver: SliverGrid(
                  gridDelegate: gridDelegate,
                  delegate: childrenDelegate,
                ),
              ),
            if (controller.showLoadMoreFooter && controller.comics.isNotEmpty)
              const SliverToBoxAdapter(
                child: HazukiLoadMoreFooter(verticalPadding: 4),
              ),
          ],
        );
      },
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

class DiscoverSectionIssueNavigationButtons extends StatelessWidget {
  const DiscoverSectionIssueNavigationButtons({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<CategoryRankingOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final selectedIndex = options.indexWhere(
      (option) => option.value == selectedValue,
    );
    final normalizedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final hasPreviousIssue = normalizedIndex > 0;
    final hasNextIssue = normalizedIndex < options.length - 1;

    return Positioned(
      right: 16,
      bottom: 16 + MediaQuery.paddingOf(context).bottom,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            key: const ValueKey<String>('weekly_date_previous'),
            heroTag: 'weekly_date_previous',
            tooltip: strings.discoverSectionPreviousIssue,
            onPressed: hasPreviousIssue
                ? () => onSelected(options[normalizedIndex - 1].value)
                : null,
            child: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            key: const ValueKey<String>('weekly_date_next'),
            heroTag: 'weekly_date_next',
            tooltip: strings.discoverSectionNextIssue,
            onPressed: hasNextIssue
                ? () => onSelected(options[normalizedIndex + 1].value)
                : null,
            child: const Icon(Icons.chevron_right_rounded),
          ),
        ],
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
