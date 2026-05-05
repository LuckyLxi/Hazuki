import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:lottie/lottie.dart';

class SearchResultsStateView extends StatelessWidget {
  const SearchResultsStateView({
    super.key,
    required this.searchKeyword,
    required this.searchLoading,
    required this.searchComics,
    required this.searchErrorMessage,
    required this.sourceRuntimeState,
    required this.onRetry,
  });

  final String searchKeyword;
  final bool searchLoading;
  final List<ExploreComic> searchComics;
  final String? searchErrorMessage;
  final SourceRuntimeState sourceRuntimeState;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    late final Widget child;

    if (searchKeyword.isEmpty) {
      child = SizedBox(
        key: const ValueKey('search-idle'),
        height: 240,
        child: Center(child: Text(strings.searchStartPrompt)),
      );
    } else if (searchLoading && searchComics.isEmpty) {
      if (shouldShowSourceRuntimeStatusCard(sourceRuntimeState)) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('search-source-runtime-loading'),
          state: sourceRuntimeState,
          minHeight: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('search-loading'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HazukiSearchingAnimationIndicator(size: 156),
                const SizedBox(height: 12),
                Text(strings.searchLoading),
              ],
            ),
          ),
        );
      }
    } else if (searchErrorMessage != null && searchComics.isEmpty) {
      if (shouldShowSourceRuntimeStatusCard(
        sourceRuntimeState,
        fallbackError: searchErrorMessage,
      )) {
        child = SourceRuntimeStatusCard(
          key: const ValueKey('search-source-runtime-error'),
          state: sourceRuntimeState,
          fallbackError: searchErrorMessage,
          onRetry: () => unawaited(onRetry()),
          minHeight: 360,
        );
      } else {
        child = SizedBox(
          key: const ValueKey('search-error'),
          height: 360,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(searchErrorMessage!, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => unawaited(onRetry()),
                  child: Text(strings.commonRetry),
                ),
              ],
            ),
          ),
        );
      }
    } else if (searchComics.isEmpty) {
      child = SizedBox(
        key: const ValueKey('search-empty'),
        height: 320,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SearchEmptyAnimation(size: 200),
              const SizedBox(height: 12),
              Text(strings.searchEmpty),
            ],
          ),
        ),
      );
    } else {
      child = const SizedBox(key: ValueKey('search-hidden'));
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

class _SearchEmptyAnimation extends StatelessWidget {
  const _SearchEmptyAnimation({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Lottie.asset(
          'assets/stickers/loading/search_empty_no_history.json',
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: false,
        ),
      ),
    );
  }
}

class SearchComicListItem extends StatelessWidget {
  const SearchComicListItem({
    super.key,
    required this.comic,
    required this.heroTag,
    required this.index,
    required this.onTap,
  });

  final ExploreComic comic;
  final String heroTag;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
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
                          sourceKey: comic.sourceKey,
                          width: 72,
                          height: 102,
                          fit: BoxFit.cover,
                          loading: Container(
                            width: 72,
                            height: 102,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
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
      ),
    );

    return TweenAnimationBuilder<double>(
      // 首次加载或滑入视野时的从下方放出放大动画
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index.clamp(0, 10)) * 60),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.85 + 0.15 * value,
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: item,
    );
  }
}
