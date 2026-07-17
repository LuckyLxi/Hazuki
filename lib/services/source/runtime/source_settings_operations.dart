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
    final handle = _runtimeHost.activeHandle;
    return handle.facade.loadSourceSetting(handle.sourceKey, key);
  }

  Future<void> updateActiveSourceSetting(String key, dynamic value) {
    final handle = _runtimeHost.activeHandle;
    return handle.facade.saveSourceSetting(handle.sourceKey, key, value);
  }

  Object? loadSourceSetting(String sourceKey, String key) {
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
    return facade.ensurePrefs().then(
      (_) => facade.saveSourceSetting(resolvedSourceKey, key, value),
    );
  }

  Future<void> clearCopyMangaDeviceInfo() async {
    const sourceKey = 'copy_manga';
    final handle = _runtimeHost.handleFor(sourceKey);
    await handle.facade.deleteSourceData(sourceKey, '_deviceinfo');
    await handle.facade.deleteSourceData(sourceKey, '_device');
    await handle.facade.deleteSourceData(sourceKey, '_pseudoid');
    final engine = handle.runtime.engine;
    if (engine == null || _runtimeHost.activeSourceKey != sourceKey) return;
    final hasRefreshAppApi = handle.facade.js.asBool(
      engine.evaluate('!!this.__hazuki_source.refreshAppApi'),
    );
    if (hasRefreshAppApi) {
      final result = engine.evaluate(
        'this.__hazuki_source.refreshAppApi()',
        name: 'copy_manga_refresh_app_api.js',
      );
      await handle.facade.js.resolve(result);
    }
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
