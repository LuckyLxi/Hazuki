import 'dart:convert';
import 'source_runtime_host.dart';

/// Active-source settings and runtime line configuration operations.
class SourceSettingsOperations {
  const SourceSettingsOperations(this._runtimeHost);

  final SourceRuntimeHost _runtimeHost;

  Future<Map<String, dynamic>> getLineSettingsSnapshot() =>
      _runtimeHost.activeHandle.lineSettings.getSnapshot();

  Future<void> updateLineSetting(String key, dynamic value) =>
      _runtimeHost.activeHandle.lineSettings.updateSetting(key, value);

  Object? loadActiveSourceSetting(String key) {
    final handle = _runtimeHost.optionalActiveHandle;
    if (handle == null) return null;
    return handle.facade.loadSourceSetting(handle.sourceKey, key);
  }

  Future<void> updateActiveSourceSetting(String key, dynamic value) {
    final handle = _runtimeHost.activeHandle;
    return handle.facade.saveSourceSetting(handle.sourceKey, key, value);
  }

  Object? loadSourceSetting(String sourceKey, String key) {
    if (!_runtimeHost.runtimeRegistry.isAllowedSourceKey(
      sourceKey.isEmpty ? _runtimeHost.activeSourceKey : sourceKey,
    )) {
      return null;
    }
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    return _runtimeHost
        .handleFor(resolvedSourceKey)
        .facade
        .loadSourceSetting(resolvedSourceKey, key);
  }

  Future<void> updateSourceSetting(
    String sourceKey,
    String key,
    dynamic value,
  ) {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final facade = _runtimeHost.handleFor(resolvedSourceKey).facade;
    return facade.handle.runOperation(() async {
      await facade.ensurePrefs();
      await facade.saveSourceSetting(resolvedSourceKey, key, value);
      final engine = facade.js.engine;
      if (engine != null) {
        await facade.js.resolve(
          engine.evaluate(
            'this.__hazuki_source.settings?.[${jsonEncode(key)}]?.onChanged?.(${jsonEncode(value)})',
          ),
        );
      }
      facade.cache.clearMemory();
    });
  }

  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) => _runtimeHost.activeHandle.lineSettings.refresh(
    refreshApiDomains: refreshApiDomains,
    refreshImageHost: refreshImageHost,
  );

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);
}
