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
  final SourceLoginScriptFactory _scriptFactory =
      const SourceLoginScriptFactory();

  HazukiSourceFacade get facade => _runtimeHost.activeHandle.facade;

  Future<void> login({required String account, required String password}) =>
      loginWithFacade(facade, account: account, password: password);

  Future<void> loginWithFacade(
    HazukiSourceFacade facade, {
    required String account,
    required String password,
  }) async {
    await facade.ensureInitialized();

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

    final script = _scriptFactory.build(
      sourceKey: sourceMeta.key,
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
      _sideData.logPicacgLoginResponseTrace(
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
    } catch (error) {
      _sideData.logPicacgLoginResponseTrace(
        facade,
        sourceKey: sourceMeta.key,
        result: resolvedResult,
        error: error.toString(),
      );
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
