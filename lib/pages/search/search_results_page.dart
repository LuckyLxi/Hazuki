import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../l10n/app_localizations.dart';
import '../../models/hazuki_models.dart';
import '../../services/hazuki_source_service.dart';
import '../../widgets/widgets.dart';
import '../../widgets/windows_comic_detail_host.dart';
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
    required this.comicDetailPageBuilder,
    this.comicCoverHeroTagBuilder = comicCoverHeroTag,
  });

  final String initialKeyword;
  final String initialOrder;
  final ComicDetailPageBuilder comicDetailPageBuilder;
  final ComicHeroTagBuilder comicCoverHeroTagBuilder;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final SearchResultsController _resultsController;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _collapsedSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _collapsedSearchFocusNode = FocusNode();
  final GlobalKey _collapsedSearchKey = GlobalKey();

  bool _showBackToTop = false;
  double _searchRevealProgress = 0;
  bool _collapsedSearchExpanded = false;
  double _lastViewInsetsBottom = 0;
  bool _awaitingCollapsedSearchFocus = false;
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
          HazukiSourceService.instance,
        ]),
        builder: (context, _) => PopScope(
          canPop: !_collapsedSearchExpanded,
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
