import 'dart:async';

import '../models/source_task.dart';

enum SourceTaskEvent { stateChanged, resultDiscarded }

typedef SourceTaskObserver =
    void Function(
      SourceTaskSnapshot task,
      SourceTaskEvent event,
      SourceTaskResultDisposition disposition,
      Object? error,
      StackTrace? stack,
    );

/// Tracks execution, not the caller's timeout or its decision to use a result.
class SourceTaskRegistry {
  final Map<String, SourceTask> _active = {};

  List<SourceTaskSnapshot> get activeTasks =>
      List.unmodifiable(_active.values.map((task) => task.snapshot));

  Future<T> run<T>({
    required String pluginId,
    required String method,
    String? pluginVersion,
    SourceTaskOrigin? origin,
    SourceTaskObserver? observe,
    required FutureOr<T> Function(SourceTask task) operation,
  }) async {
    final task = SourceTask._(
      pluginId: pluginId,
      pluginVersion: pluginVersion,
      method: method,
      origin: origin ?? SourceTaskOrigin.standalone(),
    );
    _active[task.taskId] = task;
    void notify(
      SourceTaskEvent event, {
      SourceTaskResultDisposition disposition =
          SourceTaskResultDisposition.current,
      Object? error,
      StackTrace? stack,
    }) {
      try {
        observe?.call(task.snapshot, event, disposition, error, stack);
      } catch (_) {
        // Diagnostics must never change a plugin result or keep a task alive.
      }
    }

    notify(SourceTaskEvent.stateChanged);
    task._start();
    notify(SourceTaskEvent.stateChanged);
    Object? failure;
    StackTrace? failureStack;
    try {
      final result = await operation(task);
      task._finish(SourceTaskState.succeeded);
      return result;
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
      task._finish(SourceTaskState.failed);
      rethrow;
    } finally {
      _active.remove(task.taskId);
      notify(SourceTaskEvent.stateChanged, error: failure, stack: failureStack);
      try {
        final disposition =
            task._origin.resultDisposition?.call() ??
            SourceTaskResultDisposition.current;
        if (disposition != SourceTaskResultDisposition.current) {
          notify(SourceTaskEvent.resultDiscarded, disposition: disposition);
        }
      } catch (_) {
        // A detached owner cannot affect completion of the underlying task.
      }
    }
  }
}

class SourceTask {
  SourceTask._({
    required this.pluginId,
    required String? pluginVersion,
    required this.method,
    required SourceTaskOrigin origin,
  }) : _pluginVersion = pluginVersion,
       _origin = origin;

  final String taskId = createSourceTaskId();
  final String pluginId;
  final String method;
  final SourceTaskOrigin _origin;
  final DateTime _createdAt = DateTime.now().toUtc();
  final Stopwatch _clock = Stopwatch();
  String? _pluginVersion;
  String? _runtimeId;
  SourceTaskState _state = SourceTaskState.created;
  DateTime? _startedAt;
  DateTime? _endedAt;

  void bindRuntime({
    required String runtimeId,
    required String? pluginVersion,
  }) {
    if (_state != SourceTaskState.running || _runtimeId != null) {
      throw StateError('source_task_runtime_already_bound_or_finished');
    }
    _runtimeId = runtimeId;
    _pluginVersion = pluginVersion ?? _pluginVersion;
  }

  SourceTaskSnapshot get snapshot => SourceTaskSnapshot(
    taskId: taskId,
    pluginId: pluginId,
    pluginVersion: _pluginVersion,
    method: method,
    ownerId: _origin.ownerId,
    groupId: _origin.groupId,
    requestSequence: _origin.requestSequence,
    runtimeId: _runtimeId,
    state: _state,
    createdAt: _createdAt,
    startedAt: _startedAt,
    endedAt: _endedAt,
    duration: _clock.elapsed,
  );

  void _start() {
    _state = SourceTaskState.running;
    _startedAt = DateTime.now().toUtc();
    _clock.start();
  }

  void _finish(SourceTaskState state) {
    if (_endedAt != null) return;
    _clock.stop();
    _endedAt = DateTime.now().toUtc();
    _state = state;
  }
}
