part of '../favorite_page.dart';

class _FavoriteContentSection extends StatelessWidget {
  const _FavoriteContentSection({
    required this.comics,
    required this.errorMessage,
    required this.initialLoading,
    required this.loadingMore,
    required this.strings,
    required this.onRetry,
    required this.onComicTap,
  });

  final List<ExploreComic> comics;
  final String? errorMessage;
  final bool initialLoading;
  final bool loadingMore;
  final AppLocalizations strings;
  final Future<void> Function() onRetry;
  final ValueChanged<ExploreComic> onComicTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [_buildMainContent(context), _buildLoadMoreFooter()],
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (initialLoading) {
      return SizedBox(
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
      return SizedBox(
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
    if (comics.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(child: Text(strings.favoriteEmpty)),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: comics.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final comic = comics[index];
        final heroTag = _favoriteComicHeroTag(comic, salt: 'favorite');
        return FavoriteComicTile(
          comic: comic,
          heroTag: heroTag,
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
