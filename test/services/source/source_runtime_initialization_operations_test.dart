import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_initialization_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SourceRuntimeHost host;
  late _FakeRuntimeLoader loader;
  late SourceRuntimeInitializationOperations initialization;
  late Directory cacheDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'jm.js',
          directUrls: [],
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    cacheDirectory = await Directory.systemTemp.createTemp(
      'hazuki_runtime_initialization_test_',
    );
    host.activeHandle.cache.imageCacheDir = cacheDirectory;
    loader = _FakeRuntimeLoader();
    initialization = SourceRuntimeInitializationOperations(
      runtimeHost: host,
      runtimeLoader: loader,
      jsBridgeCookieCapability: SourceJsBridgeCookieCapability(
        activeHandle: () => host.activeHandle,
      ),
      runtimeStateController: SourceRuntimeStateController(),
    );
    addTearDown(() async {
      host.dispose();
      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
      }
    });
  });

  test('initialization publishes ready state and metadata', () async {
    await initialization.init();

    expect(loader.downloadCount, 1);
    expect(loader.metadataCount, 1);
    expect(
      host.activeHandle.facade.runtimeState.phase,
      SourceRuntimePhase.ready,
    );
    expect(host.activeHandle.facade.sourceMeta?.key, 'jm');
    expect(host.activeHandle.facade.initFuture, isNull);
  });

  test('concurrent initialization requests share one in-flight load', () async {
    loader.pauseDownload = true;

    final first = initialization.init();
    await loader.downloadStarted.future;
    final second = initialization.init();
    loader.releaseDownload.complete();
    await Future.wait([first, second]);

    expect(loader.downloadCount, 1);
    expect(loader.metadataCount, 1);
  });

  test(
    'initialization failure is published without leaking in-flight state',
    () async {
      loader.error = StateError('broken source');

      await initialization.init(prewarm: true);

      expect(
        host.activeHandle.facade.runtimeState.phase,
        SourceRuntimePhase.failed,
      );
      expect(
        host.activeHandle.facade.runtimeState.error,
        contains('broken source'),
      );
      expect(host.activeHandle.facade.initFuture, isNull);
    },
  );
}

class _FakeRuntimeLoader implements SourceRuntimeLoadClient {
  final downloadStarted = Completer<void>();
  final releaseDownload = Completer<void>();
  final sourceFile = File('unused-source.js');
  var pauseDownload = false;
  var downloadCount = 0;
  var metadataCount = 0;
  Object? error;

  @override
  Future<SourceRuntimeLoadResult> downloadOrLoad(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadCount++;
    if (!downloadStarted.isCompleted) downloadStarted.complete();
    if (pauseDownload) await releaseDownload.future;
    final failure = error;
    if (failure != null) throw failure;
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
    metadataCount++;
    return SourceMeta(
      name: 'JMComic',
      key: handle.sourceKey,
      version: '1.0.0',
      supportsAccount: false,
      settingsDefaults: const {},
    );
  }

  @override
  Future<SourceRuntimeLoadResult> download(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) => throw UnsupportedError('not used');

  @override
  Future<SourceRuntimeLoadResult> ensureLocalSource(
    SourceRuntimeHandle handle, {
    bool requireFile = true,
  }) => throw UnsupportedError('not used');
}
