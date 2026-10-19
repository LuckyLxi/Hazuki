import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';

class SourceLoginSideDataOperations {
  SourceLoginSideDataOperations({
    required SourceRuntimeHost runtimeHost,
    Duration profileLoadTimeout = const Duration(seconds: 15),
  }) : _runtimeHost = runtimeHost,
       _profileLoadTimeout = profileLoadTimeout;
  final SourceRuntimeHost _runtimeHost;
  final Duration _profileLoadTimeout;
  final _profileLoads =
      <SourceRuntimeHandle, ({String? identity, Future<String?> future})>{};

  String? get cachedAvatarUrl {
    final handle = _runtimeHost.optionalActiveHandle;
    return handle == null ? null : _cachedAvatarUrl(handle.facade);
  }

  String? _cachedAvatarUrl(HazukiSourceFacade facade) {
    final stored = facade
        .loadSourceData(facade.sourceKey, 'avatar_url')
        ?.toString()
        .trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final transient = facade.runtime.transientAvatarUrl?.trim();
    return transient == null || transient.isEmpty ? null : transient;
  }

  Future<void> persistLoginSideData(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required dynamic result,
  }) async {
    if (result is! Map) return;
    if (result['avatarUrl'] is String) {
      facade.runtime.transientAvatarUrl = (result['avatarUrl'] as String)
          .trim();
    }
    for (final entry in {
      'token': result['token'],
      'avatar_url': result['avatarUrl'],
      'display_name': result['displayName'],
    }.entries) {
      if (entry.value is String && (entry.value as String).trim().isNotEmpty) {
        await facade.saveSourceData(
          sourceKey,
          entry.key,
          (entry.value as String).trim(),
        );
      }
    }
  }

  Future<String?> loadCurrentAvatarUrl() async {
    final handle = _runtimeHost.optionalActiveHandle;
    if (handle == null) return null;
    final identity = handle.session.loginIdentity;
    final pending = _profileLoads[handle];
    if (pending != null && pending.identity == identity) return pending.future;
    final future = _loadProfile(handle, identity);
    _profileLoads[handle] = (identity: identity, future: future);
    try {
      return await future;
    } finally {
      if (identical(_profileLoads[handle]?.future, future)) {
        _profileLoads.remove(handle);
      }
    }
  }

  Future<String?> _loadProfile(
    SourceRuntimeHandle handle,
    String? identity,
  ) async {
    final facade = handle.facade;
    try {
      final result = await (() async {
        await facade.ensureInitialized();
        final engine = handle.runtime.engine;
        if (engine == null ||
            engine.evaluate(
                  'typeof this.__hazuki_source.account?.loadProfile === "function"',
                ) !=
                true) {
          return null;
        }
        return facade.js.resolve(
          engine.evaluate('this.__hazuki_source.account.loadProfile()'),
        );
      })().timeout(_profileLoadTimeout);
      // A completed request must not restore a profile after logout or runtime
      // replacement. Timed-out requests never reach this persistence step.
      if (!_runtimeHost.isCurrentHandle(handle) ||
          handle.session.loginIdentity != identity) {
        return null;
      }
      await persistLoginSideData(
        facade,
        sourceKey: handle.sourceKey,
        result: result,
      );
    } catch (_) {
      // Profile refresh is optional; keep the last successfully saved profile.
    }
    if (!_runtimeHost.isCurrentHandle(handle) ||
        handle.session.loginIdentity != identity) {
      return null;
    }
    return _cachedAvatarUrl(facade);
  }
}
