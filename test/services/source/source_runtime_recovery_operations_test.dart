import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/common/source_prefs_keys.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_recovery_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_editing_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_storage.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;
  late _FakeRuntimeLoader loader;
  late SourceRuntimeRecoveryOperations recovery;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    late SourceRuntimeHost runtimeHost;
    runtimeHost = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'jm.js',
          directUrls: [],
        ),
        SourceCatalogEntry(
          key: 'copy_manga',
          name: 'CopyManga',
          fileName: 'copy_manga.js',
          directUrls: [],
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
    final store = _MemoryScriptStore();
    final stateController = SourceRuntimeStateController();
    recovery = SourceRuntimeRecoveryOperations(
      runtimeHost: host,
      runtimeLoader: loader,
      scriptEditing: SourceScriptEditingOperations(
        runtimeHost: host,
        storage: store,
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
    'manual download activates the requested source and clears edit state',
    () async {
      SharedPreferences.setMockInitialValues({
        SourcePrefsKeys.customEditedSource('copy_manga'): true,
      });

      await recovery.downloadSourceFile('copy_manga');

      expect(loader.downloadedSourceKeys, ['copy_manga']);
      expect(host.activeSourceKey, 'copy_manga');
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(SourcePrefsKeys.customEditedSource('copy_manga')),
        isFalse,
      );
    },
  );

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
  final downloadedSourceKeys = <String>[];
  final localSourceKeys = <String>[];
  final downloadOrLoadSourceKeys = <String>[];
  final metadataSourceKeys = <String>[];
  final sourceFile = File('unused-source.js');

  @override
  Future<SourceRuntimeLoadResult> download(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadedSourceKeys.add(handle.sourceKey);
    return SourceRuntimeLoadResult(
      sourceFile: sourceFile,
      message: 'source_downloaded_manually',
    );
  }

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

class _MemoryScriptStore implements SourceScriptStore {
  final edited = <String, bool>{};

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {
    edited[sourceKey] = value;
  }

  @override
  Future<bool> isCustomEdited(String sourceKey) async =>
      edited[sourceKey] ?? false;

  @override
  Future<void> delete(String sourceKey) async {}

  @override
  Future<bool> exists(String sourceKey) async => false;

  @override
  Future<File> ensureLocalSourceFile(String sourceKey) =>
      throw UnsupportedError('not used');

  @override
  Future<String?> readIfExists(String sourceKey) async => null;

  @override
  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) => throw UnsupportedError('not used');

  @override
  Future<void> write(String sourceKey, String content) async {}
}
