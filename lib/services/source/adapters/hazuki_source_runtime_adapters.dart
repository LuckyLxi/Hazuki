import '../../../models/hazuki_models.dart';
import '../../hazuki_source_service.dart';
import '../gateways/source_runtime_gateways.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceAccountAdapter extends HazukiSourceListenableAdapter
    implements SourceAccountGateway {
  const HazukiSourceAccountAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isLogged => source.isLogged;
  @override
  bool get isInitialized => source.isInitialized;
  @override
  bool get isActiveDailyCheckInSource => source.isActiveDailyCheckInSource;
  @override
  String? get currentAccount => source.currentAccount;
  @override
  SourceRuntimeState get sourceRuntimeState => source.sourceRuntimeState;
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      source.ensureInitialized(sourceKey: sourceKey);
  @override
  Future<void> loadActiveSourcePreference() =>
      source.loadActiveSourcePreference();
  @override
  Future<void> login({required String account, required String password}) =>
      source.login(account: account, password: password);
  @override
  Future<void> logout() => source.logout();
  @override
  Future<String?> loadCurrentAvatarUrl() => source.loadCurrentAvatarUrl();
  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      source.isDailyCheckInCompletedToday();
  @override
  Future<DailyCheckInResult> performDailyCheckIn() =>
      source.performDailyCheckIn();
}

class HazukiSourceDebugAdapter extends HazukiSourceAdapterBase
    implements SourceDebugGateway {
  const HazukiSourceDebugAdapter(super.source);

  @override
  bool get softwareLogCaptureEnabled => source.softwareLogCaptureEnabled;
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => this.source.addApplicationLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
  @override
  void addReaderLog({
    required String level,
    required String title,
    Object? content,
    String source = 'reader',
  }) => this.source.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
  @override
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      source.collectTypedDebugInfo(type);
  @override
  void clearCapturedLogs() => source.facade.clearCapturedLogs();
}

class HazukiSourceRuntimeAdapter extends HazukiSourceListenableAdapter
    implements SourceRuntimeGateway {
  const HazukiSourceRuntimeAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isActiveJmSource => source.isActiveJmSource;
  @override
  bool get isActiveCopyMangaSource => source.isActiveCopyMangaSource;
  @override
  bool get isLogged => source.isLogged;
  @override
  bool get isInitialized => source.isInitialized;
  @override
  bool get isActiveDailyCheckInSource => source.isActiveDailyCheckInSource;
  @override
  String? get currentAccount => source.currentAccount;
  @override
  SourceMeta? get sourceMeta => source.sourceMeta;
  @override
  SourceRuntimeState get runtimeState => source.runtimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      source.runtimeRegistry.allowedSources;
  @override
  bool isLoggedForSource(String sourceKey) =>
      source.isLoggedForSource(sourceKey);
  @override
  String? currentAccountForSource(String sourceKey) =>
      source.currentAccountForSource(sourceKey);
  @override
  Future<void> loadActiveSourcePreference() =>
      source.loadActiveSourcePreference();
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      source.ensureInitialized(sourceKey: sourceKey);
  @override
  Future<void> activateSource(String sourceKey) =>
      source.activateSource(sourceKey);
  @override
  Future<void> prewarmInBackground() => source.prewarmInBackground();
  @override
  Future<void> warmUpFavoritesDebugInfo() => source.warmUpFavoritesDebugInfo();
  @override
  Future<void> login({required String account, required String password}) =>
      source.login(account: account, password: password);
  @override
  Future<void> logout() => source.logout();
  @override
  Future<String?> loadCurrentAvatarUrl() => source.loadCurrentAvatarUrl();
  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      source.isDailyCheckInCompletedToday();
  @override
  Future<DailyCheckInResult> performDailyCheckIn() =>
      source.performDailyCheckIn();
  @override
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      source.hasLocalSourceFile(sourceKey);
  @override
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) => source.downloadSourceFile(sourceKey, onProgress: onProgress);
  @override
  Future<void> deleteLocalSourceFile(String sourceKey) =>
      source.deleteLocalSourceFile(sourceKey);
  @override
  Future<String> loadEditableActiveSource() =>
      source.loadEditableActiveSource();
  @override
  Future<void> saveEditedActiveSource(String content) =>
      source.saveEditedActiveSource(content);
  @override
  Future<bool> hasCustomEditedActiveSource() =>
      source.hasCustomEditedActiveSource();
  @override
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) => source.downloadActiveSourceAndReload(onProgress: onProgress);
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      source.loadSoftwareLogCaptureEnabled();
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      source.setSoftwareLogCaptureEnabled(enabled);
  @override
  Future<void> clearCopyMangaDeviceInfo() => source.clearCopyMangaDeviceInfo();
}

class HazukiSourceSettingsAdapter extends HazukiSourceAdapterBase
    implements SourceSettingsGateway {
  const HazukiSourceSettingsAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  bool get isActiveCopyMangaSource => source.isActiveCopyMangaSource;
  @override
  Object? loadSourceSetting(String sourceKey, String key) =>
      source.loadSourceSetting(sourceKey, key);
  @override
  Future<void> updateSourceSetting(
    String sourceKey,
    String key,
    dynamic value,
  ) => source.updateSourceSetting(sourceKey, key, value);
  @override
  Object? loadActiveSourceSetting(String key) =>
      source.loadActiveSourceSetting(key);
  @override
  Future<void> updateActiveSourceSetting(String key, dynamic value) =>
      source.updateActiveSourceSetting(key, value);
  @override
  Future<Map<String, dynamic>> getLineSettingsSnapshot() =>
      source.getLineSettingsSnapshot();
  @override
  Future<void> updateLineSetting(String key, dynamic value) =>
      source.updateLineSetting(key, value);
  @override
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) => source.refreshLines(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
  );
  @override
  Future<Map<String, dynamic>> getImageCacheStatus() =>
      source.getImageCacheStatus();
  @override
  Future<void> setImageCacheMaxBytes(int value) =>
      source.setImageCacheMaxBytes(value);
  @override
  Future<void> setImageCacheAutoCleanMode(String mode) =>
      source.setImageCacheAutoCleanMode(mode);
  @override
  Future<void> clearImageCache() => source.clearImageCache();
}
