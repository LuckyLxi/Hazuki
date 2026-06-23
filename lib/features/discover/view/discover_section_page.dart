import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/app/service_locator.dart';
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
  const DiscoverSectionPage({
    super.key,
    required this.section,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ExploreSection section;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverSectionPage> createState() => _DiscoverSectionPageState();
}

class _DiscoverSectionPageState extends State<DiscoverSectionPage> {
  late final DiscoverSectionPageController _controller;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverSectionPageController(
      sourceService: sl<SourceDiscoverGateway>(),
      viewMoreUrl: widget.section.viewMoreUrl,
      initialComics: widget.section.viewMoreUrl == null
          ? widget.section.comics
          : null,
    );
    _scrollController.addListener(_onScroll);
    _scheduleInitialBootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

    if (nextShowBackToTop != _showBackToTop) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }
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
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(widget.section.title),
          enableBlur: false,
        ),
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                Column(
                  children: [
                    if (_controller.sortOptions.isNotEmpty ||
                        _controller.sortOptionGroups.any(
                          (group) => group.isNotEmpty,
                        ))
                      DiscoverSectionSortBar(
                        sortOptions: _controller.sortOptions,
                        sortOptionGroups: _controller.sortOptionGroups,
                        useDateMorphSelector: _usesWeeklyMustReadDateSelector(),
                        selectedSortValue: _controller.selectedSortValue,
                        selectedSortValues: _controller.selectedSortValues,
                        onSelectSortOption: _onSelectSortOption,
                        onSelectSortOptionInGroup: _onSelectSortOptionInGroup,
                      ),
                    DiscoverSectionContent(
                      controller: _controller,
                      scrollController: _scrollController,
                      section: widget.section,
                      comicDetailPageBuilder: widget.comicDetailPageBuilder,
                      comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
                    ),
                  ],
                ),
                if (_controller.showLoadMoreFooter)
                  const DiscoverSectionLoadMoreFooterOverlay(),
                if (_controller.errorMessage != null)
                  DiscoverSectionErrorOverlay(
                    errorMessage: _controller.errorMessage!,
                    onRetry: _triggerLoadMore,
                  ),
                if (!_usesWeeklyMustReadDateSelector())
                  DiscoverSectionBackToTopButton(
                    showBackToTop: _showBackToTop,
                    onPressed: _scrollToTop,
                  ),
                if (_usesWeeklyMustReadDateSelector() &&
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

  bool _usesWeeklyMustReadDateSelector() {
    final title = widget.section.title.trim();
    final viewMoreUrl = widget.section.viewMoreUrl?.trim() ?? '';
    return title.contains('每周必看') ||
        title.contains('每週必看') ||
        viewMoreUrl.startsWith('category:每周必看@') ||
        viewMoreUrl.startsWith('category:每週必看@');
  }
}
