part of '../../main.dart';

class _ComicDetailAppBarTitle extends StatelessWidget {
  const _ComicDetailAppBarTitle({
    required this.showCollapsedComicTitle,
    required this.appBarComicTitle,
    required this.appBarUpdateTime,
    required this.theme,
  });

  final bool showCollapsedComicTitle;
  final String appBarComicTitle;
  final String appBarUpdateTime;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: showCollapsedComicTitle
          ? Text(
              appBarComicTitle,
              key: const ValueKey('collapsed-appbar-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              appBarUpdateTime.isNotEmpty
                  ? l10n(context).comicDetailUpdatedAt(appBarUpdateTime)
                  : l10n(context).comicDetailTitle,
              key: const ValueKey('default-appbar-update-time'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }
}

class _ComicDetailParallaxBackground extends StatelessWidget {
  const _ComicDetailParallaxBackground({
    required this.scrollController,
    required this.coverUrl,
  });

  final ScrollController scrollController;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: MediaQuery.of(context).size.height,
      child: AnimatedBuilder(
        animation: scrollController,
        builder: (context, child) {
          final offset = scrollController.hasClients
              ? scrollController.offset.clamp(0.0, double.infinity)
              : 0.0;
          return Transform.translate(
            offset: Offset(0, -offset * 0.51),
            child: child,
          );
        },
        child: RepaintBoundary(
          child: _ComicBlurredCoverBackground(coverUrl: coverUrl),
        ),
      ),
    );
  }
}

class _ComicDetailBody extends StatelessWidget {
  const _ComicDetailBody({
    required this.future,
    required this.scrollController,
    required this.surface,
    required this.heroTag,
    required this.comic,
    required this.headerTitleKey,
    required this.favoriteRowKey,
    required this.actionButtonsKey,
    required this.favoriteBusy,
    required this.favoriteOverride,
    required this.lastReadProgress,
    required this.buildViewsText,
    required this.buildMetaSection,
    required this.onShowCoverPreview,
    required this.onFavoriteTap,
    required this.onShowChapters,
    required this.onOpenReader,
    required this.onDetailsResolved,
  });

  final Future<ComicDetailsData> future;
  final ScrollController scrollController;
  final Color surface;
  final String heroTag;
  final ExploreComic comic;
  final GlobalKey headerTitleKey;
  final GlobalKey favoriteRowKey;
  final GlobalKey actionButtonsKey;
  final bool favoriteBusy;
  final bool? favoriteOverride;
  final Map<String, dynamic>? lastReadProgress;
  final String Function(ComicDetailsData details) buildViewsText;
  final Widget Function(ComicDetailsData details) buildMetaSection;
  final ValueChanged<String> onShowCoverPreview;
  final ValueChanged<ComicDetailsData> onFavoriteTap;
  final ValueChanged<ComicDetailsData> onShowChapters;
  final Future<void> Function(
    ComicDetailsData details, {
    String? epId,
    String? chapterTitle,
    int? chapterIndex,
  })
  onOpenReader;
  final void Function({required String title, required String updateTime})
  onDetailsResolved;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ComicDetailsData>(
      future: future,
      builder: (context, snapshot) {
        final details = snapshot.data;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final skeletonColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06);

        final displayTitle = details?.title ?? comic.title;
        final displaySubTitle = details?.subTitle ?? comic.subTitle;
        final listCoverUrl = comic.cover.trim();
        final displayCoverUrl = listCoverUrl.isNotEmpty
            ? listCoverUrl
            : (details?.cover.trim() ?? '');

        onDetailsResolved(
          title: displayTitle,
          updateTime: details?.updateTime ?? '',
        );

        return NestedScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          headerSliverBuilder: (context, _) {
            return [
              SliverToBoxAdapter(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surface.withValues(alpha: 0.0),
                        surface.withValues(alpha: 0.9),
                        surface,
                      ],
                      stops: const [0.75, 0.95, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ComicDetailHeaderSection(
                      heroTag: heroTag,
                      details: details,
                      skeletonColor: skeletonColor,
                      displayTitle: displayTitle,
                      displaySubTitle: displaySubTitle,
                      displayCoverUrl: displayCoverUrl,
                      viewsText: details != null ? buildViewsText(details) : '',
                      headerTitleKey: headerTitleKey,
                      favoriteRowKey: favoriteRowKey,
                      actionButtonsKey: actionButtonsKey,
                      favoriteBusy: favoriteBusy,
                      favoriteOverride: favoriteOverride,
                      lastReadProgress: lastReadProgress,
                      onCoverTap: displayCoverUrl.isEmpty
                          ? null
                          : () => onShowCoverPreview(displayCoverUrl),
                      onFavoriteTap: onFavoriteTap,
                      onShowChapters: onShowChapters,
                      onOpenReader: onOpenReader,
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _HazukiTabBarDelegate(
                  TabBar(
                    tabs: [
                      Tab(text: l10n(context).comicDetailTabInfo),
                      Tab(text: l10n(context).comicDetailTabComments),
                      Tab(text: l10n(context).comicDetailTabRelated),
                    ],
                  ),
                  surface,
                ),
              ),
            ];
          },
          body: ColoredBox(
            color: surface,
            child: TabBarView(
              children: [
                _ComicDetailInfoTab(
                  details: details,
                  skeletonColor: skeletonColor,
                  metaSectionBuilder: buildMetaSection,
                ),
                details != null
                    ? CommentsPage(
                        comicId: details.id,
                        subId: details.subId.isEmpty ? null : details.subId,
                        isTabView: true,
                      )
                    : const _ComicDetailLoadingView(),
                _ComicDetailRelatedTab(
                  details: details,
                  heroTagPrefix: heroTag,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
