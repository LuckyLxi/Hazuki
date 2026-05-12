import 'package:hazuki/models/hazuki_models.dart';

import '../repository/favorite_folders_repository.dart';
import 'favorite_selection_result.dart';

class FavoriteSelectionApplyResult {
  const FavoriteSelectionApplyResult({
    required this.selectedCloudFolderIds,
    required this.hasSelection,
  });

  final Set<String> selectedCloudFolderIds;
  final bool hasSelection;

  bool get hasCloudSelection => selectedCloudFolderIds.isNotEmpty;
}

Future<FavoriteSelectionApplyResult> applyFavoriteFolderSelectionChanges({
  required FavoriteFoldersRepository repository,
  required ComicDetailsData details,
  required FavoriteFolderSelectionResult selection,
  required bool singleFolderOnly,
}) async {
  final selectedCloudIds = selection.folderIdsForSource(
    FavoriteFolderSource.cloud,
  );
  final initialCloudIds = selection.initialFolderIdsForSource(
    FavoriteFolderSource.cloud,
  );
  final selectedLocalIds = selection.folderIdsForSource(
    FavoriteFolderSource.local,
  );
  final initialLocalIds = selection.initialFolderIdsForSource(
    FavoriteFolderSource.local,
  );

  if (singleFolderOnly &&
      repository.isLogged &&
      repository.supportFavoriteToggle) {
    if (selectedCloudIds.isEmpty && initialCloudIds.isNotEmpty) {
      await repository.toggleCloudFavorite(
        comicId: details.id,
        isAdding: false,
        folderId: initialCloudIds.first,
      );
    } else if (selectedCloudIds.isNotEmpty &&
        !_setContentsEqual(selectedCloudIds, initialCloudIds)) {
      await repository.toggleCloudFavorite(
        comicId: details.id,
        isAdding: true,
        folderId: selectedCloudIds.first,
      );
    }
  } else if (repository.isLogged && repository.supportFavoriteToggle) {
    for (final folderId in selectedCloudIds.difference(initialCloudIds)) {
      await repository.toggleCloudFavorite(
        comicId: details.id,
        isAdding: true,
        folderId: folderId,
      );
    }
    for (final folderId in initialCloudIds.difference(selectedCloudIds)) {
      await repository.toggleCloudFavorite(
        comicId: details.id,
        isAdding: false,
        folderId: folderId,
      );
    }
  }

  for (final folderId in selectedLocalIds.difference(initialLocalIds)) {
    await repository.toggleLocalFavorite(
      details: details,
      isAdding: true,
      folderId: folderId,
    );
  }
  for (final folderId in initialLocalIds.difference(selectedLocalIds)) {
    await repository.toggleLocalFavorite(
      details: details,
      isAdding: false,
      folderId: folderId,
    );
  }

  return FavoriteSelectionApplyResult(
    selectedCloudFolderIds: Set<String>.from(selectedCloudIds),
    hasSelection: selection.hasSelection,
  );
}

bool _setContentsEqual(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}
