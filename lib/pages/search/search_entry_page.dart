import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/windows_comic_detail_host.dart';
import 'search_history_section.dart';
import 'search_results_page.dart';
import 'search_reveal_support.dart';
import 'search_shared.dart';

class SearchEntryPage extends StatefulWidget {
  const SearchEntryPage({
    super.key,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<SearchEntryPage> createState() => _SearchEntryPageState();
}

class _SearchEntryPageState extends State<SearchEntryPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _collapsedSearchFocusNode = FocusNode(
    debugLabel: 'collapsed_search_focus',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final FocusNode _pageFocusNode = FocusNode(
    debugLabel: 'search_entry_page_focus',
    skipTraversal: true,
  );
  final ScrollController _scrollController = ScrollController();
  late final SearchRevealSupport _revealSupport = SearchRevealSupport(
    _scrollController,
  );

  List<String> _historyList = <String>[];
  bool _historyEditMode = false;
  bool _historyExpanded = false;
  double _searchRevealProgress = 0;
  bool _entryFocusDone = false;
  bool _entryAutoFocusCancelled = false;
  Animation<double>? _routeAnimation;

  bool get _showCollapsedSearch => _revealSupport.showCollapsedSearch;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entryFocusDone) {
      _entryFocusDone = true;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _logSearchEvent(
            'search: entry requestFocus',
            content: {'trigger': 'no_animation'},
          );
          unawaited(_focusSearchOnEntry());
        });
      } else {
        _routeAnimation = animation;
        animation.addStatusListener(_onRouteAnimationStatus);
      }
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
      _routeAnimation = null;
      if (!mounted) return;
      _logSearchEvent(
        'search: entry requestFocus',
        content: {'trigger': 'route_animation_completed'},
      );
      unawaited(_focusSearchOnEntry());
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      _logSearchEvent('search: focus gained (keyboard up)');
    } else {
      _logSearchEvent('search: focus lost (keyboard down)');
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _revealSupport.dispose();
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _collapsedSearchFocusNode.dispose();
    _pageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _logSearchEvent(
    String title, {
    String level = 'info',
    Map<String, Object?>? content,
  }) {
    HazukiSourceService.instance.addApplicationLog(
      level: level,
      title: title,
      source: 'search_entry',
      content: {
        'searchText': _searchController.text,
        'historyCount': _historyList.length,
        'hasFocus': _searchFocusNode.hasFocus,
        if (content != null) ...content,
      },
    );
  }

  void _syncSearchRevealProgress(bool force) {
    _revealSupport.sync(
      mounted: mounted,
      force: force,
      applyProgress: (nextProgress) {
        setState(() {
          _searchRevealProgress = nextProgress;
        });
      },
    );
  }

  void _scheduleSearchRevealSync(bool force) {
    _revealSupport.schedule(
      mounted: mounted,
      force: force,
      onSyncRequested: _syncSearchRevealProgress,
    );
  }

  void _scheduleSearchRevealSyncBurst(bool force) {
    _revealSupport.scheduleBurst(
      mounted: mounted,
      force: force,
      onSyncRequested: _syncSearchRevealProgress,
    );
  }

  void _onScroll() {
    _syncSearchRevealProgress(false);
  }

  void _cancelEntryAutoFocus() {
    _entryAutoFocusCancelled = true;
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatus);
    _routeAnimation = null;
  }

  void _parkSearchFocus() {
    if (!mounted) {
      return;
    }
    _cancelEntryAutoFocus();
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).requestFocus(_pageFocusNode);
  }

  void _requestExpandedSearchFocus() {
    if (!mounted) {
      return;
    }
    _searchFocusNode.requestFocus();
  }

  Future<void> _focusSearchOnEntry() async {
    if (!mounted || _entryAutoFocusCancelled) {
      return;
    }
    _requestExpandedSearchFocus();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || _entryAutoFocusCancelled || !_searchFocusNode.hasFocus) {
      return;
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
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
      _requestExpandedSearchFocus();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    final hadSearchFocus = _searchFocusNode.hasFocus;
    setState(() {
      _historyList = prefs.getStringList('search_history') ?? <String>[];
      if (_historyList.isEmpty) {
        _historyEditMode = false;
      }
    });
    _scheduleSearchRevealSyncBurst(false);
    if (hadSearchFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _logSearchEvent('search: refocus after history load');
        _searchFocusNode.requestFocus();
      });
    }
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
    _scheduleSearchRevealSyncBurst(false);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = <String>[];
      _historyEditMode = false;
      _historyExpanded = false;
    });
    _scheduleSearchRevealSyncBurst(false);
  }

  void _syncSearchText(String value) {
    if (_searchController.text == value) {
      return;
    }
    _searchController.value = _searchController.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _openResults(String rawKeyword) async {
    _cancelEntryAutoFocus();
    _syncSearchText(rawKeyword);
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
    FocusNode? focusNode,
  }) {
    return SizedBox(
      height: 56,
      child: SearchBar(
        focusNode: focusNode ?? _searchFocusNode,
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
          buildAnimatedSearchActionButton(
            showClearAction: _searchController.text.isNotEmpty,
            clearKey: clearKey,
            submitKey: submitKey,
            clearTooltip: AppLocalizations.of(context)!.searchClearTooltip,
            submitTooltip: AppLocalizations.of(context)!.searchSubmitTooltip,
            onClear: () {
              _logSearchEvent(
                'search: clear button tapped',
                content: {'clearedText': _searchController.text},
              );
              _searchController.clear();
              setState(() {});
              _requestExpandedSearchFocus();
            },
            onSubmit: () => unawaited(_openResults(_searchController.text)),
          ),
        ],
        onSubmitted: (value) => unawaited(_openResults(value)),
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
                            focusNode: _collapsedSearchFocusNode,
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

  @override
  Widget build(BuildContext context) {
    return WindowsComicDetailHost(
      child: Focus(
        focusNode: _pageFocusNode,
        skipTraversal: true,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          resizeToAvoidBottomInset: true,
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: _historyList.isNotEmpty
              ? GestureDetector(
                  onLongPress: _confirmClearHistory,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _historyEditMode = !_historyEditMode;
                      });
                      _scheduleSearchRevealSyncBurst(true);
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
            enableBlur: false,
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
              SearchHistorySection(
                historyList: _historyList,
                historyEditMode: _historyEditMode,
                historyExpanded: _historyExpanded,
                onKeywordPressed: (keyword) {
                  _logSearchEvent(
                    'search: history keyword tapped',
                    content: {'keyword': keyword},
                  );
                  unawaited(_openResults(keyword));
                },
                onKeywordDeleted: (keyword) =>
                    unawaited(_removeHistory(keyword)),
                onExpandedChanged: (expanded) {
                  setState(() {
                    _historyExpanded = expanded;
                  });
                  _scheduleSearchRevealSyncBurst(true);
                },
                onLayoutChanged: () => _scheduleSearchRevealSync(true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
