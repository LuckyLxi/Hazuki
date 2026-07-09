import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';

abstract interface class SourceAccountGateway implements Listenable {
  String get activeSourceKey;
  bool get isLogged;
  bool get isInitialized;
  bool get isActiveDailyCheckInSource;
  String? get currentAccount;
  SourceRuntimeState get sourceRuntimeState;

  Future<void> ensureInitialized({String? sourceKey});
  Future<void> loadActiveSourcePreference();
  Future<void> login({required String account, required String password});
  Future<void> logout();
  Future<String?> loadCurrentAvatarUrl();
  Future<bool> isDailyCheckInCompletedToday();
  Future<DailyCheckInResult> performDailyCheckIn();
}

abstract interface class SourceDebugGateway {
  bool get softwareLogCaptureEnabled;
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  });
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  });
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type);
  void clearCapturedLogs();
}

abstract interface class SourceRuntimeGateway implements Listenable {
  String get activeSourceKey;
  bool get isActiveJmSource;
  bool get isActiveCopyMangaSource;
  bool get isLogged;
  bool get isInitialized;
  bool get isActiveDailyCheckInSource;
  String? get currentAccount;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get runtimeState;
  List<SourceCatalogEntry> get allowedSources;

  bool isLoggedForSource(String sourceKey);
  String? currentAccountForSource(String sourceKey);
  Future<void> loadActiveSourcePreference();
  Future<void> ensureInitialized({String? sourceKey});
  Future<void> activateSource(String sourceKey);
  Future<void> prewarmInBackground();
  Future<void> warmUpFavoritesDebugInfo();
  Future<void> login({required String account, required String password});
  Future<void> logout();
  Future<String?> loadCurrentAvatarUrl();
  Future<bool> isDailyCheckInCompletedToday();
  Future<DailyCheckInResult> performDailyCheckIn();
  Future<bool> hasLocalSourceFile(String sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  });
  Future<void> deleteLocalSourceFile(String sourceKey);
  Future<String> loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content);
  Future<bool> hasCustomEditedActiveSource();
  Future<void> reloadFromLocalSourceFiles();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  });
  Future<bool> loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled);
  Future<void> clearCopyMangaDeviceInfo();
}

abstract interface class SourceSettingsGateway {
  String get activeSourceKey;
  bool get isActiveCopyMangaSource;

  Object? loadSourceSetting(String sourceKey, String key);
  Future<void> updateSourceSetting(String sourceKey, String key, dynamic value);
  Object? loadActiveSourceSetting(String key);
  Future<void> updateActiveSourceSetting(String key, dynamic value);
  Future<Map<String, dynamic>> getLineSettingsSnapshot();
  Future<void> updateLineSetting(String key, dynamic value);
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  });
  Future<Map<String, dynamic>> getImageCacheStatus();
  Future<void> setImageCacheMaxBytes(int value);
  Future<void> setImageCacheAutoCleanMode(String mode);
  Future<void> clearImageCache();
}
