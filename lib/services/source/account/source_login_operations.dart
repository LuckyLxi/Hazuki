import '../runtime/source_runtime_handle.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
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

  Future<void> login({
    required String account,
    required String password,
    SourceTaskOrigin? taskOrigin,
  }) => loginWithFacade(
    facade,
    account: account,
    password: password,
    taskOrigin: taskOrigin,
  );

  Future<void> loginWithFacade(
    HazukiSourceFacade facade, {
    required String account,
    required String password,
    SourceTaskOrigin? taskOrigin,
    bool serviceOwned = false,
  }) async => runSourceOperation(
    _runtimeHost,
    facade.handle as SourceRuntimeHandle,
    'account.login',
    (operationContext) => _loginWithFacadeTask(
      operationContext,
      facade,
      account: account,
      password: password,
    ),
    origin: taskOrigin,
    sensitiveValues: [account, password],
    serviceOwned: serviceOwned,
  );

  Future<void> _loginWithFacadeTask(
    SourceOperationContext operationContext,
    HazukiSourceFacade facade, {
    required String account,
    required String password,
  }) async {
    return facade.handle.runOperation(() async {
      await facade.ensureInitialized();

      if (facade.loadSourceData(facade.sourceKey, 'interactive_login') ==
          true) {
        throw StateError('login_interaction_required');
      }
      final engine = facade.js.engine;
      final sourceMeta = facade.sourceMeta;
      if (engine == null || sourceMeta == null) {
        throw Exception('source_not_initialized');
      }

      final supportsAccount = facade.js.asBool(
        await operationContext.evaluate(
          engine,
          '!!this.__hazuki_source.account?.login',
        ),
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
        final result = await operationContext.evaluate(
          engine,
          script.code,
          name: script.name,
        );
        resolvedResult = await operationContext.resolve(
          facade.js.resolve(result),
        );
        await _sideData.persistLoginSideData(
          facade,
          sourceKey: sourceMeta.key,
          result: resolvedResult,
          checkActive: operationContext.checkActive,
          commit: (write) => operationContext.commit(write),
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
        await operationContext.commit(
          () => facade.saveSourceData(sourceMeta.key, 'account', [
            account,
            password,
          ]),
        );
        await operationContext.commit(
          () => facade.saveSourceData(
            sourceMeta.key,
            'login_session',
            DateTime.now().microsecondsSinceEpoch.toString(),
          ),
        );
      } catch (error) {
        rethrowSourceOperationStop(error);
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
    });
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

  Future<String?> loadCurrentAvatarUrl({SourceTaskOrigin? taskOrigin}) =>
      _sideData.loadCurrentAvatarUrl(taskOrigin: taskOrigin);
}
