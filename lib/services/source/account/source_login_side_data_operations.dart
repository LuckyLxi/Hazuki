import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_host.dart';

class SourceLoginSideDataOperations {
  SourceLoginSideDataOperations({required SourceRuntimeHost runtimeHost})
    : _runtimeHost = runtimeHost;
  final SourceRuntimeHost _runtimeHost;
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
      if (entry.value is String && (entry.value as String).isNotEmpty) {
        await facade.saveSourceData(sourceKey, entry.key, entry.value);
      }
    }
  }

  Future<String?> loadCurrentAvatarUrl() async {
    final handle = _runtimeHost.optionalActiveHandle;
    if (handle == null) return null;
    await handle.facade.ensureInitialized();
    final engine = handle.runtime.engine;
    if (engine != null &&
        engine.evaluate(
              'typeof this.__hazuki_source.account?.loadProfile === "function"',
            ) ==
            true) {
      final result = await handle.facade.js.resolve(
        engine.evaluate('this.__hazuki_source.account.loadProfile()'),
      );
      await persistLoginSideData(
        handle.facade,
        sourceKey: handle.sourceKey,
        result: result,
      );
    }
    return handle.facade
        .loadSourceData(handle.sourceKey, 'avatar_url')
        ?.toString();
  }
}
