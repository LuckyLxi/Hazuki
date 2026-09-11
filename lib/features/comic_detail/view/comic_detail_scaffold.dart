import 'dart:async';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/comments/comments_loading_view.dart';
import 'package:hazuki/shared/comments/comments_widget_builder.dart';

import '../support/comic_detail_scope.dart';
import 'comic_detail_header.dart';
import 'comic_detail_info_tab.dart';
import 'comic_detail_meta.dart';
import 'comic_detail_panels.dart';
import 'comic_detail_related_tab.dart';
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
    required this.commentsWidgetBuilder,
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
  final CommentsWidgetBuilder commentsWidgetBuilder;

  @override
  Widget build(BuildContext context) {
    final scope = ComicDetailScope.of(context);
    final session = scope.session;
    final uiState = scope.uiState;
    final surface = Theme.of(context).colorScheme.surface;
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows;

    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
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
                uiState.shouldAnimateInitialDetailReveal;
            final shouldAnimateResolvedContent =
                shouldAnimateInitialDetailReveal && details != null;
            final supportsJmExclusiveActions = scope.supportsJmExclusiveActions;

            uiState.updateAppBarMetadata(
              title: displayTitle,
              updateTime: details?.updateTime ?? '',
            );
            if (details != null) {
              uiState.markComicDetailRevealHandled(details.id);
            }

            return NestedScrollView(
              controller: scrollController,
              physics: const ClampingScrollPhysics(),
              headerSliverBuilder: (context, _) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 24 : 16,
                        isDesktop ? 28 : 16,
                        isDesktop ? 24 : 16,
                        0,
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.hardEdge,
                        child: RepaintBoundary(
                          child: ComicDetailHeaderSection(
                            isDesktop: isDesktop,
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
                          controller: uiState.tabController,
                          onTap: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          isScrollable: true,
                          tabAlignment: isDesktop
                              ? TabAlignment.start
                              : TabAlignment.center,
                          padding: isDesktop
                              ? const EdgeInsets.symmetric(horizontal: 24)
                              : EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                          ),
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(
                              height: 44,
                              text: l10n(context).comicDetailTabInfo,
                            ),
                            Tab(
                              height: 44,
                              text: l10n(context).comicDetailTabComments,
                            ),
                            if (supportsJmExclusiveActions)
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
                  controller: uiState.tabController,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    ComicDetailTabTickerScope(
                      tabController: uiState.tabController,
                      tabIndex: 0,
                      builder: (context, shouldRender) {
                        return RepaintBoundary(
                          child: ComicDetailInfoTab(
                            isDesktop: isDesktop,
                            details: details,
                            error: snapshot.error,
                            hasTimedOut: session.hasDetailsTimedOut,
                            isRetrying: session.isRetryingDetails,
                            onRetry: session.retry,
                            skeletonColor: skeletonColor,
                            isActiveInTabView: shouldRender,
                            shouldAnimateResolvedContent:
                                shouldAnimateResolvedContent,
                          ),
                        );
                      },
                    ),
                    ComicDetailTabTickerScope(
                      tabController: uiState.tabController,
                      tabIndex: 1,
                      builder: (context, shouldRender) {
                        return details != null
                            ? RepaintBoundary(
                                child: commentsWidgetBuilder(
                                  comicId: details.id,
                                  subId: details.subId.isEmpty
                                      ? null
                                      : details.subId,
                                  sourceKey: details.sourceKey,
                                  showAppBar: true,
                                  isTabView: true,
                                  isActiveInTabView: shouldRender,
                                  onRequestTabFullscreen:
                                      uiState.ensureCommentsTabFullscreen,
                                  debugOuterScrollStateBuilder:
                                      uiState.buildCommentsTabDebugState,
                                ),
                              )
                            : const CommentsInitialLoadingView();
                      },
                    ),
                    if (supportsJmExclusiveActions)
                      ComicDetailTabTickerScope(
                        tabController: uiState.tabController,
                        tabIndex: 2,
                        builder: (context, shouldRender) {
                          return RepaintBoundary(
                            child: ComicDetailRelatedTab(
                              details: details,
                              isActiveInTabView: shouldRender,
                              onOpenComic: (comic, heroTag) {
                                if (isDesktopPanel &&
                                    useWindowsComicDetailPanel) {
                                  WindowsComicDetailControllerScope.of(
                                    context,
                                  ).pushRelated(
                                    comic,
                                    heroTag,
                                    historyTabIndex:
                                        uiState.tabController.index,
                                  );
                                  return;
                                }
                                unawaited(
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          buildComicDetailPage(comic, heroTag),
                                    ),
                                  ),
                                );
                              },
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
      },
    );
  }
}
