import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/widgets.dart';
import '../../widgets/windows_comic_detail_host.dart';
import 'search_bar_shell.dart';
import 'search_focus_coordinator.dart';
import 'search_history_section.dart';
import 'search_history_service.dart';
import 'search_results_page.dart';
import 'search_reveal_support.dart';
import 'search_shared.dart';

class SearchEntryPage extends StatefulWidget {
  const SearchEntryPage({
    super.key,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
    this.searchPageLoader,
  });

  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final SearchPageLoader? searchPageLoader;

  @override
  State<SearchEntryPage> createState() => _SearchEntryPageState();
}

class _SearchEntryPageState extends State<SearchEntryPage> {
  late final SearchFocusCoordinator _focusCoordinator = SearchFocusCoordinator(
    isMounted: () => mounted,
    allowCollapsedFocus: false,
  );
  final ScrollController _scrollController = ScrollController();
  final SearchHistoryService _historyService = SearchHistoryService();
  late final SearchRevealSupport _revealSupport = SearchRevealSupport(
    _scrollController,
  );

  List<String> _historyList = <String>[];
  bool _historyEditMode = false;
  bool _historyExpanded = false;
  double _searchRevealProgress = 0;

  bool get _showCollapsedSearch => _revealSupport.showCollapsedSearch;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _revealSupport.dispose();
    _scrollController.removeListener(_onScroll);
    _focusCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _scrollToTop({bool focusSearch = false}) async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (focusSearch && mounted) {
      await _focusCoordinator.requestPrimarySearchFocus(context);
    }
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _historyList = history;
      if (_historyList.isEmpty) {
        _historyEditMode = false;
      }
    });
    _scheduleSearchRevealSyncBurst(false);
  }

  Future<void> _removeHistory(String keyword) async {
    final newHistory = await _historyService.remove(keyword);
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
    await _historyService.clear();
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

  Future<void> _openResults(
    String rawKeyword, {
    required SearchEntryIntent intent,
  }) async {
    await _focusCoordinator.dismissKeyboard(context, parkOnPage: true);
    _focusCoordinator.syncText(rawKeyword);
    final keyword = await normalizeSubmittedKeyword(
      rawKeyword,
      controller: _focusCoordinator.primaryController,
    );
    if (!mounted || keyword.isEmpty) {
      return;
    }

    _focusCoordinator.syncText(keyword);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchResultsPage(
          initialKeyword: keyword,
          entryIntent: intent,
          comicDetailPageBuilder: widget.comicDetailPageBuilder,
          comicCoverHeroTagBuilder: widget.comicCoverHeroTagBuilder,
          searchPageLoader: widget.searchPageLoader,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    unawaited(_loadHistory());
  }

  Future<void> _confirmClearHistory() async {
    await _focusCoordinator.dismissKeyboard(context, parkOnPage: true);
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
    await _focusCoordinator.dismissKeyboard(context, parkOnPage: true);
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
      unawaited(_focusCoordinator.dismissKeyboard(context, parkOnPage: true));
    });
  }

  Widget _buildSearchBar({
    Key? key,
    required String clearKey,
    required String submitKey,
    FocusNode? focusNode,
    bool compact = false,
    bool autofocus = false,
  }) {
    return SearchBarShell(
      key: key,
      controller: _focusCoordinator.primaryController,
      focusNode: focusNode ?? _focusCoordinator.primaryFocusNode,
      clearKey: clearKey,
      submitKey: submitKey,
      compact: compact,
      autofocus: autofocus,
      onClear: () {
        _focusCoordinator.clearText();
        unawaited(_focusCoordinator.requestPrimarySearchFocus(context));
      },
      onSubmit: () => unawaited(
        _openResults(
          _focusCoordinator.primaryController.text,
          intent: SearchEntryIntent.submitFromEntry,
        ),
      ),
      onSubmitted: (value) => unawaited(
        _openResults(value, intent: SearchEntryIntent.submitFromEntry),
      ),
      onChanged: (value) {
        if (focusNode == _focusCoordinator.collapsedFocusNode) {
          _focusCoordinator.syncText(value, updateCollapsed: false);
        } else {
          _focusCoordinator.syncText(value, updatePrimary: false);
        }
      },
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
                    key: const ValueKey('search-entry-primary-search-bar'),
                    clearKey: 'entry-clear',
                    submitKey: 'entry-submit',
                    autofocus: true,
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
                        child: _buildSearchBar(
                          key: const ValueKey(
                            'search-entry-collapsed-search-bar',
                          ),
                          clearKey: 'entry-collapsed-clear',
                          submitKey: 'entry-collapsed-submit',
                          focusNode: _focusCoordinator.collapsedFocusNode,
                          compact: true,
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
      child: ListenableBuilder(
        listenable: _focusCoordinator,
        builder: (context, _) => PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              return;
            }
            unawaited(_focusCoordinator.dismissKeyboard(context));
          },
          child: Focus(
            focusNode: _focusCoordinator.pageFocusNode,
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
                          unawaited(
                            _focusCoordinator.dismissKeyboard(
                              context,
                              parkOnPage: true,
                            ),
                          );
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
                      unawaited(
                        _openResults(
                          keyword,
                          intent: SearchEntryIntent.historySelection,
                        ),
                      );
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
        ),
      ),
    );
  }
}
