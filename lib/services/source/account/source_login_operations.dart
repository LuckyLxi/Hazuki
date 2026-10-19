import '../debug/debug_log_internals.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'source_login_script_factory.dart';
import 'source_login_side_data_operations.dart';

/// Coordinates account login while delegating source-specific implementation.
class SourceLoginOperations {
  SourceLoginOperations({required SourceRuntimeHost runtimeHost})
    : _runtimeHost = runtimeHost,
      _sideData = SourceLoginSideDataOperations(runtimeHost: runtimeHost);

  final SourceRuntimeHost _runtimeHost;
  final SourceLoginSideDataOperations _sideData;

  String? get cachedAvatarUrl => _sideData.cachedAvatarUrl;

  HazukiSourceFacade get facade => _runtimeHost.activeHandle.facade;

  Future<void> login({required String account, required String password}) =>
      loginWithFacade(facade, account: account, password: password);

  Future<void> loginWithFacade(
    HazukiSourceFacade facade, {
    required String account,
    required String password,
  }) async {
    await facade.ensureInitialized();

    if (facade.loadSourceData(facade.sourceKey, 'interactive_login') == true) {
      throw StateError('login_interaction_required');
    }
    final engine = facade.js.engine;
    final sourceMeta = facade.sourceMeta;
    if (engine == null || sourceMeta == null) {
      throw Exception('source_not_initialized');
    }

    final supportsAccount = facade.js.asBool(
      facade.js.evaluate('!!this.__hazuki_source.account?.login'),
    );
    if (!supportsAccount) {
      throw Exception('account_login_not_supported');
    }

    final script = const SourceLoginScriptFactory().generic(
      account: account,
      password: password,
    );
    final startedAt = DateTime.now();
    dynamic resolvedResult;

    try {
      final result = engine.evaluate(script.code, name: script.name);
      resolvedResult = await facade.js.resolve(result);
      await _sideData.persistLoginSideData(
        facade,
        sourceKey: sourceMeta.key,
        result: resolvedResult,
      );
      _recordLoginDebugInfo(
        facade,
        account: account,
        startedAt: startedAt,
        result: resolvedResult,
      );
      _recordLoginNetworkEntry(
        facade,
        account: account,
        startedAt: startedAt,
        result: resolvedResult,
      );
      await facade.saveSourceData(sourceMeta.key, 'account', [
        account,
        password,
      ]);
      await facade.saveSourceData(
        sourceMeta.key,
        'login_session',
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
    } catch (error) {
      _recordLoginDebugInfo(
        facade,
        account: account,
        startedAt: startedAt,
        result: resolvedResult,
        error: error,
      );
      _recordLoginNetworkEntry(
        facade,
        account: account,
        startedAt: startedAt,
        result: resolvedResult,
        error: error,
      );
      throw Exception('login_failed:$error');
    }
  }

  void _recordLoginDebugInfo(
    HazukiSourceFacade facade, {
    required String account,
    required DateTime startedAt,
    required dynamic result,
    Object? error,
  }) {
    facade.lastLoginDebugInfo = {
      'time': DateTime.now().toIso8601String(),
      'ok': error == null,
      'account': account,
      'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
      if (error != null) 'error': error.toString(),
      'result': jsonSafe(result),
    };
  }

  void _recordLoginNetworkEntry(
    HazukiSourceFacade facade, {
    required String account,
    required DateTime startedAt,
    required dynamic result,
    Object? error,
  }) {
    facade.networkLogSink.append(
      method: 'LOGIN',
      url: 'source://account.login',
      statusCode: error == null ? 200 : null,
      error: error?.toString(),
      startedAt: startedAt,
      source: 'source_login',
      requestHeaders: const {},
      requestData: {'account': account},
      responseHeaders: const {},
      responseBody: jsonSafe(result),
    );
  }

  Future<String?> loadCurrentAvatarUrl() => _sideData.loadCurrentAvatarUrl();
}
