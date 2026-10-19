import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/scheduler.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_kernel.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_script_worker.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SourceScriptEngine engine({int timeout = 5000}) {
    final result = SourceScriptEngine(timeout: timeout);
    addTearDown(result.close);
    return result;
  }

  test(
    'background worker preserves sync values, host reads and awaited writes',
    () async {
      final js = engine();
      var stored = 0;
      js.setMessageHandler((request) {
        if (request['write'] != null) {
          return Future<void>(() {
            stored = request['write'] as int;
          });
        }
        return stored;
      });
      expect(await js.evaluate('sendMessage({}) + 1'), 1);
      expect(
        await js.evaluate(
          '(async()=>{await sendMessage({write: 41}); return sendMessage({})+1;})()',
        ),
        42,
      );
      expect(await js.evaluate('sendMessage({}) instanceof Promise'), false);
    },
  );
  test('cyclic graphs, byte slices and errors survive transport', () async {
    final js = engine();
    final bytes = Uint8List.fromList([8, 0, 128, 255, 9]);
    final slice = Uint8List.sublistView(bytes, 1, 4);
    expect(await js.invoke('(bytes)=>new Uint8Array(bytes).buffer', [slice]), [
      0,
      128,
      255,
    ]);
    expect(bytes, [8, 0, 128, 255, 9]);
    final cycle =
        await js.evaluate('(()=>{const a={};a.self=a;return a;})()') as Map;
    expect(identical(cycle, cycle['self']), true);
    js.setMessageHandler((_) => throw StateError('host error'));
    expect(
      await js.evaluate('try {sendMessage({});}catch(e){e.message;}'),
      contains('host error'),
    );
    await expectLater(
      js.evaluate('throw new Error("script error")', name: 'script.js'),
      throwsA(predicate((e) => e.toString().contains('script.js'))),
    );
  });
  test('CPU loops leave the host responsive and still time out', () async {
    final js = engine(timeout: 150);
    await js.ready;
    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 5),
      (_) => ticks++,
    );
    try {
      for (final operation in <Future<dynamic> Function()>[
        () => js.evaluate('while(true){}'),
        () => js.execute('while(true){}', name: 'source_init.js'),
        () => js.invoke('(bytes)=>{while(true){}}', [Uint8List(32)]),
      ]) {
        final before = ticks;
        await expectLater(
          operation(),
          throwsA(predicate((e) => e.toString().contains('interrupted'))),
        );
        expect(ticks - before, greaterThan(2));
      }
      expect(await js.evaluate('40+2'), 42);
    } finally {
      timer.cancel();
    }
  });
  test('remote callbacks can be called, released and invalidated', () async {
    final js = engine();
    final callback = await js.evaluate('(x)=>x+1') as SourceScriptCallback;
    expect(await callback.invoke([41]), 42);
    await callback.free();
    await callback.free();
    await expectLater(callback.invoke([1]), throwsStateError);
    final seen = <String>[];
    js.setContextMessageHandler((_, execution) => seen.add(execution.taskId));
    final outer =
        await js.evaluate(
              '()=>()=>sendMessage({})',
              execution: const SourceScriptExecution(
                taskId: 'callback-owner',
                pluginId: 'test',
                method: 'search',
              ),
            )
            as SourceScriptCallback;
    final inner = await outer.invoke([]) as SourceScriptCallback;
    await inner.invoke([]);
    expect(seen, ['callback-owner']);
    await inner.free();
    await outer.free();
    final lateCallback = await js.evaluate('()=>1') as SourceScriptCallback;
    await js.close();
    await expectLater(lateCallback.invoke([]), throwsStateError);
    expect(QuickJsHostReply.count, 0);
  });
  test('worker bootstrap failures are reported before exit', () async {
    final messages = ReceivePort();
    final exit = ReceivePort();
    final exited = exit.first;
    await Isolate.spawn(runSourceScriptWorker, {
      'port': messages.sendPort,
      'runtimeId': 'failed-bootstrap',
      'timeout': 'invalid',
      'memoryLimit': 1024,
    }, onExit: exit.sendPort);
    final failure = await messages.first as Map;
    expect(failure['type'], 'failed');
    expect(failure['runtimeId'], 'failed-bootstrap');
    await exited;
    messages.close();
    exit.close();
  });
  test(
    'shared promise reactions retain registration task across concurrent calls',
    () async {
      final js = engine();
      final seen = <String>[];
      js.setContextMessageHandler((message, context) {
        seen.add(context.taskId);
        return 42;
      });
      await js.evaluate(
        'globalThis.shared = new Promise(r=>globalThis.resolveShared=r); null;',
      );
      final first = js.evaluate(
        '(async()=>{await shared;return sendMessage({});})()',
        execution: const SourceScriptExecution(
          taskId: 'first',
          pluginId: 'test',
          method: 'search',
        ),
      );
      expect(
        await js.evaluate(
          'resolveShared(); "resolved"',
          execution: const SourceScriptExecution(
            taskId: 'second',
            pluginId: 'test',
            method: 'read',
          ),
        ),
        'resolved',
      );
      expect(await first, 42);
      expect(seen, ['first']);
    },
  );
  test(
    'close ends pending hosts and unbounded microtasks without killing the isolate',
    () async {
      final baseline = QuickJsHostReply.count;
      final js = engine();
      final pendingHost = Completer<void>();
      final called = Completer<void>();
      js.setMessageHandler((_) {
        called.complete();
        return pendingHost.future;
      });
      final waiting = js.evaluate('sendMessage({})');
      final assertion = expectLater(waiting, throwsStateError);
      await called.future;
      await js.close();
      await assertion;
      pendingHost.complete();
      expect(QuickJsHostReply.count, baseline);
      final other = engine();
      final loop = other.evaluate(
        'new Promise(()=>{const step=()=>Promise.resolve().then(step);step();})',
      );
      final failed = expectLater(loop, throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await other.close();
      await failed;
    },
  );

  test(
    'early close, worker timers and repeated rebuilds release resources',
    () async {
      final baseline = QuickJsHostReply.count;
      await engine().close();
      for (var i = 0; i < 4; i++) {
        final js = engine();
        final started = Completer<void>();
        js.setMessageHandler((_) => started.complete());
        final pending = js.evaluate(
          'sendMessage({});sendMessage({method:"delay",time:60000})',
        );
        final assertion = expectLater(pending, throwsStateError);
        await started.future;
        await js.close();
        await js.close();
        await assertion;
        expect(js.shutdownDiagnostics, {
          'nativeRuntimes': 0,
          'tasks': 0,
          'callbacks': 0,
          'hostCalls': 0,
          'timers': 0,
        });
      }
      expect(QuickJsHostReply.count, baseline);
    },
  );

  test(
    'snapshots precede results and retired instances cannot overwrite metadata',
    () async {
      final kernel = SourceRuntimeKernel();
      const meta = SourceMeta(
        name: 'Test',
        key: 'test',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
      );
      final old = engine();
      kernel.sourceMeta = meta;
      kernel.engine = old;
      await old.evaluate('''globalThis.__hazuki_source={
      key:'test',name:'Test',version:'1',settings:{line:{default:'a'}},
      translation:{hello:'old'},comic:{likeComic(){}}};null;''');
      expect(kernel.sourceMeta!.translation['hello'], 'old');
      expect(
        old.cachedValue(
          'typeof this.__hazuki_source.comic?.likeComic === "function"',
        ),
        true,
      );
      await old.evaluate('''(async()=>{await Promise.resolve();
      __hazuki_source.translation.hello='updated';
      __hazuki_source.comic.likeComic=null;})()''');
      expect(kernel.sourceMeta!.translation['hello'], 'updated');
      expect(
        old.cachedValue(
          'typeof this.__hazuki_source.comic?.likeComic === "function"',
        ),
        false,
      );
      final replacement = engine();
      kernel.engine = replacement;
      kernel.sourceMeta = meta;
      await replacement.evaluate('''globalThis.__hazuki_source={
      key:'test',name:'Test',version:'2',translation:{hello:'new'}};null;''');
      await old.evaluate('__hazuki_source.translation.hello="stale";null;');
      expect(kernel.sourceMeta!.translation['hello'], 'new');
      expect(kernel.sourceMeta!.version, '2');
      expect(replacement.runtimeId, isNot(old.runtimeId));
    },
  );

  test(
    'admitted operations retain their engine across awaits and source retirement',
    () async {
      final handle = SourceRuntimeHandle(
        sourceKey: 'test',
        secureStorage: MemorySourceSecureSessionStorage(),
        ensureInitialized: (_) async {},
        notifyRuntimeStateChanged: (_) {},
      );
      final js = engine();
      handle.runtime.engine = js;
      final entered = Completer<void>();
      final resume = Completer<void>();
      final pending = handle.runOperation(() async {
        entered.complete();
        await resume.future;
        return await js.evaluate('40+2');
      });
      await entered.future;
      handle.requestDispose();
      await expectLater(handle.runOperation(() async => 0), throwsStateError);
      resume.complete();
      expect(await pending, 42);
      await handle.whenDisposed;
      expect(js.shutdownDiagnostics['nativeRuntimes'], 0);
    },
  );

  test(
    'interleaved plugin HTTP logs retain registering task identities',
    () async {
      SharedPreferences.setMockInitialValues({});
      final handle = SourceRuntimeHandle(
        sourceKey: 'test',
        secureStorage: MemorySourceSecureSessionStorage(),
        ensureInitialized: (_) async {},
        notifyRuntimeStateChanged: (_) {},
      );
      await handle.session.ensurePrefs();
      await handle.appLogStore.setCaptureEnabled(true);
      final js = engine();
      handle.runtime.engine = js;
      final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
      js.setContextMessageHandler(
        (message, execution) => bridge.handleJsMessageForHandle(
          handle,
          message,
          execution: execution,
          runtimeId: js.runtimeId,
        ),
      );
      handle.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(requestOptions: request, statusCode: 200, data: 'ok'),
            );
          },
        ),
      );
      await js.evaluate(
        'globalThis.shared=new Promise(r=>globalThis.release=r);null;',
      );
      final calls = <Future<dynamic>>[];
      for (final method in ['search', 'read', 'download']) {
        calls.add(
          js.evaluate(
            'shared.then(()=>sendMessage({method:"http",url:"https://test.example/$method"}))',
            execution: SourceScriptExecution(
              taskId: method,
              pluginId: 'test',
              pluginVersion: '1.2',
              method: method,
            ),
          ),
        );
      }
      await js.evaluate('release();null;');
      await Future.wait(calls);
      final logs = handle.appLogStore.events.where(
        (event) => event.event == 'network_request',
      );
      expect(logs, hasLength(3));
      for (final event in logs) {
        final data = event.data as Map;
        final task = data['task'] as Map;
        expect(data['url'], endsWith('/${task['taskId']}'));
        expect(task['method'], task['taskId']);
        expect(task['runtimeId'], js.runtimeId);
        expect(task['pluginVersion'], '1.2');
      }
      handle.requestDispose();
      await handle.whenDisposed;
      handle.appLogStore.dispose();
    },
  );

  testWidgets('Flutter frames advance during a busy script', (tester) async {
    late SourceScriptEngine js;
    late Future<void> assertion;
    var finished = false;
    await tester.runAsync(() async {
      js = engine(timeout: 500);
      await js.ready;
      assertion = expectLater(
        js.evaluate('while(true){}').whenComplete(() => finished = true),
        throwsA(predicate((e) => e.toString().contains('interrupted'))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
    var frames = 0;
    for (var i = 0; i < 3; i++) {
      SchedulerBinding.instance.scheduleFrameCallback((_) => frames++);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(frames, 3);
    expect(finished, false);
    await tester.runAsync(() => assertion);
    await tester.runAsync(js.close);
  });
}
