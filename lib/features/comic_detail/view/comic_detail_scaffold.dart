import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/pages/comments_page.dart';

import 'comic_detail_header.dart';
import 'comic_detail_panels.dart';
import 'comic_detail_sections.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailBody extends StatelessWidget {
  const ComicDetailBody({
    super.key,
    required this.tabController,
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
    required this.shouldAnimateInitialDetailReveal,
    required this.buildViewsText,
    required this.buildMetaSection,
    required this.onShowCoverPreview,
    required this.onFavoriteTap,
    required this.onShowChapters,
    required this.onOpenReader,
    required this.onDetailsLoaded,
    required this.onRequestCommentsTabFullscreen,
    required this.onDetailsResolved,
    required this.isDesktopPanel,
    required this.onCloseRequested,
    required this.buildComicDetailPage,
  });

  final TabController tabController;
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
  final bool shouldAnimateInitialDetailReveal;
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
  final ValueChanged<ComicDetailsData> onDetailsLoaded;
  final Future<void> Function() onRequestCommentsTabFullscreen;
  final void Function({required String title, required String updateTime})
  onDetailsResolved;
  final bool isDesktopPanel;
  final VoidCallback? onCloseRequested;
  final Widget Function(ExploreComic comic, String heroTag)
  buildComicDetailPage;

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
        final shouldAnimateResolvedContent =
            shouldAnimateInitialDetailReveal && details != null;

        onDetailsResolved(
          title: displayTitle,
          updateTime: details?.updateTime ?? '',
        );
        if (details != null) {
          onDetailsLoaded(details);
        }

        return NestedScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          headerSliverBuilder: (context, _) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: RepaintBoundary(
                      child: ComicDetailHeaderSection(
                        heroTag: heroTag,
                        details: details,
                        skeletonColor: skeletonColor,
                        displayTitle: displayTitle,
                        displaySubTitle: displaySubTitle,
                        displayCoverUrl: displayCoverUrl,
                        viewsText: details != null
                            ? buildViewsText(details)
                            : '',
                        headerTitleKey: headerTitleKey,
                        favoriteRowKey: favoriteRowKey,
                        actionButtonsKey: actionButtonsKey,
                        favoriteBusy: favoriteBusy,
                        favoriteOverride: favoriteOverride,
                        lastReadProgress: lastReadProgress,
                        shouldAnimateInitialDetailReveal:
                            shouldAnimateInitialDetailReveal,
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
              ),
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: HazukiTabBarDelegate(
                    TabBar(
                      controller: tabController,
                      onTap: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(height: 44, text: l10n(context).comicDetailTabInfo),
                        Tab(
                          height: 44,
                          text: l10n(context).comicDetailTabComments,
                        ),
                        Tab(
                          height: 44,
                          text: l10n(context).comicDetailTabRelated,
                        ),
                      ],
                    ),
                    surface,
                    detailsReady: details != null,
                    shouldAnimateInitialDetailReveal:
                        shouldAnimateInitialDetailReveal,
                  ),
                ),
              ),
            ];
          },
          body: ColoredBox(
            color: surface,
            child: TabBarView(
              controller: tabController,
              physics: const ClampingScrollPhysics(),
              children: [
                ComicDetailTabTickerScope(
                  tabController: tabController,
                  tabIndex: 0,
                  builder: (context, shouldRender, _) {
                    return RepaintBoundary(
                      child: ComicDetailInfoTab(
                        details: details,
                        skeletonColor: skeletonColor,
                        metaSectionBuilder: buildMetaSection,
                        isActiveInTabView: shouldRender,
                        shouldAnimateResolvedContent:
                            shouldAnimateResolvedContent,
                      ),
                    );
                  },
                ),
                ComicDetailTabTickerScope(
                  tabController: tabController,
                  tabIndex: 1,
                  builder: (context, shouldRender, _) {
                    return details != null
                        ? RepaintBoundary(
                            child: CommentsPage(
                              comicId: details.id,
                              subId: details.subId.isEmpty
                                  ? null
                                  : details.subId,
                              isTabView: true,
                              isActiveInTabView: shouldRender,
                              onRequestTabFullscreen:
                                  onRequestCommentsTabFullscreen,
                            ),
                          )
                        : const ComicDetailLoadingView();
                  },
                ),
                ComicDetailTabTickerScope(
                  tabController: tabController,
                  tabIndex: 2,
                  builder: (context, shouldRender, _) {
                    return RepaintBoundary(
                      child: ComicDetailRelatedTab(
                        details: details,
                        heroTagPrefix: heroTag,
                        isActiveInTabView: shouldRender,
                        isDesktopPanel: isDesktopPanel,
                        onCloseRequested: onCloseRequested,
                        pageBuilder: buildComicDetailPage,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
