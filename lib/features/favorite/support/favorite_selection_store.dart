import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/local_favorites/local_favorites_preferences_store.dart';

class FavoriteSelectionSnapshot {
  const FavoriteSelectionSnapshot({
    required this.mode,
    required this.cloudFolderId,
    required this.localFolderId,
  });

  final FavoritePageMode mode;
  final String cloudFolderId;
  final String localFolderId;
}

/// Reads a complete selection without mutating the live page during awaits.
class FavoriteSelectionStore {
  const FavoriteSelectionStore(this._preferences);

  final LocalFavoritesPreferencesStore _preferences;

  Future<FavoriteSelectionSnapshot> load(String sourceKey) async {
    final mode = await _preferences.loadFavoritePageMode(sourceKey: sourceKey);
    final cloudFolderId = await _preferences.loadSelectedFavoriteFolderId(
      FavoritePageMode.cloud,
      sourceKey: sourceKey,
    );
    final localFolderId = await _preferences.loadSelectedFavoriteFolderId(
      FavoritePageMode.local,
      sourceKey: sourceKey,
    );
    return FavoriteSelectionSnapshot(
      mode: mode,
      cloudFolderId: cloudFolderId,
      localFolderId: localFolderId,
    );
  }

  Future<void> saveMode(FavoritePageMode mode, String sourceKey) =>
      _preferences.saveFavoritePageMode(mode, sourceKey: sourceKey);

  Future<void> saveFolder(
    FavoritePageMode mode,
    String folderId,
    String sourceKey,
  ) => _preferences.saveSelectedFavoriteFolderId(
    mode,
    folderId,
    sourceKey: sourceKey,
  );
}
