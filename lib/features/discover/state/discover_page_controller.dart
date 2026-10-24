import 'package:hazuki/shared/source_task_owner.dart';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

import 'discover_page_state.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';

class DiscoverPageController extends ChangeNotifier {
  DiscoverPageController({
    required SourceTaskControlGateway taskControl,
    required SourceDiscoverGateway sourceService,
    this.onSourceSwitched,
  }) : _readTasks = SourceTaskOwner(taskControl),
       _sourceService = sourceService {
    _lastActiveSourceKey = _sourceService.activeSourceKey;
    _lastSourceRevision = _sourceService.sourceRevision;
    _sourceService.addListener(_onSourceChanged);
  }

  static const _discoverLoadTimeout = Duration(seconds: 20);
  static const _initialVisibleSectionCount = 1;
  static const _sectionRevealBatchSize = 1;
  static const _lifecycleStopRetryLimit = 2;
  static const _lifecycleStopReasons = {
    SourceTaskStopReason.sourceChanged,
    SourceTaskStopReason.pluginUpdated,
    SourceTaskStopReason.pluginDisabled,
    SourceTaskStopReason.runtimeClosed,
  };

  final SourceDiscoverGateway _sourceService;
  final DiscoverPageState _state = DiscoverPageState();
  bool _disposed = false;
  final _sourceUi = SourceUiOwner();
  final SourceTaskOwner _readTasks;
  int _sourceGeneration = 0;
  late String? _lastActiveSourceKey;
  String? _lastSourceRevision;

  /// 源切换时的回调，由外层 View 绑定以触发刷新
  final VoidCallback? onSourceSwitched;

  SourceRuntimeState get sourceRuntimeState => _sourceService.runtimeState;

  void _onSourceChanged() {
    final activeKey = _sourceService.activeSourceKey;
    if (activeKey != _lastActiveSourceKey) _sourceUi.cancel('sourceChanged');
    if (activeKey != _lastActiveSourceKey ||
        _lastSourceRevision != _sourceService.sourceRevision) {
      // 源发生了实际切换，通知 View 执行刷新
      final reason = activeKey != _lastActiveSourceKey
          ? SourceTaskStopReason.sourceChanged
          : SourceTaskStopReason.pluginUpdated;
      _lastActiveSourceKey = activeKey;
      _lastSourceRevision = _sourceService.sourceRevision;
      _readTasks.restart(reason);
      _sourceGeneration++;
      _state.sectionRevealGeneration++;
      _state.sections = const [];
      _state.refreshing = false;
      _state.sectionLoadingMore.clear();
      onSourceSwitched?.call();
    }
    _notify();
  }

  List<ExploreSection> get sections => _state.sections;
  String? get errorMessage => _state.errorMessage;
  bool get initialLoading => _state.initialLoading;
  bool get refreshing => _state.refreshing;
  int get visibleSectionCount => _state.visibleSectionCount;
  bool isSectionLoadingMore(int index) =>
      _state.sectionLoadingMore.contains(index);
  bool sectionHasMore(int index) => !_state.sectionNoMore.contains(index);
  bool get showLoginRequired =>
      (_sourceService.requiresLogin == true) && !_sourceService.isLogged;

  Future<void> loadInitial({
    required String timeoutMessage,
    required String Function(String) loadFailedMessage,
  }) async {
    _readTasks.restart();
    _sourceUi.restart();
    if (showLoginRequired) {
      _state.sections = const [];
      _state.errorMessage = null;
      _state.visibleSectionCount = 0;
      _state.initialLoading = false;
      _notify();
      return;
    }

    final sourceGeneration = _sourceGeneration;
    final requestGeneration = _readTasks.generation;
    List<ExploreSection>? loadedSections;
    String? error;
    try {
      loadedSections = await _loadSections(
        sourceGeneration: sourceGeneration,
        requestGeneration: requestGeneration,
      );
    } catch (e) {
      error = (isSourceUiCancellation(e) || isSourceTaskCancellation(e))
          ? null
          : (e is SourceTaskTimedOut ||
                e.toString().contains('discover_load_timeout'))
          ? timeoutMessage
          : loadFailedMessage('$e');
    }

    if (_disposed ||
        sourceGeneration != _sourceGeneration ||
        requestGeneration != _readTasks.generation) {
      return;
    }

    _state.sectionRevealGeneration++;
    final generation = _state.sectionRevealGeneration;
    if (loadedSections != null) {
      _state.sections = loadedSections;
      _resetSectionPaging();
      _state.errorMessage = null;
      _state.visibleSectionCount = math.min(
        _initialVisibleSectionCount,
        loadedSections.length,
      );
    } else {
      _state.sections = const [];
      _state.errorMessage = error;
      _state.visibleSectionCount = 0;
    }
    _state.initialLoading = false;
    _notify();

    if (loadedSections != null &&
        _state.visibleSectionCount < loadedSections.length) {
      _scheduleRemainingSectionReveal(generation);
    }
  }

  Future<void> refresh({
    required String timeoutMessage,
    required String Function(String) loadFailedMessage,
  }) async {
    if (_state.refreshing) return;
    _readTasks.restart();
    _sourceUi.restart();
    if (showLoginRequired) {
      _state.sections = const [];
      _state.errorMessage = null;
      _state.visibleSectionCount = 0;
      _state.initialLoading = false;
      _state.refreshing = false;
      _notify();
      return;
    }
    if (_sourceService.runtimeState.canRetry) {
      _sourceService.logRuntimeRetryRequested('discover_page');
    }

    _state.refreshing = true;
    _notify();

    final sourceGeneration = _sourceGeneration;
    final requestGeneration = _readTasks.generation;
    List<ExploreSection>? refreshedSections;
    String? error;
    try {
      refreshedSections = await _loadSections(
        forceRefresh: true,
        sourceGeneration: sourceGeneration,
        requestGeneration: requestGeneration,
      );
    } catch (e) {
      error = (isSourceUiCancellation(e) || isSourceTaskCancellation(e))
          ? null
          : (e is SourceTaskTimedOut ||
                e.toString().contains('discover_load_timeout'))
          ? timeoutMessage
          : loadFailedMessage('$e');
    }

    if (_disposed ||
        sourceGeneration != _sourceGeneration ||
        requestGeneration != _readTasks.generation) {
      return;
    }

    final revealProgressively = _state.sections.isEmpty;
    _state.sectionRevealGeneration++;
    final generation = _state.sectionRevealGeneration;

    if (refreshedSections != null) {
      _state.sections = refreshedSections;
      _resetSectionPaging();
      _state.errorMessage = null;
      _state.visibleSectionCount = revealProgressively
          ? math.min(_initialVisibleSectionCount, refreshedSections.length)
          : refreshedSections.length;
    } else {
      _state.errorMessage = error;
    }
    _state.refreshing = false;
    _notify();

    if (refreshedSections != null &&
        _state.visibleSectionCount < refreshedSections.length) {
      _scheduleRemainingSectionReveal(generation);
    }
  }

  /// 源切换、插件更新或运行时重建会从外部中止进行中的请求，而本页的
  /// 换代通知可能晚于取消到达；此时直接重发，避免把空结果误显示为无内容。
  Future<List<ExploreSection>> _loadSections({
    bool forceRefresh = false,
    required int sourceGeneration,
    required int requestGeneration,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _sourceUi.run(
          () => SourceUiScope.timeout(
            _sourceService.loadExploreSections(
              forceRefresh: forceRefresh,
              taskOrigin: _readTasks.origin(),
            ),
            _discoverLoadTimeout,
            onTimeout: () => throw Exception('discover_load_timeout'),
          ),
        );
      } catch (e) {
        final superseded =
            _disposed ||
            sourceGeneration != _sourceGeneration ||
            requestGeneration != _readTasks.generation;
        if (superseded ||
            attempt >= _lifecycleStopRetryLimit ||
            !_isStoppedBySourceLifecycle(e)) {
          rethrow;
        }
      }
    }
  }

  static bool _isStoppedBySourceLifecycle(Object error) {
    if (error is SourceTaskTimedOut) return false;
    if (error is SourceTaskCancelled) {
      return _lifecycleStopReasons.contains(error.reason);
    }
    if (!isSourceUiCancellation(error)) return false;
    final text = error.toString();
    return text.contains('plugin_ui_cancelled:sourceChanged') ||
        text.contains('plugin_ui_cancelled:runtimeDisposed');
  }

  void _scheduleRemainingSectionReveal(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _state.sectionRevealGeneration) return;
      if (_state.visibleSectionCount >= _state.sections.length) return;

      _state.visibleSectionCount = math.min(
        _state.visibleSectionCount + _sectionRevealBatchSize,
        _state.sections.length,
      );
      _notify();

      if (_state.visibleSectionCount < _state.sections.length) {
        _scheduleRemainingSectionReveal(generation);
      }
    });
  }

  Future<void> loadMoreSection(int index) async {
    if (index < 0 || index >= _state.sections.length) return;
    if (_state.sectionLoadingMore.contains(index) ||
        _state.sectionNoMore.contains(index)) {
      return;
    }

    final section = _state.sections[index];
    final viewMoreUrl = section.viewMoreUrl;
    if (viewMoreUrl == null || viewMoreUrl.isEmpty) return;

    var currentPage = _state.sectionPages[index] ?? section.initialPage;
    final maxPage = section.maxPage;
    if (maxPage != null && currentPage >= maxPage) {
      _state.sectionNoMore.add(index);
      return;
    }

    _state.sectionLoadingMore.add(index);
    _notify();

    final sourceGeneration = _sourceGeneration;
    final requestGeneration = _readTasks.generation;
    try {
      while (true) {
        final nextPage = currentPage + 1;
        final result = await _sourceUi.run(
          () => _sourceService.loadCategoryComicsByViewMore(
            viewMoreUrl: viewMoreUrl,
            page: nextPage,
            taskOrigin: _readTasks.origin(),
          ),
        );
        if (_disposed ||
            sourceGeneration != _sourceGeneration ||
            requestGeneration != _readTasks.generation ||
            index >= _state.sections.length) {
          return;
        }

        final latest = _state.sections[index];
        final existingIds = latest.comics
            .map((comic) => comic.id)
            .where((id) => id.isNotEmpty)
            .toSet();
        final incoming = result.comics
            .where(
              (comic) => comic.id.isEmpty || !existingIds.contains(comic.id),
            )
            .toList();

        final nextSections = List<ExploreSection>.of(_state.sections);
        nextSections[index] = latest.copyWith(
          comics: <ExploreComic>[...latest.comics, ...incoming],
          maxPage: result.maxPage ?? latest.maxPage,
        );
        _state.sections = nextSections;
        _state.sectionPages[index] = nextPage;
        final nextMaxPage = result.maxPage ?? latest.maxPage;
        if (result.comics.isEmpty ||
            (incoming.isEmpty && nextPage > 1) ||
            (nextMaxPage != null && nextPage >= nextMaxPage)) {
          _state.sectionNoMore.add(index);
          break;
        }
        if (incoming.isNotEmpty) break;

        // A preview may already contain the entire first page. Continue in the
        // same request so scrolling can progress even when no items were added.
        currentPage = nextPage;
      }
    } catch (_) {
      // Keep horizontal discovery passive; users can use "More" for errors.
    } finally {
      if (!_disposed && sourceGeneration == _sourceGeneration) {
        _state.sectionLoadingMore.remove(index);
        _notify();
      }
    }
  }

  void _resetSectionPaging() {
    _state.sectionPages.clear();
    _state.sectionLoadingMore.clear();
    _state.sectionNoMore.clear();
    for (var i = 0; i < _state.sections.length; i++) {
      final section = _state.sections[i];
      _state.sectionPages[i] = section.initialPage;
      final maxPage = section.maxPage;
      if (section.viewMoreUrl == null ||
          (maxPage != null && section.initialPage >= maxPage)) {
        _state.sectionNoMore.add(i);
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _readTasks.dispose();
    _sourceUi.dispose();
    _disposed = true;
    _sourceService.removeListener(_onSourceChanged);
    super.dispose();
  }
}
