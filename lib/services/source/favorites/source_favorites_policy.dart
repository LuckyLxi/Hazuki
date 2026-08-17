import '../models/source_identity.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';

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
  bool get supportFavoriteSortOrder => _evaluateActive(
    '!!(this.__hazuki_source.settings?.favoriteOrder || this.__hazuki_source.settings?.favorites_ordering || this.__hazuki_source.settings?.favoriteSort)',
  );

  bool _evaluateActive(String expression) {
    final facade = _activeFacade;
    final engine = facade.js.engine;
    return engine != null && facade.js.asBool(facade.js.evaluate(expression));
  }

  String get favoriteSortOrder {
    final facade = _activeFacade;
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) return 'mr';
    final options = favoriteSortOrders;
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      final value = facade
          .loadSourceSetting(sourceMeta.key, 'favorites_ordering')
          ?.toString()
          .trim();
      return options.contains(value) ? value! : '-datetime_updated';
    }
    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      final value = facade
          .loadSourceSetting(sourceMeta.key, 'favoriteSort')
          ?.toString()
          .trim();
      return options.contains(value) ? value! : 'dd';
    }
    final value = facade
        .loadSourceSetting(sourceMeta.key, 'favoriteOrder')
        ?.toString()
        .trim();
    return value == 'mp' ? 'mp' : 'mr';
  }

  Future<void> setFavoriteSortOrder(String order) async {
    final facade = _activeFacade;
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) throw Exception('source_not_initialized');
    final requested = order.trim();
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      await facade.saveSourceSetting(
        sourceMeta.key,
        'favorites_ordering',
        favoriteSortOrders.contains(requested)
            ? requested
            : '-datetime_updated',
      );
      return;
    }
    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      await facade.saveSourceSetting(
        sourceMeta.key,
        'favoriteSort',
        favoriteSortOrders.contains(requested) ? requested : 'dd',
      );
      return;
    }
    await facade.saveSourceSetting(
      sourceMeta.key,
      'favoriteOrder',
      requested == 'mp' ? 'mp' : 'mr',
    );
  }

  List<String> get favoriteSortOrders {
    final sourceMeta = _activeFacade.sourceMeta;
    if (sourceMeta != null && isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      return const [
        '-datetime_updated',
        '-datetime_modifier',
        '-datetime_browse',
      ];
    }
    if (sourceMeta != null && isHazukiPicacgSourceKey(sourceMeta.key)) {
      return const ['dd', 'da'];
    }
    return const ['mr', 'mp'];
  }
}
