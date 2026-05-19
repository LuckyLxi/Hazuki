import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import 'discover_page_state.dart';

class DiscoverPageController extends ChangeNotifier {
  DiscoverPageController({
    required HazukiSourceService sourceService,
    this.onSourceSwitched,
  }) : _sourceService = sourceService {
    _lastActiveSourceKey = _sourceService.activeSourceKey;
    _sourceService.addListener(_onSourceChanged);
  }

  static const _discoverLoadTimeout = Duration(seconds: 20);
  static const _initialVisibleSectionCount = 1;
  static const _sectionRevealBatchSize = 1;

  final HazukiSourceService _sourceService;
  final DiscoverPageState _state = DiscoverPageState();
  bool _disposed = false;
  late String _lastActiveSourceKey;

  /// 源切换时的回调，由外层 View 绑定以触发刷新
  final VoidCallback? onSourceSwitched;

  SourceRuntimeState get sourceRuntimeState =>
      _sourceService.sourceRuntimeState;

  void _onSourceChanged() {
    final activeKey = _sourceService.activeSourceKey;
    if (activeKey != _lastActiveSourceKey) {
      // 源发生了实际切换，通知 View 执行刷新
      _lastActiveSourceKey = activeKey;
      onSourceSwitched?.call();
    }
    _notify();
  }

  List<ExploreSection> get sections => _state.sections;
  String? get errorMessage => _state.errorMessage;
  bool get initialLoading => _state.initialLoading;
  bool get refreshing => _state.refreshing;
  int get visibleSectionCount => _state.visibleSectionCount;
  bool get showLoginRequired =>
      isHazukiPicacgSourceKey(_sourceService.activeSourceKey) &&
      !_sourceService.isLogged;

  Future<void> loadInitial({
    required String timeoutMessage,
    required String Function(String) loadFailedMessage,
  }) async {
    if (showLoginRequired) {
      _state.sections = const [];
      _state.errorMessage = null;
      _state.visibleSectionCount = 0;
      _state.initialLoading = false;
      _notify();
      return;
    }

    List<ExploreSection>? loadedSections;
    String? error;
    try {
      loadedSections = await _sourceService.loadExploreSections().timeout(
        _discoverLoadTimeout,
        onTimeout: () => throw Exception('discover_load_timeout'),
      );
    } catch (e) {
      error = e.toString().contains('discover_load_timeout')
          ? timeoutMessage
          : loadFailedMessage('$e');
    }

    if (_disposed) return;

    _state.sectionRevealGeneration++;
    final generation = _state.sectionRevealGeneration;
    if (loadedSections != null) {
      _state.sections = loadedSections;
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
    if (showLoginRequired) {
      _state.sections = const [];
      _state.errorMessage = null;
      _state.visibleSectionCount = 0;
      _state.initialLoading = false;
      _state.refreshing = false;
      _notify();
      return;
    }
    if (_sourceService.sourceRuntimeState.canRetry) {
      _sourceService.logRuntimeRetryRequested('discover_page');
    }

    _state.refreshing = true;
    _notify();

    List<ExploreSection>? refreshedSections;
    String? error;
    try {
      refreshedSections = await _sourceService
          .loadExploreSections(forceRefresh: true)
          .timeout(
            _discoverLoadTimeout,
            onTimeout: () => throw Exception('discover_load_timeout'),
          );
    } catch (e) {
      error = e.toString().contains('discover_load_timeout')
          ? timeoutMessage
          : loadFailedMessage('$e');
    }

    if (_disposed) return;

    final revealProgressively = _state.sections.isEmpty;
    _state.sectionRevealGeneration++;
    final generation = _state.sectionRevealGeneration;

    if (refreshedSections != null) {
      _state.sections = refreshedSections;
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sourceService.removeListener(_onSourceChanged);
    super.dispose();
  }
}
