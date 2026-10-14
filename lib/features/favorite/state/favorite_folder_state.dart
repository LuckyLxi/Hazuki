import 'package:hazuki/models/hazuki_models.dart';

const defaultCloudFavoriteFolder = FavoriteFolder(
  id: '0',
  name: '__favorite_all__',
  source: FavoriteFolderSource.cloud,
);

/// Directory workflows can update folders and selection, or request the empty
/// list transition, without owning pagination or comic-loading state.
abstract interface class FavoriteFolderState {
  FavoritePageMode get mode;
  List<FavoriteFolder> get folders;
  set folders(List<FavoriteFolder> value);
  String get selectedCloudFolderId;
  set selectedCloudFolderId(String value);
  String get selectedLocalFolderId;
  set selectedLocalFolderId(String value);
  String get selectedFolderId;
  bool get loadingFolders;
  set loadingFolders(bool value);
  void clearComicsForEmptyFolders();
}
