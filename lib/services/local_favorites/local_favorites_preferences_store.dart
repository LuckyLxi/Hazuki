import 'package:shared_preferences/shared_preferences.dart';

import '../../models/hazuki_models.dart';

abstract interface class LocalFavoritesPreferencesStore {
  Future<String> loadSortOrder();
  Future<void> saveSortOrder(String order);
  Future<FavoritePageMode> loadFavoritePageMode({String sourceKey = ''});
  Future<void> saveFavoritePageMode(
    FavoritePageMode mode, {
    String sourceKey = '',
  });
  Future<String> loadSelectedFavoriteFolderId(
    FavoritePageMode mode, {
    String sourceKey = '',
  });
  Future<void> saveSelectedFavoriteFolderId(
    FavoritePageMode mode,
    String folderId, {
    String sourceKey = '',
  });
}

class SharedPreferencesLocalFavoritesPreferencesStore
    implements LocalFavoritesPreferencesStore {
  SharedPreferencesLocalFavoritesPreferencesStore({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  static const String _sortOrderKey = 'local_favorite_sort_order_v1';
  static const String _pageModeKey = 'favorite_page_mode_v1';
  static const String _pageModeSourcePrefix = 'favorite_page_mode_source_v1_';
  static const String _selectedCloudFolderKey =
      'favorite_selected_cloud_folder_v1';
  static const String _selectedLocalFolderKey =
      'favorite_selected_local_folder_v1';
  static const String _selectedCloudFolderSourcePrefix =
      'favorite_selected_cloud_folder_source_v1_';
  static const String _selectedLocalFolderSourcePrefix =
      'favorite_selected_local_folder_source_v1_';
  static const Set<String> _supportedSortOrders = <String>{
    'mr',
    'mp',
    'dd',
    'da',
    '-datetime_updated',
    '-datetime_modifier',
    '-datetime_browse',
  };

  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<String> loadSortOrder() async {
    final prefs = await _preferences();
    final raw = prefs.getString(_sortOrderKey)?.trim();
    return _supportedSortOrders.contains(raw) ? raw! : 'mr';
  }

  @override
  Future<void> saveSortOrder(String order) async {
    final prefs = await _preferences();
    final raw = order.trim();
    await prefs.setString(
      _sortOrderKey,
      _supportedSortOrders.contains(raw) ? raw : 'mr',
    );
  }

  @override
  Future<FavoritePageMode> loadFavoritePageMode({String sourceKey = ''}) async {
    final prefs = await _preferences();
    final sourceScopedKey = _pageModeKeyForSource(sourceKey);
    final raw = sourceScopedKey == null
        ? prefs.getString(_pageModeKey)
        : prefs.getString(sourceScopedKey) ?? prefs.getString(_pageModeKey);
    return raw == 'local' ? FavoritePageMode.local : FavoritePageMode.cloud;
  }

  @override
  Future<void> saveFavoritePageMode(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) async {
    final prefs = await _preferences();
    await prefs.setString(
      _pageModeKeyForSource(sourceKey) ?? _pageModeKey,
      mode == FavoritePageMode.local ? 'local' : 'cloud',
    );
  }

  @override
  Future<String> loadSelectedFavoriteFolderId(
    FavoritePageMode mode, {
    String sourceKey = '',
  }) async {
    final prefs = await _preferences();
    final legacyKey = mode == FavoritePageMode.local
        ? _selectedLocalFolderKey
        : _selectedCloudFolderKey;
    final sourceScopedKey = _selectedFolderKeyForSource(mode, sourceKey);
    final raw =
        (sourceScopedKey == null
                ? prefs.getString(legacyKey)
                : prefs.getString(sourceScopedKey) ??
                      prefs.getString(legacyKey))
            ?.trim() ??
        '';
    return mode == FavoritePageMode.cloud && raw.isEmpty ? '0' : raw;
  }

  @override
  Future<void> saveSelectedFavoriteFolderId(
    FavoritePageMode mode,
    String folderId, {
    String sourceKey = '',
  }) async {
    final prefs = await _preferences();
    final key =
        _selectedFolderKeyForSource(mode, sourceKey) ??
        (mode == FavoritePageMode.local
            ? _selectedLocalFolderKey
            : _selectedCloudFolderKey);
    final normalized = folderId.trim();
    if (mode == FavoritePageMode.local && normalized.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(
      key,
      mode == FavoritePageMode.cloud && normalized.isEmpty ? '0' : normalized,
    );
  }

  String? _pageModeKeyForSource(String sourceKey) {
    final normalized = sourceKey.trim();
    return normalized.isEmpty
        ? null
        : '$_pageModeSourcePrefix${Uri.encodeComponent(normalized)}';
  }

  String? _selectedFolderKeyForSource(FavoritePageMode mode, String sourceKey) {
    final normalized = sourceKey.trim();
    if (normalized.isEmpty) return null;
    final prefix = mode == FavoritePageMode.local
        ? _selectedLocalFolderSourcePrefix
        : _selectedCloudFolderSourcePrefix;
    return '$prefix${Uri.encodeComponent(normalized)}';
  }
}
