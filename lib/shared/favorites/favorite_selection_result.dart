import 'package:hazuki/models/hazuki_models.dart';

class FavoriteFolderSelectionResult {
  FavoriteFolderSelectionResult({
    required Set<String> selected,
    required Set<String> initial,
  }) : _selected = Set.unmodifiable(selected),
       _initial = Set.unmodifiable(initial);

  final Set<String> _selected;
  final Set<String> _initial;

  Set<String> get selected => _selected;
  Set<String> get initial => _initial;

  Set<String> get addTargets => _selected.difference(_initial);
  Set<String> get removeTargets => _initial.difference(_selected);
  bool get hasChanges => addTargets.isNotEmpty || removeTargets.isNotEmpty;
  bool get hasSelection => _selected.isNotEmpty;

  Set<String> folderIdsForSource(FavoriteFolderSource source) {
    final ids = <String>{};
    for (final storageKey in _selected) {
      final handle = favoriteFolderHandleFromStorageKey(storageKey);
      if (handle != null && handle.source == source) {
        ids.add(handle.id);
      }
    }
    return ids;
  }

  Set<String> initialFolderIdsForSource(FavoriteFolderSource source) {
    final ids = <String>{};
    for (final storageKey in _initial) {
      final handle = favoriteFolderHandleFromStorageKey(storageKey);
      if (handle != null && handle.source == source) {
        ids.add(handle.id);
      }
    }
    return ids;
  }
}
