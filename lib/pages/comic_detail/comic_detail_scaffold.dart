part of '../comic_detail_page.dart';

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
          children: <Widget>[...previousChildren, ?currentChild],
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

class _ComicDetailParallaxBackground extends StatefulWidget {
  const _ComicDetailParallaxBackground({
    required this.coverUrl,
    required this.scrollController,
  });

  final String coverUrl;
  final ScrollController scrollController;

  @override
  State<_ComicDetailParallaxBackground> createState() =>
      _ComicDetailParallaxBackgroundState();
}

class _ComicDetailParallaxBackgroundState
    extends State<_ComicDetailParallaxBackground> {
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncOffset();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ComicDetailParallaxBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
    }
    _syncOffset();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    _syncOffset();
  }

  void _syncOffset() {
    if (!mounted) {
      return;
    }
    final backgroundHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.58,
      520.0,
    );
    final nextOffset = widget.scrollController.hasClients
        ? widget.scrollController.offset
              .clamp(0.0, backgroundHeight)
              .roundToDouble()
        : 0.0;
    if ((_offset - nextOffset).abs() < 1) {
      return;
    }
    setState(() {
      _offset = nextOffset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final backgroundHeight = math.min(screenHeight * 0.58, 520.0);

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: backgroundHeight,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(0, -_offset),
          child: RepaintBoundary(
            child: _ComicBlurredCoverBackground(coverUrl: widget.coverUrl),
          ),
        ),
      ),
    );
  }
}

class _ComicDetailTabTickerScope extends StatelessWidget {
  const _ComicDetailTabTickerScope({
    required this.tabController,
    required this.tabIndex,
    required this.builder,
  });

  final TabController tabController;
  final int tabIndex;
  final Widget Function(
    BuildContext context,
    bool shouldRender,
    bool isSettledActive,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController.animation ?? tabController,
      builder: (context, _) {
        final animationValue =
            tabController.animation?.value ?? tabController.index.toDouble();
        final distance = (animationValue - tabIndex).abs();
        final isSettled =
            distance < 0.01 &&
            tabController.index == tabIndex &&
            !tabController.indexIsChanging;
        final isTransitioning =
            tabController.indexIsChanging ||
            (tabController.animation != null &&
                (tabController.animation!.value - tabController.index).abs() >=
                    0.01);
        final shouldRender =
            tabController.index == tabIndex ||
            (isTransitioning && distance <= 1.0);
        final isSettledActive = isSettled && tabController.index == tabIndex;
        return TickerMode(
          enabled: shouldRender,
          child: builder(context, shouldRender, isSettledActive),
        );
      },
    );
  }
}

class _ComicDetailEntranceReveal extends StatelessWidget {
  const _ComicDetailEntranceReveal({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 16),
    this.enabled = true,
  });

  final Widget child;
  final Offset beginOffset;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final dx = lerpDouble(beginOffset.dx, 0, value) ?? 0;
        final dy = lerpDouble(beginOffset.dy, 0, value) ?? 0;
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
    );
  }
}

class _ComicDetailSkeletonBlock extends StatelessWidget {
  const _ComicDetailSkeletonBlock({
    required this.color,
    this.width,
    this.height = 14,
    this.radius = 10,
  });

  final Color color;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ComicDetailBody extends StatelessWidget {
  const _ComicDetailBody({
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
    required this.onDetailsResolved,
    required this.isDesktopPanel,
    required this.onCloseRequested,
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
  final void Function({required String title, required String updateTime})
  onDetailsResolved;
  final bool isDesktopPanel;
  final VoidCallback? onCloseRequested;

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
                      child: _ComicDetailHeaderSection(
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
                  delegate: _HazukiTabBarDelegate(
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
              physics: const BouncingScrollPhysics(),
              children: [
                _ComicDetailTabTickerScope(
                  tabController: tabController,
                  tabIndex: 0,
                  builder: (context, shouldRender, _) {
                    return RepaintBoundary(
                      child: _ComicDetailInfoTab(
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
                _ComicDetailTabTickerScope(
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
                            ),
                          )
                        : const _ComicDetailLoadingView();
                  },
                ),
                _ComicDetailTabTickerScope(
                  tabController: tabController,
                  tabIndex: 2,
                  builder: (context, shouldRender, _) {
                    return RepaintBoundary(
                      child: _ComicDetailRelatedTab(
                        details: details,
                        heroTagPrefix: heroTag,
                        isActiveInTabView: shouldRender,
                        isDesktopPanel: isDesktopPanel,
                        onCloseRequested: onCloseRequested,
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
