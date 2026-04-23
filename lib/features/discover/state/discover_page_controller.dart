import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';

import 'discover_page_state.dart';

class DiscoverPageController extends ChangeNotifier {
  DiscoverPageController({HazukiSourceService? sourceService})
    : _sourceService = sourceService ?? HazukiSourceService.instance;

  static const _discoverLoadTimeout = Duration(seconds: 20);
  static const _initialVisibleSectionCount = 1;
  static const _sectionRevealBatchSize = 1;

  final HazukiSourceService _sourceService;
  final DiscoverPageState _state = DiscoverPageState();
  bool _disposed = false;

  List<ExploreSection> get sections => _state.sections;
  String? get errorMessage => _state.errorMessage;
  bool get initialLoading => _state.initialLoading;
  bool get refreshing => _state.refreshing;
  int get visibleSectionCount => _state.visibleSectionCount;

  Future<void> loadInitial({
    required String timeoutMessage,
    required String Function(String) loadFailedMessage,
  }) async {
    List<ExploreSection>? loadedSections;
    String? error;
    try {
      loadedSections = await _sourceService
          .loadExploreSections()
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
    super.dispose();
  }
}
