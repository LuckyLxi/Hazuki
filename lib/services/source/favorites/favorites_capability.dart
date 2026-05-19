part of '../../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesCapability on HazukiSourceService {
  bool get favoriteSingleFolderForSingleComic {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate(
        'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
      ),
    );
  }

  bool get supportFavoriteFolderManagement {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  bool get supportFavoriteFolderAdd {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
    );
  }

  bool get supportFavoriteFolderDelete {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
    );
  }

  bool get supportFavoriteFolderLoad {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  String get favoriteSortOrder {
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) {
      return 'mr';
    }
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      final raw = facade.loadSourceSetting(
        sourceMeta.key,
        'favorites_ordering',
      );
      final normalized = raw?.toString().trim() ?? '';
      if (favoriteSortOrders.contains(normalized)) {
        return normalized;
      }
      return '-datetime_updated';
    }
    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      final raw = facade.loadSourceSetting(sourceMeta.key, 'favoriteSort');
      final normalized = raw?.toString().trim() ?? '';
      if (favoriteSortOrders.contains(normalized)) {
        return normalized;
      }
      return 'dd';
    }
    final raw = facade.loadSourceSetting(sourceMeta.key, 'favoriteOrder');
    final normalized = raw?.toString().trim() ?? '';
    if (normalized == 'mp') {
      return 'mp';
    }
    return 'mr';
  }

  Future<void> setFavoriteSortOrder(String order) async {
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta == null) {
      throw Exception('source_not_initialized');
    }
    if (isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      final normalized = favoriteSortOrders.contains(order.trim())
          ? order.trim()
          : '-datetime_updated';
      await facade.saveSourceSetting(
        sourceMeta.key,
        'favorites_ordering',
        normalized,
      );
      return;
    }
    if (isHazukiPicacgSourceKey(sourceMeta.key)) {
      final normalized = favoriteSortOrders.contains(order.trim())
          ? order.trim()
          : 'dd';
      await facade.saveSourceSetting(
        sourceMeta.key,
        'favoriteSort',
        normalized,
      );
      return;
    }
    final normalized = order.trim() == 'mp' ? 'mp' : 'mr';
    await facade.saveSourceSetting(sourceMeta.key, 'favoriteOrder', normalized);
  }

  List<String> get favoriteSortOrders {
    final sourceMeta = facade.sourceMeta;
    if (sourceMeta != null && isHazukiCopyMangaSourceKey(sourceMeta.key)) {
      return const <String>[
        '-datetime_updated',
        '-datetime_modifier',
        '-datetime_browse',
      ];
    }
    if (sourceMeta != null && isHazukiPicacgSourceKey(sourceMeta.key)) {
      return const <String>['dd', 'da'];
    }
    return const <String>['mr', 'mp'];
  }

  bool get supportFavoriteSortOrder {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate(
        '!!(this.__hazuki_source.settings?.favoriteOrder || this.__hazuki_source.settings?.favorites_ordering || this.__hazuki_source.settings?.favoriteSort)',
      ),
    );
  }

  bool get supportFavoriteLoadComics {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
    );
  }

  bool get supportFavoriteLoadNext {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.loadNext'),
    );
  }

  bool get supportFavoriteToggle {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
    );
  }

  bool get supportCommentSend {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.comic?.sendComment'),
    );
  }

  bool get supportCommentLike {
    final engine = facade.js.engine;
    if (engine == null) {
      return false;
    }
    return facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.comic?.likeComment'),
    );
  }
}
