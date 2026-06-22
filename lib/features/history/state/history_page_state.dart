import 'package:hazuki/models/hazuki_models.dart';

class HistoryPageData {
  List<ExploreComic> history = const <ExploreComic>[];
  bool loading = true;
  bool selectionMode = false;
  Set<String> selectedStorageKeys = <String>{};
  bool playItemEntryAnimation = true;

  void beginLoading() {
    loading = true;
  }

  void applyLoaded(List<ExploreComic> value, {bool playEntryAnimation = true}) {
    history = List<ExploreComic>.unmodifiable(value);
    _finishApplyingLoadedHistory(playEntryAnimation: playEntryAnimation);
  }

  void applyLoadedPreservingExistingOrder(
    List<ExploreComic> value, {
    bool playEntryAnimation = true,
  }) {
    final loadedByKey = <String, ExploreComic>{
      for (final comic in value) comic.scopedId.storageKey: comic,
    };
    final ordered = <ExploreComic>[
      for (final comic in history)
        if (loadedByKey.containsKey(comic.scopedId.storageKey))
          loadedByKey.remove(comic.scopedId.storageKey)!,
      ...loadedByKey.values,
    ];
    history = List<ExploreComic>.unmodifiable(ordered);
    _finishApplyingLoadedHistory(playEntryAnimation: playEntryAnimation);
  }

  void _finishApplyingLoadedHistory({required bool playEntryAnimation}) {
    loading = false;
    // Keep animation reset batched with loaded data to avoid an extra rebuild.
    playItemEntryAnimation = playEntryAnimation;

    final validKeys = history.map((comic) => comic.scopedId.storageKey).toSet();
    selectedStorageKeys.removeWhere((key) => !validKeys.contains(key));
    if (history.isEmpty) {
      selectionMode = false;
      selectedStorageKeys.clear();
    }
  }

  void toggleSelectionMode() {
    selectionMode = !selectionMode;
    selectedStorageKeys.clear();
  }

  void exitSelectionMode() {
    selectionMode = false;
    selectedStorageKeys.clear();
  }

  void toggleSelection(String storageKey, {bool? selected}) {
    if (selected ?? !selectedStorageKeys.contains(storageKey)) {
      selectedStorageKeys.add(storageKey);
      return;
    }
    selectedStorageKeys.remove(storageKey);
  }

  void clearSelection() {
    exitSelectionMode();
  }

  List<ExploreComic> removeComic(ExploreComic comic) {
    final storageKey = comic.scopedId.storageKey;
    history = List<ExploreComic>.unmodifiable(
      history.where((entry) => entry.scopedId.storageKey != storageKey),
    );
    selectedStorageKeys.remove(storageKey);
    if (history.isEmpty) {
      selectionMode = false;
      selectedStorageKeys.clear();
    }
    return history;
  }

  List<ExploreComic> removeSelected() {
    if (selectedStorageKeys.isEmpty) {
      return history;
    }
    final selected = Set<String>.of(selectedStorageKeys);
    history = List<ExploreComic>.unmodifiable(
      history.where((entry) => !selected.contains(entry.scopedId.storageKey)),
    );
    clearSelection();
    return history;
  }

  List<ExploreComic> clearHistory() {
    history = const <ExploreComic>[];
    clearSelection();
    return history;
  }

  void disableEntryAnimation() {
    playItemEntryAnimation = false;
  }

  /// Re-enables item entry animation after returning from another page.
  void enableEntryAnimation() {
    playItemEntryAnimation = true;
  }
}
