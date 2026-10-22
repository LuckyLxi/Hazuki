import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/logging/app_log_store.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/models/source_task.dart';
import 'package:hazuki/services/source/runtime/source_catalog_resolver.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_operation_runner.dart';
import 'package:hazuki/services/source/runtime/source_runtime_diagnostics_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_facade.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_health.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_initialization_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_recovery_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_editing_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_storage.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_text_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an active source failure is rebuilt once on the same handle without replay',
    () async {
      final fixture = await _Fixture.create();
      final handle = fixture.host.activeHandle;
      final failed = handle.runtime.engine!;
      expect(fixture.loader.loads, 1);
      final pending = runSourceOperation<Object?>(
        fixture.host,
        handle,
        'test.pending',
        (context) => context.evaluate(failed, 'new Promise(()=>{})'),
      );
      final assertion = expectLater(
        pending,
        throwsA(isA<SourceRuntimeFailed>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      failed.debugInjectFault('internalJob');

      await assertion;
      await fixture.waitForLog('recovered');
      expect(fixture.failures, hasLength(1));
      expect(fixture.failures.single.recover, isTrue);
      expect(identical(fixture.host.activeHandle, handle), isTrue);
      final rebuilt = handle.runtime.engine!;
      expect(identical(rebuilt, failed), isFalse);
      expect(rebuilt.runtimeId, isNot(failed.runtimeId));
      expect(fixture.loader.loads, 2);
      expect(handle.facade.runtimeState.phase, SourceRuntimePhase.ready);
      expect(fixture.tasks(), isEmpty);
      // 被中断的操作不会被重放到新实例。
      expect(fixture.loader.loads, 2);
      expect(
        await runSourceOperation<Object?>(
          fixture.host,
          handle,
          'test.after',
          (context) => context.evaluate(rebuilt, '6*7'),
        ),
        42,
      );
    },
  );

  test(
    'a page scope receives the runtime failure instead of a silent cancellation',
    () async {
      final fixture = await _Fixture.create();
      final handle = fixture.host.activeHandle;
      final engine = handle.runtime.engine!;
      // 页面读取总是携带任务取消信号，因此任务会关联页面交互 scope。
      late Future<Object?> inner;
      final page = SourceUiService.instance.run(
        () => inner = runSourceOperation<Object?>(
          fixture.host,
          handle,
          'test.page',
          (context) => context.evaluate(engine, 'new Promise(()=>{})'),
          origin: SourceTaskOrigin(
            ownerId: 'page',
            groupId: 'read',
            requestSequence: 1,
            cancellation: SourceTaskCancellation(),
          ),
        ),
      );
      final innerAssertion = expectLater(
        inner,
        throwsA(isA<SourceRuntimeFailed>()),
      );
      final assertion = expectLater(
        page,
        throwsA(
          isA<SourceRuntimeFailed>().having(
            (e) => e.kind,
            'kind',
            SourceRuntimeFailureKind.internalJob,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      engine.debugInjectFault('internalJob');
      await assertion;
      await innerAssertion;
      // 终态记录为 failed 且无停止原因，而不是被取消。
      final terminal = [
        for (final event in fixture.host.logStore.events)
          if (event.data case {
            'method': 'test.page',
            'state': 'failed' || 'cancelled' || 'timedOut',
          })
            event.data as Map,
      ];
      expect(terminal, isNotEmpty);
      expect(terminal.first['state'], 'failed');
      expect(terminal.first['errorType'], 'SourceRuntimeFailed');
      expect(terminal.first.containsKey('stopReason'), isFalse);
      await fixture.waitForLog('recovered');
    },
  );

  test('concurrent new calls during recovery share one rebuild', () async {
    final fixture = await _Fixture.create();
    final handle = fixture.host.activeHandle;
    handle.runtime.engine!.debugInjectFault('internalJob');
    await fixture.waitFor(() => fixture.failures.isNotEmpty);
    await Future.wait([
      fixture.init.ensureSourceInitialized('jm'),
      fixture.init.ensureSourceInitialized('jm'),
      fixture.init.ensureSourceInitialized('jm'),
    ]);
    await fixture.waitForLog('recovered');
    expect(fixture.loader.loads, 2);
    expect(handle.runtime.engine, isNotNull);
  });

  test(
    'a non-active retained source is rebuilt lazily on its next call',
    () async {
      final fixture = await _Fixture.create(keys: const ['jm', 'copy']);
      final other = fixture.host.handleFor('copy');
      await fixture.init.ensureSourceInitialized('copy');
      expect(fixture.loader.loads, 2);
      final failed = other.runtime.engine!;

      failed.debugInjectFault('internalJob');

      await fixture.waitFor(() => fixture.failures.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fixture.failures.single.recover, isTrue);
      expect(other.runtime.engine, isNull);
      expect(fixture.loader.loads, 2);
      expect(fixture.recoveries(), ['deferred']);
      expect(other.facade.runtimeState.phase, SourceRuntimePhase.failed);

      await fixture.init.ensureSourceInitialized('copy');
      expect(fixture.loader.loads, 3);
      expect(other.runtime.engine, isNotNull);
      expect(identical(other.runtime.engine, failed), isFalse);
    },
  );

  test('a late failure from a retired engine is ignored', () async {
    final fixture = await _Fixture.create();
    final handle = fixture.host.activeHandle;
    final old = handle.runtime.engine!;
    await handle.runOperation(() async {
      // 操作租约期间旧实例尚未关闭，模拟其在退役后才故障。
      await fixture.loader.loadMetadata(handle, fixture.files['jm']!);
      old.debugInjectFault('internalJob');
      await old.whenFailed.timeout(const Duration(seconds: 2));
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fixture.failures, isEmpty);
    expect(handle.runtime.engine, isNotNull);
    expect(identical(handle.runtime.engine, old), isFalse);
  });

  test(
    'a crash loop latches until an explicit manual retry clears it',
    () async {
      final fixture = await _Fixture.create();
      final handle = fixture.host.activeHandle;
      handle.runtime.engine!.debugInjectFault('internalJob');
      await fixture.waitForLog('recovered');
      expect(fixture.loader.loads, 2);

      // 恢复后的实例尚未成功完成业务操作就再次故障：不再自动重建。
      handle.runtime.engine!.debugInjectFault('internalJob');
      await fixture.waitFor(() => fixture.failures.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fixture.failures.last.recover, isFalse);
      expect(handle.runtimeFault, isNotNull);
      expect(handle.runtime.engine, isNull);
      expect(fixture.recoveries().last, 'latched');
      await expectLater(
        fixture.init.ensureSourceInitialized('jm'),
        throwsA(isA<SourceRuntimeFailed>()),
      );
      expect(fixture.loader.loads, 2);
      // 网络恢复是自动入口，不能绕过锁存。
      expect(await fixture.recovery.refreshSourceOnNetworkRecovery(), isFalse);
      expect(fixture.loader.loads, 2);

      fixture.diagnostics.logRuntimeRetryRequested('test');
      expect(handle.runtimeFault, isNull);
      await fixture.init.ensureSourceInitialized('jm');
      expect(fixture.loader.loads, 3);
      expect(handle.runtime.engine, isNotNull);
    },
  );

  test(
    'a successful business operation restores the single recovery allowance',
    () async {
      final fixture = await _Fixture.create();
      final handle = fixture.host.activeHandle;
      handle.runtime.engine!.debugInjectFault('internalJob');
      await fixture.waitForLog('recovered');
      final recovered = handle.runtime.engine!;
      expect(
        await runSourceOperation<Object?>(
          fixture.host,
          handle,
          'test.ok',
          (context) => context.evaluate(recovered, '1'),
        ),
        1,
      );

      recovered.debugInjectFault('internalJob');
      await fixture.waitFor(() => fixture.failures.length == 2);
      expect(fixture.failures.last.recover, isTrue);
      await fixture.waitFor(
        () => fixture.recoveries().where((e) => e == 'recovered').length == 2,
      );
      expect(handle.runtimeFault, isNull);
      expect(fixture.loader.loads, 3);
    },
  );

  test('normal cancellation never rebuilds the runtime', () async {
    final fixture = await _Fixture.create();
    final handle = fixture.host.activeHandle;
    final engine = handle.runtime.engine!;
    final origin = SourceTaskOrigin(
      ownerId: 'page',
      groupId: 'read',
      requestSequence: 1,
      cancellation: SourceTaskCancellation(),
    );
    final running = runSourceOperation<Object?>(
      fixture.host,
      handle,
      'test.spin',
      (context) => context.evaluate(engine, 'while(true){}'),
      origin: origin,
    );
    final assertion = expectLater(running, throwsA(isA<SourceTaskCancelled>()));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    origin.cancellation!.cancel(SourceTaskStopReason.user);
    await assertion;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(fixture.failures, isEmpty);
    expect(identical(handle.runtime.engine, engine), isTrue);
    expect(fixture.loader.loads, 1);
  });
}

class _Fixture {
  _Fixture._(
    this.host,
    this.loader,
    this.init,
    this.recovery,
    this.diagnostics,
    this.files,
  );

  final SourceRuntimeHost host;
  final _CountingLoader loader;
  final SourceRuntimeInitializationOperations init;
  final SourceRuntimeRecoveryOperations recovery;
  final SourceRuntimeDiagnosticsOperations diagnostics;
  final Map<String, File> files;
  final failures =
      <
        ({
          SourceRuntimeHandle handle,
          SourceRuntimeFailed failure,
          bool recover,
        })
      >[];

  List<SourceTaskSnapshot> tasks() => host.tasks.activeTasks;

  List<String> recoveries() => [
    for (final event in host.logStore.events)
      if (event.title == 'Source runtime failure')
        (event.data as Map)['recovery'] as String,
  ];

  Future<void> waitFor(bool Function() condition) async {
    final clock = Stopwatch()..start();
    while (!condition()) {
      if (clock.elapsed > const Duration(seconds: 10)) {
        fail('condition not reached; recoveries=${recoveries()}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> waitForLog(String recovery) =>
      waitFor(() => recoveries().contains(recovery));

  static Future<_Fixture> create({List<String> keys = const ['jm']}) async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('hazuki_health_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => root.path);
    final files = {for (final key in keys) key: File('${root.path}/$key.js')};
    for (final entry in files.entries) {
      await entry.value.writeAsString(_script(entry.key));
    }
    late SourceRuntimeInitializationOperations init;
    final host = SourceRuntimeHost(
      catalog: [
        for (final key in keys)
          SourceCatalogEntry(key: key, name: key, fileName: '$key.js'),
      ],
      defaultSourceKey: keys.first,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (key) => init.ensureSourceInitialized(key),
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
      logStore: AppLogStore(),
    );
    await host.logStore.setCaptureEnabled(true);
    final state = SourceRuntimeStateController();
    final bridge = SourceJsBridgeCookieCapability(
      activeHandle: () => host.activeHandle,
    );
    final store = _Store(files);
    final downloader = _NoDownloads();
    final loader = _CountingLoader(
      SourceRuntimeLoader(
        scriptStore: store,
        catalogResolver: SourceCatalogResolver(
          runtimeHost: host,
          downloader: downloader,
          sourceIndexUrls: const [],
        ),
        downloader: downloader,
        jsBridge: bridge,
        runtimeStateController: state,
        bundledInitAssetPath: 'assets/init.js',
        loadAssetText: (path) => File(path).readAsString(),
      ),
    );
    init = SourceRuntimeInitializationOperations(
      runtimeHost: host,
      runtimeLoader: loader,
      jsBridgeCookieCapability: bridge,
      runtimeStateController: state,
    );
    final recovery = SourceRuntimeRecoveryOperations(
      runtimeHost: host,
      runtimeLoader: loader,
      scriptEditing: SourceScriptEditingOperations(
        runtimeHost: host,
        storage: store,
        runtimeStateController: state,
        ensureEditableFile: (_) => throw UnsupportedError('not used'),
      ),
      runtimeStateController: state,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {},
      ),
    );
    final fixture = _Fixture._(
      host,
      loader,
      init,
      recovery,
      SourceRuntimeDiagnosticsOperations(runtimeHost: host),
      files,
    );
    final monitor = SourceRuntimeHealthMonitor(
      runtimeHost: host,
      runtimeStateController: state,
      ensureSourceInitialized: init.ensureSourceInitialized,
    );
    host.onRuntimeFailed = (handle, failure, {required recover}) {
      fixture.failures.add((
        handle: handle,
        failure: failure,
        recover: recover,
      ));
      monitor.handleFailure(handle, failure, recover: recover);
    };
    addTearDown(() async {
      for (final key in keys) {
        final handle = host.handleFor(key);
        handle.requestDispose();
        await handle.whenDisposed.catchError((Object _) {});
      }
      host.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    });
    await init.ensureSourceInitialized(keys.first);
    expect(host.activeHandle.runtime.engine, isNotNull);
    return fixture;
  }
}

String _script(String key) =>
    '''
Hazuki.registerSource({id:'$key',name:'$key',version:'1.0.0',init:async()=>{},
  search:{load:async()=>({comics:[]})},
  comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});
''';

class _CountingLoader implements SourceRuntimeLoadClient {
  _CountingLoader(this._inner);
  final SourceRuntimeLoader _inner;
  int loads = 0;

  @override
  Future<SourceRuntimeLoadResult> ensureLocalSource(
    SourceRuntimeHandle handle, {
    bool requireFile = true,
  }) => _inner.ensureLocalSource(handle, requireFile: requireFile);

  @override
  Future<SourceRuntimeLoadResult> downloadOrLoad(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) => _inner.downloadOrLoad(handle, onProgress: onProgress);

  @override
  Future<SourceRuntimeLoadResult> download(
    SourceRuntimeHandle handle, {
    void Function(int received, int total)? onProgress,
  }) => _inner.download(handle, onProgress: onProgress);

  @override
  Future<SourceMeta> loadMetadata(SourceRuntimeHandle handle, File sourceFile) {
    loads++;
    return _inner.loadMetadata(handle, sourceFile);
  }
}

class _NoDownloads implements SourceTextDownloadClient {
  @override
  Future<String?> firstAvailable(
    List<String> urls, {
    required HazukiSourceFacade facade,
    String source = 'source_fetch',
  }) async => throw StateError('unexpected download');

  @override
  Future<String?> sequential(
    List<String> urls, {
    required HazukiSourceFacade facade,
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
  }) async => throw StateError('unexpected download');
}

class _Store implements SourceScriptStore {
  _Store(this.files);
  final Map<String, File> files;

  @override
  Future<File> ensureLocalSourceFile(String sourceKey) async =>
      files[sourceKey]!;

  @override
  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) async => files[sourceKey]!;

  @override
  Future<void> delete(String sourceKey) async {}

  @override
  Future<bool> exists(String sourceKey) => files[sourceKey]!.exists();

  @override
  Future<bool> isCustomEdited(String sourceKey) async => false;

  @override
  Future<String?> readIfExists(String sourceKey) async =>
      files[sourceKey]!.readAsString();

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {}

  @override
  Future<void> write(String sourceKey, String content) =>
      files[sourceKey]!.writeAsString(content);
}
