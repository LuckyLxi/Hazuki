import 'package:flutter/foundation.dart';

import 'package:hazuki/services/download_groups_service.dart';
import 'package:hazuki/services/manga_download/manga_download_service.dart';

enum DownloadsBulkDialogStage { actions, groups, removeConfirmation }

class DownloadsBulkGroupController extends ChangeNotifier {
  DownloadsBulkGroupController({
    required List<DownloadGroup> groups,
    required List<DownloadedMangaComic> selectedComics,
    required Map<String, Set<String>> initialComicKeysByGroup,
  }) : selectedComicKeys = {
         for (final comic in selectedComics) comic.storageKey,
       },
       initialComicKeysByGroup = {
         for (final group in groups)
           group.id: Set<String>.of(
             initialComicKeysByGroup[group.id] ?? const {},
           ),
       } {
    draftComicKeysByGroup = {
      for (final entry in this.initialComicKeysByGroup.entries)
        entry.key: Set<String>.of(entry.value),
    };
  }

  DownloadsBulkDialogStage stage = DownloadsBulkDialogStage.actions;
  final Set<String> selectedComicKeys;
  final Map<String, Set<String>> initialComicKeysByGroup;
  late final Map<String, Set<String>> draftComicKeysByGroup;

  void showActions() => _setStage(DownloadsBulkDialogStage.actions);
  void showGroups() => _setStage(DownloadsBulkDialogStage.groups);
  void showRemoveConfirmation() =>
      _setStage(DownloadsBulkDialogStage.removeConfirmation);

  void toggleGroup(String groupId) {
    final initial = initialComicKeysByGroup[groupId] ?? const <String>{};
    final draft = draftComicKeysByGroup[groupId] ?? const <String>{};
    draftComicKeysByGroup[groupId] = draft.length == selectedComicKeys.length
        ? Set<String>.of(initial)
        : Set<String>.of(selectedComicKeys);
    notifyListeners();
  }

  void updateGroupMembership(String groupId, Set<String> comicKeys) {
    draftComicKeysByGroup[groupId] = Set<String>.of(comicKeys);
    notifyListeners();
  }

  Map<String, Set<String>> snapshotDraftMemberships() => {
    for (final entry in draftComicKeysByGroup.entries)
      entry.key: Set<String>.of(entry.value),
  };

  void _setStage(DownloadsBulkDialogStage value) {
    if (stage == value) return;
    stage = value;
    notifyListeners();
  }
}
