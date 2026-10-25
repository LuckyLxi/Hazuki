import '../models/source_contract_models.dart';
import 'source_runtime_host.dart';
import '../plugins/source_plugin_manager.dart';

/// Owns version checks and online updates for the active source plugin.
class SourceUpdateOperations {
  SourceUpdateOperations({
    required SourceRuntimeHost runtimeHost,
    required SourcePluginManager plugins,
  }) : _runtimeHost = runtimeHost,
       _plugins = plugins;

  final SourceRuntimeHost _runtimeHost;
  final SourcePluginManager _plugins;

  Future<SourceVersionCheckResult?> checkActiveSourceVersion() async {
    if (!_runtimeHost.hasActiveSource) return null;
    final id = _runtimeHost.activeSourceKey;
    final update = await _plugins.checkUpdate(id);
    final plugin = _plugins.pluginFor(id);
    if (update == null || plugin == null) return null;
    return SourceVersionCheckResult(
      sourceKey: id,
      sourceName: plugin.manifest.name,
      localVersion: plugin.manifest.version,
      remoteVersion: update.version,
      hasUpdate: true,
    );
  }

  Future<bool> downloadActiveSource({
    void Function(int received, int total)? onProgress,
  }) {
    if (!_runtimeHost.hasActiveSource) return Future.value(false);
    return _plugins.redownload(_runtimeHost.activeSourceKey);
  }
}
