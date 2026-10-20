import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

// This fixture deliberately does not run Flutter initialization in the worker.
class _Runtime extends QuickJsRuntime2 {
  _Runtime(bool enabled, int timeout)
    : super(
        taskControlEnabled: enabled,
        timeout: timeout,
        hostPromiseRejectionHandler: (_) {},
      );
  @override
  JavascriptRuntime init() => this;
}

void _worker(List<dynamic> arguments) {
  final output = arguments[0] as SendPort;
  final commands = ReceivePort();
  final runtime = _Runtime(arguments[1] as bool, arguments[2] as int);
  runtime.evaluate('null');
  final callbacks = <int, JSInvokable>{};
  final hostValues = <Completer<dynamic>>[];
  var nextCallback = 0;
  output.send([0, commands.sendPort, runtime.taskControl?.controlId]);
  void reply(int id, dynamic value, [bool error = false]) {
    if (value is QuickJsTaskStoppedError) {
      output.send([
        id,
        {'stop': value.reason.name, 'token': value.taskToken},
        true,
      ]);
    } else if (value is JSError) {
      output.send([
        id,
        {'error': value.toString()},
        true,
      ]);
    } else if (value is JSInvokable) {
      callbacks[++nextCallback] = value;
      output.send([
        id,
        {'callback': nextCallback},
        false,
      ]);
    } else {
      output.send([id, value, error]);
    }
  }

  commands.listen((dynamic raw) async {
    final message = raw as List<dynamic>;
    final id = message[0] as int;
    try {
      dynamic value;
      switch (message[1]) {
        case 'eval':
          final result = runtime.withTaskContext(
            message[2] as int,
            () => runtime.evaluate(message[3] as String, notifyJobs: false),
          );
          value = result.rawResult;
          if (result.isError) {
            reply(id, value, true);
            return;
          }
        case 'invoke':
          value = runtime.withTaskContext(
            message[2] as int,
            () => callbacks[message[3]]!.invoke([]),
          );
        case 'drain':
          final steps = <Map<String, dynamic>>[];
          for (var checkpoint = 0; checkpoint < 3; checkpoint++) {
            for (var i = 0; i < 256; i++) {
              final step = runtime.executePendingJobStep();
              if (step.status == QuickJsJobStatus.idle) break;
              steps.add({
                'token': step.taskToken,
                'status': step.status.name,
                'reason': step.stopReason?.name,
              });
            }
            await Future<void>.delayed(Duration.zero);
          }
          value = steps;
        case 'host':
          final completer = Completer<dynamic>();
          hostValues.add(completer);
          final setter =
              runtime.evaluate('(v)=>globalThis.host=v').rawResult
                  as JSInvokable;
          runtime.withTaskContext(
            message[2] as int,
            () => setter.invoke([completer.future]),
          );
          setter.free();
        case 'settleHost':
          hostValues[message[2] as int].complete(message[3]);
          await Future<void>.delayed(Duration.zero);
        case 'listenJobs':
          runtime.port.listen((_) => runtime.executePendingJob());
        case 'close':
          for (final callback in callbacks.values) {
            callback.free();
          }
          callbacks.clear();
          runtime.dispose();
          value = {
            'runtimes': QuickJsRuntime2.registeredRuntimeCount,
            'callbacks': callbacks.length,
          };
        case 'exit':
          commands.close();
      }
      if (value is Future) {
        value.then(
          (dynamic result) => reply(id, result),
          onError: (dynamic error) => reply(id, error, true),
        );
      } else {
        reply(id, value);
      }
    } catch (error) {
      reply(id, error is JSError ? error : error.toString(), true);
    }
  });
}

class _Worker {
  final ReceivePort events = ReceivePort();
  final Map<int, Completer<dynamic>> pending = {};
  final Completer<void> ready = Completer<void>();
  late final SendPort commands;
  QuickJsTaskControl? control;
  int nextId = 0;
  Future<void> start({bool enabled = true, int timeout = 5000}) async {
    events.listen((dynamic raw) {
      final message = raw as List<dynamic>;
      if (message[0] == 0) {
        commands = message[1] as SendPort;
        final id = message[2] as int?;
        control = id == null ? null : QuickJsTaskControl.fromId(id);
        ready.complete();
      } else {
        final completer = pending.remove(message[0]);
        if (message[2] == true) {
          completer?.completeError(message[1] as Object);
        } else {
          completer?.complete(message[1]);
        }
      }
    });
    await Isolate.spawn(_worker, [events.sendPort, enabled, timeout]);
    await ready.future.timeout(const Duration(seconds: 10));
  }

  Future<dynamic> call(String action, [dynamic a, dynamic b]) {
    final completer = Completer<dynamic>();
    pending[++nextId] = completer;
    // Attach before any native operation can produce a result.
    completer.future.ignore();
    commands.send([nextId, action, a, b]);
    return completer.future.timeout(const Duration(seconds: 8));
  }

  Future<dynamic> eval(String code, [int token = 0]) =>
      call('eval', token, code);
  Future<void> dispose() async {
    expect(await call('close'), {'runtimes': 0, 'callbacks': 0});
    await call('exit');
    events.close();
  }
}

Matcher _stopped(int token, [String reason = 'cancelled']) => isA<Map>()
    .having((e) => e['stop'], 'stop', reason)
    .having((e) => e['token'], 'token', token);

void main() {
  var controlsBeforeTest = 0;
  setUp(() {
    controlsBeforeTest = QuickJsTaskControl.activeControlCount;
  });
  tearDown(() {
    expect(QuickJsTaskControl.activeControlCount, controlsBeforeTest);
  });

  test(
    'stop racing caller completion preserves the first decision and captured references',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final control = worker.control!;
        for (var i = 0; i < 12; i++) {
          final token = control.register();
          final callback = (await worker.eval('()=>42', token))['callback'];
          final id = control.controlId;
          final stopping = Isolate.run(
            () => QuickJsTaskControl.fromId(id).requestStop(token).name,
          );
          expect(control.complete(token), true);
          expect(await stopping, anyOf('accepted', 'completed'));
          expect(control.requestStop(token), QuickJsStopRequest.completed);
          // The captured callback retains the record until worker cleanup.
          expect(control.taskCount, greaterThan(0));
          expect(callback, isA<int>());
        }
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'active await interruption preserves a different task waiting for a Promise',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        await worker.eval(
          'globalThis.other=new Promise(r=>globalThis.releaseOther=r);null',
        );
        final reading = worker.eval('other.then(v=>v)', b);
        final computing = worker.eval(
          '(async()=>{await 0;while(true){}})()',
          a,
        );
        final assertion = expectLater(computing, throwsA(_stopped(a)));
        await worker.eval('null');
        final draining = worker.call('drain');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final elapsed = Stopwatch()..start();
        worker.control!.requestStop(a);
        await draining;
        await assertion;
        expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
        await worker.eval('releaseOther(42);null');
        await worker.call('drain');
        expect(await reading, 42);
      } finally {
        await worker.dispose();
      }
    },
  );
  for (final enabled in [false, true]) {
    test(
      'host Future completion wakes the job dispatcher (task control: $enabled)',
      () async {
        final worker = _Worker();
        await worker.start(enabled: enabled);
        try {
          await worker.call('host', worker.control?.register() ?? 0);
          final result = worker.eval('(async()=>{return (await host)+1})()');
          await worker.call('listenJobs');
          await worker.call('settleHost', 0, 41);
          expect(await result, 42);
        } finally {
          await worker.dispose();
        }
      },
    );
  }
  test(
    'cancelling the producer caller settles its Dart observer while shared work continues',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        final producing = worker.eval(
          'globalThis.shared=new Promise(r=>globalThis.release=r);shared',
          a,
        );
        final assertion = expectLater(producing, throwsA(_stopped(a)));
        final consuming = worker.eval('shared.then(v=>v+1)', b);
        await worker.eval('null');
        worker.control!.requestStop(a);
        await worker.call('drain');
        await assertion;
        expect(worker.control!.sharedRetainedWorkCount, greaterThan(0));
        await worker.eval('release(41);null');
        await worker.call('drain');
        expect(await consuming, 42);
      } finally {
        await worker.dispose();
      }
    },
  );
  test(
    'settled tasks release every task and work capture before runtime shutdown',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final control = worker.control!;
        final token = control.register();
        final value = worker.eval(
          '(async()=>{await Promise.all([1,2]);return 42})()',
          token,
        );
        await worker.call('drain');
        expect(await value, 42);
        expect(control.complete(token), true);
        await worker.call('drain');
        expect(control.taskCount, 0);
        expect(control.workCount, 0);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'remote callback captures preserve their work until the callback is freed',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final token = worker.control!.register();
        final callback = (await worker.eval('()=>42', token))['callback'];
        worker.control!.requestStop(token);
        worker.control!.complete(token);
        expect(worker.control!.taskCount, 1);
        await expectLater(
          worker.call('invoke', 0, callback),
          throwsA(_stopped(token)),
        );
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'initial async computation and direct functions use native stop markers',
    () async {
      final worker = _Worker();
      await worker.start(timeout: 40);
      try {
        final token = worker.control!.register();
        final result = worker.eval('(async()=>{while(true){}})()', token);
        final assertion = expectLater(
          result,
          throwsA(_stopped(token, 'timedOut')),
        );
        await worker.call('drain');
        await assertion;
        final callback = (await worker.eval('()=>{while(true){}}'))['callback'];
        await expectLater(
          worker.call('invoke', token, callback),
          throwsA(_stopped(token, 'timedOut')),
        );
        await expectLater(
          worker.eval(
            'throw Object.assign(new Error("cancelled"), {host_stop_reason:1,taskToken:$token})',
          ),
          throwsA(
            isA<Map>().having(
              (e) => e['stop'],
              'private native marker',
              isNull,
            ),
          ),
        );
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'native result observation never invokes a plugin replacement for then',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        await worker.eval('globalThis.effects=0;null');
        final token = worker.control!.register();
        final result = worker.eval(
          '(()=>{const p=Promise.resolve(42);p.then=()=>{effects++;throw Error("custom then")};return p})()',
          token,
        );
        await worker.call('drain');
        expect(await result, 42);
        expect(await worker.eval('effects'), 0);
      } finally {
        await worker.dispose();
      }
    },
  );
  test(
    'A can stop while an independent B is computing, and later tasks still run',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        final waiting = worker.eval(
          '(async()=>{await new Promise(()=>{});return 1})()',
          a,
        );
        final assertion = expectLater(waiting, throwsA(_stopped(a)));
        final computing = worker.eval(
          '(()=>{const start=Date.now();while(Date.now()-start<180){};return 42})()',
          b,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        worker.control!.requestStop(a);
        expect(await computing, 42);
        await worker.call('drain');
        await assertion;
        expect(await worker.eval('42', worker.control!.register()), 42);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'last consumer departure releases protection of a running shared producer',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        final producing = worker.eval(
          'globalThis.shared=Promise.resolve().then(()=>{while(true){}});shared',
          a,
        );
        final stoppedA = expectLater(producing, throwsA(_stopped(a)));
        final consuming = worker.eval('shared.then(v=>v)', b);
        final stoppedB = expectLater(consuming, throwsA(_stopped(b)));
        await worker.eval('null');
        final draining = worker.call('drain');
        await Future<void>.delayed(const Duration(milliseconds: 70));
        worker.control!.requestStop(a);
        expect(worker.control!.sharedRetainedWorkCount, greaterThan(0));
        await Future<void>.delayed(const Duration(milliseconds: 70));
        final elapsed = Stopwatch()..start();
        worker.control!.requestStop(b);
        await draining;
        await stoppedA;
        await stoppedB;
        expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
        expect(await worker.eval('42'), 42);
      } finally {
        await worker.dispose();
      }
    },
  );

  for (final combination in ['all', 'race', 'any', 'allSettled']) {
    test(
      '$combination preserves shared dependencies across cancelled consumer branches',
      () async {
        final worker = _Worker();
        await worker.start();
        try {
          await worker.eval(
            'globalThis.effects=[];globalThis.shared=new Promise(r=>globalThis.release=r);null',
          );
          final a = worker.control!.register();
          final b = worker.control!.register();
          final cancelled = worker.eval(
            'Promise.$combination([shared]).then(v=>{effects.push("A");return v})',
            a,
          );
          final assertion = expectLater(cancelled, throwsA(_stopped(a)));
          final reading = worker.eval(
            'Promise.$combination([shared]).then(v=>{effects.push("B");return v})',
            b,
          );
          await worker.eval('null');
          worker.control!.requestStop(a);
          await worker.call('drain');
          await assertion;
          await worker.eval('release(42);null');
          await worker.call('drain');
          final result = await reading;
          if (combination == 'all') {
            expect(result, [42]);
          }
          if (combination == 'race' || combination == 'any') {
            expect(result, 42);
          }
          if (combination == 'allSettled') {
            expect(result, [
              {'status': 'fulfilled', 'value': 42},
            ]);
          }
          expect(await worker.eval('effects'), ['B']);
        } finally {
          await worker.dispose();
        }
      },
    );
  }

  test(
    'thenables, adoption and finally preserve a live consumer of a cancelled producer',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        await worker.eval(
          'globalThis.shared=Promise.resolve({then(resolve){globalThis.release=resolve}});null',
          a,
        );
        await worker.call('drain');
        final reading = worker.eval(
          '(async()=>{return await Promise.resolve(shared).finally(()=>{})})()',
          b,
        );
        await worker.eval('null');
        worker.control!.requestStop(a);
        await worker.call('drain');
        await worker.eval('release(42);null');
        await worker.call('drain');
        expect(await reading, 42);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'cancelled adoption cycles settle and a terminated producer rejects late subscriptions',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final cycle = worker.eval(
          'globalThis.p=new Promise(r=>globalThis.rp=r);globalThis.q=new Promise(r=>globalThis.rq=r);rp(q);rq(p);p',
          a,
        );
        final assertion = expectLater(cycle, throwsA(_stopped(a)));
        await worker.call('drain');
        worker.control!.requestStop(a);
        await worker.call('drain');
        await assertion;
        final b = worker.control!.register();
        final late = worker.eval('p.then(()=>"must not run")', b);
        final lateAssertion = expectLater(late, throwsA(_stopped(a)));
        await worker.call('drain');
        await lateAssertion;
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'host Future production stays alive for another task and preserves byte slices',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        await worker.call('host', a);
        final reading = worker.eval('host.then(v=>v)', b);
        await worker.eval('null');
        worker.control!.requestStop(a);
        await worker.call('drain');
        final original = Uint8List.fromList([8, 0, 128, 255, 9]);
        final slice = Uint8List.sublistView(original, 1, 4);
        await worker.call('settleHost', 0, slice);
        await worker.call('drain');
        expect(await reading, [0, 128, 255]);
        expect(original, [8, 0, 128, 255, 9]);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'registration, stopping and completion racing close never retain a control',
    () async {
      final baseline = QuickJsTaskControl.activeControlCount;
      for (var round = 0; round < 5; round++) {
        final worker = _Worker();
        await worker.start();
        final id = worker.control!.controlId;
        final racing = Isolate.run(() {
          final control = QuickJsTaskControl.fromId(id);
          for (var i = 0; i < 200; i++) {
            try {
              final token = control.register();
              control.requestStop(token);
              control.complete(token);
            } on StateError {
              break;
            }
          }
        });
        await worker.dispose();
        await racing;
        expect(QuickJsTaskControl.activeControlCount, baseline);
      }
    },
  );
  test(
    'control IDs and task tokens are unique; invalid, repeated and completed stops are explicit',
    () async {
      final baseline = QuickJsTaskControl.activeControlCount;
      final seen = <int>{};
      for (var i = 0; i < 4; i++) {
        final worker = _Worker();
        await worker.start();
        final control = worker.control!;
        expect(seen.add(control.controlId), true);
        final a = control.register();
        final b = control.register();
        expect(seen.add(a), true);
        expect(seen.add(b), true);
        expect(control.requestStop(a), QuickJsStopRequest.accepted);
        expect(control.requestStop(a), QuickJsStopRequest.alreadyRequested);
        expect(control.requestStop(0), QuickJsStopRequest.invalid);
        expect(control.complete(a), true);
        expect(control.complete(a), false);
        expect(control.complete(b), true);
        expect(control.taskCount, 0);
        expect(control.workCount, 0);
        await worker.dispose();
        expect(control.requestStop(a), QuickJsStopRequest.invalid);
        expect(control.register, throwsStateError);
      }
      expect(QuickJsTaskControl.activeControlCount, baseline);
    },
  );

  test(
    'pre-cancelled eval and direct calls execute no user side effects',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        await worker.eval('globalThis.effects=0;null');
        final fn = (await worker.eval('()=>++effects'))['callback'];
        final token = worker.control!.register();
        worker.control!.requestStop(token);
        await expectLater(
          worker.eval('++effects', token),
          throwsA(_stopped(token)),
        );
        await expectLater(
          worker.call('invoke', token, fn),
          throwsA(_stopped(token)),
        );
        expect(await worker.eval('effects'), 0);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'native active cancellation interrupts a loop while main heartbeats advance',
    () async {
      final worker = _Worker();
      await worker.start();
      var beats = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => beats++,
      );
      try {
        final token = worker.control!.register();
        final result = worker.eval('while(true){}', token);
        final assertion = expectLater(result, throwsA(_stopped(token)));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final elapsed = Stopwatch()..start();
        expect(worker.control!.requestStop(token), QuickJsStopRequest.accepted);
        await assertion;
        expect(elapsed.elapsed, lessThan(const Duration(seconds: 2)));
        expect(beats, greaterThan(2));
        expect(await worker.eval('21*2'), 42);
      } finally {
        heartbeat.cancel();
        await worker.dispose();
      }
    },
  );

  test(
    'timeouts and ordinary errors cannot impersonate task cancellation',
    () async {
      final worker = _Worker();
      await worker.start(timeout: 40);
      try {
        final token = worker.control!.register();
        await expectLater(
          worker.eval('while(true){}', token),
          throwsA(_stopped(token, 'timedOut')),
        );
        await expectLater(
          worker.eval('throw new Error("interrupted")', token),
          throwsA(
            isA<Map>().having(
              (e) => e['stop'],
              'not a native stop marker',
              isNull,
            ),
          ),
        );
        expect(await worker.eval('42'), 42);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'cancelled await and then branches settle observers without running catch or finally',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        await worker.eval(
          'globalThis.effects=[];globalThis.shared=new Promise(r=>globalThis.release=r);null',
        );
        final a = worker.control!.register();
        final b = worker.control!.register();
        final waiting = worker.eval(
          '(async()=>{try {await shared;effects.push("A")}catch(e){effects.push("catch")}finally{effects.push("finally")}})()',
          a,
        );
        final stopped = expectLater(waiting, throwsA(_stopped(a)));
        final reading = worker.eval(
          'shared.then(()=>{effects.push("B");return 42})',
          b,
        );
        await worker.eval('null'); // registration barrier
        worker.control!.requestStop(a);
        await worker.call('drain');
        await stopped;
        await worker.eval('release();null');
        await worker.call('drain');
        expect(await reading, 42);
        expect(await worker.eval('effects'), ['B']);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'shared producer survives cancellation until its last live consumer leaves',
    () async {
      final worker = _Worker();
      await worker.start();
      try {
        final a = worker.control!.register();
        final b = worker.control!.register();
        await worker.eval(
          'globalThis.shared=new Promise(r=>globalThis.release=r);null',
          a,
        );
        final consumer = worker.eval('shared.then(v=>v+1)', b);
        await worker.eval('null');
        worker.control!.requestStop(a);
        expect(worker.control!.sharedRetainedWorkCount, greaterThan(0));
        await worker.call('drain');
        await worker.eval('release(41);null');
        await worker.call('drain');
        expect(await consumer, 42);
        worker.control!.complete(b);
        worker.control!.requestStop(a);
        await worker.call('drain');
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'Promise jobs and await computations stop with the actual job identity',
    () async {
      final worker = _Worker();
      await worker.start(timeout: 40);
      try {
        for (final script in [
          'Promise.resolve().then(()=>{while(true){}})',
          '(async()=>{await 0;while(true){}})()',
        ]) {
          final token = worker.control!.register();
          final result = worker.eval(script, token);
          final assertion = expectLater(
            result,
            throwsA(_stopped(token, 'timedOut')),
          );
          final steps = await worker.call('drain') as List;
          expect(
            steps,
            contains(
              isA<Map>()
                  .having((e) => e['token'], 'job token', token)
                  .having((e) => e['reason'], 'reason', 'timedOut'),
            ),
          );
          await assertion;
        }
        expect(await worker.eval('42'), 42);
      } finally {
        await worker.dispose();
      }
    },
  );

  test(
    'late host Future completions after close never access a freed runtime',
    () async {
      final worker = _Worker();
      await worker.start();
      await worker.call('host', worker.control!.register());
      await worker.call('close');
      await worker.call('settleHost', 0, 'late');
      await worker.call('exit');
      worker.events.close();
    },
  );

  test(
    'task control is opt-in and legacy unknown contexts still run',
    () async {
      final worker = _Worker();
      await worker.start(enabled: false);
      try {
        expect(worker.control, isNull);
        expect(await worker.eval('42', 123), 42);
      } finally {
        await worker.dispose();
      }
    },
  );
}
