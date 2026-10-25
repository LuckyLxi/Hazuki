import '../account/source_relogin_coordinator.dart';
import '../plugins/source_plugin_manager.dart';
import 'source_js_bridge_cookie_capability.dart';
import 'source_local_runtime_operations.dart';
import 'source_runtime_diagnostics_operations.dart';
import 'source_runtime_host.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_initialization_operations.dart';
import 'source_runtime_loader.dart';
import 'source_runtime_recovery_operations.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_editing_operations.dart';
import 'source_update_operations.dart';

/// Assembles the focused operations that make up the source runtime.
class SourceRuntimeCapability {
  SourceRuntimeCapability({
    required SourceRuntimeHost runtimeHost,
    required SourcePluginManager scriptStorage,
    required SourceJsBridgeCookieCapability jsBridgeCookieCapability,
    required SourceRuntimeStateController runtimeStateController,
    required SourceReloginCoordinator reloginCoordinator,
    required String bundledInitAssetPath,
  }) : _runtimeHost = runtimeHost,
       _scriptStorage = scriptStorage,
       _jsBridgeCookieCapability = jsBridgeCookieCapability,
       _runtimeStateController = runtimeStateController,
       _reloginCoordinator = reloginCoordinator,
       _bundledInitAssetPath = bundledInitAssetPath;

  final SourceRuntimeHost _runtimeHost;

  Future<void> loadLoginRuntime(SourceRuntimeHandle handle) async {
    await handle.facade.ensurePrefs();
    _jsBridgeCookieCapability.configureDioCookieBridge(handle);
    final file = await _scriptStorage.sourceFileFor(handle.sourceKey);
    await _runtimeLoader.loadMetadata(handle, file);
  }

  final SourcePluginManager _scriptStorage;
  final SourceJsBridgeCookieCapability _jsBridgeCookieCapability;
  final SourceRuntimeStateController _runtimeStateController;
  final SourceReloginCoordinator _reloginCoordinator;
  final String _bundledInitAssetPath;

  late final SourceScriptEditingOperations scriptEditing =
      SourceScriptEditingOperations(
        runtimeHost: _runtimeHost,
        storage: _scriptStorage,
        runtimeStateController: _runtimeStateController,
        ensureEditableFile: (handle) async =>
            (await _runtimeLoader.downloadOrLoad(handle)).sourceFile,
      );
  late final SourceUpdateOperations sourceUpdates = SourceUpdateOperations(
    runtimeHost: _runtimeHost,
    plugins: _scriptStorage,
  );
  late final SourceRuntimeLoader _runtimeLoader = SourceRuntimeLoader(
    scriptStore: _scriptStorage,
    jsBridge: _jsBridgeCookieCapability,
    runtimeStateController: _runtimeStateController,
    bundledInitAssetPath: _bundledInitAssetPath,
  );
  late final SourceRuntimeInitializationOperations initialization =
      SourceRuntimeInitializationOperations(
        runtimeHost: _runtimeHost,
        runtimeLoader: _runtimeLoader,
        jsBridgeCookieCapability: _jsBridgeCookieCapability,
        runtimeStateController: _runtimeStateController,
      );
  late final SourceLocalRuntimeOperations localRuntime =
      SourceLocalRuntimeOperations(
        runtimeHost: _runtimeHost,
        scriptStore: _scriptStorage,
        runtimeLoader: _runtimeLoader,
        jsBridge: _jsBridgeCookieCapability,
      );
  late final SourceRuntimeDiagnosticsOperations diagnostics =
      SourceRuntimeDiagnosticsOperations(runtimeHost: _runtimeHost);
  late final SourceRuntimeRecoveryOperations sourceRecovery =
      SourceRuntimeRecoveryOperations(
        runtimeHost: _runtimeHost,
        plugins: _scriptStorage,
        runtimeLoader: _runtimeLoader,
        scriptEditing: scriptEditing,
        runtimeStateController: _runtimeStateController,
        reloginCoordinator: _reloginCoordinator,
      );
}
