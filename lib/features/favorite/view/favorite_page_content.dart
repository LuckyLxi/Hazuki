import 'package:flutter/material.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';
import 'package:hazuki/widgets/source_runtime_status_card.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';

import 'favorite_comic_tile.dart';
import 'favorite_view_support.dart';
import '../support/favorite_entry_animation_queue.dart';

class FavoriteBackToTopButton extends StatelessWidget {
  const FavoriteBackToTopButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.24),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.86,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !visible,
            child: FloatingActionButton(
              key: const ValueKey('favorite-back-to-top-fallback'),
              heroTag: 'favorite_back_to_top',
              onPressed: onPressed,
              child: const Icon(Icons.vertical_align_top_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritePageContentSection extends StatelessWidget {
  const FavoritePageContentSection({
    super.key,
    required this.comics,
    required this.comicAnimationStyles,
    required this.errorMessage,
    required this.initialLoading,
    required this.refreshing,
    required this.loadingMore,
    required this.sourceRuntimeState,
    required this.strings,
    required this.onRetry,
    required this.showCreateLocalFolderButton,
    required this.onComicTap,
    required this.mode,
    this.onCreateLocalFolder,
    this.layout = FavoriteLayout.list,
    this.entryScrollController,
    this.entryAnimationQueue,
  });

  final List<ExploreComic> comics;
  final Map<String, FavoriteEntryAnimationStyle> comicAnimationStyles;
  final String? errorMessage;
  final bool initialLoading;
  final bool refreshing;
  final bool loadingMore;
  final SourceRuntimeState sourceRuntimeState;
  final AppLocalizations strings;
  final Future<void> Function() onRetry;
  final bool showCreateLocalFolderButton;
  final ValueChanged<ExploreComic> onComicTap;
  final FavoritePageMode mode;
  final VoidCallback? onCreateLocalFolder;
  final FavoriteLayout layout;
  final ScrollController? entryScrollController;
  final FavoriteEntryAnimationQueue? entryAnimationQueue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                // Keep the same keyed wrapper when a child starts fading out.
                for (final child in previousChildren)
                  IgnorePointer(key: child.key, child: child),
                if (currentChild != null)
                  IgnorePointer(
                    key: currentChild.key,
                    ignoring: false,
                    child: currentChild,
                  ),
              ],
            );
          },
          child: _buildMainContent(context),
        ),
        _buildLoadMoreFooter(),
      ],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final showBlockingLoading =
        initialLoading || (refreshing && comics.isEmpty);
    if (showBlockingLoading) {
      if (shouldShowSourceRuntimeStatusCard(sourceRuntimeState)) {
        return SourceRuntimeStatusCard(
          key: const ValueKey('favorite-source-runtime-loading'),
          state: sourceRuntimeState,
          minHeight: 360,
        );
      }
      return SizedBox(
        key: const ValueKey('favorite-loading'),
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HazukiSandyLoadingIndicator(size: 144),
              const SizedBox(height: 10),
              Text(strings.commonLoading),
            ],
          ),
        ),
      );
    }
    if (errorMessage != null && comics.isEmpty) {
      if (shouldShowSourceRuntimeStatusCard(
        sourceRuntimeState,
        fallbackError: errorMessage,
      )) {
        return SourceRuntimeStatusCard(
          key: const ValueKey('favorite-source-runtime-error'),
          state: sourceRuntimeState,
          fallbackError: errorMessage,
          onRetry: onRetry,
          minHeight: 360,
        );
      }
      return SizedBox(
        key: const ValueKey('favorite-error'),
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
    if (showCreateLocalFolderButton) {
      final emptyStateHeight =
          (MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).top -
                  kToolbarHeight -
                  176)
              .clamp(300.0, 560.0)
              .toDouble();
      final textTheme = Theme.of(context).textTheme;
      final colorScheme = Theme.of(context).colorScheme;
      return SizedBox(
        key: const ValueKey('favorite-create-folder'),
        height: emptyStateHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.onSecondaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 22,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: onCreateLocalFolder,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.create_new_folder_rounded, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    strings.favoriteCreateLocalFolderAction,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (comics.isEmpty) {
      return SizedBox(
        key: const ValueKey('favorite-empty'),
        height: 220,
        child: Center(child: Text(strings.favoriteEmpty)),
      );
    }

    // Keep one switcher child across layouts so cover Heroes are never duplicated.
    return LayoutBuilder(
      key: const ValueKey('favorite-list'),
      builder: (context, constraints) {
        if (layout == FavoriteLayout.list) {
          return _buildList();
        }
        final columns = layout.columns;
        final coverWidth =
            (constraints.maxWidth - 32 - (columns - 1) * 10) / columns;
        final titleStyle = Theme.of(context).textTheme.bodyMedium!;
        final titleHeight = layout == FavoriteLayout.coverOnly
            ? 0.0
            : 6 +
                  MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) *
                      1.3 *
                      2;
        return GridView.builder(
          key: const ValueKey('favorite-grid'),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: coverWidth * 102 / 72 + titleHeight,
          ),
          itemCount: comics.length,
          itemBuilder: _buildComicTile,
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: comics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: _buildComicTile,
    );
  }

  Widget _buildComicTile(BuildContext context, int index) {
    final comic = comics[index];
    return FavoriteComicTile(
      key: ValueKey('${comic.id}-${mode.name}'),
      comic: comic,
      heroTag: favoriteComicHeroTag(comic, salt: 'favorite'),
      layout: layout,
      entryScrollController: entryScrollController,
      entryAnimationQueue: entryAnimationQueue,
      animationStyle: comic.id.isEmpty
          ? FavoriteEntryAnimationStyle.none
          : (comicAnimationStyles[comic.id] ??
                FavoriteEntryAnimationStyle.none),
      onTap: () => onComicTap(comic),
    );
  }

  Widget _buildLoadMoreFooter() {
    if (!loadingMore) {
      return const SizedBox(height: 4);
    }

    return const HazukiLoadMoreFooter();
  }
}
