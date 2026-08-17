import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';
import 'source_login_operations.dart';

/// Owns account session state and delegates source-specific login workflows.
class SourceAccountSessionCapability {
  SourceAccountSessionCapability({required SourceRuntimeHost runtimeHost})
    : _runtimeHost = runtimeHost,
      _loginOperations = SourceLoginOperations(runtimeHost: runtimeHost);

  final SourceRuntimeHost _runtimeHost;
  final SourceLoginOperations _loginOperations;

  HazukiSourceFacade get facade => _runtimeHost.activeHandle.facade;

  String? get currentAccount {
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

  bool get isLogged => facade.loadAccountDataSync() != null;

  Future<void> login({required String account, required String password}) =>
      _loginOperations.login(account: account, password: password);

  Future<void> loginWithFacade(
    HazukiSourceFacade facade, {
    required String account,
    required String password,
  }) => _loginOperations.loginWithFacade(
    facade,
    account: account,
    password: password,
  );

  Future<void> logout() async {
    final facade = this.facade;
    final engine = facade.js.engine;
    final sourceMeta = facade.sourceMeta;
    final sourceKey = (sourceMeta?.key ?? facade.sourceKey).trim();

    if (engine != null && sourceMeta != null) {
      final hasLogout = facade.js.asBool(
        facade.js.evaluate('!!this.__hazuki_source.account?.logout'),
      );

      if (hasLogout) {
        try {
          final result = engine.evaluate(
            'this.__hazuki_source.account.logout()',
            name: 'source_logout.js',
          );
          await facade.js.resolve(result);
        } catch (_) {}
      }
    }

    if (sourceKey.isEmpty) return;

    await facade.deleteSourceData(sourceKey, 'account');
    await facade.deleteSourceData(sourceKey, 'avatar_url');
    await facade.deleteSourceData(sourceKey, 'display_name');
    await facade.saveCookieStore(const []);
    facade.runtime.transientAvatarUrl = null;
    await facade.deleteSourceData(sourceKey, 'token');
  }

  String? currentAccountForSource(String sourceKey) {
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
    final handle = _runtimeHost.handleFor(sourceKey);
    return handle.session.loadAccountDataSync(
          handle.runtime.sourceMeta,
          fallbackSourceKey: handle.sourceKey,
        ) !=
        null;
  }

  Future<String?> loadCurrentAvatarUrl() =>
      _loginOperations.loadCurrentAvatarUrl();
}
