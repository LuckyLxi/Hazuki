import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/search_focus_coordinator.dart';
import '../state/search_id_extract_controller.dart';
import '../support/search_history_service.dart';
import '../support/search_shared.dart';
import 'search_bar_shell.dart';
import 'search_entry_widgets.dart';
import 'search_results_page.dart';

class SearchEntryPage extends StatefulWidget {
  const SearchEntryPage({
    super.key,
    this.autoFocusOnOpen = false,
    required this.comicDetailPageBuilder,
    required this.comicCoverHeroTagBuilder,
    this.searchPageLoader,
  });

  final bool autoFocusOnOpen;
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
  late final SearchIdExtractController _idExtractController =
      SearchIdExtractController(
        sourceService: _sourceService,
        isMounted: () => mounted,
        isInputFocused: () => _searchInputFocused,
        currentText: () => _focusCoordinator.text,
      );
  final ScrollController _scrollController = ScrollController();
  final SearchHistoryService _historyService = sl<SearchHistoryService>();

  List<String> _historyList = <String>[];
  Animation<double>? _initialDataLoadRouteAnimation;
  bool _historyEditMode = false;
  bool _historyExpanded = false;
  bool _initialDataLoadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusCoordinator.primaryFocusNode.addListener(_handleSearchFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusCoordinator.attachRouteAutoFocus(
      context,
      showKeyboard: widget.autoFocusOnOpen,
      forceShowKeyboard: true,
    );
    _scheduleInitialDataLoadAfterRouteAnimation();
  }

  @override
  void dispose() {
    final routeAnimation = _initialDataLoadRouteAnimation;
    if (routeAnimation != null) {
      routeAnimation.removeStatusListener(_handleInitialDataLoadRouteStatus);
      _initialDataLoadRouteAnimation = null;
    }
    _focusCoordinator.primaryFocusNode.removeListener(
      _handleSearchFocusChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    _idExtractController.dispose();
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
      _idExtractController.scheduleHideIfUnfocused();
    }
  }

  void _scheduleInitialDataLoadAfterRouteAnimation() {
    if (_initialDataLoadScheduled || !mounted) {
      return;
    }
    _initialDataLoadScheduled = true;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadInitialData());
        }
      });
      return;
    }
    _initialDataLoadRouteAnimation = animation;
    animation.addStatusListener(_handleInitialDataLoadRouteStatus);
  }

  void _handleInitialDataLoadRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    final animation = _initialDataLoadRouteAnimation;
    animation?.removeStatusListener(_handleInitialDataLoadRouteStatus);
    _initialDataLoadRouteAnimation = null;
    if (mounted) {
      unawaited(_loadInitialData());
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadHistory(), _idExtractController.load()]);
  }

  void _handleSearchFocusChanged() {
    if (_searchInputFocused) {
      _idExtractController.syncWithFocus(_focusCoordinator.text);
    } else {
      _idExtractController.scheduleHideIfUnfocused();
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

  bool get _searchInputFocused =>
      _focusCoordinator.primaryFocusNode.hasFocus ||
      _focusCoordinator.collapsedFocusNode.hasFocus;

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
    _idExtractController.hide();
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
        _idExtractController.hide();
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
        _idExtractController.syncWithFocus(value);
      },
    );
  }

  void _handleSearchBarTap(String target) {
    _idExtractController.syncWithFocus(_focusCoordinator.text);
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

  void _toggleHistoryEditMode() {
    unawaited(_focusCoordinator.dismissKeyboard(context, parkOnPage: true));
    setState(() {
      _historyEditMode = !_historyEditMode;
    });
  }

  void _applyExtractedComicId() {
    final id = _idExtractController.captureApplyId();
    if (id == null) return;
    _focusCoordinator.syncText(id);
    _idExtractController.hide();
    unawaited(_openResults(id, intent: SearchEntryIntent.submitFromEntry));
  }

  @override
  Widget build(BuildContext context) {
    return WindowsComicDetailHost(
      child: ListenableBuilder(
        listenable: Listenable.merge([_focusCoordinator, _idExtractController]),
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
                  ? SearchEntryHistoryEditFab(
                      editMode: _historyEditMode,
                      onPressed: _toggleHistoryEditMode,
                      onLongPress: _confirmClearHistory,
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
              body: SearchEntryBody(
                scrollController: _scrollController,
                historyList: _historyList,
                historyEditMode: _historyEditMode,
                historyExpanded: _historyExpanded,
                extractedComicId: _idExtractController.extractedId,
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
                onHistoryExpandedChanged: (expanded) {
                  setState(() {
                    _historyExpanded = expanded;
                  });
                },
                onApplyExtractedComicId: _applyExtractedComicId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
