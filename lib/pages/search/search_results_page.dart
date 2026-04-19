import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/windows_comic_detail_host.dart';
import 'search_bar_shell.dart';
import 'search_focus_coordinator.dart';
import 'search_results_controller.dart';
import 'search_results_widgets.dart';
import 'search_shared.dart';

part 'search_results_lifecycle_actions.dart';
part 'search_results_search_actions.dart';
part 'search_results_shell_widgets.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.initialKeyword,
    this.initialOrder = 'mr',
    this.entryIntent = SearchEntryIntent.externalKeyword,
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
    this.searchPageLoader,
  });

  final String initialKeyword;
  final String initialOrder;
  final SearchEntryIntent entryIntent;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;
  final SearchPageLoader? searchPageLoader;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final SearchResultsController _resultsController;
  late final SearchFocusCoordinator _focusCoordinator = SearchFocusCoordinator(
    isMounted: () => mounted,
    initialText: widget.initialKeyword,
  );

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _collapsedSearchKey = GlobalKey();

  bool _showBackToTop = false;
  double _searchRevealProgress = 0;
  bool _flyingSearchToTop = false;
  AnimationController? _flyController;
  OverlayEntry? _flyOverlay;

  bool get _showCollapsedSearch => _searchRevealProgress >= 0.94;
  String get _searchKeyword => _resultsController.searchKeyword;
  String? get _searchErrorMessage => _resultsController.searchErrorMessage;
  List<ExploreComic> get _searchComics => _resultsController.searchComics;
  bool get _searchLoading => _resultsController.searchLoading;
  bool get _searchLoadingMore => _resultsController.searchLoadingMore;
  String get _searchOrder => _resultsController.searchOrder;
  bool get _collapsedSearchExpanded =>
      _focusCoordinator.collapsedSearchExpanded;
  bool get _showKeyboardOnEnter => widget.entryIntent.showKeyboardOnEnter;

  @override
  void initState() {
    super.initState();
    _initializeSearchResultsPage();
  }

  @override
  void dispose() {
    _disposeSearchResultsPage();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _handleMetricsChanged();
  }

  void _updateSearchResultsState(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    return WindowsComicDetailHost(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _resultsController,
          _focusCoordinator,
          HazukiSourceService.instance,
        ]),
        builder: (context, _) => PopScope(
          canPop: !_focusCoordinator.collapsedSearchExpanded,
          onPopInvokedWithResult: _handlePopInvoked,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: _buildSearchResultsAppBar(),
            body: Stack(
              children: [
                _buildSearchResultsBody(),
                _buildSearchBackToTopButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
