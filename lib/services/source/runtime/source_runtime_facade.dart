import 'dart:io';

import 'package:flutter_qjs/flutter_qjs.dart';
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

abstract interface class SourceRuntimeHandleView {
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
  SourceJsBridge(this._runtime);

  final SourceRuntimeKernel _runtime;

  FlutterQjs? get engine => _runtime.engine;

  dynamic evaluate(String code, {String? name}) {
    return engine?.evaluate(code, name: name);
  }

  Future<dynamic> resolve(dynamic value) {
    return awaitJsResult(value);
  }

  bool asBool(dynamic value) => jsAsBool(value);

  int? asInt(dynamic value) => jsAsInt(value);

  String evaluateString(String code) {
    return (evaluate(code) ?? '').toString().trim();
  }
}

class HazukiSourceFacade {
  HazukiSourceFacade({
    required this.handle,
    required this.runtime,
    required this.session,
    required this.cache,
    required this.debug,
    required this.js,
    required this.networkLogSink,
    required this.httpGateway,
    required Future<void> Function(String sourceKey) ensureInitialized,
    required void Function(String sourceKey) notifyRuntimeStateChanged,
    required SourceApplicationLogAppender addApplicationLog,
    required Future<Directory> Function() ensureImageCacheDir,
    required Future<int> Function() computeImageCacheSizeBytes,
    required Future<void> Function({bool force}) enforceImageCachePolicy,
  }) : _ensureInitialized = ensureInitialized,
       _notifyRuntimeStateChanged = notifyRuntimeStateChanged,
       _addApplicationLog = addApplicationLog,
       _ensureImageCacheDir = ensureImageCacheDir,
       _computeImageCacheSizeBytes = computeImageCacheSizeBytes,
       _enforceImageCachePolicy = enforceImageCachePolicy;

  final Future<void> Function(String sourceKey) _ensureInitialized;
  final void Function(String sourceKey) _notifyRuntimeStateChanged;
  final SourceApplicationLogAppender _addApplicationLog;
  final Future<Directory> Function() _ensureImageCacheDir;
  final Future<int> Function() _computeImageCacheSizeBytes;
  final Future<void> Function({bool force}) _enforceImageCachePolicy;
  final SourceRuntimeHandleView handle;
  final SourceRuntimeKernel runtime;
  final SourceSessionStore session;
  final SourceCacheStore cache;
  final SourceDebugLogStore debug;
  final SourceJsBridge js;
  final SourceNetworkLogSink networkLogSink;
  final SourceHttpGateway httpGateway;

  String get sourceKey => handle.sourceKey;

  Future<void> ensureInitialized() => _ensureInitialized(sourceKey);

  Future<SharedPreferences> ensurePrefs() => session.ensurePrefs();

  bool get isLogged =>
      session.loadAccountDataSync(sourceMeta, fallbackSourceKey: sourceKey) !=
      null;

  SourceMeta? get sourceMeta => runtime.sourceMeta;

  bool get softwareLogCaptureEnabled => debug.softwareLogCaptureEnabled;

  DateTime? get lastReloginAt => runtime.lastReloginAt;
  set lastReloginAt(DateTime? value) => runtime.lastReloginAt = value;

  bool get isRefreshingSource => runtime.isRefreshingSource;
  set isRefreshingSource(bool value) => runtime.isRefreshingSource = value;

  SourceRuntimeState get runtimeState => runtime.runtimeState;
  set runtimeState(SourceRuntimeState value) => runtime.runtimeState = value;

  String get statusText => runtime.statusText;
  set statusText(String value) => runtime.statusText = value;

  Future<void>? get initFuture => runtime.initFuture;
  set initFuture(Future<void>? value) => runtime.initFuture = value;

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

  Future<Directory> ensureImageCacheDir() => _ensureImageCacheDir();

  Future<int> computeImageCacheSizeBytes() => _computeImageCacheSizeBytes();

  Future<void> enforceImageCachePolicy({bool force = false}) {
    return _enforceImageCachePolicy(force: force);
  }

  Uri resolveImageBaseUri(String imageUrl, Uri baseUri) {
    final imageUri = Uri.tryParse(imageUrl);
    if (imageUri != null && imageUri.hasScheme && imageUri.host.isNotEmpty) {
      return imageUri;
    }
    return baseUri;
  }
}
