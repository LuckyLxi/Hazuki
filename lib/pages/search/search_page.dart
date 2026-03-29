import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';
import 'search_results_page.dart';
import 'search_shared.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    this.initialKeyword,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final String? initialKeyword;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  Widget build(BuildContext context) {
    final keyword = initialKeyword?.trim() ?? '';
    if (keyword.isNotEmpty) {
      return SearchResultsPage(
        initialKeyword: keyword,
        comicDetailPageBuilder: comicDetailPageBuilder,
        comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
      );
    }
    return _SearchEntryPage(
      comicDetailPageBuilder: comicDetailPageBuilder,
      comicCoverHeroTagBuilder: comicCoverHeroTagBuilder,
    );
  }
}

class _SearchEntryPage extends StatefulWidget {
  const _SearchEntryPage({
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<_SearchEntryPage> createState() => _SearchEntryPageState();
}

class _SearchEntryPageState extends State<_SearchEntryPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _pageFocusNode = FocusNode(
    debugLabel: 'search_entry_page_focus',
    skipTraversal: true,
  );
  final ScrollController _scrollController = ScrollController();
  final List<Timer> _searchRevealSyncTimers = <Timer>[];

  List<String> _historyList = [];
  bool _historyEditMode = false;
  bool _historyExpanded = false;
  double _searchRevealProgress = 0;

  bool get _showCollapsedSearch => _searchRevealProgress >= 0.94;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelSearchRevealSyncTimers();
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateSearchRevealProgress() {
    if (!_scrollController.hasClients) {
      return 0;
    }
    return (_scrollController.position.pixels / searchAppBarRevealOffset).clamp(
      0.0,
      1.0,
    );
  }

  void _syncSearchRevealProgress({bool force = false}) {
    if (!mounted) {
      return;
    }
    final nextReveal = _calculateSearchRevealProgress();
    if (!force && (nextReveal - _searchRevealProgress).abs() < 0.01) {
      return;
    }
    setState(() {
      _searchRevealProgress = nextReveal;
    });
  }

  void _scheduleSearchRevealSync({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSearchRevealProgress(force: force);
    });
  }

  void _cancelSearchRevealSyncTimers() {
    for (final timer in _searchRevealSyncTimers) {
      timer.cancel();
    }
    _searchRevealSyncTimers.clear();
  }

  void _scheduleSearchRevealSyncBurst({bool force = false}) {
    _cancelSearchRevealSyncTimers();
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 50),
      Duration(milliseconds: 120),
      Duration(milliseconds: 220),
      Duration(milliseconds: 340),
    ];
    for (final delay in delays) {
      final timer = Timer(delay, () {
        if (!mounted) {
          return;
        }
        _scheduleSearchRevealSync(force: force);
      });
      _searchRevealSyncTimers.add(timer);
    }
  }

  void _onScroll() {
    _syncSearchRevealProgress();
  }

  void _parkSearchFocus() {
    if (!mounted) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(_pageFocusNode);
  }

  Future<void> _scrollToTop({bool focusSearch = false}) async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (focusSearch && mounted) {
      _searchFocusNode.requestFocus();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = prefs.getStringList('search_history') ?? [];
      if (_historyList.isEmpty) {
        _historyEditMode = false;
      }
    });
    _scheduleSearchRevealSyncBurst();
  }

  Future<void> _removeHistory(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final newHistory = _historyList.where((e) => e != keyword).toList();
    await prefs.setStringList('search_history', newHistory);
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = newHistory;
      if (_historyList.isEmpty) {
        _historyEditMode = false;
      }
    });
    _scheduleSearchRevealSyncBurst();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = [];
      _historyEditMode = false;
      _historyExpanded = false;
    });
    _scheduleSearchRevealSyncBurst();
  }

  double _estimateHistoryChipWidth(String keyword, BuildContext context) {
    final chipTheme = ChipTheme.of(context);
    final textStyle =
        chipTheme.labelStyle ??
        Theme.of(context).textTheme.labelLarge ??
        const TextStyle(fontSize: 14);
    final painter = TextPainter(
      text: TextSpan(text: keyword, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final horizontalExtra = _historyEditMode ? 72.0 : 40.0;
    return painter.width + horizontalExtra;
  }

  int _computeCollapsedHistoryVisibleCount(double maxWidth) {
    if (_historyList.isEmpty || maxWidth <= 0 || maxWidth.isInfinite) {
      return _historyList.length;
    }

    var rowCount = 1;
    var rowWidth = 0.0;
    var visibleCount = 0;

    for (final keyword in _historyList) {
      final chipWidth = math.min(
        maxWidth,
        _estimateHistoryChipWidth(keyword, context),
      );
      final nextWidth = rowWidth == 0
          ? chipWidth
          : rowWidth + searchHistoryChipSpacing + chipWidth;
      if (rowWidth > 0 && nextWidth > maxWidth) {
        rowCount += 1;
        if (rowCount > searchHistoryCollapsedMaxRows) {
          break;
        }
        rowWidth = chipWidth;
      } else {
        rowWidth = nextWidth;
      }
      visibleCount += 1;
    }

    return visibleCount.clamp(1, _historyList.length);
  }

  Future<void> _openResults(String rawKeyword) async {
    final keyword = await normalizeSubmittedKeyword(
      rawKeyword,
      controller: _searchController,
    );
    if (!mounted || keyword.isEmpty) {
      return;
    }

    _parkSearchFocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultsPage(
          initialKeyword: keyword,
          comicDetailPageBuilder: widget.comicDetailPageBuilder,
          comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    unawaited(_loadHistory());
  }

  Future<void> _confirmClearHistory() async {
    _parkSearchFocus();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }
    final strings = AppLocalizations.of(context)!;
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: strings.commonClose,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          title: Text(strings.searchClearHistoryTitle),
          content: Text(strings.searchClearHistoryContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.commonConfirm),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInBack,
          ).value,
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
    if (!mounted) {
      return;
    }
    _parkSearchFocus();
    if (confirm == true) {
      await _clearHistory();
      if (!mounted) {
        return;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _parkSearchFocus();
    });
  }

  Widget _buildSearchBar({
    required String clearKey,
    required String submitKey,
  }) {
    return SizedBox(
      height: 56,
      child: SearchBar(
        focusNode: _searchFocusNode,
        controller: _searchController,
        hintText: AppLocalizations.of(context)!.searchHint,
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        leading: const Icon(Icons.search),
        trailing: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                  reverseCurve: Curves.easeInCubic,
                ),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _searchController.text.isNotEmpty
                ? IconButton(
                    key: ValueKey(clearKey),
                    tooltip: AppLocalizations.of(context)!.searchClearTooltip,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      _searchFocusNode.requestFocus();
                    },
                    icon: const Icon(Icons.close),
                  )
                : IconButton(
                    key: ValueKey(submitKey),
                    tooltip: AppLocalizations.of(context)!.searchSubmitTooltip,
                    onPressed: () =>
                        unawaited(_openResults(_searchController.text)),
                    icon: const Icon(Icons.arrow_forward),
                  ),
          ),
        ],
        onSubmitted: (_) => unawaited(_openResults(_searchController.text)),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildTopSearchBox() {
    final hideProgress = Curves.easeOutCubic.transform(_searchRevealProgress);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: IgnorePointer(
        ignoring: _showCollapsedSearch,
        child: Opacity(
          opacity: 1 - hideProgress,
          child: Transform.translate(
            offset: Offset(0, -10 * hideProgress),
            child: Transform.scale(
              scale: 1 - 0.04 * hideProgress,
              alignment: Alignment.topCenter,
              child: HeroMode(
                enabled: !_showCollapsedSearch,
                child: Hero(
                  tag: discoverSearchHeroTag,
                  child: _buildSearchBar(
                    clearKey: 'entry-clear',
                    submitKey: 'entry-submit',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedSearchBox() {
    return HeroMode(
      enabled: _showCollapsedSearch,
      child: Hero(
        tag: discoverSearchHeroTag,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: _showCollapsedSearch ? 180 : 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: _showCollapsedSearch
                    ? Offset.zero
                    : const Offset(-0.08, 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedScale(
                  scale: _showCollapsedSearch ? 1 : 0.94,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _showCollapsedSearch ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_showCollapsedSearch,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => unawaited(_scrollToTop(focusSearch: true)),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 40),
                          child: _buildSearchBar(
                            clearKey: 'entry-collapsed-clear',
                            submitKey: 'entry-collapsed-submit',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    if (_historyList.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsedCount = _computeCollapsedHistoryVisibleCount(
          constraints.maxWidth,
        );
        final isTooLong = collapsedCount < _historyList.length;
        final displayList = (_historyExpanded || !isTooLong)
            ? _historyList
            : _historyList.sublist(0, collapsedCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                AppLocalizations.of(context)!.searchHistoryTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              onEnd: () => _scheduleSearchRevealSync(force: true),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  spacing: searchHistoryChipSpacing,
                  runSpacing: 8,
                  children: displayList.map((keyword) {
                    if (_historyEditMode) {
                      return InputChip(
                        label: Text(keyword),
                        deleteIcon: const Icon(Icons.cancel, size: 18),
                        onDeleted: () => _removeHistory(keyword),
                        onPressed: () => _removeHistory(keyword),
                      );
                    }
                    return ActionChip(
                      label: Text(keyword),
                      onPressed: () => unawaited(_openResults(keyword)),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (isTooLong)
              Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 8),
                child: IconButton(
                  icon: Icon(
                    _historyExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () {
                    setState(() {
                      _historyExpanded = !_historyExpanded;
                    });
                    _scheduleSearchRevealSyncBurst(force: true);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _pageFocusNode,
      skipTraversal: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        floatingActionButton: _historyList.isNotEmpty
            ? GestureDetector(
                onLongPress: _confirmClearHistory,
                child: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _historyEditMode = !_historyEditMode;
                    });
                    _scheduleSearchRevealSyncBurst(force: true);
                  },
                  child: Icon(
                    _historyEditMode ? Icons.done : Icons.delete_outline,
                  ),
                ),
              )
            : null,
        appBar: hazukiFrostedAppBar(
          context: context,
          title: Text(AppLocalizations.of(context)!.searchTitle),
          actions: [
            _buildCollapsedSearchBox(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: _showCollapsedSearch ? 12 : 0,
            ),
          ],
        ),
        body: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _buildTopSearchBox(),
            const SizedBox(height: 18),
            _buildHistoryView(),
          ],
        ),
      ),
    );
  }
}
