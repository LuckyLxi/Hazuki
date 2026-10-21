import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_host_call_context.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';

SourceScriptExecution execution(String id) =>
    SourceScriptExecution(taskId: id, pluginId: 'fixture', method: 'test.$id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'exhausting the synchronous host handshake budget is a typed timeout',
    () async {
      final engine = SourceScriptEngine(timeout: 20);
      addTearDown(engine.close);
      engine.setMessageHandler((_) {
        // Simulate a synchronous service that answers after the worker budget.
        final clock = Stopwatch()..start();
        while (clock.elapsedMilliseconds < 80) {}
        return 42;
      });
      await expectLater(
        engine.evaluate('''globalThis.caught=false;
        try {sendMessage({method:"fixture"})} catch (_) {caught=true}
      ''', execution: execution('A')),
        throwsA(
          isA<SourceScriptStopped>().having((e) => e.timedOut, 'timeout', true),
        ),
      );
      expect(await engine.evaluate('caught', execution: execution('B')), false);
      expect(await engine.evaluate('42', execution: execution('B')), 42);
    },
  );

  test(
    'cancellation includes commands still waiting for worker ready',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      var completed = false;
      final call = engine.evaluate(
        'globalThis.preReady=1',
        execution: execution('A'),
      );
      final assertion = expectLater(
        call.whenComplete(() => completed = true),
        throwsA(isA<SourceScriptStopped>()),
      );
      final receipt = await engine.cancelExecution('A', 'user');
      await receipt.whenSettled;
      expect(receipt.status, SourceScriptCancelStatus.accepted);
      expect(completed, true);
      await assertion;
      expect(await engine.evaluate('typeof preReady'), 'undefined');
    },
  );

  test(
    'cancel acknowledgements and releases bypass another task spinning microtasks',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final a = engine.evaluate(
        'sendMessage({method:"delay",time:60000})',
        execution: execution('A'),
      );
      final stoppedA = expectLater(a, throwsA(isA<SourceScriptStopped>()));
      final callback =
          await engine.evaluate('()=>42', execution: execution('callback'))
              as SourceScriptCallback;
      final b = engine.evaluate(
        'new Promise(()=>{function spin(){Promise.resolve().then(spin)}spin()})',
        execution: execution('B'),
      );
      final stoppedB = expectLater(b, throwsA(isA<SourceScriptStopped>()));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final receipt = await engine.cancelExecution('A', 'user');
      await stoppedA;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      await callback.free().timeout(const Duration(seconds: 2));
      await engine.cancelExecution('B', 'user');
      await stoppedB;
    },
  );

  test(
    'a custom Promise reject resolver cannot disable timeout during stop cleanup',
    () async {
      final engine = SourceScriptEngine(timeout: 40);
      addTearDown(engine.close);
      await expectLater(
        engine.evaluate('''
      class CustomPromise extends Promise {
        constructor(executor) { super((resolve,reject)=>executor(resolve,()=>{while(true){}})); }
      }
      new CustomPromise(resolve=>resolve(0)).then(()=>{while(true){}})
    ''', execution: execution('A')),
        throwsA(
          isA<SourceScriptStopped>().having((e) => e.timedOut, 'timeout', true),
        ),
      );
      expect(await engine.evaluate('42', execution: execution('B')), 42);
    },
  );

  test('sharing one host resource does not retain its unused sibling', () async {
    final engine = SourceScriptEngine();
    addTearDown(engine.close);
    final values = [Completer<int>(), Completer<int>()];
    final contexts = <SourceHostCallContext>[];
    final entered = Completer<void>();
    engine.setOperationMessageHandler((message, context) {
      contexts.add(context);
      if (contexts.length == 2) entered.complete();
      return values[(message as Map)['index'] as int].future;
    });
    final a = engine.evaluate(
      'sendMessage({index:0});globalThis.shared=sendMessage({index:1});shared',
      execution: execution('A'),
    );
    final stopped = expectLater(a, throwsA(isA<SourceScriptStopped>()));
    await entered.future;
    final b = engine.evaluate('shared.then(v=>v)', execution: execution('B'));
    await engine.evaluate('null');
    final receipt = await engine.cancelExecution('A', 'user');
    await stopped;
    await contexts[0].whenStopped.timeout(const Duration(seconds: 2));
    expect(contexts[1].isStopped, false);
    values[0].complete(0);
    await receipt.whenSettled;
    values[1].complete(42);
    expect(await b, 42);
  });

  test(
    'a failed job does not end another command with the same task identity',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final b = engine.evaluate(
        'sendMessage({method:"delay",time:100}).then(()=>42)',
        execution: execution('A'),
      );
      final assertion = expectLater(b, completion(42));
      await expectLater(
        engine.evaluate('''
      class RejectingPromise extends Promise {
        constructor(executor) { super((resolve,reject)=>executor(resolve,()=>{throw Error("reject resolver")})); }
      }
      new RejectingPromise(resolve=>resolve(0)).then(()=>{throw Error("reaction")})
    ''', execution: execution('A')),
        throwsA(anything),
      );
      await assertion;
      expect(await engine.evaluate('42'), 42);
    },
  );

  test(
    'deadline stops retain typed identity and repeated cancellation is idempotent',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final call = engine.evaluate(
        'sendMessage({method:"delay",time:60000})',
        execution: execution('A'),
      );
      final assertion = expectLater(
        call,
        throwsA(
          isA<SourceScriptStopped>()
              .having((e) => e.nativeToken, 'native token', greaterThan(0))
              .having((e) => e.execution.taskId, 'task', 'A')
              .having((e) => e.runtimeId, 'runtime', engine.runtimeId)
              .having((e) => e.timedOut, 'timeout', true),
        ),
      );
      await engine.evaluate('null');
      final first = await engine.cancelExecution('A', 'deadlineExceeded');
      final second = await engine.cancelExecution('A', 'user');
      expect(first.status, SourceScriptCancelStatus.accepted);
      expect(second.status, SourceScriptCancelStatus.alreadyRequested);
      await assertion;
      await first.whenSettled;
      await second.whenSettled;
    },
  );

  test(
    'late subscribers to stopped production fail explicitly without cancelling their own task',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final call = engine.evaluate(
        'globalThis.shared=sendMessage({method:"delay",time:60000});shared',
        execution: execution('A'),
      );
      final assertion = expectLater(call, throwsA(isA<SourceScriptStopped>()));
      await engine.evaluate('null');
      final receipt = await engine.cancelExecution('A', 'user');
      await assertion;
      await receipt.whenSettled;
      await expectLater(
        engine.evaluate('shared.then(()=>42)', execution: execution('B')),
        throwsA(
          isA<SourceScriptStopped>().having(
            (e) => e.reason,
            'reason',
            'dependencyStopped',
          ),
        ),
      );
      expect(await engine.evaluate('42', execution: execution('B')), 42);
    },
  );

  test(
    'close waits for an explicitly retained host commit before confirming cleanup',
    () async {
      final engine = SourceScriptEngine();
      final commit = Completer<void>();
      final entered = Completer<void>();
      engine.setOperationMessageHandler((message, context) {
        context.requiresDrain = true;
        entered.complete();
        return commit.future;
      });
      final call = engine.evaluate('sendMessage({method:"commit"})');
      final assertion = expectLater(call, throwsA(anything));
      await entered.future;
      var closed = false;
      final closing = engine.close().then((_) => closed = true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(closed, false);
      commit.complete();
      await closing;
      await assertion;
      expect(engine.shutdownDiagnostics.values, everyElement(0));
    },
  );

  test(
    'a rejected Promise affects only its own execution and diagnostics omit script contents',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final diagnostic = <Map<String, Object?>>[];
      engine.onDiagnostic = diagnostic.add;
      await engine.evaluate(
        'globalThis.other=new Promise(r=>globalThis.release=r);null',
      );
      final b = engine.evaluate(
        'other.then(()=>42)',
        execution: execution('B'),
      );
      await expectLater(
        engine.evaluate(
          'Promise.resolve().then(()=>{throw Error("secret-keyword")})',
          execution: execution('A'),
        ),
        throwsA(anything),
      );
      await engine.evaluate('release();null');
      expect(await b, 42);
      expect(diagnostic.toString(), isNot(contains('secret-keyword')));
      expect(
        diagnostic.any((e) => e['phase'] == 'running' && e['taskId'] == 'B'),
        true,
      );
    },
  );

  Future<(SourceScriptEngine, _HeldAdapter)> httpEngine({
    MemorySourceSecureSessionStorage? storage,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final handle = SourceRuntimeHandle(
      sourceKey: 'fixture',
      secureStorage: storage ?? MemorySourceSecureSessionStorage(),
      ensureInitialized: (_) async {},
      notifyRuntimeStateChanged: (_) {},
    );
    await handle.session.ensurePrefs();
    final engine = SourceScriptEngine(pluginId: 'fixture');
    handle.runtime.engine = engine;
    final bridge = SourceJsBridgeCookieCapability(activeHandle: () => handle);
    engine.setOperationMessageHandler(
      (message, context) => bridge.handleJsMessageForHandle(
        handle,
        message,
        execution: context.execution,
        runtimeId: engine.runtimeId,
        hostContext: context,
      ),
    );
    final adapter = _HeldAdapter();
    handle.dio.httpClientAdapter = adapter;
    handle.httpGateway.configureCookieBridge();
    addTearDown(() async {
      handle.requestDispose();
      await handle.whenDisposed;
    });
    return (engine, adapter);
  }

  test(
    'cancellation and close drain an HTTP Cookie commit already started',
    () async {
      final storage = _HeldCookieStorage();
      final (engine, adapter) = await httpEngine(storage: storage);
      addTearDown(() {
        if (!storage.resume.isCompleted) storage.resume.complete();
      });
      final call = engine.evaluate(
        'sendMessage({method:"http",url:"https://fixture.test/page",http_method:"GET"})',
        execution: execution('A'),
      );
      final stopped = expectLater(call, throwsA(isA<SourceScriptStopped>()));
      await adapter.started.future;
      adapter.response.complete(
        ResponseBody.fromString(
          'ok',
          200,
          headers: {
            'set-cookie': ['sid=value; Path=/'],
          },
        ),
      );
      await storage.started.future.timeout(const Duration(seconds: 2));
      final receipt = await engine.cancelExecution('A', 'user');
      await stopped;
      var settled = false;
      final settling = receipt.whenSettled.then((_) => settled = true);
      var closed = false;
      final closing = engine.close().then((_) => closed = true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(settled, false);
      expect(closed, false);
      storage.resume.complete();
      await settling;
      await closing;
      expect(engine.shutdownDiagnostics.values, everyElement(0));
      expect(
        storage.values[SourceSecureSessionStorageKeys.cookies('fixture')],
        contains('sid'),
      );
    },
  );

  test(
    'plugin HTTP aborts only after the final shared consumer leaves',
    () async {
      final (engine, adapter) = await httpEngine();
      final a = engine.evaluate(
        'globalThis.shared=sendMessage({method:"http",url:"https://fixture.test/page",http_method:"GET"});shared',
        execution: execution('A'),
      );
      final stoppedA = expectLater(a, throwsA(isA<SourceScriptStopped>()));
      await adapter.started.future;
      final b = engine.evaluate(
        'shared.then(r=>r.body)',
        execution: execution('B'),
      );
      final stoppedB = expectLater(b, throwsA(isA<SourceScriptStopped>()));
      await engine.evaluate('null');
      final receiptA = await engine.cancelExecution('A', 'user');
      await stoppedA;
      await receiptA.whenSettled;
      expect(adapter.aborted.isCompleted, false);
      final receiptB = await engine.cancelExecution('B', 'user');
      await stoppedB;
      await receiptB.whenSettled;
      await adapter.aborted.future.timeout(const Duration(seconds: 2));
      expect(adapter.calls, 1);
      expect(await engine.evaluate('42'), 42);
    },
  );

  test(
    'the last consumer waits for a retained producer resource to drain',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final host = Completer<int>();
      addTearDown(() {
        if (!host.isCompleted) host.complete(0);
      });
      final entered = Completer<SourceHostCallContext>();
      engine.setOperationMessageHandler((message, context) {
        entered.complete(context);
        return host.future;
      });
      await engine.evaluate(
        'globalThis.shared=sendMessage({method:"fixture"});null',
        execution: execution('A'),
      );
      final context = await entered.future;
      final b = engine.evaluate('shared.then(v=>v)', execution: execution('B'));
      final stopped = expectLater(b, throwsA(isA<SourceScriptStopped>()));
      await engine.evaluate('null');
      final first = await engine.cancelExecution('A', 'user');
      await first.whenSettled;
      expect(context.isStopped, false);
      final last = await engine.cancelExecution('B', 'user');
      await stopped;
      await context.whenStopped;
      var settled = false;
      last.whenSettled.then((_) => settled = true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(settled, false);
      host.complete(42);
      await last.whenSettled;
    },
  );

  test(
    'a late browser result cannot commit cookies for stopped work',
    () async {
      final storage = MemorySourceSecureSessionStorage();
      final (engine, _) = await httpEngine(storage: storage);
      final ui = SourceUiService.instance;
      ui.setForeground(true);
      addTearDown(ui.detach);
      final shown = Completer<SourceDialogSession>();
      ui.presenter = (dialog) async {
        dialog.markShown();
        shown.complete(dialog);
        await dialog.whenClosed;
      };
      final call = engine.evaluate(
        '''sendMessage({method:"ui_browser", options:{
      url:"https://fixture.test/",completion:"manual",cookieScopes:[{url:"https://fixture.test/",names:["sid"]}]
    }})''',
        execution: execution('A'),
      );
      final stopped = expectLater(call, throwsA(isA<SourceScriptStopped>()));
      final dialog = await shown.future.timeout(const Duration(seconds: 2));
      final receipt = await engine.cancelExecution('A', 'user');
      await stopped;
      expect(dialog.isClosed, false);
      dialog.completeBrowser({
        'status': 'completed',
        '_cookies': [
          {
            'scopeUrl': 'https://fixture.test/',
            'name': 'sid',
            'value': 'late',
            'domain': 'fixture.test',
            'path': '/',
            'secure': true,
          },
        ],
        '_userAgent': 'Fixture UA',
      });
      await receipt.whenSettled;
      expect(
        storage.values[SourceSecureSessionStorageKeys.cookies('fixture')],
        isNull,
      );
      expect(
        storage.values[SourceSecureSessionStorageKeys.browserUserAgents(
          'fixture',
        )],
        isNull,
      );
    },
  );

  test(
    'a shared plugin HTTP response still reaches the surviving consumer',
    () async {
      final (engine, adapter) = await httpEngine();
      final a = engine.evaluate(
        'globalThis.shared=sendMessage({method:"http",url:"https://fixture.test/page",http_method:"GET"});shared',
        execution: execution('A'),
      );
      final stoppedA = expectLater(a, throwsA(isA<SourceScriptStopped>()));
      await adapter.started.future;
      final b = engine.evaluate(
        'shared.then(r=>r.body)',
        execution: execution('B'),
      );
      await engine.evaluate('null');
      await engine.cancelExecution('A', 'superseded');
      await stoppedA;
      adapter.response.complete(ResponseBody.fromString('ok', 200));
      expect(await b, 'ok');
      expect(adapter.aborted.isCompleted, false);
    },
  );

  test(
    'shared worker delays survive one cancellation and exclusive long delays settle promptly',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final a = engine.evaluate(
        'globalThis.shared=sendMessage({method:"delay",time:150});shared',
        execution: execution('A'),
      );
      final stoppedA = expectLater(a, throwsA(isA<SourceScriptStopped>()));
      final b = engine.evaluate(
        'shared.then(()=>42)',
        execution: execution('B'),
      );
      await engine.evaluate('null');
      await engine.cancelExecution('A', 'user');
      await stoppedA;
      expect(await b, 42);
      final c = engine.evaluate(
        'sendMessage({method:"delay",time:60000})',
        execution: execution('C'),
      );
      final stoppedC = expectLater(c, throwsA(isA<SourceScriptStopped>()));
      await engine.evaluate('null');
      final receipt = await engine.cancelExecution('C', 'user');
      await stoppedC;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      await engine.close();
      expect(engine.shutdownDiagnostics.values, everyElement(0));
    },
  );

  test('a queued command is cancelled before any user side effect', () async {
    final engine = SourceScriptEngine();
    addTearDown(engine.close);
    await engine.evaluate('globalThis.effects=0');
    final busy = engine.evaluate(
      '(()=>{let start=Date.now();while(Date.now()-start<150){};return 1})()',
      execution: execution('busy'),
    );
    final queued = engine.evaluate('++effects', execution: execution('queued'));
    final assertion = expectLater(queued, throwsA(isA<SourceScriptStopped>()));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final receipt = await engine.cancelExecution('queued', 'superseded');
    await busy;
    await assertion;
    await receipt.whenSettled;
    expect(await engine.evaluate('effects'), 0);
  });

  test(
    'active computation stops independently and the same runtime remains usable',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      await engine.ready;
      final running = engine.evaluate(
        'while(true){}',
        execution: execution('A'),
      );
      final assertion = expectLater(
        running,
        throwsA(isA<SourceScriptStopped>()),
      );
      var beats = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => beats++,
      );
      try {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final elapsed = Stopwatch()..start();
        final receipt = await engine.cancelExecution('A', 'user');
        await assertion;
        await receipt.whenSettled.timeout(const Duration(seconds: 2));
        expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
        expect(beats, greaterThan(2));
        expect(await engine.evaluate('42', execution: execution('B')), 42);
        await expectLater(
          engine.evaluate('1', execution: execution('A')),
          throwsA(isA<SourceScriptStopped>()),
        );
      } finally {
        heartbeat.cancel();
      }
    },
  );

  test(
    'cancelling a shared host producer settles its caller but preserves the consumer',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final host = Completer<int>();
      final called = Completer<SourceHostCallContext>();
      engine.setOperationMessageHandler((message, context) {
        called.complete(context);
        return host.future;
      });
      final a = engine.evaluate(
        'globalThis.shared=sendMessage({method:"fixture"});shared',
        execution: execution('A'),
      );
      final stopped = expectLater(a, throwsA(isA<SourceScriptStopped>()));
      final context = await called.future;
      final b = engine.evaluate(
        'shared.then(v=>v+1)',
        execution: execution('B'),
      );
      await engine.evaluate('null');
      final receipt = await engine.cancelExecution('A', 'superseded');
      await stopped;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(context.isStopped, false);
      expect(receipt.sharedResourceCount, greaterThan(0));
      host.complete(41);
      expect(await b, 42);
    },
  );

  test(
    'exclusive host work signals stop but non-interruptible writes drain before settled',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final write = Completer<void>();
      final started = Completer<SourceHostCallContext>();
      engine.setOperationMessageHandler((message, context) {
        started.complete(context);
        return write.future;
      });
      final call = engine.evaluate(
        'sendMessage({method:"write"})',
        execution: execution('A'),
      );
      final assertion = expectLater(call, throwsA(isA<SourceScriptStopped>()));
      final context = await started.future;
      final receipt = await engine.cancelExecution('A', 'user');
      await assertion;
      await context.whenStopped.timeout(const Duration(seconds: 2));
      var settled = false;
      receipt.whenSettled.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, false);
      write.complete();
      await receipt.whenSettled;
    },
  );

  test(
    'returned callbacks retain identity and can be stopped after caller completion',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final callback =
          await engine.evaluate('()=>42', execution: execution('A'))
              as SourceScriptCallback;
      final receipt = await engine.cancelExecution('A', 'ownerDisposed');
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      await expectLater(
        callback.invoke([]),
        throwsA(isA<SourceScriptStopped>()),
      );
      await callback.free();
      await callback.free();
      expect(await engine.evaluate('42'), 42);
    },
  );
}

class _HeldCookieStorage extends MemorySourceSecureSessionStorage {
  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> write(String key, String value) async {
    if (key == SourceSecureSessionStorageKeys.cookies('fixture')) {
      if (!started.isCompleted) started.complete();
      await resume.future;
    }
    await super.write(key, value);
  }
}

class _HeldAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final aborted = Completer<void>();
  final response = Completer<ResponseBody>();
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    if (!started.isCompleted) started.complete();
    return Future.any([
      response.future,
      if (cancelFuture != null)
        cancelFuture.then<ResponseBody>((_) {
          if (!aborted.isCompleted) aborted.complete();
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'fixture cancelled',
          );
        }),
    ]);
  }

  @override
  void close({bool force = false}) {}
}
