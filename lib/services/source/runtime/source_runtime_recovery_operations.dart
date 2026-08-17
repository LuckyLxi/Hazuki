import '../account/source_relogin_coordinator.dart';
import '../models/source_contract_models.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_runtime_loader.dart';
import 'source_runtime_state_controller.dart';
import 'source_script_editing_operations.dart';

/// Owns manual source replacement and runtime recovery workflows.
class SourceRuntimeRecoveryOperations {
  SourceRuntimeRecoveryOperations({
    required SourceRuntimeHost runtimeHost,
    required SourceRuntimeLoadClient runtimeLoader,
    required SourceScriptEditingOperations scriptEditing,
    required SourceRuntimeStateController runtimeStateController,
    required SourceReloginCoordinator reloginCoordinator,
  }) : _runtimeHost = runtimeHost,
       _runtimeLoader = runtimeLoader,
       _scriptEditing = scriptEditing,
       _runtimeStateController = runtimeStateController,
       _reloginCoordinator = reloginCoordinator;

  final SourceRuntimeHost _runtimeHost;
  final SourceRuntimeLoadClient _runtimeLoader;
  final SourceScriptEditingOperations _scriptEditing;
  final SourceRuntimeStateController _runtimeStateController;
  final SourceReloginCoordinator _reloginCoordinator;

  Future<void> downloadSourceFile(
    String sourceKey, {
    void Function(int received, int total)? onProgress,
  }) async {
    final normalizedSourceKey = _runtimeHost.normalize(sourceKey);
    final handle = _runtimeHost.handleFor(normalizedSourceKey);
    await handle.runOperation(() async {
      final facade = handle.facade;
      _clearRuntimeCaches(handle, clearMetadata: false);
      final result = await _runtimeLoader.download(
        handle,
        onProgress: onProgress,
      );
      await _scriptEditing.setCustomEditedSourceFlag(
        handle.sourceKey,
        false,
        targetFacade: facade,
      );
      facade.lastSourceVersionDebugInfo = {
        'checkedAt': DateTime.now().toIso8601String(),
        'resolvedFrom': 'manual_source_download',
        'sourceKey': handle.sourceKey,
        'outcome': result.message,
      };
    });
    await _runtimeHost.activateSource(normalizedSourceKey);
  }

  Future<void> reloadFromLocalSourceFiles() async {
    final handle = _runtimeHost.activeHandle;
    await handle.runOperation(() async {
      final facade = handle.facade;
      if (facade.isRefreshingSource) {
        throw Exception('source_reload_in_progress');
      }
      facade.isRefreshingSource = true;
      try {
        _runtimeStateController.setBusy(
          facade,
          SourceRuntimePhase.loading,
          SourceRuntimeStep.loadingCache,
          statusText: 'source_reloading_from_local_restore',
          debugDetail: 'cloud_sync_restore',
        );
        _clearRuntimeCaches(handle, clearFavoritesDebugCache: true);
        final result = await _runtimeLoader.ensureLocalSource(handle);
        _runtimeStateController.setBusy(
          facade,
          SourceRuntimePhase.loading,
          SourceRuntimeStep.creatingEngine,
          debugDetail: 'creating_engine',
        );
        final meta = await _runtimeLoader.loadMetadata(
          handle,
          result.sourceFile,
        );
        facade.runtime.sourceMeta = meta;
        _runtimeStateController.setReady(
          facade,
          message: result.message,
          meta: meta,
        );
        await _reloginIfNeeded(handle);
      } finally {
        facade.isRefreshingSource = false;
      }
    });
  }

  Future<bool> refreshSourceOnNetworkRecovery() {
    final handle = _runtimeHost.activeHandle;
    return handle.runOperation(() => _refreshSource(handle));
  }

  Future<bool> _refreshSource(SourceRuntimeHandle handle) async {
    final facade = handle.facade;
    if (facade.isRefreshingSource) return false;
    facade.isRefreshingSource = true;
    try {
      _runtimeStateController.setBusy(
        facade,
        facade.runtimeState.hasFailure
            ? SourceRuntimePhase.retrying
            : SourceRuntimePhase.loading,
        SourceRuntimeStep.downloadingSource,
        statusText: 'source_refreshing_after_network_recovery',
        debugDetail: 'network_recovery',
      );
      _clearRuntimeCaches(
        handle,
        clearFavoritesDebugCache: true,
        clearMetadata: true,
      );
      final result = await _runtimeLoader.downloadOrLoad(handle);
      final meta = await _runtimeLoader.loadMetadata(handle, result.sourceFile);
      facade.runtime.sourceMeta = meta;
      _runtimeStateController.setReady(
        facade,
        message: result.message,
        meta: meta,
      );
      await _reloginIfNeeded(handle);
      return true;
    } catch (error) {
      _runtimeStateController.setFailed(facade, error);
      return false;
    } finally {
      facade.isRefreshingSource = false;
    }
  }

  void _clearRuntimeCaches(
    SourceRuntimeHandle handle, {
    bool clearFavoritesDebugCache = false,
    bool clearMetadata = false,
  }) {
    final facade = handle.facade;
    facade.lastReloginAt = null;
    if (clearFavoritesDebugCache) facade.favoritesDebugCache = null;
    handle.exploreCache.clearMemory();
    facade.cache.clearCategoryTagGroupsMemoryCache();
    if (clearMetadata) facade.runtime.sourceMeta = null;
  }

  Future<void> _reloginIfNeeded(SourceRuntimeHandle handle) async {
    final facade = handle.facade;
    if (_runtimeHost.activeSourceKey != handle.sourceKey || !facade.isLogged) {
      return;
    }
    await _reloginCoordinator.tryReloginFromStoredAccount(
      SourceFacadeReloginContext(facade),
      force: true,
    );
  }
}
