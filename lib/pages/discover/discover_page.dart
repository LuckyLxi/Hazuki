import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import '../search/search.dart';
import 'discover_section_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.comicDetailPageBuilder,
    this.onSearchMorphProgressChanged,
    this.onSearchTap,
    this.allowInitialLoad = true,
    this.hideLoadingUntilInitialLoadAllowed = false,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ValueChanged<double>? onSearchMorphProgressChanged;
  final VoidCallback? onSearchTap;
  final bool allowInitialLoad;
  final bool hideLoadingUntilInitialLoadAllowed;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _discoverLoadTimeout = Duration(seconds: 20);
  static const _searchMorphDistance = kToolbarHeight;
  static const _initialVisibleSectionCount = 1;
  static const _sectionRevealBatchSize = 1;

  final ScrollController _scrollController = ScrollController();

  List<ExploreSection> _sections = const [];
  String? _errorMessage;
  bool _initialLoading = true;
  bool _refreshing = false;
  double _searchMorphProgress = 0;
  int _visibleSectionCount = 0;
  int _sectionRevealGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onSearchMorphProgressChanged?.call(_searchMorphProgress);
    });
    if (widget.allowInitialLoad) {
      unawaited(_loadInitial());
    }
  }

  @override
  void didUpdateWidget(covariant DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onSearchMorphProgressChanged !=
        widget.onSearchMorphProgressChanged) {
      widget.onSearchMorphProgressChanged?.call(_searchMorphProgress);
    }
    if (!oldWidget.allowInitialLoad &&
        widget.allowInitialLoad &&
        _initialLoading) {
      unawaited(_loadInitial());
    }
  }

  @override
  void dispose() {
    _sectionRevealGeneration++;
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _scheduleRemainingSectionReveal(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _sectionRevealGeneration) {
        return;
      }
      if (_visibleSectionCount >= _sections.length) {
        return;
      }

      setState(() {
        _visibleSectionCount = math.min(
          _visibleSectionCount + _sectionRevealBatchSize,
          _sections.length,
        );
      });

      if (_visibleSectionCount < _sections.length) {
        _scheduleRemainingSectionReveal(generation);
      }
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final pixels = _scrollController.position.pixels.clamp(
      0.0,
      double.infinity,
    );
    final progress = (pixels / _searchMorphDistance).clamp(0.0, 1.0);
    if ((progress - _searchMorphProgress).abs() < 0.001) {
      return;
    }
    setState(() {
      _searchMorphProgress = progress;
    });
    widget.onSearchMorphProgressChanged?.call(progress);
  }

  Future<List<ExploreSection>> _loadSections({bool forceRefresh = false}) {
    return HazukiSourceService.instance
        .loadExploreSections(forceRefresh: forceRefresh)
        .timeout(
          _discoverLoadTimeout,
          onTimeout: () {
            throw Exception('discover_load_timeout');
          },
        );
  }

  Future<void> _loadInitial() async {
    final strings = AppLocalizations.of(context)!;
    List<ExploreSection>? loadedSections;
    String? errorMessage;
    try {
      loadedSections = await _loadSections();
    } catch (e) {
      errorMessage = e.toString().contains('discover_load_timeout')
          ? strings.discoverLoadTimeout
          : strings.discoverLoadFailed('$e');
    }

    if (!mounted) {
      return;
    }

    int? revealGeneration;
    setState(() {
      _sectionRevealGeneration++;
      if (loadedSections != null) {
        _sections = loadedSections;
        _errorMessage = null;
        _visibleSectionCount = math.min(
          _initialVisibleSectionCount,
          loadedSections.length,
        );
        if (_visibleSectionCount < loadedSections.length) {
          revealGeneration = _sectionRevealGeneration;
        }
      } else {
        _sections = const [];
        _errorMessage = errorMessage;
        _visibleSectionCount = 0;
      }
      _initialLoading = false;
    });

    if (revealGeneration != null) {
      _scheduleRemainingSectionReveal(revealGeneration!);
    }
  }

  Future<void> _refreshDiscover() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    final strings = AppLocalizations.of(context)!;
    List<ExploreSection>? refreshedSections;
    String? errorMessage;
    try {
      refreshedSections = await _loadSections(forceRefresh: true);
    } catch (e) {
      errorMessage = e.toString().contains('discover_load_timeout')
          ? strings.discoverLoadTimeout
          : strings.discoverLoadFailed('$e');
    }

    if (!mounted) {
      return;
    }

    final revealProgressively = _sections.isEmpty;
    int? revealGeneration;
    setState(() {
      _sectionRevealGeneration++;
      if (refreshedSections != null) {
        _sections = refreshedSections;
        _errorMessage = null;
        _visibleSectionCount = revealProgressively
            ? math.min(_initialVisibleSectionCount, refreshedSections.length)
            : refreshedSections.length;
        if (_visibleSectionCount < refreshedSections.length) {
          revealGeneration = _sectionRevealGeneration;
        }
      } else {
        _errorMessage = errorMessage;
      }
      _refreshing = false;
    });

    if (revealGeneration != null) {
      _scheduleRemainingSectionReveal(revealGeneration!);
    }
  }

  void _openSearch() {
    if (widget.onSearchTap != null) {
      widget.onSearchTap!.call();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(
          initialKeyword: null,
          comicDetailPageBuilder: (comic, heroTag) =>
              widget.comicDetailPageBuilder(comic, heroTag),
          comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
        ),
      ),
    );
  }

  Widget _buildSearchBox({
    required double height,
    required double borderRadius,
    required double horizontalPadding,
    required VoidCallback? onTap,
    required bool heroEnabled,
    double opacity = 1,
  }) {
    return Opacity(
      opacity: opacity,
      child: HeroMode(
        enabled: heroEnabled,
        child: Hero(
          tag: discoverSearchHeroTag,
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onTap,
            child: IgnorePointer(
              child: SizedBox(
                height: height,
                child: SearchBar(
                  hintText: AppLocalizations.of(context)!.searchHint,
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: horizontalPadding),
                  ),
                  leading: const Icon(Icons.search),
                  trailing: const [Icon(Icons.arrow_forward)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchMorphProgress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: 1 - hideProgress,
        child: Transform.translate(
          offset: Offset(0, -10 * hideProgress),
          child: Transform.scale(
            scale: 1 - 0.04 * hideProgress,
            alignment: Alignment.topCenter,
            child: _buildSearchBox(
              height: 56,
              borderRadius: 16,
              horizontalPadding: 16,
              onTap: _searchMorphProgress >= 0.96 ? null : _openSearch,
              heroEnabled: _searchMorphProgress < 0.96,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverStateView() {
    final strings = AppLocalizations.of(context)!;
    if (_initialLoading) {
      if (!widget.allowInitialLoad &&
          widget.hideLoadingUntilInitialLoadAllowed) {
        return const SizedBox(height: 360);
      }
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HazukiSandyLoadingIndicator(size: 136),
              const SizedBox(height: 10),
              Text(strings.commonLoading),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _sections.isEmpty) {
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refreshDiscover,
                child: Text(strings.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_sections.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(child: Text(strings.discoverEmpty)),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDiscoverSection(ExploreSection section, int sectionIndex) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;
    final coverCacheWidth = (130 * MediaQuery.devicePixelRatioOf(context))
        .round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(section.title, style: theme.textTheme.titleMedium),
              ),
              if (section.comics.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DiscoverSectionPage(
                          section: section,
                          comicDetailPageBuilder: widget.comicDetailPageBuilder,
                          comicCoverHeroTagBuilder:
                              widget.comicCoverHeroTagBuilder,
                        ),
                      ),
                    );
                  },
                  child: Text(strings.discoverMore),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 228,
            child: ListView.separated(
              key: PageStorageKey<String>(
                'discover-section-$sectionIndex-${section.title}',
              ),
              scrollDirection: Axis.horizontal,
              itemCount: section.comics.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final comic = section.comics[index];
                final heroTag = widget.comicCoverHeroTagBuilder(
                  comic,
                  salt: 'discover-$sectionIndex-${section.title}-$index',
                );
                return SizedBox(
                  width: 130,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              widget.comicDetailPageBuilder(comic, heroTag),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: heroTag,
                            child: ClipRRect(
                              clipBehavior: Clip.hardEdge,
                              borderRadius: BorderRadius.circular(8),
                              child: comic.cover.isEmpty
                                  ? ColoredBox(
                                      color: placeholderColor,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                        ),
                                      ),
                                    )
                                  : HazukiCachedImage(
                                      url: comic.cover,
                                      fit: BoxFit.cover,
                                      width: 130,
                                      cacheWidth: coverCacheWidth,
                                      animateOnLoad: true,
                                      filterQuality: FilterQuality.low,
                                      deferLoadingWhileScrolling: true,
                                      loading: SizedBox.expand(
                                        child: ColoredBox(
                                          color: placeholderColor,
                                        ),
                                      ),
                                      error: ColoredBox(
                                        color: placeholderColor,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          comic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (comic.subTitle.isNotEmpty)
                          Text(
                            comic.subTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSectionCount = math.min(
      _visibleSectionCount,
      _sections.length,
    );
    final hasSections = visibleSectionCount > 0;

    return HazukiPullToRefresh(
      onRefresh: _refreshDiscover,
      edgeOffset: 56,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        itemCount: hasSections ? visibleSectionCount + 1 : 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTopSearchBox();
          }
          if (!hasSections) {
            return _buildDiscoverStateView();
          }
          return _buildDiscoverSection(_sections[index - 1], index - 1);
        },
      ),
    );
  }
}
