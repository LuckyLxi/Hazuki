import 'source_js_bridge_cookie_capability.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_loader.dart';
import 'source_script_storage.dart';

/// Provides settings access without waiting for a source's network startup.
class SourceLocalRuntimeOperations {
  const SourceLocalRuntimeOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceScriptStore scriptStore,
    required SourceRuntimeLoader runtimeLoader,
    required SourceJsBridgeCookieCapability jsBridge,
  }) : _runtimeHost = runtimeHost,
       _scriptStore = scriptStore,
       _runtimeLoader = runtimeLoader,
       _jsBridge = jsBridge;

  final SourceRuntimeHost _runtimeHost;
  final SourceScriptStore _scriptStore;
  final SourceRuntimeLoader _runtimeLoader;
  final SourceJsBridgeCookieCapability _jsBridge;

  Future<T> run<T>(
    String sourceKey,
    Future<T> Function(SourceRuntimeHandle handle) operation,
  ) {
    final handle = _runtimeHost.handleFor(sourceKey);
    return handle.runOperation(() async {
      await handle.facade.ensurePrefs();
      if (handle.runtime.engine != null && handle.runtime.sourceMeta != null) {
        return operation(handle);
      }

      // Keep local access separate so normal content requests still run init.
      final local = SourceRuntimeHandle(
        sourceKey: handle.sourceKey,
        secureStorage: handle.secureStorage,
        ensureInitialized: (_) async {},
        notifyRuntimeStateChanged: (_) {},
        appLogStore: handle.appLogStore,
      )..pluginDirectory = handle.pluginDirectory;
      try {
        await local.facade.ensurePrefs();
        _jsBridge.configureDioCookieBridge(local);
        final file = await _scriptStore.ensureLocalSourceFile(handle.sourceKey);
        await _runtimeLoader.loadLocalMetadata(local, file);
        return await operation(local);
      } finally {
        local.requestDispose();
      }
    });
  }
}
