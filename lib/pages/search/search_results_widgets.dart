import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../widgets/widgets.dart';

class SearchResultsStateView extends StatelessWidget {
  const SearchResultsStateView({
    super.key,
    required this.searchKeyword,
    required this.searchLoading,
    required this.searchComics,
    required this.searchErrorMessage,
    required this.onRetry,
  });

  final String searchKeyword;
  final bool searchLoading;
  final List<ExploreComic> searchComics;
  final String? searchErrorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    if (searchKeyword.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(child: Text(strings.searchStartPrompt)),
      );
    }

    if (searchLoading && searchComics.isEmpty) {
      return SizedBox(
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

    if (searchErrorMessage != null && searchComics.isEmpty) {
      return SizedBox(
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

    if (searchComics.isEmpty) {
      return SizedBox(
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
    }

    return const SizedBox.shrink();
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
    required this.onTap,
  });

  final ExploreComic comic;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}
