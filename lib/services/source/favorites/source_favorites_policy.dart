import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import '../plugins/source_sort_options.dart';

/// Resolves source favorite capabilities and source-specific sort settings.
class SourceFavoritesPolicy {
  const SourceFavoritesPolicy(this._runtimeHost);

  final SourceRuntimeHost _runtimeHost;

  HazukiSourceFacade get _activeFacade => _runtimeHost.activeHandle.facade;

  HazukiSourceFacade _facadeForSource(String sourceKey) {
    final resolved = sourceKey.trim().isEmpty
        ? _runtimeHost.activeSourceKey
        : _runtimeHost.normalize(sourceKey);
    return _runtimeHost.handleFor(resolved).facade;
  }

  bool favoriteSingleFolderForSingleComicForSource(String sourceKey) =>
      _evaluateForSource(
        sourceKey,
        'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
      );

  bool supportFavoriteFolderAddForSource(String sourceKey) =>
      _evaluateForSource(
        sourceKey,
        '!!this.__hazuki_source.favorites?.addFolder',
      );

  bool supportFavoriteFolderDeleteForSource(String sourceKey) =>
      _evaluateForSource(
        sourceKey,
        '!!this.__hazuki_source.favorites?.deleteFolder',
      );

  bool supportFavoriteFolderLoadForSource(String sourceKey) =>
      _evaluateForSource(
        sourceKey,
        '!!this.__hazuki_source.favorites?.loadFolders',
      );

  bool supportFavoriteToggleForSource(String sourceKey) => _evaluateForSource(
    sourceKey,
    '!!this.__hazuki_source.favorites?.addOrDelFavorite',
  );

  bool _evaluateForSource(String sourceKey, String expression) {
    final facade = _facadeForSource(sourceKey);
    final engine = facade.js.engine;
    return engine != null && facade.js.asBool(engine.evaluate(expression));
  }

  bool get favoriteSingleFolderForSingleComic => _evaluateActive(
    'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
  );
  bool get supportFavoriteFolderManagement =>
      _evaluateActive('!!this.__hazuki_source.favorites?.loadFolders');
  bool get supportFavoriteFolderAdd =>
      _evaluateActive('!!this.__hazuki_source.favorites?.addFolder');
  bool get supportFavoriteFolderDelete =>
      _evaluateActive('!!this.__hazuki_source.favorites?.deleteFolder');
  bool get supportFavoriteFolderLoad =>
      _evaluateActive('!!this.__hazuki_source.favorites?.loadFolders');
  bool get supportFavoriteLoadComics =>
      _evaluateActive('!!this.__hazuki_source.favorites?.loadComics');
  bool get supportFavoriteLoadNext =>
      _evaluateActive('!!this.__hazuki_source.favorites?.loadNext');
  bool get supportFavoriteToggle =>
      _evaluateActive('!!this.__hazuki_source.favorites?.addOrDelFavorite');
  bool get supportCommentSend =>
      _evaluateActive('!!this.__hazuki_source.comic?.sendComment');
  bool get supportCommentLike =>
      _evaluateActive('!!this.__hazuki_source.comic?.likeComment');
  bool get supportFavoriteSortOrder => favoriteSortOrders.length > 1;

  bool _evaluateActive(String expression) {
    if (!_runtimeHost.hasActiveSource) return false;
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null && facade.js.asBool(facade.js.evaluate(expression));
  }

  Map<String, dynamic> get _options => _runtimeHost.runtimeRegistry
      .presentationFor(_runtimeHost.activeSourceKey);
  String get favoriteSortOrder {
    if (!_runtimeHost.hasActiveSource) return '';
    final key = _options['favoriteOrderSetting']?.toString() ?? 'favoriteOrder';
    final value =
        _activeFacade
            .loadSourceSetting(_activeFacade.sourceKey, key)
            ?.toString() ??
        '';
    return normalizeSourceOrder(
      value,
      orders: favoriteSortOrders,
      defaultOrder: _options['favoriteDefaultOrder'],
    );
  }

  Future<void> setFavoriteSortOrder(String order) async {
    final resolvedOrder = normalizeSourceOrder(
      order,
      orders: favoriteSortOrders,
      defaultOrder: _options['favoriteDefaultOrder'],
    );
    if (resolvedOrder.isEmpty) throw StateError('favorite_sort_not_supported');
    await _activeFacade.saveSourceSetting(
      _activeFacade.sourceKey,
      _options['favoriteOrderSetting']?.toString() ?? 'favoriteOrder',
      resolvedOrder,
    );
  }

  List<String> get favoriteSortOrders =>
      (_options['favoriteOrders'] as List? ?? const [])
          .map((v) => v.toString())
          .toList();
}
