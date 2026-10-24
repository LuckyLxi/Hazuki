import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_contracts.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/favorites/favorite_folders_repository.dart';

/// 绑定到单个漫画源的收藏夹仓储：云端操作走该源，本地操作走本地收藏库。
class SourceFavoriteFoldersRepository implements FavoriteFoldersRepository {
  /// [sourceKey] 为空时在构造时取当前活动源，之后不随活动源切换。
  SourceFavoriteFoldersRepository({
    required SourceComicDetailGateway source,
    required LocalFavoritesRepository local,
    String sourceKey = '',
  }) : _source = source,
       _local = local,
       _sourceKey = sourceKey.trim().isEmpty
           ? (source.activeSourceKey ?? '')
           : sourceKey.trim();

  final SourceComicDetailGateway _source;
  final LocalFavoritesRepository _local;
  final String _sourceKey;

  @override
  bool get isLogged => _source.isLoggedForSource(_sourceKey);
  @override
  bool get supportFavoriteFolderLoad =>
      _source.supportFavoriteFolderLoadForSource(_sourceKey);
  @override
  bool get supportFavoriteFolderAdd =>
      _source.supportFavoriteFolderAddForSource(_sourceKey);
  @override
  bool get supportFavoriteFolderDelete =>
      _source.supportFavoriteFolderDeleteForSource(_sourceKey);
  @override
  bool get supportFavoriteToggle =>
      _source.supportFavoriteToggleForSource(_sourceKey);
  @override
  bool get favoriteSingleFolderForSingleComic =>
      _source.favoriteSingleFolderForSingleComicForSource(_sourceKey);

  @override
  Future<FavoriteFoldersResult> loadCloudFavoriteFolders({
    required String comicId,
    SourceTaskOrigin? taskOrigin,
  }) => _source.loadFavoriteFolders(
    comicId: comicId,
    sourceKey: _sourceKey,
    taskOrigin: taskOrigin,
  );

  @override
  Future<void> addCloudFavoriteFolder(String name) =>
      _source.addFavoriteFolder(name, sourceKey: _sourceKey);

  @override
  Future<void> deleteCloudFavoriteFolder(String id) =>
      _source.deleteFavoriteFolder(id, sourceKey: _sourceKey);

  @override
  Future<void> toggleCloudFavorite({
    required String comicId,
    required bool isAdding,
    required String folderId,
  }) => _source.toggleFavorite(
    comicId: comicId,
    isAdding: isAdding,
    folderId: folderId,
    sourceKey: _sourceKey,
  );

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
