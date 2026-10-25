import 'package:hazuki/shared/source_task_owner.dart';
import 'package:flutter/widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import 'discover_section_page_state.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';

class DiscoverSectionPageController extends ChangeNotifier {
  DiscoverSectionPageController({
    required SourceTaskControlGateway taskControl,
    required SourceDiscoverGateway sourceService,
    String? viewMoreUrl,
    List<ExploreComic>? initialComics,
  }) : _readTasks = SourceTaskOwner(taskControl),
       _viewMoreUrl = viewMoreUrl,
       _sourceService = sourceService {
    _sourceKey = sourceService.activeSourceKey;
    _sourceRevision = sourceService.sourceRevision;
    sourceService.addListener(_sourceChanged);
    if (viewMoreUrl == null && initialComics != null) {
      _state.comics = List<ExploreComic>.of(initialComics);
      _state.hasMore = false;
      _state.sortLoading = false;
    }
  }

  final SourceDiscoverGateway _sourceService;
  final String? _viewMoreUrl;
  String Function(String)? _loadFailedMessage;
  final DiscoverSectionPageState _state = DiscoverSectionPageState();
  bool _disposed = false;
  final _sourceUi = SourceUiOwner();
  final SourceTaskOwner _readTasks;
  String? _sourceKey;
  String? _sourceRevision;

  void _sourceChanged() {
    final key = _sourceService.activeSourceKey;
    final revision = _sourceService.sourceRevision;
    if (key == _sourceKey && revision == _sourceRevision) return;
    _readTasks.restart(
      key != _sourceKey
          ? SourceTaskStopReason.sourceChanged
          : SourceTaskStopReason.pluginUpdated,
    );
    _sourceKey = key;
    _sourceRevision = revision;
    _sourceUi.cancel('sourceChanged');
    _state.requestVersion++;
    _state.loadingMore = false;
    _state.sortLoading = false;
    _notify();
  }

  List<ExploreComic> get comics => _state.comics;
  List<CategoryRankingOption> get sortOptions => _state.sortOptions;
  List<List<CategoryRankingOption>> get sortOptionGroups =>
      _state.sortOptionGroups;
  String? get selectedSortValue => _state.selectedSortValue;
  List<String> get selectedSortValues => _state.selectedSortValues;
  bool get loadingMore => _state.loadingMore;
  bool get hasMore => _state.hasMore;
  int get currentPage => _state.currentPage;
  String? get errorMessage => _state.errorMessage;
  bool get sortLoading => _state.sortLoading;
  bool get showLoadMoreFooter => _state.showLoadMoreFooter;

  /// Loads sort options then triggers the first page load.
  /// On sort option failure, lets the plugin choose its default ordering.
  Future<void> loadSortOptionsAndInitial({
    required String Function(String) loadFailedMessage,
  }) async {
    _readTasks.restart();
    final generation = _readTasks.generation;
    _loadFailedMessage = loadFailedMessage;
    final url = _viewMoreUrl;
    if (url == null) return;

    if (!_state.sortLoading) {
      _state.sortLoading = true;
      _notify();
    }

    try {
      final optionGroups = await _sourceUi.run(
        () => _sourceService.loadCategoryOptionGroupsByViewMore(
          viewMoreUrl: url,
          taskOrigin: _readTasks.origin(),
        ),
      );
      if (_disposed || generation != _readTasks.generation) return;

      _state.sortOptionGroups = optionGroups;
      _state.sortOptions = optionGroups.isEmpty
          ? const <CategoryRankingOption>[]
          : optionGroups.first;
      _state.selectedSortValues = optionGroups
          .asMap()
          .entries
          .map((entry) => _initialSelectionForGroup(entry.value))
          .toList();
      _state.selectedSortValue = _state.selectedSortValues.isEmpty
          ? null
          : _state.selectedSortValues.first;
      _state.currentPage = 0;
      _state.hasMore = true;
      _state.errorMessage = null;
      _notify();

      if (!_sourceUi.wasCancelled) await _loadPage();
    } catch (error) {
      if (_disposed || generation != _readTasks.generation) return;
      if ((isSourceUiCancellation(error) || isSourceTaskCancellation(error)) ||
          _sourceUi.wasCancelled) {
        return;
      }
      _state.sortOptions = const <CategoryRankingOption>[];
      _state.sortOptionGroups = const <List<CategoryRankingOption>>[];
      _state.selectedSortValue = null;
      _state.selectedSortValues = const <String>[];
      _notify();
      await _loadPage();
    } finally {
      if (!_disposed && generation == _readTasks.generation) {
        _state.sortLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (_state.loadingMore || !_state.hasMore) return;
    await _loadPage();
  }

  Future<void> selectSortOption({required String value}) async {
    if (_state.selectedSortValue == value || _state.loadingMore) return;

    _readTasks.restart();
    _state.selectedSortValue = value;
    _state.errorMessage = null;
    _state.currentPage = 0;
    _state.hasMore = true;
    _state.showLoadMoreFooter = false;
    _state.comics.clear();
    _notify();

    await _loadPage();
  }

  Future<void> selectSortOptionInGroup({
    required int groupIndex,
    required String value,
  }) async {
    if (_state.loadingMore || groupIndex < 0) return;
    final next = List<String>.of(_state.selectedSortValues);
    while (next.length <= groupIndex) {
      next.add('');
    }
    if (next[groupIndex] == value) return;

    next[groupIndex] = value;
    _readTasks.restart();
    _state.selectedSortValues = next;
    _state.selectedSortValue = next.isEmpty ? null : next.first;
    _state.errorMessage = null;
    _state.currentPage = 0;
    _state.hasMore = true;
    _state.showLoadMoreFooter = false;
    _state.comics.clear();
    _notify();

    await _loadPage();
  }

  void revealLoadMoreFooter() {
    if (!_state.showLoadMoreFooter) {
      _state.showLoadMoreFooter = true;
      _notify();
    }
  }

  Future<void> _loadPage() async {
    final url = _viewMoreUrl;
    final failedMsg = _loadFailedMessage;
    if (url == null || failedMsg == null) return;

    final nextPage = _state.currentPage + 1;
    final showFooter = nextPage > 1 && _state.comics.isNotEmpty;
    final requestVersion = ++_state.requestVersion;
    _sourceUi.restart();

    _state.loadingMore = true;
    _state.showLoadMoreFooter = showFooter;
    _state.errorMessage = null;
    _notify();

    try {
      final result = await _sourceUi.run(
        () => _sourceService.loadCategoryComicsByViewMore(
          viewMoreUrl: url,
          page: nextPage,
          order: _state.selectedSortValue ?? '',
          orders: _state.selectedSortValues,
          taskOrigin: _readTasks.origin(),
        ),
      );

      if (_disposed || requestVersion != _state.requestVersion) return;

      if (nextPage == 1) {
        _state.comics
          ..clear()
          ..addAll(result.comics);
      } else {
        final existedIds = _state.comics
            .map((e) => e.id)
            .where((id) => id.isNotEmpty)
            .toSet();
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
      _state.errorMessage =
          (isSourceUiCancellation(e) || isSourceTaskCancellation(e))
          ? null
          : failedMsg('$e');
      _notify();
    } finally {
      if (!_disposed && requestVersion == _state.requestVersion) {
        _state.loadingMore = false;
        _state.showLoadMoreFooter = false;
        _notify();
      }
    }
  }

  String _initialSelectionForGroup(List<CategoryRankingOption> group) {
    if (group.isEmpty) return '';
    return group.first.value;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _sourceService.removeListener(_sourceChanged);
    _readTasks.dispose();
    _sourceUi.dispose();
    _disposed = true;
    super.dispose();
  }
}
