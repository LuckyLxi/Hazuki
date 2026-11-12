import 'package:hazuki/shared/text/chinese_conversion_scope.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/shared/source_presentation.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/hazuki_models.dart';
import '../../../services/source/source_capabilities.dart';
import '../../../widgets/widgets.dart';
import '../../../widgets/windows_comic_detail_host.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/preferences/hazuki_general_preferences_store.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import '../state/ranking_page_controller.dart';

enum _RankingComicLayout { list, grid3 }

class RankingPage extends StatefulWidget {
  final SourceTaskControlGateway taskControl;
  const RankingPage({
    required this.taskControl,
    super.key,
    required this.comicDetailPageBuilder,
    required this.sourceService,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final SourceCategoryGateway sourceService;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  static const _preferences = HazukiGeneralPreferencesStore();

  final ScrollController _scrollController = ScrollController();
  late final RankingPageController _ranking;
  bool _showBackToTop = false;
  bool _rankingOptionsIntroPlayed = false;
  _RankingComicLayout _comicLayout = _RankingComicLayout.list;

  @override
  void initState() {
    super.initState();
    _ranking = RankingPageController(
      sourceUiService: SourcePresentationScope.uiOf(context),
      sourceService: widget.sourceService,
      taskControl: widget.taskControl,
      optionsTimeoutMessage: () =>
          AppLocalizations.of(context)!.rankingLoadOptionsTimeout,
      pageTimeoutMessage: () =>
          AppLocalizations.of(context)!.rankingLoadTimeout,
      loadFailedMessage: (error) =>
          AppLocalizations.of(context)!.rankingLoadFailed(error),
    )..addListener(_rankingChanged);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    try {
      await _restoreComicLayout();
    } catch (_) {
      // A preference read failure must not prevent rankings from loading.
    }
    if (mounted) {
      await _ranking.loadInitial();
    }
  }

  void _rankingChanged() => setState(() {});

  Future<void> _restoreComicLayout() async {
    final savedLayout = await _preferences.loadRankingComicLayoutName();
    final restoredLayout = _RankingComicLayout.values.firstWhere(
      (layout) => layout.name == savedLayout,
      orElse: () => _RankingComicLayout.list,
    );
    if (!mounted || restoredLayout == _comicLayout) {
      return;
    }
    setState(() {
      _comicLayout = restoredLayout;
    });
  }

  Future<void> _persistComicLayout() =>
      _preferences.saveRankingComicLayoutName(_comicLayout.name);

  @override
  void dispose() {
    _ranking
      ..removeListener(_rankingChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final nextShowBackToTop = position.pixels > 520;
    if (nextShowBackToTop != _showBackToTop && mounted) {
      setState(() {
        _showBackToTop = nextShowBackToTop;
      });
    }

    if (_ranking.loading ||
        _ranking.loadingMore ||
        !_ranking.hasMore ||
        _ranking.selectedRanking == null) {
      return;
    }

    if (position.maxScrollExtent <= 0) {
      return;
    }

    if (position.pixels >= position.maxScrollExtent - 360) {
      unawaited(_ranking.loadMore());
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _showLayoutDialog() async {
    final strings = AppLocalizations.of(context)!;
    final selected = await showGeneralDialog<_RankingComicLayout>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          InheritedTheme.captureAll(
            context,
            AlertDialog(
              title: Text(strings.rankingLayoutDialogTitle),
              contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    key: const ValueKey('ranking-layout-list'),
                    leading: const Icon(Icons.view_list_rounded),
                    title: Text(strings.rankingLayoutList),
                    trailing: _comicLayout == _RankingComicLayout.list
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(dialogContext).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_RankingComicLayout.list),
                  ),
                  ListTile(
                    key: const ValueKey('ranking-layout-grid3'),
                    leading: const Icon(Icons.apps_rounded),
                    title: Text(strings.rankingLayoutGrid3),
                    trailing: _comicLayout == _RankingComicLayout.grid3
                        ? Icon(
                            Icons.check_rounded,
                            color: Theme.of(dialogContext).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_RankingComicLayout.grid3),
                  ),
                ],
              ),
            ),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final opacity = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.92, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        );
        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
    if (!mounted || selected == null || selected == _comicLayout) {
      return;
    }
    setState(() {
      _comicLayout = selected;
    });
    await _persistComicLayout();
  }

  Widget _buildRankingComicItem(ExploreComic comic, int index) {
    final heroTag = widget.comicCoverHeroTagBuilder(
      comic,
      salt: 'ranking-page-${_ranking.selectedRanking ?? 'none'}-$index',
    );

    final item = Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await openComicDetail(
            context,
            comic: comic,
            heroTag: heroTag,
            pageBuilder: widget.comicDetailPageBuilder,
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: index < 3 ? 24 : 18,
                      fontWeight: index < 3 ? FontWeight.w900 : FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: index == 0
                          ? Colors.red.shade400
                          : (index == 1
                                ? Colors.orange.shade400
                                : (index == 2
                                      ? Colors.amber.shade400
                                      : Theme.of(context).colorScheme.outline)),
                    ),
                  ),
                ),
              ),
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: comic.cover.isEmpty
                      ? Container(
                          width: 72,
                          height: 102,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported_outlined),
                        )
                      : HazukiCachedImage(
                          url: comic.cover,
                          sourceKey: comic.sourceKey,
                          width: 72,
                          height: 102,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      convertChineseText(context, comic.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (comic.subTitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        comic.subTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey('ranking-list-entry-${comic.sourceKey}-${comic.id}-$index'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 240 + index.clamp(0, 10) * 35),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(-24 * (1 - value), 0),
        child: Opacity(
          key: ValueKey(
            'ranking-list-entry-opacity-${comic.sourceKey}-${comic.id}',
          ),
          opacity: value,
          child: child,
        ),
      ),
      child: item,
    );
  }

  Widget _buildRankingComicGrid() {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final coverWidth = (constraints.maxWidth - spacing * 2) / 3;
        final coverCacheWidth =
            (coverWidth * MediaQuery.devicePixelRatioOf(context)).round();
        return GridView.builder(
          key: const ValueKey('ranking-comic-grid3'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ranking.comics.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: 0.57,
          ),
          itemBuilder: (context, index) {
            final comic = _ranking.comics[index];
            final heroTag = widget.comicCoverHeroTagBuilder(
              comic,
              salt: 'ranking-page-${_ranking.selectedRanking ?? 'none'}-$index',
            );
            return TweenAnimationBuilder<double>(
              key: ValueKey(
                'ranking-grid-entry-${comic.sourceKey}-${comic.id}-$index',
              ),
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 260 + index.clamp(0, 8) * 45),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset(0, 18 * (1 - value)),
                child: Opacity(
                  key: ValueKey('ranking-grid-entry-opacity-$index'),
                  opacity: value,
                  child: child,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ComicCoverTile(
                      comic: comic,
                      heroTag: heroTag,
                      coverCacheWidth: coverCacheWidth,
                      placeholderColor: colorScheme.surfaceContainerHighest,
                      onTap: () => openComicDetail(
                        context,
                        comic: comic,
                        heroTag: heroTag,
                        pageBuilder: widget.comicDetailPageBuilder,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: IgnorePointer(
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: index == 0
                                ? Colors.red.shade400
                                : index == 1
                                ? Colors.orange.shade400
                                : index == 2
                                ? Colors.amber.shade400
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCenteredRankingLoading({String? text}) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HazukiSandyLoadingIndicator(size: 136),
                if (text != null) ...[const SizedBox(height: 10), Text(text)],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingLoadingSection(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HazukiSandyLoadingIndicator(size: 136),
            const SizedBox(height: 10),
            Text(text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return WindowsComicDetailHost(
      child: Scaffold(
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(strings.rankingTitle),
          actions: [
            IconButton(
              key: const ValueKey('ranking-layout-button'),
              tooltip: strings.rankingLayoutButtonTooltip,
              onPressed: _showLayoutDialog,
              icon: Icon(
                _comicLayout == _RankingComicLayout.list
                    ? Icons.view_list_rounded
                    : Icons.apps_rounded,
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            HazukiPullToRefresh(
              onRefresh: () => _ranking.loadInitial(forceRefresh: true),
              child: _ranking.initialLoading
                  ? _buildCenteredRankingLoading(text: strings.commonLoading)
                  : (_ranking.errorMessage != null &&
                        _ranking.options.isEmpty &&
                        _ranking.comics.isEmpty)
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 90),
                        Text(
                          _ranking.errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: FilledButton(
                            onPressed: () {
                              unawaited(
                                _ranking.loadInitial(forceRefresh: true),
                              );
                            },
                            child: Text(strings.commonRetry),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      children: [
                        if (_ranking.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _ranking.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (_ranking.options.isEmpty)
                          Text(strings.rankingEmptyOptions)
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _ranking.options.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final option = entry.value;
                              final chip = ChoiceChip(
                                label: Text(option.label),
                                selected:
                                    _ranking.selectedRanking == option.value,
                                onSelected: (_) => unawaited(
                                  _ranking.selectRanking(option.value),
                                ),
                              );
                              if (_rankingOptionsIntroPlayed) {
                                return chip;
                              }
                              // 为每个分类按钮添加从左向右滑入并渐显的交错动画
                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: 1.0),
                                duration: Duration(
                                  milliseconds: 300 + (index * 50),
                                ),
                                curve: Curves.easeOutCubic,
                                onEnd: index == _ranking.options.length - 1
                                    ? () {
                                        if (!mounted ||
                                            _rankingOptionsIntroPlayed) {
                                          return;
                                        }
                                        setState(() {
                                          _rankingOptionsIntroPlayed = true;
                                        });
                                      }
                                    : null,
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(
                                      -MediaQuery.of(context).size.width *
                                          (1 - value),
                                      0,
                                    ),
                                    child: Opacity(
                                      opacity: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: chip,
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 10),
                        if (_ranking.loading && _ranking.comics.isEmpty)
                          _buildRankingLoadingSection(strings.commonLoading)
                        else if (_ranking.comics.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(strings.rankingEmptyComics),
                            ),
                          )
                        else if (_comicLayout == _RankingComicLayout.list) ...[
                          for (int i = 0; i < _ranking.comics.length; i++)
                            _buildRankingComicItem(_ranking.comics[i], i),
                        ] else
                          _buildRankingComicGrid(),
                        if (_ranking.loadingMore)
                          const HazukiLoadMoreFooter(verticalPadding: 8),
                        if (!_ranking.loading &&
                            !_ranking.loadingMore &&
                            !_ranking.hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Center(
                              child: Text(strings.rankingReachedEnd),
                            ),
                          ),
                        if (_ranking.refreshing)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: SizedBox.shrink(),
                          ),
                      ],
                    ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSlide(
                offset: _showBackToTop ? Offset.zero : const Offset(0, 0.24),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: _showBackToTop ? 1 : 0.86,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _showBackToTop ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showBackToTop,
                      child: FloatingActionButton(
                        heroTag: 'ranking_back_to_top',
                        onPressed: _scrollToTop,
                        child: const Icon(Icons.vertical_align_top_rounded),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
