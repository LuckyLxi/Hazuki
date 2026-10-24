import '../models/source_task.dart';
import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../models/source_contract_models.dart';

abstract interface class SourceAccountGateway implements Listenable {
  String? get activeSourceKey;
  bool get isLogged;
  bool get isInitialized;
  bool get isActiveDailyCheckInSource;
  String? get currentAccount;
  SourceRuntimeState get runtimeState;

  Future<void> ensureInitialized({String? sourceKey});
  Future<void> loadActiveSourcePreference();
  Future<void> login({
    required String account,
    required String password,
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> logout({SourceTaskOrigin? taskOrigin});
  Future<String?> loadCurrentAvatarUrl({SourceTaskOrigin? taskOrigin});
  Future<bool> isDailyCheckInCompletedToday({SourceTaskOrigin? taskOrigin});
  Future<DailyCheckInResult> performDailyCheckIn({
    SourceTaskOrigin? taskOrigin,
  });
}

abstract interface class SourceLocalizationGateway {
  void clearLocalizedSourceTextCaches();
}

abstract interface class SourceHomeGateway
    implements Listenable, SourceAccountGateway {
  String? get cachedAvatarUrl;
  String? get sourceRevision;
  bool get supportsLegacyRanking;
  SourceMeta? get sourceMeta;

  Future<void> prewarmInBackground();
  Future<void> warmUpFavoritesDebugInfo();
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

abstract interface class SourceSettingsGateway {
  Map<String, dynamic>? presentationForSource(String id);
  String? get activeSourceKey;
  bool get supportsLegacyRanking;
  int get imageCacheMaxBytes;

  Object? loadSourceSetting(String sourceKey, String key);
  Future<void> updateSourceSetting(
    String sourceKey,
    String key,
    dynamic value, {
    SourceTaskOrigin? taskOrigin,
  });
  Object? loadActiveSourceSetting(String key);
  Future<void> updateActiveSourceSetting(String key, dynamic value);
  Future<Map<String, dynamic>> getLineSettingsSnapshot({
    SourceTaskOrigin? taskOrigin,
  });
  Future<void> updateLineSetting(String key, dynamic value);
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
    SourceTaskOrigin? taskOrigin,
  });
  Future<Map<String, dynamic>> getImageCacheStatus();
  Future<void> setImageCacheMaxBytes(int value);
  Future<void> setImageCacheAutoCleanMode(String mode);
  Future<void> clearImageCache();
}

/// 运行时与选源：启动初始化、活动源切换、源脚本文件的就绪检查与下载。
abstract interface class SourceRuntimeGateway implements Listenable {
  String? get activeSourceKey;
  bool get hasActiveSource;
  bool get supportsDirectComicId;
  bool get supportsDailyRecommendation;
  bool get supportsLegacyRanking;
  bool get isActiveDailyCheckInSource;
  bool get isInitialized;
  SourceMeta? get sourceMeta;
  SourceRuntimeState get runtimeState;
  List<SourceCatalogEntry> get allowedSources;

  Future<void> prepareSources();
  Future<void> loadActiveSourcePreference();
  Future<void> init({void Function(int received, int total)? onProgress});
  Future<void> ensureInitialized({String? sourceKey});
  Future<void> activateSource(String sourceKey);
  Future<void> prewarmInBackground();
  Future<bool> hasLocalJmSourceFile();
  Future<bool> hasLocalSourceFile(String sourceKey);
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  });
}

/// 活动源脚本：本地编辑、备份恢复、云端更新与同步写回。
abstract interface class SourceScriptGateway implements Listenable {
  String? get activeSourceKey;

  Future<String> loadEditableActiveSource();
  Future<void> saveEditedActiveSource(String content);
  Future<bool> hasCustomEditedActiveSource();
  Future<bool> hasActiveSourceBackup();
  Future<bool> restoreActiveSourceBackup();
  Future<String?> readLocalActiveSourceIfExists();
  Future<void> writeLocalActiveSource(String content);
  Future<void> reloadFromLocalSourceFiles();
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud();
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  });
  Future<bool> refreshSourceOnNetworkRecovery();
}
