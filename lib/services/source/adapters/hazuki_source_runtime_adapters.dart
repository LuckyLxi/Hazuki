import '../models/source_task.dart';
import '../account/source_login_interaction.dart';

import '../../../models/hazuki_models.dart';
import '../account/account_session_capability.dart';
import '../account/source_daily_check_in_capability.dart';
import '../debug/debug_favorites_capability.dart';
import '../gateways/source_runtime_gateways.dart';
import '../image/source_image_operations.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_runtime_initialization_operations.dart';
import '../runtime/source_runtime_recovery_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../runtime/source_script_editing_operations.dart';
import '../runtime/source_settings_operations.dart';
import '../runtime/source_update_operations.dart';
import 'hazuki_source_adapter_base.dart';

/// 运行时、账号与脚本三组 Gateway 共用一个实现。
class HazukiSourceRuntimeAdapter extends HazukiSourceListenableAdapter
    implements
        SourceRuntimeGateway,
        SourceAccountGateway,
        SourceInteractiveAccountGateway,
        SourceHomeGateway,
        SourceScriptGateway {
  HazukiSourceRuntimeAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeInitializationOperations initialization,
    required SourceScriptEditingOperations scriptEditing,
    required SourceUpdateOperations updates,
    required SourceRuntimeRecoveryOperations recovery,
    required SourceAccountSessionCapability account,
    required SourceDailyCheckInCapability dailyCheckIn,
    required SourceFavoritesDebugCapability favoritesDebug,
  }) : _initialization = initialization,
       _scriptEditing = scriptEditing,
       _updates = updates,
       _recovery = recovery,
       _account = account,
       _dailyCheckIn = dailyCheckIn,
       _favoritesDebug = favoritesDebug,
       super(runtime);

  final SourceRuntimeInitializationOperations _initialization;
  final SourceScriptEditingOperations _scriptEditing;
  final SourceUpdateOperations _updates;
  final SourceRuntimeRecoveryOperations _recovery;
  final SourceAccountSessionCapability _account;
  final SourceDailyCheckInCapability _dailyCheckIn;
  final SourceFavoritesDebugCapability _favoritesDebug;

  @override
  String? get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get hasActiveSource => runtime.activeSourceKey?.isNotEmpty ?? false;
  @override
  String? get sourceRevision => runtime.sourceRevision;
  @override
  bool get supportsDirectComicId => runtime.supportsDirectComicId;
  @override
  bool get supportsDailyRecommendation => runtime.supportsDailyRecommendation;
  @override
  bool get supportsLegacyRanking => runtime.supportsLegacyRanking;
  @override
  bool get isLogged => _account.isLogged;
  @override
  bool get isInitialized => runtime.isInitialized;
  @override
  bool get isActiveDailyCheckInSource => runtime.isActiveDailyCheckInSource;
  @override
  String? get currentAccount => _account.currentAccount;
  @override
  String? get cachedAvatarUrl => _account.cachedAvatarUrl;
  @override
  SourceMeta? get sourceMeta => runtime.sourceMeta;
  @override
  SourceRuntimeState get runtimeState => runtime.runtimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      runtime.runtimeRegistry.allowedSources;
  @override
  Future<void> loadActiveSourcePreference() =>
      runtime.loadActiveSourcePreference();
  @override
  Future<void> init({void Function(int received, int total)? onProgress}) =>
      _initialization.init(onSourceDownloadProgress: onProgress);
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      _initialization.ensureInitialized(sourceKey: sourceKey);
  @override
  Future<void> activateSource(String sourceKey) =>
      runtime.activateSource(sourceKey);
  @override
  Future<void> prewarmInBackground() => _initialization.prewarmInBackground();
  @override
  Future<void> warmUpFavoritesDebugInfo() =>
      _favoritesDebug.warmUpFavoritesDebugInfo();
  @override
  Future<void> login({
    required String account,
    required String password,
    SourceTaskOrigin? taskOrigin,
  }) => _account.login(
    account: account,
    password: password,
    taskOrigin: taskOrigin,
  );
  @override
  Future<void> logout({SourceTaskOrigin? taskOrigin}) =>
      _account.logout(taskOrigin: taskOrigin);
  @override
  Future<String?> loadCurrentAvatarUrl({SourceTaskOrigin? taskOrigin}) =>
      _account.loadCurrentAvatarUrl(taskOrigin: taskOrigin);
  @override
  Future<bool> isDailyCheckInCompletedToday({SourceTaskOrigin? taskOrigin}) =>
      _dailyCheckIn.isCompletedToday(taskOrigin: taskOrigin);
  @override
  Future<DailyCheckInResult> performDailyCheckIn({
    SourceTaskOrigin? taskOrigin,
  }) => _dailyCheckIn.perform(taskOrigin: taskOrigin);
  @override
  Future<bool> hasLocalActiveSourceFile() =>
      _scriptEditing.hasLocalActiveSourceFile();
  @override
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _scriptEditing.hasLocalSourceFile(sourceKey);
  @override
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) => _recovery.downloadSourceFile(sourceKey, onProgress: onProgress);
  @override
  Future<String> loadEditableActiveSource() =>
      _scriptEditing.loadEditableActiveSource();
  @override
  Future<void> saveEditedActiveSource(String content) =>
      _scriptEditing.saveEditedActiveSource(content);
  @override
  Future<bool> hasCustomEditedActiveSource() =>
      _scriptEditing.hasCustomEditedActiveSource();
  @override
  Future<bool> hasActiveSourceBackup() =>
      _scriptEditing.hasActiveSourceBackup();
  @override
  Future<bool> restoreActiveSourceBackup() =>
      _scriptEditing.restoreActiveSourceBackup();
  @override
  Future<String?> readLocalActiveSourceIfExists() =>
      _scriptEditing.readLocalActiveSourceIfExists();
  @override
  Future<void> writeLocalActiveSource(String content) =>
      _scriptEditing.writeLocalActiveSource(content);
  @override
  Future<void> reloadFromLocalSourceFiles() =>
      _recovery.reloadFromLocalSourceFiles();
  @override
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() =>
      _updates.checkActiveSourceVersion();
  @override
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) => _updates.downloadActiveSource(onProgress: onProgress);
  @override
  Future<bool> refreshSourceOnNetworkRecovery() =>
      _recovery.refreshSourceOnNetworkRecovery();

  @override
  void cancelPendingLogin() => _account.interactive?.cancelPendingLogin();
  @override
  Future<List<SourceLoginMethod>> loadLoginMethods({
    SourceTaskOrigin? taskOrigin,
  }) =>
      _account.interactive?.loadLoginMethods(taskOrigin: taskOrigin) ??
      Future.value(const []);

  @override
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
    SourceTaskOrigin? taskOrigin,
  }) => _account.interactive!.loginInteractive(
    account: account,
    password: password,
    method: method,
    present: present,
    cancellation: cancellation,
    taskOrigin: taskOrigin,
  );
}

class HazukiSourceSettingsAdapter implements SourceSettingsGateway {
  const HazukiSourceSettingsAdapter({
    required SourceRuntimeView runtime,
    required SourceSettingsOperations settings,
    required SourceImageOperations image,
  }) : _runtime = runtime,
       _settings = settings,
       _image = image;

  final SourceRuntimeView _runtime;
  final SourceSettingsOperations _settings;
  final SourceImageOperations _image;

  @override
  Map<String, dynamic>? presentationForSource(String id) =>
      _runtime.runtimeRegistry.isAllowedSourceKey(id)
      ? _runtime.runtimeRegistry.definitionFor(id).presentation
      : null;
  @override
  String? get activeSourceKey => _runtime.activeSourceKey;
  @override
  bool get supportsLegacyRanking => _runtime.supportsLegacyRanking;
  @override
  int get imageCacheMaxBytes => _image.imageCacheMaxBytes;
  @override
  Object? loadSourceSetting(String sourceKey, String key) =>
      _settings.loadSourceSetting(sourceKey, key);
  @override
  Future<void> updateSourceSetting(
    String sourceKey,
    String key,
    dynamic value, {
    SourceTaskOrigin? taskOrigin,
  }) => _settings.updateSourceSetting(
    sourceKey,
    key,
    value,
    taskOrigin: taskOrigin,
  );
  @override
  Object? loadActiveSourceSetting(String key) =>
      _settings.loadActiveSourceSetting(key);
  @override
  Future<void> updateActiveSourceSetting(String key, dynamic value) =>
      _settings.updateActiveSourceSetting(key, value);
  @override
  Future<Map<String, dynamic>> getLineSettingsSnapshot({
    SourceTaskOrigin? taskOrigin,
  }) => _settings.getLineSettingsSnapshot(taskOrigin: taskOrigin);
  @override
  Future<void> updateLineSetting(String key, dynamic value) =>
      _settings.updateLineSetting(key, value);
  @override
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
    SourceTaskOrigin? taskOrigin,
  }) => _settings.refreshLines(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
    taskOrigin: taskOrigin,
  );
  @override
  Future<Map<String, dynamic>> getImageCacheStatus() =>
      _image.getImageCacheStatus();
  @override
  Future<void> setImageCacheMaxBytes(int value) =>
      _image.setImageCacheMaxBytes(value);
  @override
  Future<void> setImageCacheAutoCleanMode(String mode) =>
      _image.setImageCacheAutoCleanMode(mode);
  @override
  Future<void> clearImageCache() => _image.clearImageCache();
}
