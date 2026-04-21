part of 'favorite_page.dart';

class _FavoriteContentSection extends StatelessWidget {
  const _FavoriteContentSection({
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
                ...previousChildren,
                ...<Widget?>[currentChild].whereType<Widget>(),
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

    return ListView.separated(
      key: const ValueKey('favorite-list'),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: comics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final comic = comics[index];
        final heroTag = _favoriteComicHeroTag(comic, salt: 'favorite');
        return FavoriteComicTile(
          key: ValueKey('${comic.id}-${mode.name}'),
          comic: comic,
          heroTag: heroTag,
          animationStyle: comic.id.isEmpty
              ? FavoriteEntryAnimationStyle.none
              : (comicAnimationStyles[comic.id] ??
                    FavoriteEntryAnimationStyle.none),
          entryIndex: index,
          onTap: () => onComicTap(comic),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter() {
    if (!loadingMore) {
      return const SizedBox(height: 4);
    }

    return const HazukiLoadMoreFooter();
  }
}
