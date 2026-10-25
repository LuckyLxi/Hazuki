import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/discover_section_page_controller.dart';
import 'discover_section_page_widgets.dart';
import 'package:hazuki/shared/navigation_tags.dart';

/// 涓撴爮婕敾鍒楄〃锟?/// 锟?[section.viewMoreUrl] 涓嶄负绌猴紝鍒欒繘鍏ラ〉鍚庡姞杞借椤甸潰鑷繁鐨勭涓€椤垫暟鎹紱
/// 鑻ヤ负绌猴紝鍒欑洿鎺ュ睍锟?[section.comics]
class DiscoverSectionPage extends StatefulWidget {
  final SourceTaskControlGateway taskControl;
  const DiscoverSectionPage({
    required this.taskControl,
    super.key,
    required this.section,
    required this.comicDetailPageBuilder,
    required this.sourceService,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ExploreSection section;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final SourceDiscoverGateway sourceService;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverSectionPage> createState() => _DiscoverSectionPageState();
}

class _DiscoverSectionPageState extends State<DiscoverSectionPage> {
  late final DiscoverSectionPageController _controller;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showBackToTop = ValueNotifier(false);
  ModalRoute<Object?>? _route;
  Animation<double>? _routeAnimation;
  bool _routeSettled = false;
  DiscoverSectionSortBar? _sortBar;
  Widget? _sortBarHeader;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverSectionPageController(
      sourceService: widget.sourceService,
      viewMoreUrl: widget.section.viewMoreUrl,
      initialComics: widget.section.comics,
      taskControl: widget.taskControl,
    );
    _scrollController.addListener(_onScroll);
    _scheduleInitialBootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSettled) return;
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (route == null || animation == null) {
      _routeSettled = true;
      return;
    }
    _route = route;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
      _routeAnimation = animation;
      animation.addStatusListener(_onRouteAnimationStatusChanged);
    }
    // Hero 预构建时路由处于 offstage，动画代理会暂时指向已完成状态，需等真正入场后再判断
    if (!route.offstage && animation.isCompleted) _settleRoute();
  }

  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    if (!status.isCompleted || _route?.offstage != false) return;
    if (!mounted || _routeSettled) return;
    setState(_settleRoute);
  }

  void _settleRoute() {
    _routeSettled = true;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    _scrollController.dispose();
    _showBackToTop.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleInitialBootstrap() {
    final viewMoreUrl = widget.section.viewMoreUrl;
    if (viewMoreUrl == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_triggerLoadSortOptionsAndInitial());
    });
  }

  Future<void> _triggerLoadSortOptionsAndInitial() async {
    if (widget.section.viewMoreUrl == null) return;
    final strings = AppLocalizations.of(context)!;
    await _controller.loadSortOptionsAndInitial(
      loadFailedMessage: strings.discoverSectionLoadFailed,
    );
  }

  Future<void> _triggerLoadMore() async {
    await _controller.loadMore();
  }

  void _onSelectSortOption(String value) {
    unawaited(_controller.selectSortOption(value: value));
  }

  void _onSelectSortOptionInGroup(int groupIndex, String value) {
    unawaited(
      _controller.selectSortOptionInGroup(groupIndex: groupIndex, value: value),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final nextShowBackToTop = pos.pixels > 520;

    final shouldRevealInitialLoadFooter =
        _controller.loadingMore &&
        !_controller.showLoadMoreFooter &&
        _controller.currentPage == 0 &&
        _controller.comics.isNotEmpty &&
        pos.pixels >= pos.maxScrollExtent - 240;

    _showBackToTop.value = nextShowBackToTop;
    if (shouldRevealInitialLoadFooter) {
      _controller.revealLoadMoreFooter();
    }

    if (!_controller.hasMore || _controller.loadingMore) return;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      unawaited(_triggerLoadMore());
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WindowsComicDetailHost(
      suppressExistingPanel: true,
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(widget.section.title),
          backgroundAlpha: 1,
        ),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final usesWeeklyDateSelector = _usesWeeklyMustReadDateSelector();
            final hasSortBar =
                _controller.sortOptions.isNotEmpty ||
                _controller.sortOptionGroups.any((group) => group.isNotEmpty);
            // 过渡动画结束前不放筛选栏，避免大量胶囊的构建挤进动画帧
            final showSortBar = hasSortBar && _routeSettled;
            final content = DiscoverSectionContent(
              controller: _controller,
              scrollController: _scrollController,
              section: widget.section,
              comicDetailPageBuilder: widget.comicDetailPageBuilder,
              comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
              // 筛选栏作为列表头部随内容一起滚动，向上滑动时被推出视口
              scrollHeader: showSortBar
                  ? _sortBarHeaderFor(usesWeeklyDateSelector)
                  : null,
              topPadding: showSortBar ? 8 : 16,
            );

            return Stack(
              children: [
                content,
                if (_controller.errorMessage != null)
                  DiscoverSectionErrorOverlay(
                    errorMessage: _controller.errorMessage!,
                    onRetry: _triggerLoadMore,
                  ),
                if (!usesWeeklyDateSelector)
                  ValueListenableBuilder<bool>(
                    valueListenable: _showBackToTop,
                    builder: (context, showBackToTop, _) =>
                        DiscoverSectionBackToTopButton(
                          showBackToTop: showBackToTop,
                          onPressed: _scrollToTop,
                        ),
                  ),
                if (usesWeeklyDateSelector &&
                    _controller.sortOptionGroups.isNotEmpty &&
                    _controller.sortOptionGroups.first.isNotEmpty)
                  DiscoverSectionIssueNavigationButtons(
                    options: _controller.sortOptionGroups.first,
                    selectedValue: _controller.selectedSortValues.isEmpty
                        ? _controller.selectedSortValue
                        : _controller.selectedSortValues.first,
                    onSelected: (value) => _onSelectSortOptionInGroup(0, value),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 筛选栏只在选项或选中项变化时重建；加载状态和漫画列表变化时复用同一实例，
  /// Flutter 遇到相同的 widget 实例会直接跳过整栏重建
  Widget _sortBarHeaderFor(bool usesWeeklyDateSelector) {
    final cached = _sortBar;
    final header = _sortBarHeader;
    if (cached != null &&
        header != null &&
        identical(cached.sortOptions, _controller.sortOptions) &&
        identical(cached.sortOptionGroups, _controller.sortOptionGroups) &&
        identical(cached.selectedSortValues, _controller.selectedSortValues) &&
        cached.selectedSortValue == _controller.selectedSortValue &&
        cached.useDateMorphSelector == usesWeeklyDateSelector) {
      return header;
    }
    final sortBar = DiscoverSectionSortBar(
      sortOptions: _controller.sortOptions,
      sortOptionGroups: _controller.sortOptionGroups,
      useDateMorphSelector: usesWeeklyDateSelector,
      selectedSortValue: _controller.selectedSortValue,
      selectedSortValues: _controller.selectedSortValues,
      onSelectSortOption: _onSelectSortOption,
      onSelectSortOptionInGroup: _onSelectSortOptionInGroup,
    );
    _sortBar = sortBar;
    // 首次出现时短淡入；之后目标值不变，重建不会重新播放
    return _sortBarHeader = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: sortBar,
    );
  }

  bool _usesWeeklyMustReadDateSelector() {
    final title = widget.section.title.trim();
    final viewMoreUrl = widget.section.viewMoreUrl?.trim() ?? '';
    return title.contains('每周必看') ||
        title.contains('每週必看') ||
        viewMoreUrl.startsWith('category:每周必看@') ||
        viewMoreUrl.startsWith('category:每週必看@');
  }
}
