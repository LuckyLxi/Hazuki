import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/app/app.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'discover_section_page.dart';

class DiscoverTopSearchBox extends StatelessWidget {
  const DiscoverTopSearchBox({
    super.key,
    required this.searchMorphProgress,
    required this.onOpenSearch,
  });

  final double searchMorphProgress;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final hideProgress = Curves.easeOutCubic.transform(searchMorphProgress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: 1 - hideProgress,
        child: Transform.translate(
          offset: Offset(0, -10 * hideProgress),
          child: Transform.scale(
            scale: 1 - 0.04 * hideProgress,
            alignment: Alignment.topCenter,
            child: _DiscoverSearchBox(
              height: 56,
              borderRadius: 16,
              horizontalPadding: 16,
              onTap: searchMorphProgress >= 0.96 ? null : onOpenSearch,
              heroEnabled: searchMorphProgress < 0.96,
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoverStateView extends StatelessWidget {
  const DiscoverStateView({
    super.key,
    required this.initialLoading,
    required this.refreshing,
    required this.sections,
    required this.errorMessage,
    required this.allowInitialLoad,
    required this.hideLoadingUntilInitialLoadAllowed,
    required this.onRetry,
  });

  final bool initialLoading;
  final bool refreshing;
  final List<ExploreSection> sections;
  final String? errorMessage;
  final bool allowInitialLoad;
  final bool hideLoadingUntilInitialLoadAllowed;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final sourceRuntimeState = HazukiSourceService.instance.sourceRuntimeState;
    final showBlockingLoading =
        initialLoading || (refreshing && sections.isEmpty);
    late final Widget child;

    if (showBlockingLoading) {
      if (shouldShowSourceRuntimeStatusCard(sourceRuntimeState)) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('discover-source-runtime-loading'),
          state: sourceRuntimeState,
          minHeight: 360,
        );
      } else if (!allowInitialLoad && hideLoadingUntilInitialLoadAllowed) {
        child = const SizedBox(
          key: ValueKey('discover-placeholder'),
          height: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('discover-loading'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HazukiSandyLoadingIndicator(size: 136),
                const SizedBox(height: 10),
                Text(strings.commonLoading),
              ],
            ),
          ),
        );
      }
    } else if (errorMessage != null && sections.isEmpty) {
      if (shouldShowSourceRuntimeStatusCard(
        sourceRuntimeState,
        fallbackError: errorMessage,
      )) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('discover-source-runtime-error'),
          state: sourceRuntimeState,
          fallbackError: errorMessage,
          onRetry: onRetry,
          minHeight: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('discover-error'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(errorMessage!, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(strings.commonRetry),
                ),
              ],
            ),
          ),
        );
      }
    } else if (sections.isEmpty) {
      child = SizedBox(
        key: const ValueKey('discover-empty'),
        height: 220,
        child: Center(child: Text(strings.discoverEmpty)),
      );
    } else {
      child = const SizedBox(key: ValueKey('discover-hidden'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            ...<Widget?>[currentChild].whereType<Widget>(),
          ],
        );
      },
      child: child,
    );
  }
}

class DiscoverSectionBlock extends StatelessWidget {
  const DiscoverSectionBlock({
    super.key,
    required this.section,
    required this.sectionIndex,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final ExploreSection section;
  final int sectionIndex;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(section.title, style: theme.textTheme.titleMedium),
              ),
              if (section.comics.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscoverSectionPage(
                          section: section,
                          comicDetailPageBuilder: comicDetailPageBuilder,
                          comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
                        ),
                      ),
                    );
                  },
                  child: Text(strings.discoverMore),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: ListView.separated(
              key: PageStorageKey<String>(
                'discover-section-$sectionIndex-${section.title}',
              ),
              scrollDirection: Axis.horizontal,
              itemCount: section.comics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comic = section.comics[index];
                final heroTag = comicCoverHeroTagBuilder(
                  comic,
                  salt: 'discover-$sectionIndex-${section.title}-$index',
                );
                return SizedBox(
                  width: 130,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      unawaited(
                        openComicDetail(
                          context,
                          comic: comic,
                          heroTag: heroTag,
                          pageBuilder: comicDetailPageBuilder,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              clipBehavior: Clip.hardEdge,
                              borderRadius: BorderRadius.circular(8),
                              child: comic.cover.isEmpty
                                  ? ColoredBox(
                                      color: placeholderColor,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                                    )
                                  : HazukiCachedImage(
                                      url: comic.cover,
                                      fit: BoxFit.cover,
                                      width: 130,
                                      cacheWidth: coverCacheWidth,
                                      animateOnLoad: true,
                                      filterQuality: FilterQuality.low,
                                      deferLoadingWhileScrolling: true,
                                      loading: SizedBox.expand(
                                        child: ColoredBox(
                                          color: placeholderColor,
                                        ),
                                      ),
                                      error: ColoredBox(
                                        color: placeholderColor,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          comic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (comic.subTitle.isNotEmpty)
                          Text(
                            comic.subTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSearchBox extends StatelessWidget {
  const _DiscoverSearchBox({
    required this.height,
    required this.borderRadius,
    required this.horizontalPadding,
    required this.onTap,
    required this.heroEnabled,
  });

  final double height;
  final double borderRadius;
  final double horizontalPadding;
  final VoidCallback? onTap;
  final bool heroEnabled;
  @override
  Widget build(BuildContext context) {
    return HeroMode(
      enabled: heroEnabled,
      child: Hero(
        tag: discoverSearchHeroTag,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: IgnorePointer(
            child: SizedBox(
              height: height,
              child: SearchBar(
                hintText: AppLocalizations.of(context)!.searchHint,
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: horizontalPadding),
                ),
                leading: const Icon(Icons.search),
                trailing: const [Icon(Icons.arrow_forward)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
