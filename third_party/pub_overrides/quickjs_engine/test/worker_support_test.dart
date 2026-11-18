import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quickjs_engine/quickjs_engine.dart';

void main() {
  test(
    'native byte mailboxes wake another isolate and reject duplicate or late replies',
    () async {
      final baseline = QuickJsHostReply.count;
      final id = QuickJsHostReply.create();
      final response = Isolate.run(() => QuickJsHostReply.wait(id, 2000));
      expect(
        QuickJsHostReply.complete(id, Uint8List.fromList([0, 128, 255])),
        true,
      );
      expect(QuickJsHostReply.complete(id, Uint8List.fromList([9])), false);
      expect(await response, [0, 128, 255]);
      QuickJsHostReply.close(id);
      expect(QuickJsHostReply.complete(id, Uint8List(0)), false);
      QuickJsHostReply.close(id);
      expect(QuickJsHostReply.count, baseline);
    },
  );
  test(
    'closing and timing out a mailbox do not retain its allocation',
    () async {
      final baseline = QuickJsHostReply.count;
      final id = QuickJsHostReply.create();
      final waiting = Isolate.run(() {
        try {
          QuickJsHostReply.wait(id, 2000);
          return false;
        } catch (_) {
          return true;
        }
      });
      QuickJsHostReply.close(id);
      expect(await waiting, true);
      final timeout = QuickJsHostReply.create();
      try {
        expect(() => QuickJsHostReply.wait(timeout, 1), throwsStateError);
      } finally {
        QuickJsHostReply.close(timeout);
      }
      expect(QuickJsHostReply.count, baseline);
    },
  );
  test(
    'await, shared promise, thenables and combinations restore registration context and free references',
    () async {
      final references = <int, int>{};
      final seen = <int>[];
      final runtime = QuickJsRuntime2(
        taskReferenceHandler: (token, delta) {
          references[token] = (references[token] ?? 0) + delta;
        },
      );
      try {
        final setter =
            runtime.evaluate('(callback)=>globalThis.report=callback').rawResult
                as JSInvokable;
        setter.invoke([
          () {
            seen.add(runtime.taskContext);
            return runtime.taskContext;
          },
        ]);
        setter.free();
        runtime.evaluate(
          'globalThis.shared=new Promise(r=>globalThis.release=r);null;',
        );
        runtime.withTaskContext(
          11,
          () => runtime.evaluate('''
        (async()=>{await shared;await {then(resolve){resolve(1)}};
          await Promise.all([Promise.resolve(1),Promise.resolve(2)]);
          report();return true;})()
      '''),
        );
        runtime.withTaskContext(
          22,
          () => runtime.evaluate('shared.then(()=>report());null;'),
        );
        runtime.withTaskContext(33, () => runtime.evaluate('release();null;'));
        runtime.executePendingJob();
        await Future<void>.delayed(Duration.zero);
        runtime.executePendingJob();
        expect(seen, containsAll([11, 22]));
        expect(seen, isNot(contains(33)));
        expect(runtime.taskContext, 0);
      } finally {
        runtime.dispose();
      }
      expect(
        references.values.every((value) => value == 0),
        true,
        reason: 'all captured jobs and reactions must release their contexts',
      );
    },
  );
}
