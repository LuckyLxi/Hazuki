import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_exception.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_recovery_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_editing_operations.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;
  late _FakeRuntimeLoader loader;
  late _FakePluginManager plugins;
  late SourceRuntimeRecoveryOperations recovery;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    late SourceRuntimeHost runtimeHost;
    runtimeHost = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'jm', name: 'JMComic', fileName: 'jm.js'),
        SourceCatalogEntry(
          key: 'copy_manga',
          name: 'CopyManga',
          fileName: 'copy_manga.js',
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    host = runtimeHost;
    loader = _FakeRuntimeLoader();
    plugins = _FakePluginManager();
    final stateController = SourceRuntimeStateController();
    recovery = SourceRuntimeRecoveryOperations(
      runtimeHost: host,
      plugins: plugins,
      runtimeLoader: loader,
      scriptEditing: SourceScriptEditingOperations(
        runtimeHost: host,
        storage: plugins,
        runtimeStateController: stateController,
        ensureEditableFile: (_) => throw UnsupportedError('not used'),
      ),
      runtimeStateController: stateController,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {},
      ),
    );
    addTearDown(host.dispose);
  });

  test(
    'manual download reinstalls the plugin, activates it and clears edit state',
    () async {
      plugins.edited['copy_manga'] = true;

      await recovery.downloadSourceFile('copy_manga');

      expect(plugins.redownloadedIds, ['copy_manga']);
      expect(host.activeSourceKey, 'copy_manga');
      expect(plugins.edited['copy_manga'], isFalse);
    },
  );

  test('manual download rejects plugins without a repository', () async {
    plugins.hasRepository = false;

    await expectLater(
      recovery.downloadSourceFile('copy_manga'),
      throwsA(
        isA<SourcePluginException>().having(
          (error) => error.code,
          'code',
          'plugin_not_installed',
        ),
      ),
    );
    expect(host.activeSourceKey, 'jm');
  });

  test('local restore rebuilds the engine and publishes ready state', () async {
    await recovery.reloadFromLocalSourceFiles();

    expect(loader.localSourceKeys, ['jm']);
    expect(loader.metadataSourceKeys, ['jm']);
    expect(
      host.activeHandle.facade.runtimeState.phase,
      SourceRuntimePhase.ready,
    );
    expect(host.activeHandle.facade.statusText, contains('JMComic'));
    expect(host.activeHandle.facade.isRefreshingSource, isFalse);
  });

  test('network recovery ignores a refresh already in progress', () async {
    host.activeHandle.facade.isRefreshingSource = true;

    expect(await recovery.refreshSourceOnNetworkRecovery(), isFalse);
    expect(loader.downloadOrLoadSourceKeys, isEmpty);
  });
}

class _FakeRuntimeLoader implements SourceRuntimeLoadClient {
  final localSourceKeys = <String>[];
  final downloadOrLoadSourceKeys = <String>[];
  final metadataSourceKeys = <String>[];
  final sourceFile = File('unused-source.js');

  @override
  Future<SourceRuntimeLoadResult> downloadOrLoad(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadOrLoadSourceKeys.add(handle.sourceKey);
    return SourceRuntimeLoadResult(
      sourceFile: sourceFile,
      message: 'source_loaded_from_local_cache',
    );
  }

  @override
  Future<SourceRuntimeLoadResult> ensureLocalSource(
    SourceRuntimeHandle handle, {
    bool requireFile = true,
  }) async {
    localSourceKeys.add(handle.sourceKey);
    return SourceRuntimeLoadResult(
      sourceFile: sourceFile,
      message: 'source_loaded_from_local_cache',
    );
  }

  @override
  Future<SourceMeta> loadMetadata(
    SourceRuntimeHandle handle,
    File sourceFile,
  ) async {
    metadataSourceKeys.add(handle.sourceKey);
    return SourceMeta(
      name: 'JMComic',
      key: handle.sourceKey,
      version: '1.0.0',
      supportsAccount: false,
      settingsDefaults: const {},
    );
  }
}

class _FakePluginManager implements SourcePluginManager {
  final edited = <String, bool>{};
  final redownloadedIds = <String>[];
  var hasRepository = true;

  @override
  Future<bool> redownload(String id) async {
    redownloadedIds.add(id);
    return hasRepository;
  }

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {
    edited[sourceKey] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
