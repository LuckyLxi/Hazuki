import '../account/source_relogin_coordinator.dart';
import 'source_catalog_resolver.dart';
import 'source_js_bridge_cookie_capability.dart';
import 'source_runtime_diagnostics_operations.dart';
import 'source_runtime_host.dart';
import 'source_runtime_initialization_operations.dart';
import 'source_runtime_loader.dart';
import 'source_runtime_recovery_operations.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_editing_operations.dart';
import 'source_script_storage.dart';
import 'source_text_downloader.dart';
import 'source_update_operations.dart';

/// Assembles the focused operations that make up the source runtime.
class SourceRuntimeCapability {
  SourceRuntimeCapability({
    required SourceRuntimeHost runtimeHost,
    required SourceScriptStore scriptStorage,
    required SourceJsBridgeCookieCapability jsBridgeCookieCapability,
    required SourceRuntimeStateController runtimeStateController,
    required SourceReloginCoordinator reloginCoordinator,
    required String bundledInitAssetPath,
    required List<String> sourceIndexUrls,
  }) : _runtimeHost = runtimeHost,
       _scriptStorage = scriptStorage,
       _jsBridgeCookieCapability = jsBridgeCookieCapability,
       _runtimeStateController = runtimeStateController,
       _reloginCoordinator = reloginCoordinator,
       _bundledInitAssetPath = bundledInitAssetPath,
       _sourceIndexUrls = sourceIndexUrls;

  final SourceRuntimeHost _runtimeHost;
  final SourceScriptStore _scriptStorage;
  final SourceJsBridgeCookieCapability _jsBridgeCookieCapability;
  final SourceRuntimeStateController _runtimeStateController;
  final SourceReloginCoordinator _reloginCoordinator;
  final String _bundledInitAssetPath;
  final List<String> _sourceIndexUrls;

  late final SourceScriptEditingOperations scriptEditing =
      SourceScriptEditingOperations(
        runtimeHost: _runtimeHost,
        storage: _scriptStorage,
        runtimeStateController: _runtimeStateController,
        ensureEditableFile: (handle) async =>
            (await _runtimeLoader.downloadOrLoad(handle)).sourceFile,
      );
  final SourceTextDownloader _textDownloader = const SourceTextDownloader();
  late final SourceCatalogResolver _catalogResolver = SourceCatalogResolver(
    runtimeHost: _runtimeHost,
    downloader: _textDownloader,
    sourceIndexUrls: _sourceIndexUrls,
  );
  late final SourceUpdateOperations sourceUpdates = SourceUpdateOperations(
    runtimeHost: _runtimeHost,
    scriptStore: _scriptStorage,
    scriptEditing: scriptEditing,
    runtimeStateController: _runtimeStateController,
    downloader: _textDownloader,
    urlResolver: _catalogResolver,
    sourceIndexUrls: _sourceIndexUrls,
  );
  late final SourceRuntimeLoader _runtimeLoader = SourceRuntimeLoader(
    scriptStore: _scriptStorage,
    catalogResolver: _catalogResolver,
    downloader: _textDownloader,
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
  late final SourceRuntimeDiagnosticsOperations diagnostics =
      SourceRuntimeDiagnosticsOperations(runtimeHost: _runtimeHost);
  late final SourceRuntimeRecoveryOperations sourceRecovery =
      SourceRuntimeRecoveryOperations(
        runtimeHost: _runtimeHost,
        runtimeLoader: _runtimeLoader,
        scriptEditing: scriptEditing,
        runtimeStateController: _runtimeStateController,
        reloginCoordinator: _reloginCoordinator,
      );
}
