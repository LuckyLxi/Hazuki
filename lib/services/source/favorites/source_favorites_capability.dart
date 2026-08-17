import '../../../models/hazuki_models.dart';
import '../account/source_relogin_coordinator.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'source_favorite_comics_loader.dart';
import 'source_favorite_folder_membership_probe.dart';
import 'source_favorites_policy.dart';
import 'source_favorites_response_parser.dart';
import 'source_favorites_script_factory.dart';

typedef SourceFavoritesComicParser =
    List<ExploreComic> Function(List comics, {String sourceKey});

typedef SourceFavoriteStateUpdater =
    void Function({
      required String sourceKey,
      required String comicId,
      required bool isFavorite,
    });

/// Loads and mutates remote favorites through explicit runtime collaborators.
class SourceFavoritesCapability {
  SourceFavoritesCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceReloginCoordinator reloginCoordinator,
    required SourceFavoritesComicParser parseExploreComics,
    required SourceFavoriteStateUpdater updateComicDetailsFavoriteState,
    required void Function() notifyCloudFavoritesChanged,
  }) : _runtimeHost = runtimeHost,
       _reloginCoordinator = reloginCoordinator,
       _responseParser = SourceFavoritesResponseParser(parseExploreComics),
       _updateComicDetailsFavoriteState = updateComicDetailsFavoriteState,
       _notifyCloudFavoritesChanged = notifyCloudFavoritesChanged;

  final SourceRuntimeHost _runtimeHost;
  final SourceReloginCoordinator _reloginCoordinator;
  final SourceFavoritesResponseParser _responseParser;
  late final SourceFavoriteComicsLoader _comicsLoader =
      SourceFavoriteComicsLoader(
        runtimeHost: _runtimeHost,
        reloginCoordinator: _reloginCoordinator,
        responseParser: _responseParser,
      );
  final SourceFavoriteStateUpdater _updateComicDetailsFavoriteState;
  final void Function() _notifyCloudFavoritesChanged;
  final SourceFavoriteFolderMembershipProbe _membershipProbe =
      const SourceFavoriteFolderMembershipProbe();
  final SourceFavoritesScriptFactory _scriptFactory =
      const SourceFavoritesScriptFactory();
  late final SourceFavoritesPolicy _policy = SourceFavoritesPolicy(
    _runtimeHost,
  );

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  HazukiSourceFacade _facadeForSource(String sourceKey) =>
      _runtimeHost.handleFor(_resolveSourceKey(sourceKey)).facade;

  SourceFacadeReloginContext _reloginContext(HazukiSourceFacade facade) =>
      SourceFacadeReloginContext(facade);

  static String normalizeFolderId(String folderId) =>
      SourceFavoritesResponseParser.normalizeFolderId(folderId);

  static List<ExploreComic> mergeFavoriteComics(Iterable<ExploreComic> comics) {
    return SourceFavoritesResponseParser.mergeComics(comics);
  }

  List<ExploreComic> parseFavoriteComicsForTesting(
    List comics, {
    String sourceKey = '',
  }) => _responseParser.parseComics(comics, sourceKey: sourceKey);

  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) {
    return _policy.favoriteSingleFolderForSingleComicForSource(sourceKey);
  }

  bool supportFavoriteFolderAddForSource(String sourceKey) {
    return _policy.supportFavoriteFolderAddForSource(sourceKey);
  }

  bool supportFavoriteFolderDeleteForSource(String sourceKey) {
    return _policy.supportFavoriteFolderDeleteForSource(sourceKey);
  }

  bool supportFavoriteFolderLoadForSource(String sourceKey) {
    return _policy.supportFavoriteFolderLoadForSource(sourceKey);
  }

  bool supportFavoriteToggleForSource(String sourceKey) {
    return _policy.supportFavoriteToggleForSource(sourceKey);
  }

  bool get favoriteSingleFolderForSingleComic {
    return _policy.favoriteSingleFolderForSingleComic;
  }

  bool get supportFavoriteFolderManagement {
    return _policy.supportFavoriteFolderManagement;
  }

  bool get supportFavoriteFolderAdd {
    return _policy.supportFavoriteFolderAdd;
  }

  bool get supportFavoriteFolderDelete {
    return _policy.supportFavoriteFolderDelete;
  }

  bool get supportFavoriteFolderLoad {
    return _policy.supportFavoriteFolderLoad;
  }

  String get favoriteSortOrder {
    return _policy.favoriteSortOrder;
  }

  Future<void> setFavoriteSortOrder(String order) =>
      _policy.setFavoriteSortOrder(order);

  List<String> get favoriteSortOrders {
    return _policy.favoriteSortOrders;
  }

  bool get supportFavoriteSortOrder {
    return _policy.supportFavoriteSortOrder;
  }

  bool get supportFavoriteLoadComics {
    return _policy.supportFavoriteLoadComics;
  }

  bool get supportFavoriteLoadNext {
    return _policy.supportFavoriteLoadNext;
  }

  bool get supportFavoriteToggle {
    return _policy.supportFavoriteToggle;
  }

  bool get supportCommentSend {
    return _policy.supportCommentSend;
  }

  bool get supportCommentLike {
    return _policy.supportCommentLike;
  }

  Future<FavoriteComicsResult> loadFavoriteComics({
    required int page,
    required String folderId,
  }) => _comicsLoader.load(page: page, folderId: folderId);

  Future<FavoriteFoldersResult> loadFavoriteFolders({
    String? comicId,
    String sourceKey = '',
  }) async {
    try {
      final resolvedSourceKey = _resolveSourceKey(sourceKey);
      final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
      await facade.ensureInitialized();
      final context = _reloginContext(facade);
      final sessionReady = await _reloginCoordinator.ensureFavoriteSessionReady(
        context,
      );
      if (!sessionReady) throw Exception('login_expired');
      Future<(List<FavoriteFolder>, Set<String>)> runLoad() async {
        final engine = facade.js.engine;
        if (engine == null) throw Exception('source_not_initialized');
        final hasFavorites = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites'),
        );
        if (!hasFavorites) throw Exception('favorites_not_supported');
        final hasLoadFolders = facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
        );
        if (!hasLoadFolders) {
          final hasLoadComics = facade.js.asBool(
            engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
          );
          if (hasLoadComics) {
            return (
              const <FavoriteFolder>[
                FavoriteFolder(id: '0', name: '__favorite_all__'),
              ],
              const <String>{},
            );
          }
          throw Exception('favorite_folders_not_supported');
        }
        final dynamic raw = engine.evaluate(
          _scriptFactory.loadFolders(comicId),
          name: 'source_favorite_folders.js',
        );
        final dynamic resolved = await facade.js.resolve(raw);
        if (resolved is! Map) {
          throw Exception('favorite_folders_invalid_response');
        }
        final parsed = _responseParser.parseFolders(resolved);
        final folders = parsed.folders;
        final favorited = parsed.favoritedFolderIds;
        final normalizedComicId = comicId?.trim() ?? '';
        if (normalizedComicId.isNotEmpty &&
            favorited.isEmpty &&
            folders.any((folder) => folder.id != '0')) {
          favorited.addAll(
            await _inferFavoritedFolderIds(
              engine: engine,
              comicId: normalizedComicId,
              folders: folders,
              facade: facade,
              sourceKey: resolvedSourceKey,
            ),
          );
        }
        return (folders, favorited);
      }

      final result = await _reloginCoordinator.runWithReloginRetry(
        runLoad,
        context: context,
      );
      return FavoriteFoldersResult.success(
        folders: result.$1,
        favoritedFolderIds: result.$2,
      );
    } catch (error) {
      return FavoriteFoldersResult.error(error.toString());
    }
  }

  Future<Set<String>> _inferFavoritedFolderIds({
    required dynamic engine,
    required String comicId,
    required List<FavoriteFolder> folders,
    required HazukiSourceFacade facade,
    required String sourceKey,
  }) async {
    final normalizedComicId = comicId.trim();
    if (normalizedComicId.isEmpty ||
        !facade.js.asBool(
          engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
        )) {
      return const <String>{};
    }
    return _membershipProbe.infer(
      comicId: normalizedComicId,
      folders: folders,
      singleFolderOnly: favoriteSingleFolderForSingleComicForSource(sourceKey),
      loadPage: ({required page, required folderId}) async {
        final safeFolderId = folderId.replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );
        final dynamic raw = engine.evaluate(
          _scriptFactory.loadComics(page: page, folderId: folderId),
          name: 'source_favorite_folder_probe_${safeFolderId}_$page.js',
        );
        final dynamic resolved = await facade.js.resolve(raw);
        return _responseParser.parseComicsPage(resolved, sourceKey: sourceKey);
      },
    );
  }

  Future<void> addFavoriteFolder(String name, {String sourceKey = ''}) async {
    final facade = _facadeForSource(sourceKey);
    await facade.ensureInitialized();
    await _reloginCoordinator.runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
      )) {
        throw Exception('favorite_folder_creation_not_supported');
      }
      final dynamic result = engine.evaluate(
        _scriptFactory.addFolder(name),
        name: 'source_favorite_add_folder.js',
      );
      await facade.js.resolve(result);
    }, context: _reloginContext(facade));
  }

  Future<void> deleteFavoriteFolder(
    String folderId, {
    String sourceKey = '',
  }) async {
    final facade = _facadeForSource(sourceKey);
    await facade.ensureInitialized();
    await _reloginCoordinator.runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
      )) {
        throw Exception('favorite_folder_deletion_not_supported');
      }
      final dynamic result = engine.evaluate(
        _scriptFactory.deleteFolder(folderId),
        name: 'source_favorite_delete_folder.js',
      );
      await facade.js.resolve(result);
    }, context: _reloginContext(facade));
  }

  Future<void> toggleFavorite({
    required String comicId,
    required bool isAdding,
    String folderId = '0',
    String? favoriteId,
    String sourceKey = '',
  }) async {
    final normalizedComicId = comicId.trim();
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    await facade.ensureInitialized();
    await _reloginCoordinator.runWithReloginRetry(() async {
      final engine = facade.js.engine;
      if (engine == null) throw Exception('source_not_initialized');
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites'),
      )) {
        throw Exception('favorites_not_supported');
      }
      if (!facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
      )) {
        throw Exception('favorite_toggle_not_supported');
      }
      final normalizedFolderId = normalizeFolderId(folderId);
      final dynamic result = engine.evaluate(
        _scriptFactory.toggleFavorite(
          comicId: comicId,
          folderId: normalizedFolderId,
          isAdding: isAdding,
          favoriteId: favoriteId,
        ),
        name: 'source_toggle_favorite.js',
      );
      await facade.js.resolve(result);
    }, context: _reloginContext(facade));
    if (normalizedComicId.isNotEmpty) {
      _updateComicDetailsFavoriteState(
        sourceKey: resolvedSourceKey,
        comicId: normalizedComicId,
        isFavorite: isAdding,
      );
    }
    _notifyCloudFavoritesChanged();
  }
}
