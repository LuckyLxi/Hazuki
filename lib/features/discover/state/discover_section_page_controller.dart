import 'package:flutter/widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import 'discover_section_page_state.dart';

class DiscoverSectionPageController extends ChangeNotifier {
  DiscoverSectionPageController({
    HazukiSourceService? sourceService,
    List<ExploreComic>? initialComics,
  }) : _sourceService = sourceService ?? HazukiSourceService.instance {
    if (initialComics != null) {
      _state.comics = List<ExploreComic>.of(initialComics);
      _state.hasMore = false;
      _state.sortLoading = false;
    }
  }

  final HazukiSourceService _sourceService;
  final DiscoverSectionPageState _state = DiscoverSectionPageState();
  bool _disposed = false;

  List<ExploreComic> get comics => _state.comics;
  List<CategoryRankingOption> get sortOptions => _state.sortOptions;
  String? get selectedSortValue => _state.selectedSortValue;
  bool get loadingMore => _state.loadingMore;
  bool get hasMore => _state.hasMore;
  int get currentPage => _state.currentPage;
  String? get errorMessage => _state.errorMessage;
  bool get sortLoading => _state.sortLoading;
  bool get showLoadMoreFooter => _state.showLoadMoreFooter;

  /// Loads sort options then triggers the first page load.
  /// On sort option failure, sets default sort value but does not load.
  Future<void> loadSortOptionsAndInitial({
    required String viewMoreUrl,
    required String Function(String) loadFailedMessage,
  }) async {
    if (!_state.sortLoading) {
      _state.sortLoading = true;
      _notify();
    }

    try {
      final options = await _sourceService.loadCategoryRankingOptionsByViewMore(
        viewMoreUrl: viewMoreUrl,
      );
      if (_disposed) return;

      _state.sortOptions = options;
      _state.selectedSortValue = options.isEmpty ? null : options.first.value;
      _state.currentPage = 0;
      _state.hasMore = true;
      _state.errorMessage = null;
      _notify();

      await _loadPage(
        viewMoreUrl: viewMoreUrl,
        loadFailedMessage: loadFailedMessage,
      );
    } catch (_) {
      if (_disposed) return;
      _state.sortOptions = const <CategoryRankingOption>[];
      _state.selectedSortValue = 'mr';
      _notify();
    } finally {
      if (!_disposed) {
        _state.sortLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore({
    required String viewMoreUrl,
    required String Function(String) loadFailedMessage,
  }) async {
    if (_state.loadingMore || !_state.hasMore) return;
    await _loadPage(
      viewMoreUrl: viewMoreUrl,
      loadFailedMessage: loadFailedMessage,
    );
  }

  Future<void> selectSortOption({
    required String value,
    required String viewMoreUrl,
    required String Function(String) loadFailedMessage,
  }) async {
    if (_state.selectedSortValue == value || _state.loadingMore) return;

    _state.selectedSortValue = value;
    _state.errorMessage = null;
    _state.currentPage = 0;
    _state.hasMore = true;
    _state.showLoadMoreFooter = false;
    _state.comics.clear();
    _notify();

    await _loadPage(
      viewMoreUrl: viewMoreUrl,
      loadFailedMessage: loadFailedMessage,
    );
  }

  void revealLoadMoreFooter() {
    if (!_state.showLoadMoreFooter) {
      _state.showLoadMoreFooter = true;
      _notify();
    }
  }

  Future<void> _loadPage({
    required String viewMoreUrl,
    required String Function(String) loadFailedMessage,
  }) async {
    final nextPage = _state.currentPage + 1;
    final showFooter = nextPage > 1 && _state.comics.isNotEmpty;
    final requestVersion = ++_state.requestVersion;

    _state.loadingMore = true;
    _state.showLoadMoreFooter = showFooter;
    _state.errorMessage = null;
    _notify();

    try {
      final result = await _sourceService.loadCategoryComicsByViewMore(
        viewMoreUrl: viewMoreUrl,
        page: nextPage,
        order: _state.selectedSortValue ?? 'mr',
      );

      if (_disposed || requestVersion != _state.requestVersion) return;

      if (nextPage == 1) {
        _state.comics
          ..clear()
          ..addAll(result.comics);
      } else {
        final existedIds = _state.comics.map((e) => e.id).toSet();
        final incoming = result.comics
            .where((e) => e.id.isEmpty || !existedIds.contains(e.id))
            .toList();
        _state.comics.addAll(incoming);
      }
      _state.currentPage = nextPage;
      final maxPage = result.maxPage;
      _state.hasMore =
          result.comics.isNotEmpty && (maxPage == null || nextPage < maxPage);
      _notify();
    } catch (e) {
      if (_disposed || requestVersion != _state.requestVersion) return;
      _state.errorMessage = loadFailedMessage('$e');
      _notify();
    } finally {
      if (!_disposed && requestVersion == _state.requestVersion) {
        _state.loadingMore = false;
        _state.showLoadMoreFooter = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
