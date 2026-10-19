import '../account/source_login_interaction.dart';
import 'package:flutter/foundation.dart';

import '../../../models/hazuki_models.dart';
import '../account/source_account_operations.dart';
import '../debug/source_debug_operations.dart';
import '../favorites/source_favorites_operations.dart';
import '../gateways/source_runtime_gateways.dart';
import '../image/source_image_operations.dart';
import '../models/source_contract_models.dart';
import '../runtime/source_localization_operations.dart';
import '../runtime/source_runtime_operations.dart';
import '../runtime/source_runtime_view.dart';
import '../runtime/source_settings_operations.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceBootstrapAdapter implements SourceBootstrapGateway {
  const HazukiSourceBootstrapAdapter(this._runtimeOperations, [this._runtime]);

  final SourceRuntimeOperations _runtimeOperations;
  final SourceRuntimeView? _runtime;
  @override
  Future<void> prepareSources() async {
    await _runtime?.loadActiveSourcePreference();
  }

  @override
  bool get hasActiveSource => _runtime?.activeSourceKey?.isNotEmpty ?? false;

  @override
  Future<bool> hasLocalJmSourceFile() =>
      _runtimeOperations.hasLocalJmSourceFile();
  @override
  Future<void> init({void Function(int received, int total)? onProgress}) =>
      _runtimeOperations.init(onSourceDownloadProgress: onProgress);
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      _runtimeOperations.ensureInitialized(sourceKey: sourceKey);
}

class HazukiSourceUpdateAdapter implements SourceUpdateGateway {
  const HazukiSourceUpdateAdapter(this._runtimeOperations);

  final SourceRuntimeOperations _runtimeOperations;

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
}

class HazukiSourceScriptAdapter implements SourceScriptGateway {
  const HazukiSourceScriptAdapter(this._runtimeOperations);

  final SourceRuntimeOperations _runtimeOperations;

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
}

class HazukiSourceLocalizationAdapter implements SourceLocalizationGateway {
  const HazukiSourceLocalizationAdapter(this._localizationOperations);

  final SourceLocalizationOperations _localizationOperations;

  @override
  void clearLocalizedSourceTextCaches() =>
      _localizationOperations.clearLocalizedSourceTextCaches();
}

class HazukiSourceHomeAdapter extends HazukiSourceListenableAdapter
    with _InteractiveAccountAdapter
    implements SourceHomeGateway {
  HazukiSourceHomeAdapter({
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
  String? get sourceRevision => runtime.sourceRevision;
  @override
  String? get cachedAvatarUrl => _account.cachedAvatarUrl;
  @override
  String? get activeSourceKey => runtime.activeSourceKey;
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
  SourceMeta? get sourceMeta => runtime.sourceMeta;
  @override
  SourceRuntimeState get runtimeState => runtime.runtimeState;
  @override
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  Future<void> loadActiveSourcePreference() =>
      runtime.loadActiveSourcePreference();
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      _runtimeOperations.ensureInitialized(sourceKey: sourceKey);
  @override
  Future<void> prewarmInBackground() => runtime.prewarmInBackground();
  @override
  Future<void> warmUpFavoritesDebugInfo() =>
      _favorites.warmUpFavoritesDebugInfo();
  @override
  Future<void> login({required String account, required String password}) =>
      _account.login(account: account, password: password);
  @override
  Future<void> logout() => _account.logout();
  @override
  Future<String?> loadCurrentAvatarUrl() => _account.loadCurrentAvatarUrl();
  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      _account.isDailyCheckInCompletedToday();
  @override
  Future<DailyCheckInResult> performDailyCheckIn() =>
      _account.performDailyCheckIn();
}

class HazukiSourceAdvancedAdapter extends HazukiSourceListenableAdapter
    implements SourceAdvancedGateway {
  HazukiSourceAdvancedAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeOperations runtimeOperations,
  }) : _runtimeOperations = runtimeOperations,
       super(runtime);

  final SourceRuntimeOperations _runtimeOperations;
  @override
  Future<bool> hasCustomEditedActiveSource() =>
      _runtimeOperations.hasCustomEditedActiveSource();
  @override
  Future<bool> hasActiveSourceBackup() =>
      _runtimeOperations.hasActiveSourceBackup();
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _runtimeOperations.loadSoftwareLogCaptureEnabled();
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _runtimeOperations.setSoftwareLogCaptureEnabled(enabled);
}

class HazukiSourceAccountAdapter extends HazukiSourceListenableAdapter
    with _InteractiveAccountAdapter
    implements SourceAccountGateway {
  HazukiSourceAccountAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeOperations runtimeOperations,
    required SourceAccountOperations account,
  }) : _runtimeOperations = runtimeOperations,
       _account = account,
       super(runtime);

  final SourceRuntimeOperations _runtimeOperations;
  final SourceAccountOperations _account;
  @override
  SourceAccountOperations get interactiveAccountOperations => _account;

  @override
  String? get activeSourceKey => runtime.activeSourceKey;
  @override
  bool get isLogged => _account.isLogged;
  @override
  bool get isInitialized => runtime.isInitialized;
  @override
  bool get isActiveDailyCheckInSource => runtime.isActiveDailyCheckInSource;
  @override
  String? get currentAccount => _account.currentAccount;
  @override
  SourceRuntimeState get sourceRuntimeState => runtime.sourceRuntimeState;
  @override
  Future<void> ensureInitialized({String? sourceKey}) =>
      _runtimeOperations.ensureInitialized(sourceKey: sourceKey);
  @override
  Future<void> loadActiveSourcePreference() =>
      runtime.loadActiveSourcePreference();
  @override
  Future<void> login({required String account, required String password}) =>
      _account.login(account: account, password: password);
  @override
  Future<void> logout() => _account.logout();
  @override
  Future<String?> loadCurrentAvatarUrl() => _account.loadCurrentAvatarUrl();
  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      _account.isDailyCheckInCompletedToday();
  @override
  Future<DailyCheckInResult> performDailyCheckIn() =>
      _account.performDailyCheckIn();
}

class HazukiSourceDebugAdapter implements SourceDebugGateway {
  const HazukiSourceDebugAdapter({
    required SourceRuntimeOperations runtimeOperations,
    required SourceDebugOperations debug,
  }) : _runtimeOperations = runtimeOperations,
       _debug = debug;

  final SourceRuntimeOperations _runtimeOperations;
  final SourceDebugOperations _debug;

  @override
  bool get softwareLogCaptureEnabled => _debug.softwareLogCaptureEnabled;
  @override
  Listenable get logChanges => _debug.logStore;
  @override
  Future<bool> loadSoftwareLogCaptureEnabled() =>
      _runtimeOperations.loadSoftwareLogCaptureEnabled();
  @override
  Future<void> setSoftwareLogCaptureEnabled(bool enabled) =>
      _runtimeOperations.setSoftwareLogCaptureEnabled(enabled);
  @override
  void addApplicationLog({
    required String level,
    required String title,
    Object? content,
    String source = 'app',
  }) => _debug.addApplicationLog(
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
  }) => _debug.addReaderLog(
    level: level,
    title: title,
    content: content,
    source: source,
  );
  @override
  Future<Map<String, dynamic>> collectTypedDebugInfo(String type) =>
      _debug.collectTypedDebugInfo(type);
  @override
  Future<Map<String, dynamic>> collectAllDebugInfo() =>
      _debug.collectAllDebugInfo();
  @override
  Future<void> clearCapturedLogs() => _debug.clearCapturedLogs();
}

class HazukiSourceRuntimeAdapter extends HazukiSourceListenableAdapter
    with _InteractiveAccountAdapter
    implements
        SourceRuntimeGateway,
        SourceSelectionGateway,
        SourceSwitchGateway {
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
  Future<void> loadActiveSourcePreference() =>
      runtime.loadActiveSourcePreference();
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
  Future<void> login({required String account, required String password}) =>
      _account.login(account: account, password: password);
  @override
  Future<void> logout() => _account.logout();
  @override
  Future<String?> loadCurrentAvatarUrl() => _account.loadCurrentAvatarUrl();
  @override
  Future<bool> isDailyCheckInCompletedToday() =>
      _account.isDailyCheckInCompletedToday();
  @override
  Future<DailyCheckInResult> performDailyCheckIn() =>
      _account.performDailyCheckIn();
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
  Future<void> reloadFromLocalSourceFiles() =>
      _runtimeOperations.reloadFromLocalSourceFiles();
  @override
  Future<bool> downloadActiveSourceAndReload({
    void Function(int received, int total)? onProgress,
  }) =>
      _runtimeOperations.downloadActiveSourceAndReload(onProgress: onProgress);
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
    dynamic value,
  ) => _settings.updateSourceSetting(sourceKey, key, value);
  @override
  Object? loadActiveSourceSetting(String key) =>
      _settings.loadActiveSourceSetting(key);
  @override
  Future<void> updateActiveSourceSetting(String key, dynamic value) =>
      _settings.updateActiveSourceSetting(key, value);
  @override
  Future<Map<String, dynamic>> getLineSettingsSnapshot() =>
      _settings.getLineSettingsSnapshot();
  @override
  Future<void> updateLineSetting(String key, dynamic value) =>
      _settings.updateLineSetting(key, value);
  @override
  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) => _settings.refreshLines(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
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
      (interactiveAccountOperations as SourceInteractiveAccountGateway)
          .cancelPendingLogin();
  @override
  Future<List<SourceLoginMethod>> loadLoginMethods() {
    final account = interactiveAccountOperations;
    return account is SourceInteractiveAccountGateway
        ? (account as SourceInteractiveAccountGateway).loadLoginMethods()
        : Future.value(const []);
  }

  @override
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
  }) => (interactiveAccountOperations as SourceInteractiveAccountGateway)
      .loginInteractive(
        account: account,
        password: password,
        method: method,
        present: present,
        cancellation: cancellation,
      );
}
