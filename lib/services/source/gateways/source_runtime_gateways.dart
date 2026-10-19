import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';

abstract interface class SourceAccountGateway implements Listenable {
  String? get activeSourceKey;
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

abstract interface class SourceBootstrapGateway {
  Future<void> prepareSources();
  bool get hasActiveSource;
  Future<bool> hasLocalJmSourceFile();
  Future<void> init({void Function(int received, int total)? onProgress});
  Future<void> ensureInitialized({String? sourceKey});
}

abstract interface class SourceUpdateGateway {
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  });
  Future<bool> refreshSourceOnNetworkRecovery();
}

abstract interface class SourceScriptGateway {
  Future<String> loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content);
  Future<bool> hasCustomEditedActiveSource();
  Future<bool> restoreActiveSourceBackup();
  Future<String?> readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content);
  Future<void> reloadFromLocalSourceFiles();
}

abstract interface class SourceLocalizationGateway {
  void clearLocalizedSourceTextCaches();
}

abstract interface class SourceSelectionGateway implements Listenable {
  String? get activeSourceKey;
  bool get supportsDirectComicId;
  bool get supportsDailyRecommendation;
  bool get supportsLegacyRanking;
  bool get isActiveDailyCheckInSource;
  bool get isInitialized;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get runtimeState;
  List<SourceCatalogEntry> get allowedSources;

  Future<void> loadActiveSourcePreference();
  Future<void> activateSource(String sourceKey);
  Future<void> prewarmInBackground();
}

abstract interface class SourceHomeGateway
    implements Listenable, SourceAccountGateway {
  String? get cachedAvatarUrl;
  String? get sourceRevision;
  bool get supportsLegacyRanking;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get runtimeState;

  Future<void> prewarmInBackground();
  Future<void> warmUpFavoritesDebugInfo();
}

abstract interface class SourceSwitchGateway {
  String? get activeSourceKey;
  List<SourceCatalogEntry> get allowedSources;

  Future<void> loadActiveSourcePreference();
  Future<void> activateSource(String sourceKey);
  Future<void> ensureInitialized({String? sourceKey});
  Future<bool> hasLocalSourceFile(String sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  });
}

abstract interface class SourceAdvancedGateway implements Listenable {
  Future<bool> hasCustomEditedActiveSource();
  Future<bool> hasActiveSourceBackup();
  Future<bool> loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled);
}

abstract interface class SourceDebugGateway {
  bool get softwareLogCaptureEnabled;
  Listenable get logChanges;
  Future<bool> loadSoftwareLogCaptureEnabled();
  Future<void> setSoftwareLogCaptureEnabled(bool enabled);
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
  Future<Map<String, dynamic>> collectAllDebugInfo();
  Future<void> clearCapturedLogs();
}

abstract interface class SourceRuntimeGateway
    implements Listenable, SourceAccountGateway {
  bool get supportsDirectComicId;
  bool get supportsDailyRecommendation;
  bool get supportsLegacyRanking;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get runtimeState;
  List<SourceCatalogEntry> get allowedSources;

  bool isLoggedForSource(String sourceKey);
  String? currentAccountForSource(String sourceKey);
  Future<void> activateSource(String sourceKey);
  Future<void> prewarmInBackground();
  Future<void> warmUpFavoritesDebugInfo();
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
}

abstract interface class SourceSettingsGateway {
  Map<String, dynamic>? presentationForSource(String id);
  String? get activeSourceKey;
  bool get supportsLegacyRanking;
  int get imageCacheMaxBytes;

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
