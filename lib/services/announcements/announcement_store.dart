import 'package:shared_preferences/shared_preferences.dart';

import 'package:hazuki/services/preferences/hazuki_preference_keys.dart';

class AnnouncementStoredState {
  AnnouncementStoredState({
    required this.cachedManifest,
    required Set<String> readIds,
    required Set<String> presentedPopupIds,
    required Set<String> hiddenCardIds,
  }) : readIds = Set<String>.unmodifiable(readIds),
       presentedPopupIds = Set<String>.unmodifiable(presentedPopupIds),
       hiddenCardIds = Set<String>.unmodifiable(hiddenCardIds);

  final String? cachedManifest;
  final Set<String> readIds;
  final Set<String> presentedPopupIds;
  final Set<String> hiddenCardIds;
}

class AnnouncementStore {
  AnnouncementStore({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  Future<AnnouncementStoredState> load() async {
    final preferences = await _preferences();
    return AnnouncementStoredState(
      cachedManifest: preferences.getString(
        hazukiAnnouncementCachePreferenceKey,
      ),
      readIds:
          preferences
              .getStringList(hazukiAnnouncementReadIdsPreferenceKey)
              ?.toSet() ??
          <String>{},
      presentedPopupIds:
          preferences
              .getStringList(hazukiAnnouncementPresentedIdsPreferenceKey)
              ?.toSet() ??
          <String>{},
      hiddenCardIds:
          preferences
              .getStringList(hazukiAnnouncementHiddenCardIdsPreferenceKey)
              ?.toSet() ??
          <String>{},
    );
  }

  Future<void> saveCachedManifest(String manifest) async {
    final preferences = await _preferences();
    await preferences.setString(hazukiAnnouncementCachePreferenceKey, manifest);
  }

  Future<void> saveReadIds(Set<String> ids) async {
    final preferences = await _preferences();
    await preferences.setStringList(
      hazukiAnnouncementReadIdsPreferenceKey,
      ids.toList(growable: false),
    );
  }

  Future<void> savePresentedPopupIds(Set<String> ids) async {
    final preferences = await _preferences();
    await preferences.setStringList(
      hazukiAnnouncementPresentedIdsPreferenceKey,
      ids.toList(growable: false),
    );
  }

  Future<void> saveHiddenCardIds(Set<String> ids) async {
    final preferences = await _preferences();
    await preferences.setStringList(
      hazukiAnnouncementHiddenCardIdsPreferenceKey,
      ids.toList(growable: false),
    );
  }
}
