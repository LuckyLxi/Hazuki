import 'source_operation_context.dart';
import 'source_operation_runner.dart';
import '../models/source_task.dart';
import 'dart:convert';
import 'source_local_runtime_operations.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';

/// Active-source settings and runtime line configuration operations.
class SourceSettingsOperations {
  const SourceSettingsOperations(this._runtimeHost, {this.localRuntime});

  final SourceRuntimeHost _runtimeHost;
  final SourceLocalRuntimeOperations? localRuntime;

  Future<Map<String, dynamic>> getLineSettingsSnapshot({
    SourceTaskOrigin? taskOrigin,
  }) {
    final handle = _runtimeHost.activeHandle;
    return runSourceOperation(
      _runtimeHost,
      handle,
      'settings.lines',
      (context) => handle.lineSettings.getSnapshot(operationContext: context),
      origin: taskOrigin,
    );
  }

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
    dynamic value, {
    SourceTaskOrigin? taskOrigin,
  }) => _runSetting(
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    key,
    value,
    origin: taskOrigin,
  );

  /// Plugin controls retain their callbacks even before network initialization.
  Future<void> updatePluginSetting(
    String sourceKey,
    String key,
    dynamic value, {
    SourceTaskOrigin? taskOrigin,
  }) {
    final resolvedSourceKey = _resolveSourceKey(sourceKey);
    final handle = _runtimeHost.handleFor(resolvedSourceKey);
    return runSourceOperation(
      _runtimeHost,
      handle,
      'settings.pluginChanged',
      (context) async {
        final local = localRuntime;
        if (local != null) {
          await local.run(
            resolvedSourceKey,
            (localHandle) =>
                _updateSourceSetting(localHandle, key, value, context),
          );
          context.checkActive();
          if (context.canCache()) handle.cache.clearMemory();
        } else {
          await _updateSourceSetting(handle, key, value, context);
        }
      },
      origin: taskOrigin,
      serviceOwned: true,
      sensitiveValues: [if (value is String) value],
    );
  }

  Future<void> _runSetting(
    SourceRuntimeHandle handle,
    String key,
    dynamic value, {
    SourceTaskOrigin? origin,
  }) => runSourceOperation(
    _runtimeHost,
    handle,
    'settings.changed',
    (context) => _updateSourceSetting(handle, key, value, context),
    origin: origin,
    serviceOwned: true,
    sensitiveValues: [if (value is String) value],
  );

  Future<void> _updateSourceSetting(
    SourceRuntimeHandle handle,
    String key,
    dynamic value,
    SourceOperationContext context,
  ) {
    final facade = handle.facade;
    return facade.handle.runOperation(() async {
      await facade.ensurePrefs();
      await context.commit(
        () => facade.saveSourceSetting(handle.sourceKey, key, value),
      );
      final engine = facade.js.engine;
      if (engine != null) {
        await facade.js.resolve(
          context.evaluate(
            engine,
            'this.__hazuki_source.settings?.[${jsonEncode(key)}]?.onChanged?.(${jsonEncode(value)})',
          ),
        );
      }
      context.checkActive();
      if (context.canCache()) facade.cache.clearMemory();
    });
  }

  Future<void> refreshLines({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
    SourceTaskOrigin? taskOrigin,
  }) {
    final handle = _runtimeHost.activeHandle;
    return runSourceOperation(
      _runtimeHost,
      handle,
      'settings.refreshLines',
      (context) => handle.lineSettings.refresh(
        refreshApiDomains: refreshApiDomains,
        refreshImageHost: refreshImageHost,
        operationContext: context,
      ),
      origin: taskOrigin,
      serviceOwned: true,
    );
  }

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);
}
