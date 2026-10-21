import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_script_execution.dart';
import 'package:hazuki/services/source/runtime/source_host_call_context.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_shared_request.dart';
import 'package:hazuki/services/source/runtime/source_task_registry.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceTaskRegistry registry;
  setUp(() {
    registry = SourceTaskRegistry();
    addTearDown(registry.dispose);
  });

  const origin = SourceTaskOrigin(
    ownerId: 'page',
    groupId: 'query',
    requestSequence: 1,
  );

  test(
    'cancellation detaches initialization and prevents later commands',
    () async {
      final ready = Completer<void>();
      var commands = 0;
      final pending = registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: origin,
        operation: (task) async {
          await ready.future;
          task.checkActive();
          commands++;
          return 42;
        },
      );
      final taskId = registry.activeTasks.single.taskId;
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      final receipt = await registry.cancelOwner(
        'page',
        SourceTaskStopReason.ownerDisposed,
      );
      expect(receipt.status, SourceTaskCancelStatus.accepted);
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      await stopped;
      expect(registry.activeTasks, isEmpty);
      expect(
        (await registry.cancelTask(taskId, SourceTaskStopReason.user)).status,
        SourceTaskCancelStatus.alreadyRequested,
      );
      ready.complete();
      await Future<void>.delayed(Duration.zero);
      expect(commands, 0);
    },
  );

  test(
    'cancellation wins an unresolved result and finished success is immutable',
    () async {
      final result = Completer<int>();
      final pending = registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: origin,
        operation: (_) => result.future,
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      result.complete(42);
      final receipt = await registry.cancelOwner(
        'page',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      await receipt.whenSettled;
      expect(
        await registry.run(
          pluginId: 'one',
          method: 'search.load',
          origin: origin,
          operation: (_) => 7,
        ),
        7,
      );
      expect(
        (await registry.cancelOwner('page', SourceTaskStopReason.user)).status,
        SourceTaskCancelStatus.alreadyFinished,
      );
      expect(
        (await registry.cancelTask(
          'missing',
          SourceTaskStopReason.user,
        )).status,
        SourceTaskCancelStatus.notFound,
      );
    },
  );

  test('group filters leave other sources and owners active', () async {
    final responses = List.generate(3, (_) => Completer<int>());
    final futures = [
      for (var i = 0; i < 3; i++)
        registry.run(
          pluginId: i == 1 ? 'two' : 'one',
          method: 'search.load',
          origin: i == 2
              ? const SourceTaskOrigin(
                  ownerId: 'other-page',
                  groupId: 'query',
                  requestSequence: 1,
                )
              : origin,
          operation: (_) => responses[i].future,
        ),
    ];
    final stopped = expectLater(
      futures[0],
      throwsA(isA<SourceTaskCancelled>()),
    );
    final receipt = await registry.cancelGroup(
      ownerId: 'page',
      groupId: 'query',
      pluginId: 'one',
      reason: SourceTaskStopReason.superseded,
    );
    await stopped;
    await receipt.whenSettled;
    expect(registry.activeTasks, hasLength(2));
    responses[0].complete(0);
    responses[1].complete(1);
    responses[2].complete(2);
    expect(await futures[1], 1);
    expect(await futures[2], 2);
  });

  test(
    'host cancellation interrupts CPU work and leaves the same engine usable',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final started = Completer<void>();
      engine.setMessageHandler((_) {
        started.complete();
        return null;
      });
      final pending = registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: origin,
        operation: (task) {
          task.bindRuntime(
            runtimeId: engine.runtimeId,
            pluginVersion: '1',
            engine: engine,
          );
          return engine.evaluate(
            'sendMessage({started:true}); while(true) {}',
            execution: SourceScriptExecution.fromTask(task.snapshot),
          );
        },
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await started.future.timeout(const Duration(seconds: 2));
      final receipt = await registry.cancelOwner(
        'page',
        SourceTaskStopReason.superseded,
      );
      await stopped.timeout(const Duration(seconds: 2));
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(await engine.evaluate('42'), 42);
    },
  );

  test(
    'a successful task retains resource ownership and drains started writes',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final response = Completer<int>();
      final started = Completer<SourceHostCallContext>();
      engine.setOperationMessageHandler((_, context) {
        context.requiresDrain = true;
        started.complete(context);
        return response.future;
      });
      final states = <SourceTaskState>[];
      final pending = registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: origin,
        observe: (task, event, disposition, error, stack) {
          states.add(task.state);
        },
        operation: (task) {
          task.bindRuntime(
            runtimeId: engine.runtimeId,
            pluginVersion: '1',
            engine: engine,
          );
          return engine.evaluate(
            'sendMessage({write:true}); 42',
            execution: SourceScriptExecution.fromTask(task.snapshot),
          );
        },
      );
      expect(await pending, 42);
      final context = await started.future;
      expect(registry.activeTasks, isEmpty);
      final receipt = await registry.cancelOwner(
        'page',
        SourceTaskStopReason.ownerDisposed,
      );
      expect(receipt.status, SourceTaskCancelStatus.accepted);
      await context.whenStopped.timeout(const Duration(seconds: 2));
      var settled = false;
      receipt.whenSettled.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      response.complete(7);
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(states.last, SourceTaskState.succeeded);
      expect(states, isNot(contains(SourceTaskState.cancelled)));
    },
  );

  test(
    'native shared producers survive cancellation of one business task',
    () async {
      final engine = SourceScriptEngine();
      addTearDown(engine.close);
      final response = Completer<int>();
      final started = Completer<SourceHostCallContext>();
      engine.setOperationMessageHandler((_, context) {
        started.complete(context);
        return response.future;
      });
      Future<dynamic> run(String owner, String code) => registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: SourceTaskOrigin(
          ownerId: owner,
          groupId: 'query',
          requestSequence: 1,
        ),
        operation: (task) {
          task.bindRuntime(
            runtimeId: engine.runtimeId,
            pluginVersion: '1',
            engine: engine,
          );
          return engine.evaluate(
            code,
            execution: SourceScriptExecution.fromTask(task.snapshot),
          );
        },
      );
      final first = run('page', 'globalThis.shared=sendMessage({});shared');
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final context = await started.future;
      // The barrier confirms B has installed its reaction before cancellation.
      final barrier = Completer<void>();
      engine.setMessageHandler((_) {
        barrier.complete();
        return 0;
      });
      final second = run(
        'other',
        'const p=shared.then(v=>v+1);sendMessage({barrier:true});p',
      );
      await barrier.future;
      final receipt = await registry.cancelOwner(
        'page',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(context.isStopped, isFalse);
      expect(receipt.sharedResourceCount, greaterThan(0));
      response.complete(41);
      expect(await second, 42);
    },
  );

  testWidgets('work budgets pause while the owned scope waits for input', (
    tester,
  ) async {
    final response = Completer<int>();
    final lifetime = SourceTaskCancellation();
    late SourceUiScope scope;
    final pending = SourceUiService.instance.run(
      () => registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: SourceTaskOrigin(
          ownerId: 'page',
          groupId: 'query',
          requestSequence: 1,
          cancellation: lifetime,
          workTimeout: const Duration(milliseconds: 25),
        ),
        operation: (_) {
          scope = SourceUiScope.current!;
          scope.setWaiting(true);
          return response.future;
        },
      ),
    );
    final stopped = expectLater(pending, throwsA(isA<SourceTaskTimedOut>()));
    await tester.pump(const Duration(minutes: 1));
    expect(registry.activeTasks.single.state, SourceTaskState.running);
    scope.setWaiting(false);
    await tester.pump(const Duration(seconds: 1));
    await stopped;
    response.complete(42);
    await tester.pump();
    expect(registry.activeTasks, isEmpty);
  });

  test(
    'observer re-entry preserves a single stop reason and receipt',
    () async {
      final result = Completer<int>();
      Future<SourceTaskCancelReceipt>? repeated;
      final pending = registry.run(
        pluginId: 'one',
        method: 'search.load',
        origin: origin,
        observe: (task, event, disposition, error, stack) {
          if (task.state == SourceTaskState.cancelRequested &&
              repeated == null) {
            repeated = registry.cancelTask(
              task.taskId,
              SourceTaskStopReason.user,
            );
          }
        },
        operation: (_) => result.future,
      );
      final stopped = expectLater(
        pending,
        throwsA(
          isA<SourceTaskCancelled>().having(
            (error) => error.reason,
            'reason',
            SourceTaskStopReason.superseded,
          ),
        ),
      );
      final first = await registry.cancelOwner(
        'page',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      final second = await repeated!;
      expect(second.status, SourceTaskCancelStatus.alreadyRequested);
      await Future.wait([first.whenSettled, second.whenSettled]);
      result.complete(42);
    },
  );

  test('a stopped dependency is a failure, not a user cancellation', () async {
    SourceTaskState? state;
    await expectLater(
      registry.run<int>(
        pluginId: 'one',
        method: 'search.load',
        observe: (task, event, disposition, error, stack) {
          state = task.state;
        },
        operation: (_) => throw SourceScriptStopped(
          execution: const SourceScriptExecution(
            taskId: 'dependency',
            pluginId: 'one',
            method: 'test',
          ),
          runtimeId: 'runtime',
          nativeToken: 1,
          reason: 'dependencyStopped',
        ),
      ),
      throwsA(isA<SourceScriptStopped>()),
    );
    expect(state, SourceTaskState.failed);
  });

  testWidgets(
    'shared input waiting is counted independently for each producer',
    (tester) async {
      final responses = List.generate(2, (_) => Completer<int>());
      final scopes = <SourceUiScope>[];
      final requests = [
        for (var i = 0; i < 2; i++)
          SourceSharedRequest<int>(
            pluginId: 'one',
            method: 'comic.loadInfo',
            onUnavailable: () {},
            operation: (_) {
              final scope = SourceUiScope.current!;
              scopes.add(scope);
              scope.setWaiting(true);
              return responses[i].future;
            },
          ),
      ];
      late SourceUiScope subscriberScope;
      final pending = SourceUiService.instance.run(
        () => registry.run(
          pluginId: 'one',
          method: 'search.directId',
          origin: const SourceTaskOrigin(
            ownerId: 'page',
            groupId: 'query',
            requestSequence: 1,
            workTimeout: Duration(milliseconds: 25),
          ),
          operation: (task) {
            subscriberScope = SourceUiScope.current!;
            return Future.wait(
              requests.map((request) => request.subscribe(task: task)),
            );
          },
        ),
      );
      await tester.pump(const Duration(minutes: 1));
      expect(subscriberScope.waiting, isTrue);
      scopes[0].setWaiting(false);
      responses[0].complete(20);
      await tester.pump();
      expect(subscriberScope.waiting, isTrue);
      await tester.pump(const Duration(minutes: 1));
      expect(registry.activeTasks.single.state, SourceTaskState.running);
      scopes[1].setWaiting(false);
      responses[1].complete(22);
      await tester.pump();
      expect(await pending, [20, 22]);
      expect(registry.activeTasks, isEmpty);
    },
  );
}
