import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hazuki/app/service_locator.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/widgets/widgets.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

import '../state/search_focus_coordinator.dart';
import '../state/search_id_extract_controller.dart';
import '../support/search_shared.dart';
import 'search_bar_shell.dart';
import 'search_entry_widgets.dart';
import 'search_results_page.dart';
import 'search_settings_dialog.dart';

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
  final SourceSearchGateway _sourceService = sl<SourceSearchGateway>();
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
  bool _aggregateSearchEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusCoordinator.primaryFocusNode.addListener(_handleSearchFocusChanged);
    _historyService.addListener(_handleHistoryChanged);
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
    _historyService.removeListener(_handleHistoryChanged);
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
    final aggregateSearchFuture = isAggregateSearchEnabled();
    await Future.wait([_loadHistory(), _idExtractController.load()]);
    final aggregateSearchEnabled = await aggregateSearchFuture;
    if (!mounted) return;
    setState(() {
      _aggregateSearchEnabled = aggregateSearchEnabled;
    });
  }

  void _handleSearchFocusChanged() {
    if (_searchInputFocused) {
      _idExtractController.syncWithFocus(_focusCoordinator.text);
    } else {
      _idExtractController.scheduleHideIfUnfocused();
    }
  }

  void _handleHistoryChanged() {
    unawaited(_loadHistory());
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

  Future<void> _copyHistoryKeyword(String keyword) async {
    final copiedText = keyword.trim();
    if (copiedText.isEmpty) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact());
    await Clipboard.setData(ClipboardData(text: copiedText));
    if (!mounted) {
      return;
    }
    unawaited(
      showHazukiPrompt(
        context,
        AppLocalizations.of(context)!.searchHistoryCopied,
      ),
    );
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
          aggregateSearchEnabled: _aggregateSearchEnabled,
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
      onTap: _handleSearchBarTap,
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

  void _handleSearchBarTap() {
    _idExtractController.syncWithFocus(_focusCoordinator.text);
  }

  Future<void> _openSearchSettings() async {
    await _focusCoordinator.dismissKeyboard(context, parkOnPage: true);
    if (!mounted) return;
    await showSearchSettingsDialog(
      context,
      aggregateSearchEnabled: _aggregateSearchEnabled,
      onAggregateSearchChanged: (enabled) {
        if (mounted) {
          setState(() {
            _aggregateSearchEnabled = enabled;
          });
        }
        unawaited(setAggregateSearchEnabled(enabled));
      },
    );
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
              floatingActionButtonLocation: _KeyboardSafeEndFloatFabLocation(
                MediaQuery.viewPaddingOf(context).bottom,
              ),
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
                    compact: true,
                  ),
                ),
                enableBlur: false,
                actions: [
                  IconButton(
                    key: const ValueKey('search-settings-button'),
                    tooltip: AppLocalizations.of(context)!.searchSettingsTitle,
                    onPressed: () => unawaited(_openSearchSettings()),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
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
                onKeywordLongPressed: (keyword) =>
                    unawaited(_copyHistoryKeyword(keyword)),
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

class _KeyboardSafeEndFloatFabLocation extends FloatingActionButtonLocation {
  const _KeyboardSafeEndFloatFabLocation(this.bottomViewPadding);

  final double bottomViewPadding;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final offset = FloatingActionButtonLocation.endFloat.getOffset(
      scaffoldGeometry,
    );
    final lowestSafeY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        kFloatingActionButtonMargin -
        bottomViewPadding;
    final safeY = lowestSafeY < 0 ? 0.0 : lowestSafeY;
    return Offset(offset.dx, offset.dy > safeY ? safeY : offset.dy);
  }

  @override
  bool operator ==(Object other) {
    return other is _KeyboardSafeEndFloatFabLocation &&
        other.bottomViewPadding == bottomViewPadding;
  }

  @override
  int get hashCode => bottomViewPadding.hashCode;
}
