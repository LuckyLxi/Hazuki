part of '../hazuki_source_service.dart';

extension HazukiSourceServiceFavoritesCapability on HazukiSourceService {
  bool get favoriteSingleFolderForSingleComic {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate(
        'this.__hazuki_source.favorites?.singleFolderForSingleComic == true',
      ),
    );
  }

  bool get supportFavoriteFolderManagement {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  bool get supportFavoriteFolderAdd {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.addFolder'),
    );
  }

  bool get supportFavoriteFolderDelete {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.deleteFolder'),
    );
  }

  bool get supportFavoriteFolderLoad {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadFolders'),
    );
  }

  String get favoriteSortOrder {
    final sourceMeta = _sourceMeta;
    if (sourceMeta == null) {
      return 'mr';
    }
    final raw = _loadSourceSetting(sourceMeta.key, 'favoriteOrder');
    final normalized = raw?.toString().trim() ?? '';
    if (normalized == 'mp') {
      return 'mp';
    }
    return 'mr';
  }

  Future<void> setFavoriteSortOrder(String order) async {
    final sourceMeta = _sourceMeta;
    if (sourceMeta == null) {
      throw Exception('source_not_initialized');
    }
    final normalized = order.trim() == 'mp' ? 'mp' : 'mr';
    await _saveSourceSetting(sourceMeta.key, 'favoriteOrder', normalized);
  }

  bool get supportFavoriteSortOrder {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.settings?.favoriteOrder'),
    );
  }

  bool get supportFavoriteLoadComics {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadComics'),
    );
  }

  bool get supportFavoriteLoadNext {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.loadNext'),
    );
  }

  bool get supportFavoriteToggle {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.favorites?.addOrDelFavorite'),
    );
  }

  bool get supportCommentSend {
    final engine = _engine;
    if (engine == null) {
      return false;
    }
    return _asBool(
      engine.evaluate('!!this.__hazuki_source.comic?.sendComment'),
    );
  }
}
