import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/read_history_service.dart';

import 'history_page_state.dart';

class HistoryPageController extends ChangeNotifier {
  HistoryPageController({
    required ReadHistoryService readHistoryService,
    required HazukiSourceService sourceService,
  }) : _readHistoryService = readHistoryService,
       _sourceService = sourceService,
       _activeSourceKey = _normalizeSourceKey(sourceService.activeSourceKey) {
    _readHistoryService.addListener(_handleReadHistoryChanged);
    _sourceService.addListener(_handleSourceChanged);
  }

  final ReadHistoryService _readHistoryService;
  final HazukiSourceService _sourceService;
  final HistoryPageData _state = HistoryPageData();

  bool _disposed = false;
  int _requestVersion = 0;
  int _autoReloadPauseDepth = 0;
  bool _hasDeferredHistoryChange = false;
  String _activeSourceKey;

  List<ExploreComic> get history => _state.history;
  bool get loading => _state.loading;
  bool get selectionMode => _state.selectionMode;
  Set<String> get selectedStorageKeys =>
      Set<String>.unmodifiable(_state.selectedStorageKeys);
  int get selectedCount => _state.selectedStorageKeys.length;
  bool get hasHistory => _state.history.isNotEmpty;
  bool get playItemEntryAnimation => _state.playItemEntryAnimation;

  Future<void> loadInitial() {
    return _loadHistory(markLoading: true);
  }

  Future<void> reload({
    bool playEntryAnimation = true,
    bool preserveExistingOrder = false,
  }) {
    return _loadHistory(
      markLoading: false,
      playEntryAnimation: playEntryAnimation,
      preserveExistingOrder: preserveExistingOrder,
    );
  }

  void pauseAutoReloads() {
    _autoReloadPauseDepth += 1;
  }

  bool resumeAutoReloads() {
    if (_autoReloadPauseDepth == 0) {
      return false;
    }
    _autoReloadPauseDepth -= 1;
    if (_autoReloadPauseDepth > 0) {
      return false;
    }
    final hadDeferredChange = _hasDeferredHistoryChange;
    _hasDeferredHistoryChange = false;
    return hadDeferredChange;
  }

  Future<void> deleteComic(ExploreComic comic) async {
    final sourceKey = _activeSourceKey;
    pauseAutoReloads();
    try {
      await _deleteSourceHistoryEntries(
        sourceKey: sourceKey,
        storageKeys: {comic.scopedId.storageKey},
      );
    } finally {
      resumeAutoReloads();
    }
    if (_disposed || sourceKey != _activeSourceKey) {
      return;
    }
    _state.removeComic(comic);
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_state.selectedStorageKeys.isEmpty) {
      return;
    }
    final sourceKey = _activeSourceKey;
    final selected = Set<String>.of(_state.selectedStorageKeys);
    pauseAutoReloads();
    try {
      await _deleteSourceHistoryEntries(
        sourceKey: sourceKey,
        storageKeys: selected,
      );
    } finally {
      resumeAutoReloads();
    }
    if (_disposed || sourceKey != _activeSourceKey) {
      return;
    }
    _state.removeSelected();
    notifyListeners();
  }

  Future<void> clearAll() async {
    final sourceKey = _activeSourceKey;
    await _replaceSourceHistory(
      sourceKey: sourceKey,
      history: const <ExploreComic>[],
    );
    if (_disposed || sourceKey != _activeSourceKey) {
      return;
    }
    _state.clearHistory();
    notifyListeners();
  }

  void toggleSelectionMode() {
    _state.toggleSelectionMode();
    notifyListeners();
  }

  void exitSelectionMode() {
    if (!_state.selectionMode) {
      return;
    }
    _state.exitSelectionMode();
    notifyListeners();
  }

  void toggleSelection(String storageKey, {bool? selected}) {
    _state.toggleSelection(storageKey, selected: selected);
    notifyListeners();
  }

  void disableEntryAnimation() {
    if (!_state.playItemEntryAnimation) {
      return;
    }
    _state.disableEntryAnimation();
    notifyListeners();
  }

  /// Re-enables item entry animation for the next loaded history list.
  void enableEntryAnimation() {
    if (_state.playItemEntryAnimation) {
      return;
    }
    _state.enableEntryAnimation();
    notifyListeners();
  }

  Future<void> _loadHistory({
    required bool markLoading,
    bool playEntryAnimation = true,
    bool preserveExistingOrder = false,
  }) async {
    final requestVersion = ++_requestVersion;
    final sourceKey = _activeSourceKey;
    if (markLoading && !_state.loading) {
      _state.beginLoading();
      notifyListeners();
    }

    final history = await _readHistoryService.loadHistory(sourceKey: sourceKey);
    if (_disposed ||
        requestVersion != _requestVersion ||
        sourceKey != _activeSourceKey) {
      return;
    }
    if (preserveExistingOrder) {
      _state.applyLoadedPreservingExistingOrder(
        history,
        playEntryAnimation: playEntryAnimation,
      );
    } else {
      _state.applyLoaded(history, playEntryAnimation: playEntryAnimation);
    }
    notifyListeners();
  }

  Future<void> _replaceSourceHistory({
    required String sourceKey,
    required List<ExploreComic> history,
  }) {
    return _readHistoryService.replaceSourceHistory(
      sourceKey: sourceKey,
      history: history,
    );
  }

  Future<void> _deleteSourceHistoryEntries({
    required String sourceKey,
    required Set<String> storageKeys,
  }) {
    return _readHistoryService.deleteSourceHistoryEntries(
      sourceKey: sourceKey,
      storageKeys: storageKeys,
    );
  }

  void _handleReadHistoryChanged() {
    if (_autoReloadPauseDepth > 0) {
      _hasDeferredHistoryChange = true;
      return;
    }
    unawaited(reload());
  }

  void _handleSourceChanged() {
    final nextSourceKey = _normalizeSourceKey(_sourceService.activeSourceKey);
    if (nextSourceKey == _activeSourceKey) {
      return;
    }
    _activeSourceKey = nextSourceKey;
    _state.clearSelection();
    unawaited(_loadHistory(markLoading: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _readHistoryService.removeListener(_handleReadHistoryChanged);
    _sourceService.removeListener(_handleSourceChanged);
    super.dispose();
  }
}

String _normalizeSourceKey(String sourceKey) {
  final normalized = sourceKey.trim();
  return normalized.isEmpty ? hazukiDefaultSourceKey : normalized;
}
