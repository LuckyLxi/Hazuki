import 'dart:convert';
import 'source_local_runtime_operations.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';

/// Active-source settings and runtime line configuration operations.
class SourceSettingsOperations {
  const SourceSettingsOperations(this._runtimeHost, {this.localRuntime});

  final SourceRuntimeHost _runtimeHost;
  final SourceLocalRuntimeOperations? localRuntime;

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
  ) => _updateSourceSetting(
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    key,
    value,
  );

  /// Plugin controls retain their callbacks even before network initialization.
  Future<void> updatePluginSetting(
    String sourceKey,
    String key,
    dynamic value,
  ) {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final handle = _runtimeHost.handleFor(resolvedSourceKey);
    final local = localRuntime;
    if (local != null) {
      return local.run(resolvedSourceKey, (localHandle) async {
        await _updateSourceSetting(localHandle, key, value);
        handle.cache.clearMemory();
      });
    }
    return _updateSourceSetting(handle, key, value);
  }

  Future<void> _updateSourceSetting(
    SourceRuntimeHandle handle,
    String key,
    dynamic value,
  ) {
    final facade = handle.facade;
    return facade.handle.runOperation(() async {
      await facade.ensurePrefs();
      await facade.saveSourceSetting(handle.sourceKey, key, value);
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
