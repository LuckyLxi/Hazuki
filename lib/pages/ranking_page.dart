import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app.dart';
import '../l10n/app_localizations.dart';
import '../models/hazuki_models.dart';
import '../services/hazuki_source_service.dart';
import '../widgets/widgets.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({
    super.key,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  static const _loadTimeout = Duration(seconds: 25);

  final ScrollController _scrollController = ScrollController();

  List<CategoryRankingOption> _rankingOptions = const <CategoryRankingOption>[];
  List<ExploreComic> _rankingComics = const <ExploreComic>[];

  String? _errorMessage;
  String? _selectedRankingValue;

  bool _initialLoading = true;
  bool _refreshing = false;
  bool _rankingLoading = false;
  bool _rankingLoadingMore = false;
  bool _showBackToTop = false;

  int _rankingPage = 1;
  bool _rankingHasMore = true;
  int _rankingRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
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

    if (_rankingLoading ||
        _rankingLoadingMore ||
        !_rankingHasMore ||
        _selectedRankingValue == null) {
      return;
    }

    if (position.maxScrollExtent <= 0) {
      return;
    }

    if (position.pixels >= position.maxScrollExtent - 360) {
      unawaited(_loadRankingComics(append: true));
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

  Future<List<CategoryRankingOption>> _loadRankingOptions() {
    final timeoutMessage = AppLocalizations.of(
      context,
    )!.rankingLoadOptionsTimeout;
    return HazukiSourceService.instance.loadCategoryRankingOptions().timeout(
      _loadTimeout,
      onTimeout: () => throw Exception(timeoutMessage),
    );
  }

  Future<CategoryComicsResult> _loadRankingPage({
    required String rankingOption,
    required int page,
  }) {
    final timeoutMessage = AppLocalizations.of(context)!.rankingLoadTimeout;
    return HazukiSourceService.instance
        .loadCategoryRankingComics(rankingOption: rankingOption, page: page)
        .timeout(
          _loadTimeout,
          onTimeout: () => throw Exception(timeoutMessage),
        );
  }

  Future<void> _loadInitial({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }

    if (forceRefresh) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final rankingOptions = await _loadRankingOptions();
      if (!mounted) {
        return;
      }

      final selected = rankingOptions.isEmpty
          ? null
          : (_selectedRankingValue != null &&
                    rankingOptions.any((e) => e.value == _selectedRankingValue)
                ? _selectedRankingValue
                : rankingOptions.first.value);

      setState(() {
        _rankingOptions = rankingOptions;
        _selectedRankingValue = selected;
        _rankingComics = const <ExploreComic>[];
        _rankingPage = 1;
        _rankingHasMore = selected != null;
        _errorMessage = null;
      });

      if (selected != null) {
        await _loadRankingComics(reset: true);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.rankingLoadFailed('$e');
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadRankingComics({
    bool reset = false,
    bool append = false,
  }) async {
    final option = _selectedRankingValue;
    if (option == null || option.isEmpty) {
      return;
    }

    if (append &&
        (_rankingLoading || _rankingLoadingMore || !_rankingHasMore)) {
      return;
    }

    final targetPage = reset ? 1 : (append ? _rankingPage + 1 : _rankingPage);
    final requestToken = ++_rankingRequestToken;

    setState(() {
      if (append) {
        _rankingLoadingMore = true;
      } else {
        _rankingLoading = true;
        if (reset) {
          _rankingComics = const <ExploreComic>[];
          _rankingPage = 1;
          _rankingHasMore = true;
        }
      }
      _errorMessage = null;
    });

    try {
      final result = await _loadRankingPage(
        rankingOption: option,
        page: targetPage,
      );
      if (!mounted || requestToken != _rankingRequestToken) {
        return;
      }

      setState(() {
        if (append) {
          final previousCount = _rankingComics.length;
          final merged = <String, ExploreComic>{
            for (final comic in _rankingComics)
              if (comic.id.isNotEmpty) comic.id: comic,
          };
          for (final comic in result.comics) {
            if (comic.id.isNotEmpty) {
              merged[comic.id] = comic;
            }
          }
          _rankingComics = merged.values.toList();

          final reachedMax =
              result.maxPage != null && targetPage >= result.maxPage!;
          final noNewItems = _rankingComics.length == previousCount;
          _rankingHasMore =
              !reachedMax && result.comics.isNotEmpty && !noNewItems;
        } else {
          _rankingComics = result.comics;
          final reachedMax =
              result.maxPage != null && targetPage >= result.maxPage!;
          _rankingHasMore = !reachedMax && result.comics.isNotEmpty;
        }

        _rankingPage = targetPage;
      });
    } catch (e) {
      if (!mounted || requestToken != _rankingRequestToken) {
        return;
      }
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.rankingLoadFailed('$e');
      });
    } finally {
      if (mounted && requestToken == _rankingRequestToken) {
        setState(() {
          _rankingLoading = false;
          _rankingLoadingMore = false;
        });
      }
    }
  }

  void _onSelectRankingOption(String value) {
    if (_selectedRankingValue == value) {
      return;
    }
    setState(() {
      _selectedRankingValue = value;
      _rankingLoading = true;
      _rankingLoadingMore = false;
      _rankingComics = const <ExploreComic>[];
      _rankingPage = 1;
      _rankingHasMore = true;
      _errorMessage = null;
    });
    unawaited(_loadRankingComics(reset: true));
  }

  Widget _buildRankingComicItem(ExploreComic comic, int index) {
    final heroTag = widget.comicCoverHeroTagBuilder(
      comic,
      salt: 'ranking-page-${_selectedRankingValue ?? 'none'}-$index',
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => widget.comicDetailPageBuilder(comic, heroTag),
            ),
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
                      comic.title,
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

    return Scaffold(
      appBar: hazukiFrostedAppBar(
        context: context,
        title: Text(strings.rankingTitle),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _loadInitial(forceRefresh: true),
            child: _initialLoading
                ? _buildCenteredRankingLoading(text: strings.commonLoading)
                : (_errorMessage != null &&
                      _rankingOptions.isEmpty &&
                      _rankingComics.isEmpty)
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 90),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton(
                          onPressed: () {
                            unawaited(_loadInitial(forceRefresh: true));
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
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_rankingOptions.isEmpty)
                        Text(strings.rankingEmptyOptions)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _rankingOptions.map((option) {
                            return ChoiceChip(
                              label: Text(option.label),
                              selected: _selectedRankingValue == option.value,
                              onSelected: (_) =>
                                  _onSelectRankingOption(option.value),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 10),
                      if (_rankingLoading && _rankingComics.isEmpty)
                        _buildRankingLoadingSection(strings.commonLoading)
                      else if (_rankingComics.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(strings.rankingEmptyComics),
                          ),
                        )
                      else
                        for (int i = 0; i < _rankingComics.length; i++)
                          _buildRankingComicItem(_rankingComics[i], i),
                      if (_rankingLoadingMore)
                        const HazukiLoadMoreFooter(verticalPadding: 8),
                      if (!_rankingLoading &&
                          !_rankingLoadingMore &&
                          !_rankingHasMore)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Center(child: Text(strings.rankingReachedEnd)),
                        ),
                      if (_refreshing)
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
    );
  }
}
