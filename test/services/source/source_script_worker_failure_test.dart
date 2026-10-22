import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/models/source_task.dart';
import 'package:hazuki/services/source/runtime/source_host_call_context.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';

SourceScriptExecution execution(String id) =>
    SourceScriptExecution(taskId: id, pluginId: 'fixture', method: 'test.$id');

Matcher _failedWith(SourceRuntimeFailureKind kind, {String? taskId}) =>
    isA<SourceRuntimeFailed>()
        .having((e) => e.kind, 'kind', kind)
        .having((e) => e.taskId, 'taskId', taskId);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an internal job failure fails pending and new calls with a typed runtime failure',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(() => _closeQuietly(engine));
      final host = Completer<int>();
      engine.setMessageHandler((_) => host.future);
      await engine.ready;
      late SourceUiScope scope;
      final pending = SourceUiService.instance.run(() {
        scope = SourceUiScope.current!;
        return engine.evaluate(
          '(async()=>await sendMessage({}))()',
          execution: execution('A'),
        );
      }, abortOnScopeCancellation: false);
      final assertion = expectLater(
        pending,
        throwsA(_failedWith(SourceRuntimeFailureKind.internalJob, taskId: 'A')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      engine.debugInjectFault('internalJob');

      await assertion;
      final failure = await engine.whenFailed.timeout(
        const Duration(seconds: 2),
      );
      expect(failure.kind, SourceRuntimeFailureKind.internalJob);
      expect(failure.runtimeId, engine.runtimeId);
      expect(failure.toString(), 'source_runtime_failed:internalJob');
      expect(identical(engine.failure, failure), isTrue);
      // 故障以独立原因撤销交互，而不是正常退役的 runtimeDisposed。
      expect(scope.reason, 'runtimeFailed');
      expect(scope.failure, same(failure));
      await expectLater(
        engine.evaluate('1', execution: execution('B')),
        throwsA(_failedWith(SourceRuntimeFailureKind.internalJob, taskId: 'B')),
      );
      await expectLater(engine.whenClosed, throwsA(anything));
      expect(engine.shutdownDiagnostics['nativeRuntimes'], 0);
    },
  );

  test('normal close never reports a runtime failure', () async {
    final engine = SourceScriptEngine();
    await engine.ready;
    expect(await engine.evaluate('1'), 1);
    var failed = false;
    unawaited(engine.whenFailed.then((_) => failed = true));
    await engine.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(failed, isFalse);
    expect(engine.failure, isNull);
    await expectLater(engine.evaluate('1'), throwsStateError);
  });

  test(
    'an interrupted computation runs one healthy probe and the runtime stays usable',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(() => _closeQuietly(engine));
      final probes = <Map<String, Object?>>[];
      engine.onDiagnostic = (data) {
        if (data['phase'] == 'runtimeProbe') probes.add(data);
      };
      await engine.ready;
      final runtimeId = engine.runtimeId;
      final running = engine.evaluate(
        'while(true){}',
        execution: execution('A'),
      );
      final assertion = expectLater(
        running,
        throwsA(isA<SourceScriptStopped>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final receipt = await engine.cancelExecution('A', 'user');
      await assertion;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(await engine.evaluate('42', execution: execution('B')), 42);
      expect(probes, hasLength(1));
      expect(probes.single['healthy'], isTrue);
      expect(probes.single['runtimeId'], runtimeId);
      expect(engine.runtimeId, runtimeId);
      expect(engine.failure, isNull);
    },
  );

  test('a command cancelled while queued does not run a probe', () async {
    final engine = SourceScriptEngine();
    addTearDown(() => _closeQuietly(engine));
    var probes = 0;
    engine.onDiagnostic = (data) {
      if (data['phase'] == 'runtimeProbe') probes++;
    };
    await engine.ready;
    final host = Completer<int>();
    engine.setMessageHandler((_) => host.future);
    // 前一条命令持有宿主等待，后一条在入队后、进入 JS 前取消。
    final busy = engine.evaluate(
      '(async()=>await sendMessage({}))()',
      execution: execution('busy'),
    );
    final queued = engine.evaluate('1', execution: execution('queued'));
    final assertion = expectLater(queued, throwsA(isA<SourceScriptStopped>()));
    final receipt = await engine.cancelExecution('queued', 'superseded');
    await assertion;
    host.complete(7);
    expect(await busy, 7);
    await receipt.whenSettled;
    expect(await engine.evaluate('2'), 2);
    expect(probes, 0);
  });

  test('a failed probe turns into a typed runtime failure', () async {
    final engine = SourceScriptEngine();
    addTearDown(() => _closeQuietly(engine));
    await engine.ready;
    engine.debugInjectFault('probe');
    final running = engine.evaluate('while(true){}', execution: execution('A'));
    final assertion = expectLater(running, throwsA(anything));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await engine.cancelExecution('A', 'user');
    await assertion;
    final failure = await engine.whenFailed.timeout(const Duration(seconds: 2));
    expect(failure.kind, SourceRuntimeFailureKind.probeFailed);
    await expectLater(
      engine.evaluate('1', execution: execution('B')),
      throwsA(_failedWith(SourceRuntimeFailureKind.probeFailed, taskId: 'B')),
    );
  });

  // 以下两项让 worker 不经正常释放就退出，放在本文件最后，避免影响资源基线。
  test('an uncaught worker error is a workerError failure', () async {
    final engine = SourceScriptEngine();
    addTearDown(() => _closeQuietly(engine));
    await engine.ready;
    engine.debugInjectFault('workerError');
    final failure = await engine.whenFailed.timeout(const Duration(seconds: 5));
    expect(failure.kind, SourceRuntimeFailureKind.workerError);
    await expectLater(
      engine.evaluate('1'),
      throwsA(_failedWith(SourceRuntimeFailureKind.workerError)),
    );
  });

  test('a worker exit without cleanup is reported as such', () async {
    final engine = SourceScriptEngine();
    addTearDown(() => _closeQuietly(engine));
    await engine.ready;
    engine.debugInjectFault('exitWithoutCleanup');
    final failure = await engine.whenFailed.timeout(const Duration(seconds: 5));
    expect(failure.kind, SourceRuntimeFailureKind.exitedWithoutCleanup);
    await expectLater(engine.whenClosed, throwsA(anything));
  });
}

/// 故障实例的 whenClosed 以故障原因结束；测试收尾只确认释放流程结束。
Future<void> _closeQuietly(SourceScriptEngine engine) =>
    engine.close().catchError((Object _) {});
