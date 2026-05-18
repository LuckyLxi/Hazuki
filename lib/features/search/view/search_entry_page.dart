import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import 'search_bar_shell.dart';
import 'search_history_section.dart';
import 'search_id_extract_pill.dart';
import 'search_results_page.dart';
import '../state/search_focus_coordinator.dart';
import '../support/search_history_service.dart';
import '../support/search_shared.dart';

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

class _SearchEntryPageState extends State<SearchEntryPage>
    with WidgetsBindingObserver {
  late final SearchFocusCoordinator _focusCoordinator = SearchFocusCoordinator(
    isMounted: () => mounted,
    allowCollapsedFocus: false,
  );
  final HazukiSourceService _sourceService = sl<HazukiSourceService>();
  final ScrollController _scrollController = ScrollController();
  final SearchHistoryService _historyService = SearchHistoryService();

  List<String> _historyList = <String>[];
  bool _historyEditMode = false;
  bool _historyExpanded = false;
  bool _comicIdSearchEnhance = false;
  bool _pendingExtractedComicIdHide = false;
  String? _extractedComicId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
    unawaited(_loadComicIdSearchEnhance());
    WidgetsBinding.instance.addObserver(this);
    _sourceService.addListener(_handleSourceChanged);
    _focusCoordinator.primaryFocusNode.addListener(_handleSearchFocusChanged);
  }

  @override
  void dispose() {
    _focusCoordinator.primaryFocusNode.removeListener(
      _handleSearchFocusChanged,
    );
    // 页面退出时清除额外底部偏移，避免影响其他页面的提示药丸
    hazukiPromptPlacementController.setExtraBottomPadding(0);
    WidgetsBinding.instance.removeObserver(this);
    _sourceService.removeListener(_handleSourceChanged);
    _focusCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }
    final wasKeyboardVisible = _focusCoordinator.keyboardVisible;
    _focusCoordinator.syncKeyboardVisibility();
    if (wasKeyboardVisible && !_focusCoordinator.keyboardVisible) {
      _scheduleHideExtractedComicIdIfUnfocused();
    }
  }

  void _handleSearchFocusChanged() {
    if (_searchInputFocused) {
      _syncExtractedComicIdWithFocus(_focusCoordinator.text);
    } else {
      _scheduleHideExtractedComicIdIfUnfocused();
    }
    _logSearchEntryEvent('Search entry focus changed', stage: 'focus_listener');
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
  }

  Future<void> _loadComicIdSearchEnhance() async {
    final enabled = await isComicIdSearchEnhanceEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _comicIdSearchEnhance = enabled && _sourceService.isActiveJmSource;
      _extractedComicId = _extractComicIdFromFocusedInput(
        _focusCoordinator.text,
      );
    });
  }

  void _handleSourceChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (!_sourceService.isActiveJmSource) {
        _comicIdSearchEnhance = false;
        _extractedComicId = null;
        _syncPromptAnchor(false);
      }
    });
    if (_sourceService.isActiveJmSource) {
      unawaited(_loadComicIdSearchEnhance());
    }
  }

  bool get _searchInputFocused =>
      _focusCoordinator.primaryFocusNode.hasFocus ||
      _focusCoordinator.collapsedFocusNode.hasFocus;

  String? _extractComicIdFromFocusedInput(String value) {
    if (!_comicIdSearchEnhance || !_searchInputFocused) {
      return null;
    }
    return extractBestComicId(value);
  }

  void _hideExtractedComicId() {
    _pendingExtractedComicIdHide = false;
    if (_extractedComicId == null) {
      _syncPromptAnchor(false);
      return;
    }
    setState(() => _extractedComicId = null);
    _syncPromptAnchor(false);
  }

  /// 同步提示药丸的底部偏移，避免被搜索 ID 药丸遮挡
  void _syncPromptAnchor(bool pillVisible) {
    // 药丸高度约 36px + 底部定位 12px，间距约 6px
    hazukiPromptPlacementController.setExtraBottomPadding(
      pillVisible ? 36.0 : 0.0,
    );
  }

  void _scheduleHideExtractedComicIdIfUnfocused() {
    if (_pendingExtractedComicIdHide) {
      return;
    }
    _pendingExtractedComicIdHide = true;
    // 延迟需大于 InkWell 的点击响应时间，避免药丸 onTap 前状态已被清空
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !_pendingExtractedComicIdHide) {
        return;
      }
      _pendingExtractedComicIdHide = false;
      if (!_searchInputFocused) {
        _hideExtractedComicId();
      }
    });
  }

  void _syncExtractedComicIdWithFocus(String value) {
    _pendingExtractedComicIdHide = false;
    final id = _extractComicIdFromFocusedInput(value);
    if (id != _extractedComicId) {
      setState(() => _extractedComicId = id);
      _syncPromptAnchor(id != null);
    }
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
  }

  Future<void> _openResults(
    String rawKeyword, {
    required SearchEntryIntent intent,
  }) async {
    _hideExtractedComicId();
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
    required String logTarget,
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
      onTap: () => _handleSearchBarTap(logTarget),
      onClear: () {
        _focusCoordinator.clearText();
        _hideExtractedComicId();
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
        _syncExtractedComicIdWithFocus(value);
      },
    );
  }

  void _handleSearchBarTap(String target) {
    _syncExtractedComicIdWithFocus(_focusCoordinator.text);
    _logSearchEntryEvent(
      'Search entry bar tapped',
      stage: 'tap_start',
      target: target,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _logSearchEntryEvent(
        'Search entry bar tapped',
        stage: 'tap_post_frame',
        target: target,
      );
    });
    unawaited(_logSearchEntryTapDelayed(target));
  }

  Future<void> _logSearchEntryTapDelayed(String target) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    _logSearchEntryEvent(
      'Search entry bar tapped',
      stage: 'tap_after_120ms',
      target: target,
    );
  }

  void _logSearchEntryEvent(
    String title, {
    required String stage,
    String? target,
  }) {
    final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
        ? WidgetsBinding.instance.platformDispatcher.views.first
        : null;
    final primarySelection = _focusCoordinator.primaryController.selection;
    final collapsedSelection = _focusCoordinator.collapsedController.selection;
    _sourceService.addApplicationLog(
      level: 'info',
      title: title,
      source: 'search_entry_focus',
      content: {
        'stage': stage,
        ...?target == null ? null : {'target': target},
        'showCollapsedSearch': false,
        'keyboardVisible': _focusCoordinator.keyboardVisible,
        'viewInsetsBottom': view?.viewInsets.bottom ?? 0,
        'primaryHasFocus': _focusCoordinator.primaryFocusNode.hasFocus,
        'collapsedHasFocus': _focusCoordinator.collapsedFocusNode.hasFocus,
        'pageHasFocus': _focusCoordinator.pageFocusNode.hasFocus,
        'primaryTextLength': _focusCoordinator.primaryController.text.length,
        'collapsedTextLength':
            _focusCoordinator.collapsedController.text.length,
        'primarySelection': _selectionSnapshot(primarySelection),
        'collapsedSelection': _selectionSnapshot(collapsedSelection),
        'focusManagerPrimary':
            FocusManager.instance.primaryFocus?.debugLabel ?? 'null',
      },
    );
  }

  Map<String, Object?> _selectionSnapshot(TextSelection selection) {
    return {
      'valid': selection.isValid,
      'baseOffset': selection.baseOffset,
      'extentOffset': selection.extentOffset,
      'isCollapsed': selection.isCollapsed,
    };
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
                        },
                        child: Icon(
                          _historyEditMode ? Icons.done : Icons.delete_outline,
                        ),
                      ),
                    )
                  : null,
              appBar: hazukiFrostedAppBar(
                context: context,
                title: Hero(
                  tag: discoverSearchHeroTag,
                  child: _buildSearchBar(
                    key: const ValueKey('search-entry-app-bar-search-bar'),
                    clearKey: 'entry-clear',
                    submitKey: 'entry-submit',
                    logTarget: 'app_bar',
                    compact: true,
                  ),
                ),
                enableBlur: false,
              ),
              body: Stack(
                children: [
                  ListView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
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
                        },
                        onLayoutChanged: () {},
                      ),
                    ],
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: SearchIdExtractPill(
                      extractedId: _extractedComicId,
                      onApply: () {
                        // 提前捕获，防止计时器并发时状态已为 null
                        final id = _extractedComicId;
                        if (id == null) return;
                        _pendingExtractedComicIdHide = false;
                        _focusCoordinator.syncText(id);
                        _hideExtractedComicId();
                        unawaited(
                          _openResults(
                            id,
                            intent: SearchEntryIntent.submitFromEntry,
                          ),
                        );
                      },
                    ),
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
