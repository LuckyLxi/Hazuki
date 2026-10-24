import '../models/source_task.dart';
import '../account/source_login_interaction.dart';

import '../../../models/hazuki_models.dart';
import '../account/source_account_operations.dart';
import '../favorites/source_favorites_operations.dart';
import '../gateways/source_runtime_gateways.dart';
import '../gateways/source_sync_gateway.dart';
import '../image/source_image_operations.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_runtime_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../runtime/source_settings_operations.dart';
import 'hazuki_source_adapter_base.dart';

/// 运行时、账号与脚本相关的全部 Gateway 共用一个实现，各功能仍只依赖自己的窄接口。
class HazukiSourceRuntimeAdapter extends HazukiSourceListenableAdapter
    with _InteractiveAccountAdapter
    implements
        SourceRuntimeGateway,
        SourceSelectionGateway,
        SourceSwitchGateway,
        SourceAccountGateway,
        SourceHomeGateway,
        SourceAdvancedGateway,
        SourceScriptGateway,
        SourceUpdateGateway,
        SourceSyncGateway,
        SourceBootstrapGateway {
  HazukiSourceRuntimeAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeOperations runtimeOperations,
    required SourceAccountOperations account,
    required SourceFavoritesOperations favorites,
  }) : _runtimeOperations = runtimeOperations,
       _account = account,
       _favorites = favorites,
       super(runtime);

  final SourceRuntimeOperations _runtimeOperations;
  final SourceAccountOperations _account;
  @override
  SourceAccountOperations get interactiveAccountOperations => _account;
  final SourceFavoritesOperations _favorites;

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
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  List<SourceCatalogEntry> get allowedSources =>
      runtime.runtimeRegistry.allowedSources;
  @override
  bool isLoggedForSource(String sourceKey) =>
      _account.isLoggedForSource(sourceKey);
  @override
  String? currentAccountForSource(String sourceKey) =>
      _account.currentAccountForSource(sourceKey);
  @override
  Future<void> prepareSources() => runtime.loadActiveSourcePreference();
  @override
  Future<void> loadActiveSourcePreference() =>
      runtime.loadActiveSourcePreference();
  @override
  Future<void> init({void Function(int received, int total)? onProgress}) =>
      _runtimeOperations.init(onSourceDownloadProgress: onProgress);
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      _runtimeOperations.ensureInitialized(sourceKey: sourceKey);
  @override
  Future<void> activateSource(String sourceKey) =>
      runtime.activateSource(sourceKey);
  @override
  Future<void> prewarmInBackground() => runtime.prewarmInBackground();
  @override
  Future<void> warmUpFavoritesDebugInfo() =>
      _favorites.warmUpFavoritesDebugInfo();
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
      _account.isDailyCheckInCompletedToday(taskOrigin: taskOrigin);
  @override
  Future<DailyCheckInResult> performDailyCheckIn({
    SourceTaskOrigin? taskOrigin,
  }) => _account.performDailyCheckIn(taskOrigin: taskOrigin);
  @override
  Future<bool> hasLocalJmSourceFile() =>
      _runtimeOperations.hasLocalJmSourceFile();
  @override
  Future<bool> hasLocalSourceFile(String sourceKey) =>
      _runtimeOperations.hasLocalSourceFile(sourceKey);
  @override
  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) =>
      _runtimeOperations.downloadSourceFile(sourceKey, onProgress: onProgress);
  @override
  Future<void> deleteLocalSourceFile(String sourceKey) =>
      _runtimeOperations.deleteLocalSourceFile(sourceKey);
  @override
  Future<String> loadEditableActiveSource() =>
      _runtimeOperations.loadEditableActiveSource();
  @override
  Future<void> saveEditedActiveSource(String content) =>
      _runtimeOperations.saveEditedActiveSource(content);
  @override
  Future<bool> hasCustomEditedActiveSource() =>
      _runtimeOperations.hasCustomEditedActiveSource();
  @override
  Future<bool> hasActiveSourceBackup() =>
      _runtimeOperations.hasActiveSourceBackup();
  @override
  Future<bool> restoreActiveSourceBackup() =>
      _runtimeOperations.restoreActiveSourceBackup();
  @override
  Future<String?> readLocalActiveSourceIfExists() =>
      _runtimeOperations.readLocalActiveSourceIfExists();
  @override
  Future<void> writeLocalActiveSource(String content) =>
      _runtimeOperations.writeLocalActiveSource(content);
  @override
  Future<void> reloadFromLocalSourceFiles() =>
      _runtimeOperations.reloadFromLocalSourceFiles();
  @override
  Future<SourceVersionCheckResult?> checkActiveSourceVersionFromCloud() =>
      _runtimeOperations.checkActiveSourceVersionFromCloud();
  @override
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) =>
      _runtimeOperations.downloadActiveSourceAndReload(onProgress: onProgress);
  @override
  Future<bool> refreshSourceOnNetworkRecovery() =>
      _runtimeOperations.refreshSourceOnNetworkRecovery();
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _runtimeOperations.loadSoftwareLogCaptureEnabled();
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _runtimeOperations.setSoftwareLogCaptureEnabled(enabled);
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

mixin _InteractiveAccountAdapter implements SourceInteractiveAccountGateway {
  SourceAccountOperations get interactiveAccountOperations;
  @override
  void cancelPendingLogin() =>
      interactiveAccountOperations.cancelPendingLogin();
  @override
  Future<List<SourceLoginMethod>> loadLoginMethods({
    SourceTaskOrigin? taskOrigin,
  }) => interactiveAccountOperations.loadLoginMethods(taskOrigin: taskOrigin);

  @override
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
    SourceTaskOrigin? taskOrigin,
  }) => interactiveAccountOperations.loginInteractive(
    account: account,
    password: password,
    method: method,
    present: present,
    cancellation: cancellation,
    taskOrigin: taskOrigin,
  );
}
