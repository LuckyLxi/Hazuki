import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/shared/favorites/favorite_folders_repository.dart';

export 'package:hazuki/shared/favorites/favorite_folders_repository.dart';

class DefaultFavoriteFoldersRepository implements FavoriteFoldersRepository {
  const DefaultFavoriteFoldersRepository({
    required SourceFavoriteGateway source,
    required LocalFavoritesRepository local,
  }) : _source = source,
       _local = local;

  final SourceFavoriteGateway _source;
  final LocalFavoritesRepository _local;

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
  Future<void> addLocalFavoriteFolder(String name, {String sourceKey = ''}) =>
      _local.addFavoriteFolder(name, sourceKey: sourceKey);

  @override
  Future<void> deleteLocalFavoriteFolder(String id, {String sourceKey = ''}) =>
      _local.deleteFavoriteFolder(id, sourceKey: sourceKey);

  @override
  Future<void> toggleCloudFavorite({
    required String comicId,
    required bool isAdding,
    required String folderId,
  }) => _source.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
  );

  @override
  Future<void> toggleLocalFavorite({
    required ComicDetailsData details,
    required bool isAdding,
    required String folderId,
  }) => _local.toggleFavorite(
    details: details,
    isAdding: isAdding,
    folderId: folderId,
  );
}
