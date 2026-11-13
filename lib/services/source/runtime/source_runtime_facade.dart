import 'source_script_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/source_meta.dart';
import '../common/source_json_coerce.dart';
import '../debug/debug_log_internals.dart';
import '../debug/source_debug_log_store.dart';
import '../debug/source_network_log_sink.dart';
import '../http/source_http_gateway.dart';
import '../models/source_contract_models.dart';
import 'source_cache_store.dart';
import 'source_cookie_store.dart';
import 'source_runtime_kernel.dart';
import 'source_session_store.dart';
import '../../logging/app_log_store.dart';
import '../interaction/source_ui_service.dart';

abstract interface class SourceRuntimeHandleView {
  SourceUiService get sourceUiService;
  String get sourceKey;
  bool get isDisposed;
  SourceCookieStore get cookieStore;
  Future<T> runOperation<T>(Future<T> Function() operation);
}

typedef SourceApplicationLogAppender =
    void Function({
      required String title,
      String level,
      String source,
      Object? content,
    });

class SourceJsBridge {
  SourceJsBridge(this._runtime, this._handle);

  final SourceRuntimeKernel _runtime;
  final SourceRuntimeHandleView _handle;

  SourceScriptEngine? get engine => _runtime.engine;
  dynamic cachedValue(String code) => engine?.cachedValue(code);

  Future<dynamic> evaluate(String code, {String? name}) async {
    return await engine?.evaluate(code, name: name);
  }

  Future<dynamic> resolve(dynamic value) =>
      _handle.runOperation(() => awaitJsResult(value));

  bool asBool(dynamic value) => jsAsBool(value);

  int? asInt(dynamic value) => jsAsInt(value);

  Future<String> evaluateString(String code) async {
    return (await evaluate(code) ?? '').toString().trim();
  }
}

class HazukiSourceFacade {
  HazukiSourceFacade({
    required this.handle,
    required this.runtime,
    required this.session,
    required this.cache,
    required this.debug,
    required this.appLogStore,
    required this.js,
    required this.networkLogSink,
    required this.httpGateway,
    required Future<void> Function(String sourceKey) ensureInitialized,
    required void Function(String sourceKey) notifyRuntimeStateChanged,
    required SourceApplicationLogAppender addApplicationLog,
  }) : _ensureInitialized = ensureInitialized,
       _notifyRuntimeStateChanged = notifyRuntimeStateChanged,
       _addApplicationLog = addApplicationLog;

  final Future<void> Function(String sourceKey) _ensureInitialized;
  final void Function(String sourceKey) _notifyRuntimeStateChanged;
  final SourceApplicationLogAppender _addApplicationLog;
  final SourceRuntimeHandleView handle;
  final SourceRuntimeKernel runtime;
  final SourceSessionStore session;
  final SourceCacheStore cache;
  final SourceDebugLogStore debug;
  final AppLogStore appLogStore;
  final SourceJsBridge js;
  final SourceNetworkLogSink networkLogSink;
  final SourceHttpGateway httpGateway;

  String get sourceKey => handle.sourceKey;

  Future<void> ensureInitialized() => _ensureInitialized(sourceKey);

  Future<SharedPreferences> ensurePrefs() => session.ensurePrefs();

  bool get isLogged => session.hasLogin;

  SourceMeta? get sourceMeta => runtime.sourceMeta;

  bool get softwareLogCaptureEnabled => appLogStore.captureEnabled;

  SourceRuntimeState get runtimeState => runtime.runtimeState;

  String get statusText => runtime.statusText;

  void notifyRuntimeStateChanged() {
    _notifyRuntimeStateChanged(sourceKey);
  }

  Map<String, dynamic>? get favoritesDebugCache => debug.favoritesDebugCache;
  set favoritesDebugCache(Map<String, dynamic>? value) =>
      debug.favoritesDebugCache = value;

  Map<String, dynamic>? get lastLoginDebugInfo => debug.lastLoginDebugInfo;
  set lastLoginDebugInfo(Map<String, dynamic>? value) =>
      debug.lastLoginDebugInfo = value;

  Map<String, dynamic>? get lastSourceVersionDebugInfo =>
      debug.lastSourceVersionDebugInfo;
  set lastSourceVersionDebugInfo(Map<String, dynamic>? value) =>
      debug.lastSourceVersionDebugInfo = value;

  void clearCapturedLogs() => debug.clearCapturedLogs();

  dynamic loadSourceData(String sourceKey, String dataKey) {
    return session.loadSourceData(sourceKey, dataKey);
  }

  Future<void> saveSourceData(String sourceKey, String dataKey, dynamic data) {
    return session.saveSourceData(sourceKey, dataKey, data);
  }

  Future<void> deleteSourceData(String sourceKey, String dataKey) {
    return session.deleteSourceData(sourceKey, dataKey);
  }

  void addApplicationLog({
    required String title,
    String level = 'info',
    String source = 'app',
    Object? content,
  }) => _addApplicationLog(
    title: title,
    level: level,
    source: source,
    content: content,
  );

  Object? loadSourceSetting(String sourceKey, String settingKey) {
    return session.loadSourceSetting(
      sourceKey: sourceKey,
      settingKey: settingKey,
      sourceMeta: sourceMeta,
    );
  }

  Future<void> saveSourceSetting(
    String sourceKey,
    String settingKey,
    Object? value,
  ) {
    return session.saveSourceSetting(sourceKey, settingKey, value);
  }

  List<String>? loadAccountDataSync() =>
      session.loadAccountDataSync(sourceMeta, fallbackSourceKey: sourceKey);

  List<SourceCookie> loadCookieStore() => session.loadCookieStore();

  Future<void> saveCookieStore(List<SourceCookie> cookies) {
    return session.saveCookieStore(cookies);
  }

  Uri resolveImageBaseUri(String imageUrl, Uri baseUri) {
    final imageUri = Uri.tryParse(imageUrl);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      return imageUri;
    }
    return baseUri;
  }
}
