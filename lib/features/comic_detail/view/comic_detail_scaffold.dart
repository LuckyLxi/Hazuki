import 'package:flutter/material.dart';

import 'package:hazuki/features/comments/comments.dart';
import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_header.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_panels.dart';
import 'comic_detail_sections.dart';
import 'comic_detail_view_primitives.dart';

class ComicDetailBody extends StatelessWidget {
  const ComicDetailBody({
    super.key,
    required this.scrollController,
    required this.heroTag,
    required this.comic,
    required this.headerTitleKey,
    required this.favoriteRowKey,
    required this.actionButtonsKey,
    required this.isDesktopPanel,
    required this.onCloseRequested,
    required this.buildComicDetailPage,
  });

  final ScrollController scrollController;
  final String heroTag;
  final ExploreComic comic;
  final GlobalKey headerTitleKey;
  final GlobalKey favoriteRowKey;
  final GlobalKey actionButtonsKey;
  final bool isDesktopPanel;
  final VoidCallback? onCloseRequested;
  final Widget Function(ExploreComic comic, String heroTag)
  buildComicDetailPage;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final session = scope.session;
    final surface = Theme.of(context).colorScheme.surface;

    return FutureBuilder<ComicDetailsData>(
      future: session.future,
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
        final shouldAnimateInitialDetailReveal =
            session.shouldAnimateInitialDetailReveal;
        final shouldAnimateResolvedContent =
            shouldAnimateInitialDetailReveal && details != null;

        session.updateAppBarMetadata(
          title: displayTitle,
          updateTime: details?.updateTime ?? '',
        );
        if (details != null) {
          session.markComicDetailRevealHandled(details);
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
                            ? extractComicViewsText(details)
                            : '',
                        headerTitleKey: headerTitleKey,
                        favoriteRowKey: favoriteRowKey,
                        actionButtonsKey: actionButtonsKey,
                        shouldAnimateInitialDetailReveal:
                            shouldAnimateInitialDetailReveal,
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
                      controller: session.tabController,
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
              controller: session.tabController,
              physics: const ClampingScrollPhysics(),
              children: [
                ComicDetailTabTickerScope(
                  tabController: session.tabController,
                  tabIndex: 0,
                  builder: (context, shouldRender, _) {
                    return RepaintBoundary(
                      child: ComicDetailInfoTab(
                        details: details,
                        skeletonColor: skeletonColor,
                        isActiveInTabView: shouldRender,
                        shouldAnimateResolvedContent:
                            shouldAnimateResolvedContent,
                      ),
                    );
                  },
                ),
                ComicDetailTabTickerScope(
                  tabController: session.tabController,
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
                                  session.ensureCommentsTabFullscreen,
                              debugOuterScrollStateBuilder:
                                  session.buildCommentsTabDebugState,
                            ),
                          )
                        : const ComicDetailLoadingView();
                  },
                ),
                ComicDetailTabTickerScope(
                  tabController: session.tabController,
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
