import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/models/source_task.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
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
        SourceCatalogEntry(key: 'jm', name: 'JMComic', fileName: 'jm.js'),
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
    'shared initialization survives its first search and forwards input waiting',
    () async {
      loader.pauseDownload = true;
      loader.waitForInput = true;
      final lifetime = SourceTaskCancellation();
      late SourceUiScope firstScope;
      late SourceUiScope secondScope;
      final first = SourceUiService.instance.run(() {
        firstScope = SourceUiScope.current!;
        return host.tasks.run(
          pluginId: 'jm',
          method: 'search.load',
          origin: SourceTaskOrigin(
            ownerId: 'first',
            groupId: 'query',
            requestSequence: 1,
            cancellation: lifetime,
            workTimeout: const Duration(seconds: 25),
          ),
          operation: (_) => initialization.init(),
        );
      });
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      await loader.downloadStarted.future;
      expect(loader.scope, isNot(same(firstScope)));
      expect(firstScope.waiting, isTrue);
      final second = SourceUiService.instance.run(() {
        secondScope = SourceUiScope.current!;
        return initialization.init();
      });
      expect(secondScope.waiting, isTrue);
      lifetime.cancel(SourceTaskStopReason.ownerDisposed);
      await stopped;
      expect(loader.scope!.reason, isNull);
      expect(secondScope.waiting, isTrue);
      loader.releaseDownload.complete();
      await second;
      expect(loader.downloadCount, 1);
      expect(loader.metadataCount, 1);
      expect(
        host.activeHandle.facade.runtimeState.phase,
        SourceRuntimePhase.ready,
      );
    },
  );

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
  var waitForInput = false;
  SourceUiScope? scope;
  var downloadCount = 0;
  var metadataCount = 0;
  Object? error;

  @override
  Future<SourceRuntimeLoadResult> downloadOrLoad(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadCount++;
    scope = SourceUiScope.current;
    if (waitForInput) scope?.setWaiting(true);
    if (!downloadStarted.isCompleted) downloadStarted.complete();
    if (pauseDownload) await releaseDownload.future;
    if (waitForInput) scope?.setWaiting(false);
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
  Future<SourceRuntimeLoadResult> ensureLocalSource(
    SourceRuntimeHandle handle, {
    bool requireFile = true,
  }) => throw UnsupportedError('not used');
}
