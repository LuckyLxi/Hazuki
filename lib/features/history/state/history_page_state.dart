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

  void applyLoaded(List<ExploreComic> value) {
    history = List<ExploreComic>.unmodifiable(value);
    loading = false;

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

  void toggleSelection(String storageKey, {bool? selected}) {
    if (selected ?? !selectedStorageKeys.contains(storageKey)) {
      selectedStorageKeys.add(storageKey);
      return;
    }
    selectedStorageKeys.remove(storageKey);
  }

  void clearSelection() {
    selectedStorageKeys.clear();
    selectionMode = false;
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
}
