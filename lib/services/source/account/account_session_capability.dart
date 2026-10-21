import '../runtime/source_runtime_handle.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'source_login_operations.dart';
import 'source_login_interaction.dart';

/// Owns account session state and delegates source-specific login workflows.
class SourceAccountSessionCapability {
  SourceAccountSessionCapability({required SourceRuntimeHost runtimeHost})
    : _runtimeHost = runtimeHost,
      _loginOperations = SourceLoginOperations(runtimeHost: runtimeHost);

  final SourceRuntimeHost _runtimeHost;
  final SourceLoginOperations _loginOperations;
  SourceInteractiveAccountGateway? interactive;

  HazukiSourceFacade get facade => _runtimeHost.activeHandle.facade;

  String? get cachedAvatarUrl => _loginOperations.cachedAvatarUrl;

  String? get currentAccount {
    if (!_runtimeHost.hasActiveSource) return null;
    final sourceKey = facade.sourceMeta?.key ?? facade.sourceKey;
    final displayName = facade
        .loadSourceData(sourceKey, 'display_name')
        ?.toString()
        .trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    final accountData = facade.loadAccountDataSync();
    if (accountData == null || accountData.isEmpty) {
      return null;
    }
    return accountData.first;
  }

  bool get isLogged =>
      _runtimeHost.hasActiveSource &&
      (facade.loadAccountDataSync() != null ||
          facade.loadSourceData(facade.sourceKey, 'login_session') is String);

  Future<void> login({
    required String account,
    required String password,
    SourceTaskOrigin? taskOrigin,
  }) => _loginOperations.login(
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
  }) => _loginOperations.loginWithFacade(
    facade,
    account: account,
    password: password,
    taskOrigin: taskOrigin,
    serviceOwned: serviceOwned,
  );

  Future<void> logout({SourceTaskOrigin? taskOrigin}) async =>
      runSourceOperation(
        _runtimeHost,
        _runtimeHost.activeHandle,
        'account.logout',
        (operationContext) => _logoutTask(operationContext),
        origin: taskOrigin,
        serviceOwned: true,
      );

  Future<void> _logoutTask(SourceOperationContext operationContext) async {
    interactive?.cancelPendingLogin();
    final facade = (operationContext.resource as SourceRuntimeHandle).facade;
    return facade.handle.runOperation(() async {
      final engine = facade.js.engine;
      final sourceMeta = facade.sourceMeta;
      final sourceKey = (sourceMeta?.key ?? facade.sourceKey).trim();

      if (engine != null && sourceMeta != null) {
        final hasLogout = facade.js.asBool(
          await operationContext.evaluate(
            engine,
            '!!this.__hazuki_source.account?.logout',
          ),
        );

        if (hasLogout) {
          try {
            final result = await operationContext.evaluate(
              engine,
              'this.__hazuki_source.account.logout()',
              name: 'source_logout.js',
            );
            await operationContext.resolve(facade.js.resolve(result));
          } catch (error) {
            rethrowSourceOperationStop(error);
          }
        }
      }

      if (sourceKey.isEmpty) return;

      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'account'),
      );
      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'avatar_url'),
      );
      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'display_name'),
      );
      await operationContext.commit(() => facade.saveCookieStore(const []));
      facade.runtime.transientAvatarUrl = null;
      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'token'),
      );
      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'interactive_login'),
      );
      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'login_method'),
      );
      await operationContext.commit(
        () => facade.deleteSourceData(sourceKey, 'login_session'),
      );
      _runtimeHost.notifyActiveRuntimeChanged(sourceKey);
    });
  }

  String? currentAccountForSource(String sourceKey) {
    if (!_runtimeHost.runtimeRegistry.isAllowedSourceKey(sourceKey)) {
      return null;
    }
    final handle = _runtimeHost.handleFor(sourceKey);
    final displayName = handle.session
        .loadSourceData(handle.sourceKey, 'display_name')
        ?.toString()
        .trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final account = handle.session.loadAccountDataSync(
      handle.runtime.sourceMeta,
      fallbackSourceKey: handle.sourceKey,
    );
    return account == null || account.isEmpty ? null : account.first;
  }

  bool isLoggedForSource(String sourceKey) {
    if (!_runtimeHost.runtimeRegistry.isAllowedSourceKey(sourceKey)) {
      return false;
    }
    final handle = _runtimeHost.handleFor(sourceKey);
    return handle.session.loadSourceData(sourceKey, 'login_session')
            is String ||
        handle.session.loadAccountDataSync(
              handle.runtime.sourceMeta,
              fallbackSourceKey: handle.sourceKey,
            ) !=
            null;
  }

  Future<String?> loadCurrentAvatarUrl({SourceTaskOrigin? taskOrigin}) =>
      _runtimeHost.hasActiveSource
      ? _loginOperations.loadCurrentAvatarUrl(taskOrigin: taskOrigin)
      : Future.value(null);
}
