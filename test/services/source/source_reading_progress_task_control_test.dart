import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/logging/app_log_store.dart';
import 'package:hazuki/services/source/content/source_reading_progress_uploads.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  while (!predicate() && clock.elapsed < const Duration(seconds: 4)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceScriptEngine engine;
  late SourceReadingProgressUploads uploads;
  late Map<int, Completer<Object?>> gates;
  late List<Map> calls;
  late Directory directory;
  late AppLogStore logs;
  Map<String, Object> progress(int page) => {
    'comicId': 'comic',
    'chapterId': 'ep',
    'page': page,
    'visiblePages': [page],
    'totalPages': 5,
    'reason': 'page',
  };

  Future<void> install(SourceRuntimeHandle handle, {String? script}) async {
    final next = SourceScriptEngine(pluginId: 'one');
    engine = next;
    next.operationGuard = handle.runOperation;
    handle.runtime.engine = next;
    next.setOperationMessageHandler((message, context) {
      final map = Map.from(message as Map);
      calls.add(map);
      final page = map['page'] as int;
      return Future.any<Object?>([
        (gates[page] ??= Completer<Object?>()).future,
        context.whenStopped.then<Object?>((_) {
          context.checkActive();
          return null;
        }),
      ]);
    });
    await next.execute(
      script ??
          'globalThis.__hazuki_source={comic:{onReadingProgress:p=>sendMessage(p)}}',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('hazuki-progress-tasks-');
    logs = AppLogStore(supportDirectory: () async => directory);
    await logs.setCaptureEnabled(true);
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '1',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
      logStore: logs,
    );
    await host.activeHandle.session.ensurePrefs();
    await host.activeHandle.session.saveSourceData(
      'one',
      'login_session',
      'account',
    );
    calls = [];
    gates = {};
    await install(host.activeHandle);
    uploads = SourceReadingProgressUploads(host);
  });
  tearDown(() async {
    uploads.dispose();
    await uploads.whenSettled;
    host.dispose();
    await engine.close();
    logs.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'exit synchronously admits the upload before the reader lease closes and source switches',
    () async {
      final old = host.activeHandle;
      final reading = host.acquireReaderSession('one');
      final pending = uploads.report(progress(1), 'one');
      expect(host.tasks.activeTasks.single.method, 'cloud.upload');
      reading.close();
      await host.activateSource('two');
      expect(host.handleFor('one'), same(old));
      await _until(() => calls.isNotEmpty);
      gates[1]!.complete(null);
      await pending;
      await old.whenDisposed;
      expect(host.existingHandles.map((h) => h.sourceKey), ['two']);
    },
  );

  test('queued uploads keep FIFO and original handle while inactive', () async {
    final old = host.activeHandle;
    final first = uploads.report(progress(1), 'one');
    final second = uploads.report(progress(2), 'one');
    await host.activateSource('two');
    await _until(() => calls.length == 1);
    expect(calls.single['page'], 1);
    gates[1]!.complete(null);
    await first;
    await _until(() => calls.length == 2);
    expect(host.handleFor('one'), same(old));
    gates[2]!.complete(null);
    await second;
    await old.whenDisposed;
    expect(calls.map((e) => e['page']), [1, 2]);
  });

  test(
    'execution timeout excludes queue waiting and the next item gets its own budget',
    () async {
      uploads.dispose();
      uploads = SourceReadingProgressUploads(
        host,
        workTimeout: const Duration(milliseconds: 250),
      );
      await engine.execute(
        'globalThis.__hazuki_source.comic.onReadingProgress=p=>p.page===1?new Promise(()=>{}):sendMessage(p)',
      );
      final old = host.activeHandle;
      final first = uploads.report(progress(1), 'one');
      final failed = expectLater(first, throwsA(isA<SourceTaskTimedOut>()));
      final second = uploads.report(progress(2), 'one');
      await host.activateSource('two');
      await failed;
      await _until(() => calls.isNotEmpty);
      expect(calls.single['page'], 2);
      gates[2]!.complete(null);
      await second;
      await old.whenDisposed;
      expect(
        logs.events.any(
          (e) =>
              e.event == 'source_task_timedOut' &&
              (e.data as Map)['method'] == 'cloud.upload',
        ),
        isTrue,
      );
      expect(sourceReadingProgressWorkTimeout, const Duration(seconds: 30));
    },
  );

  test(
    'a runtime failure ends admitted uploads without moving them to the rebuilt instance',
    () async {
      final handle = host.activeHandle;
      final failed = engine;
      handle.watchEngine(failed);
      final first = uploads.report(progress(1), 'one');
      final second = uploads.report(progress(2), 'one');
      await _until(() => calls.length == 1);

      failed.debugInjectFault('internalJob');

      await first;
      await _until(() => handle.runtime.engine == null);
      // 模拟恢复后发布的新实例；故障前接纳的第二项不得在它上面执行。
      await install(handle);
      final third = uploads.report(progress(3), 'one');
      await second;
      await _until(() => calls.length == 2);
      gates[3]!.complete(null);
      await third;
      expect(calls.map((e) => e['page']), [1, 3]);
      final failures = logs.events
          .where(
            (e) =>
                e.event == 'source_task_failed' &&
                (e.data as Map)['method'] == 'cloud.upload',
          )
          .map((e) => (e.data as Map)['errorType'])
          .toList();
      expect(failures, ['SourceRuntimeFailed', 'SourceRuntimeFailed']);
      await failed.whenClosed.catchError((Object _) {});
    },
  );

  test('deep snapshot does not change while its upload is queued', () async {
    final first = uploads.report(progress(1), 'one');
    final visible = [2];
    final nested = <String, Object?>{
      'values': [1, null],
    };
    final payload = progress(2)
      ..['visiblePages'] = visible
      ..['extra'] = nested;
    final second = uploads.report(payload, 'one');
    visible.add(4);
    (nested['values'] as List).add(99);
    payload['page'] = 5;
    await _until(() => calls.isNotEmpty);
    gates[1]!.complete(null);
    await first;
    await _until(() => calls.length == 2);
    expect(calls.last['page'], 2);
    expect(calls.last['visiblePages'], [2]);
    expect((calls.last['extra'] as Map)['values'], [1, null]);
    gates[2]!.complete(null);
    await second;
  });

  test(
    'ordinary failure is recorded and does not poison the next upload',
    () async {
      await engine.execute(
        'globalThis.__hazuki_source.comic.onReadingProgress=p=>{if(p.page===1)throw Error("fixture");return sendMessage(p)}',
      );
      final first = uploads.report(progress(1), 'one');
      final second = uploads.report(progress(2), 'one');
      await first;
      await _until(() => calls.isNotEmpty);
      gates[2]!.complete(null);
      await second;
      expect(
        logs.events.any(
          (e) =>
              e.event == 'source_task_failed' &&
              (e.data as Map)['method'] == 'cloud.upload',
        ),
        isTrue,
      );
    },
  );

  test(
    'cancelling a queued item cannot let a later item overtake its predecessor',
    () async {
      final first = uploads.report(progress(1), 'one');
      final signal = SourceTaskCancellation();
      final second = uploads.report(
        progress(2),
        'one',
        origin: SourceTaskOrigin(
          ownerId: 'second',
          groupId: 'upload',
          requestSequence: 1,
          cancellation: signal,
        ),
      );
      final stopped = expectLater(second, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.isNotEmpty);
      signal.cancel(SourceTaskStopReason.user);
      await stopped;
      final third = uploads.report(progress(3), 'one');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls.map((e) => e['page']), [1]);
      gates[1]!.complete(null);
      await first;
      await _until(() => calls.length == 2);
      expect(calls.last['page'], 3);
      gates[3]!.complete(null);
      await third;
    },
  );

  test(
    'inactive account replacement cancels running and queued uploads without affecting its reader',
    () async {
      final old = host.activeHandle;
      final reading = host.acquireReaderSession('one');
      final first = uploads.report(progress(1), 'one');
      final second = uploads.report(progress(2), 'one');
      final failed = [
        expectLater(first, throwsA(isA<SourceTaskCancelled>())),
        expectLater(second, throwsA(isA<SourceTaskCancelled>())),
      ];
      await _until(() => calls.isNotEmpty);
      await host.activateSource('two');
      await old.session.saveSourceData('one', 'login_session', 'next');
      host.notifyActiveRuntimeChanged('one');
      await Future.wait(failed);
      expect(calls.map((e) => e['page']), [1]);
      expect(await engine.evaluate('12'), 12);
      expect(host.handleFor('one'), same(old));
      reading.close();
      await old.whenDisposed;
    },
  );

  test(
    'catalog update stops old uploads and new instance is unaffected by old cleanup',
    () async {
      final old = host.activeHandle;
      final pending = uploads.report(progress(1), 'one');
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.isNotEmpty);
      await host.replaceCatalog(const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '2',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ]);
      await stopped;
      await old.whenDisposed;
      final next = host.activeHandle;
      await next.session.ensurePrefs();
      await install(next);
      final fresh = uploads.report(progress(2), 'one');
      await _until(() => calls.length == 2);
      gates[2]!.complete(null);
      await fresh;
      expect(host.activeHandle, same(next));
    },
  );

  test(
    'host write rechecks account even before the lifecycle notification arrives',
    () async {
      final handle = host.activeHandle;
      final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
      engine.setOperationMessageHandler((message, context) {
        final data = message as Map;
        if (data['method'] == 'gate') {
          calls.add(data);
          return (gates[1] ??= Completer<Object?>()).future;
        }
        return bridge.handleJsMessageForHandle(
          handle,
          message,
          execution: context.execution,
          hostContext: context,
          runtimeId: context.runtimeId,
        );
      });
      await engine.execute(
        'globalThis.__hazuki_source.comic.onReadingProgress=async()=>{await sendMessage({method:"gate"});await sendMessage({method:"save_data",key:"one",data_key:"late",data:"old-account"})}',
      );
      final pending = uploads.report(progress(1), 'one');
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.isNotEmpty);
      await handle.session.saveSourceData('one', 'login_session', 'next');
      gates[1]!.complete(null);
      await stopped;
      expect(handle.session.loadSourceData('one', 'late'), isNull);
      expect(handle.hostExecutionGuards, isEmpty);
      expect(await engine.evaluate('17'), 17);
    },
  );

  test('logged out report acquires no lease and registers no task', () async {
    await host.activeHandle.session.deleteSourceData('one', 'login_session');
    final old = host.activeHandle;
    await uploads.report(progress(1), 'one');
    expect(host.tasks.activeTasks, isEmpty);
    await host.activateSource('two');
    await old.whenDisposed;
    expect(calls, isEmpty);
  });

  test(
    'dispose cancels both running and queued uploads and drains leases',
    () async {
      final old = host.activeHandle;
      final first = uploads.report(progress(1), 'one');
      final second = uploads.report(progress(2), 'one');
      final failed = [
        expectLater(first, throwsA(isA<SourceTaskCancelled>())),
        expectLater(second, throwsA(isA<SourceTaskCancelled>())),
      ];
      await _until(() => calls.isNotEmpty);
      await host.activateSource('two');
      uploads.dispose();
      await Future.wait(failed);
      await uploads.whenSettled;
      await old.whenDisposed;
      expect(host.tasks.activeTasks, isEmpty);
      expect(calls.map((e) => e['page']), [1]);
    },
  );
}
