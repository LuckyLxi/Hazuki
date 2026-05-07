import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/local_favorites_service.dart';

abstract class FavoriteFoldersRepository {
  bool get isLogged;
  bool get supportFavoriteFolderLoad;
  bool get supportFavoriteFolderAdd;
  bool get supportFavoriteFolderDelete;
  bool get supportFavoriteToggle;
  bool get favoriteSingleFolderForSingleComic;

  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  });

  Future<void> addCloudFavoriteFolder(String name);

  Future<void> deleteCloudFavoriteFolder(String id);

  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  });

  Future<void> addLocalFavoriteFolder(String name);

  Future<void> deleteLocalFavoriteFolder(String id);
}

class DefaultFavoriteFoldersRepository implements FavoriteFoldersRepository {
  const DefaultFavoriteFoldersRepository();

  HazukiSourceService get _source => HazukiSourceService.instance;
  LocalFavoritesService get _local => LocalFavoritesService.instance;

  @override
  bool get isLogged => _source.isLogged;

  @override
  bool get supportFavoriteFolderLoad => _source.supportFavoriteFolderLoad;

  @override
  bool get supportFavoriteFolderAdd => _source.supportFavoriteFolderAdd;

  @override
  bool get supportFavoriteFolderDelete => _source.supportFavoriteFolderDelete;

  @override
  bool get supportFavoriteToggle => _source.supportFavoriteToggle;

  @override
  bool get favoriteSingleFolderForSingleComic =>
      _source.favoriteSingleFolderForSingleComic;

  @override
  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
  }) => _source.loadFavoriteFolders(comicId: comicId);

  @override
  Future<void> addCloudFavoriteFolder(String name) =>
      _source.addFavoriteFolder(name);

  @override
  Future<void> deleteCloudFavoriteFolder(String id) =>
      _source.deleteFavoriteFolder(id);

  @override
  Future<FavoriteFoldersResult> loadLocalFavoriteFolders({
    required String comicId,
    String sourceKey = '',
  }) => _local.loadFavoriteFolders(comicId: comicId, sourceKey: sourceKey);

  @override
  Future<void> addLocalFavoriteFolder(String name) =>
      _local.addFavoriteFolder(name);

  @override
  Future<void> deleteLocalFavoriteFolder(String id) =>
      _local.deleteFavoriteFolder(id);
}
