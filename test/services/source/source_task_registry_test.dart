import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_task.dart';
import 'package:hazuki/services/source/runtime/source_task_registry.dart';

void main() {
  test(
    'tracks overlapping executions with independent identities and lifetimes',
    () async {
      final registry = SourceTaskRegistry();
      final first = Completer<int>();
      final second = Completer<int>();
      final events = <(SourceTaskSnapshot, SourceTaskEvent)>[];
      final origin = SourceTaskOrigin.standalone();
      Future<int> run(Completer<int> response) => registry.run(
        pluginId: 'plugin',
        method: 'search.load',
        origin: origin,
        observe: (task, event, _, _, _) => events.add((task, event)),
        operation: (task) {
          task.bindRuntime(runtimeId: 'engine', pluginVersion: '1.2');
          return response.future;
        },
      );
      final pendingFirst = run(first);
      final pendingSecond = run(second);
      final active = registry.activeTasks;
      expect(active, hasLength(2));
      expect(active.map((task) => task.taskId).toSet(), hasLength(2));
      expect(active.every((task) => task.runtimeId == 'engine'), isTrue);
      second.complete(2);
      expect(await pendingSecond, 2);
      expect(registry.activeTasks.single.taskId, active.first.taskId);
      first.complete(1);
      expect(await pendingFirst, 1);
      expect(registry.activeTasks, isEmpty);
      // Snapshots remain unchanged after their task completes.
      expect(
        active.every((task) => task.state == SourceTaskState.running),
        isTrue,
      );
      for (final id in active.map((task) => task.taskId)) {
        final history = events
            .where((event) => event.$1.taskId == id)
            .map((e) => e.$1)
            .toList();
        expect(history.map((task) => task.state), [
          SourceTaskState.created,
          SourceTaskState.running,
          SourceTaskState.succeeded,
        ]);
        expect(history.last.pluginVersion, '1.2');
        expect(history.last.ownerId, origin.ownerId);
        expect(history.last.groupId, origin.groupId);
        expect(history.last.startedAt, isNotNull);
        expect(history.last.endedAt, isNotNull);
        expect(history.last.duration, greaterThanOrEqualTo(Duration.zero));
      }
    },
  );

  for (final asynchronous in [false, true]) {
    test(
      'preserves ${asynchronous ? 'async' : 'sync'} errors and finishes once',
      () async {
        final registry = SourceTaskRegistry();
        final failure = StateError('failure');
        final stack = StackTrace.fromString('original stack');
        final events = <SourceTaskSnapshot>[];
        Object? observedError;
        StackTrace? observedStack;
        await expectLater(
          registry.run<int>(
            pluginId: 'plugin',
            method: 'search.load',
            observe: (task, _, _, error, stack) {
              events.add(task);
              if (error != null) {
                observedError = error;
                observedStack = stack;
              }
            },
            operation: (_) {
              if (asynchronous) return Future.error(failure, stack);
              Error.throwWithStackTrace(failure, stack);
            },
          ),
          throwsA(same(failure)),
        );
        expect(registry.activeTasks, isEmpty);
        expect(events.map((task) => task.state), [
          SourceTaskState.created,
          SourceTaskState.running,
          SourceTaskState.failed,
        ]);
        expect(observedError, same(failure));
        expect(observedStack.toString(), stack.toString());
        expect(events.last.runtimeId, isNull);
      },
    );
  }

  test('diagnostics and detached owners cannot alter task outcomes', () async {
    final registry = SourceTaskRegistry();
    expect(
      await registry.run(
        pluginId: 'plugin',
        method: 'search.load',
        origin: SourceTaskOrigin(
          ownerId: 'owner',
          groupId: 'group',
          requestSequence: 1,
          resultDisposition: () => throw StateError('detached'),
        ),
        observe: (_, _, _, _, _) => throw StateError('log failed'),
        operation: (_) => 42,
      ),
      42,
    );
    expect(registry.activeTasks, isEmpty);
  });

  for (final disposition in SourceTaskResultDisposition.values.skip(1)) {
    test('records $disposition independently of execution success', () async {
      final registry = SourceTaskRegistry();
      final events =
          <(SourceTaskEvent, SourceTaskState, SourceTaskResultDisposition)>[];
      expect(
        await registry.run(
          pluginId: 'plugin',
          method: 'search.load',
          origin: SourceTaskOrigin(
            ownerId: 'owner',
            groupId: 'group',
            requestSequence: 7,
            resultDisposition: () => disposition,
          ),
          observe: (task, event, disposition, _, _) {
            events.add((event, task.state, disposition));
          },
          operation: (_) => 42,
        ),
        42,
      );
      expect(events.last, (
        SourceTaskEvent.resultDiscarded,
        SourceTaskState.succeeded,
        disposition,
      ));
      expect(
        events.where((event) => event.$1 == SourceTaskEvent.stateChanged),
        hasLength(3),
      );
      expect(registry.activeTasks, isEmpty);
    });
  }

  test('standalone calls receive independent owners and groups', () async {
    final registry = SourceTaskRegistry();
    final snapshots = <SourceTaskSnapshot>[];
    for (var i = 0; i < 2; i++) {
      await registry.run(
        pluginId: 'plugin',
        method: 'search.load',
        operation: (task) => snapshots.add(task.snapshot),
      );
    }
    expect(snapshots.first.ownerId, isNot(snapshots.last.ownerId));
    expect(snapshots.first.groupId, isNot(snapshots.last.groupId));
  });
}
