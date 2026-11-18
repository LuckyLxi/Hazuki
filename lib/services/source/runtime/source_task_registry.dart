import 'dart:async';

import '../gateways/source_task_control_gateway.dart';
import '../interaction/source_ui_scope.dart';
import '../models/source_task.dart';
import 'source_host_call_context.dart';
import 'source_script_engine.dart';

enum SourceTaskEvent { stateChanged, resultDiscarded, resourcesSettled }

typedef SourceTaskObserver =
    void Function(
      SourceTaskSnapshot task,
      SourceTaskEvent event,
      SourceTaskResultDisposition disposition,
      Object? error,
      StackTrace? stack,
    );

/// Business results and retained runtime resources have separate lifetimes.
class SourceTaskRegistry implements SourceTaskControlGateway {
  final Map<String, SourceTask> _tasks = {};
  final Map<String, SourceTaskSnapshot> _finished = {};
  final Expando<SourceTaskStopReason> _retiredResources = Expando();
  bool _disposed = false;

  List<SourceTaskSnapshot> get activeTasks => List.unmodifiable(
    _tasks.values
        .where((task) => task._endedAt == null)
        .map((task) => task.snapshot),
  );

  Future<T> run<T>({
    required String pluginId,
    required String method,
    String? pluginVersion,
    SourceTaskOrigin? origin,
    SourceTaskObserver? observe,
    bool linkUiCancellation = true,
    required FutureOr<T> Function(SourceTask task) operation,
  }) async {
    if (_disposed) throw StateError('source_task_registry_disposed');
    final task = SourceTask._(
      pluginId: pluginId,
      pluginVersion: pluginVersion,
      method: method,
      origin: origin ?? SourceTaskOrigin.standalone(),
      observe: observe,
      onResourcesChanged: _prune,
      checkResourceActive: checkResourceActive,
    );
    _tasks[task.taskId] = task;
    task._notify(SourceTaskEvent.stateChanged);
    task._start();
    task._notify(SourceTaskEvent.stateChanged);
    final cancellation = task._origin.cancellation;
    void stopped() {
      final reason = cancellation?.reason;
      if (reason != null) task._requestStop(reason);
    }

    cancellation?.addListener(stopped);
    stopped();
    final session =
        task._origin.readerSession ??
        task._origin.downloadSession ??
        task._origin.serviceLease;
    void sessionStopped() {
      if (session?.cancellation.reason case final reason?) {
        task._requestStop(reason);
      }
    }

    session?.cancellation.addListener(sessionStopped);
    sessionStopped();
    final scope = SourceUiScope.current;
    if ((session != null || task._origin.retainOnSourceChange) &&
        scope?.available == true) {
      scope!.survivesSourceChange = true;
    }
    void scopeStopped() {
      final reason = scope?.reason;
      // 实例故障由调用错误以 SourceRuntimeFailed 结算，不能转成取消。
      if (reason == null || reason == 'runtimeFailed') return;
      task._requestStop(switch (reason) {
        'timeout' => SourceTaskStopReason.deadlineExceeded,
        'sourceChanged' => SourceTaskStopReason.sourceChanged,
        'superseded' => SourceTaskStopReason.superseded,
        'ownerGone' => SourceTaskStopReason.ownerDisposed,
        'runtimeDisposed' => SourceTaskStopReason.runtimeClosed,
        _ => SourceTaskStopReason.user,
      });
    }

    // Only explicitly owned calls opt into the page's interaction lifetime.
    if (cancellation != null && linkUiCancellation) {
      scope?.addListener(scopeStopped);
    }
    Object? failure;
    StackTrace? failureStack;
    try {
      task.checkActive();
      Future<T> work = Future<T>.sync(() => operation(task));
      final timeout = task._origin.workTimeout;
      if (timeout != null) {
        work = SourceUiScope.timeout(
          work,
          timeout,
          onTimeout: () {
            task._requestStop(SourceTaskStopReason.deadlineExceeded);
            throw task._failure;
          },
        );
      }
      final result = await Future.any<T>([
        work,
        task.whenStopped.then<T>((_) => throw task._failure),
      ]);
      task.checkActive();
      task._finish(SourceTaskState.succeeded);
      return result;
    } catch (error, stack) {
      if (error is SourceTaskCancelled && task._stopReason == null) {
        task._requestStop(error.reason);
      }
      if (error is SourceScriptStopped && task._stopReason == null) {
        final reason = error.timedOut
            ? (error.reason == 'deadlineExceeded'
                  ? SourceTaskStopReason.deadlineExceeded
                  : SourceTaskStopReason.executionTimeout)
            : SourceTaskStopReason.values
                  .where((reason) => reason.name == error.reason)
                  .firstOrNull;
        if (reason != null) task._requestStop(reason);
      }
      failure = task._stopReason == null ? error : task._failure;
      failureStack = stack;
      task._finish(
        task._stopReason == null
            ? SourceTaskState.failed
            : failure is SourceTaskTimedOut
            ? SourceTaskState.timedOut
            : SourceTaskState.cancelled,
      );
      Error.throwWithStackTrace(failure, stack);
    } finally {
      cancellation?.removeListener(stopped);
      session?.cancellation.removeListener(sessionStopped);
      if (cancellation != null && linkUiCancellation) {
        scope?.removeListener(scopeStopped);
      }
      task._notify(
        SourceTaskEvent.stateChanged,
        error: failure,
        stack: failureStack,
      );
      try {
        final disposition =
            task._origin.resultDisposition?.call() ??
            SourceTaskResultDisposition.current;
        if (disposition != SourceTaskResultDisposition.current) {
          task._notify(
            SourceTaskEvent.resultDiscarded,
            disposition: disposition,
          );
        }
      } catch (_) {
        // Result-usefulness diagnostics cannot alter completion.
      }
      task._finished.complete();
      _prune();
    }
  }

  void _prune() {
    for (final task in _tasks.values.toList()) {
      if (task._endedAt == null ||
          !task._finished.isCompleted ||
          task._pendingCommits != 0 ||
          task._engines.any((engine) => engine.hasExecutionWork(task.taskId)) ||
          task._settling) {
        continue;
      }
      _tasks.remove(task.taskId);
      for (final engine in task._engines) {
        engine.removeExecutionListener(_prune);
      }
      task._settledAt = DateTime.now().toUtc();
      task._notify(SourceTaskEvent.resourcesSettled);
      _finished[task.taskId] = task.snapshot;
      // A small host-only receipt history; no origins, engines or callbacks.
      while (_finished.length > 256) {
        _finished.remove(_finished.keys.first);
      }
    }
  }

  Future<SourceTaskCancelReceipt> _cancel(
    bool Function(SourceTaskSnapshot) matches,
    SourceTaskStopReason reason,
  ) async {
    final tasks = _tasks.values
        .where((task) => matches(task.snapshot))
        .toList();
    if (tasks.isEmpty) {
      final completed = _finished.values.where(matches).toList();
      return SourceTaskCancelReceipt(
        completed.isEmpty
            ? SourceTaskCancelStatus.notFound
            : completed.every((task) => task.stopReason != null)
            ? SourceTaskCancelStatus.alreadyRequested
            : SourceTaskCancelStatus.alreadyFinished,
        Future<void>.value(),
      );
    }
    final repeated = tasks.every((task) => task._stopReceipt != null);
    // Mark every selected task before yielding to any acknowledgement.
    final receipts = tasks.map((task) => task._requestStop(reason)).toList();
    return SourceTaskCancelReceipt(
      repeated
          ? SourceTaskCancelStatus.alreadyRequested
          : SourceTaskCancelStatus.accepted,
      Future.wait(receipts.map((receipt) => receipt.whenSettled)).then((_) {}),
      sharedResourceCount: () => receipts.fold(
        0,
        (count, receipt) => count + receipt.sharedResourceCount,
      ),
    );
  }

  @override
  Future<SourceTaskCancelReceipt> cancelTask(
    String taskId,
    SourceTaskStopReason reason,
  ) => _cancel((task) => task.taskId == taskId, reason);
  @override
  Future<SourceTaskCancelReceipt> cancelGroup({
    required String ownerId,
    required String groupId,
    String? pluginId,
    required SourceTaskStopReason reason,
  }) => _cancel(
    (task) =>
        task.ownerId == ownerId &&
        task.groupId == groupId &&
        (pluginId == null || task.pluginId == pluginId),
    reason,
  );
  @override
  Future<SourceTaskCancelReceipt> cancelOwner(
    String ownerId,
    SourceTaskStopReason reason,
  ) => _cancel((task) => task.ownerId == ownerId, reason);

  Future<SourceTaskCancelReceipt> cancelResource(
    Object resource,
    SourceTaskStopReason reason, {
    bool includeServiceTasks = true,
  }) {
    final ids = _tasks.values
        .where(
          (task) =>
              identical(task._resource, resource) &&
              (reason != SourceTaskStopReason.sourceChanged ||
                  !task.survivesSourceChange) &&
              (includeServiceTasks || !task._serviceOwned),
        )
        .map((task) => task.taskId)
        .toSet();
    return _cancel((task) => ids.contains(task.taskId), reason);
  }

  void checkResourceActive(Object resource) {
    final reason = _disposed
        ? SourceTaskStopReason.runtimeClosed
        : _retiredResources[resource];
    if (reason != null) throw SourceTaskCancelled(createSourceTaskId(), reason);
  }

  /// Catalog retirement also rejects submissions made during cancel callbacks.
  Future<SourceTaskCancelReceipt> retireResource(
    Object resource,
    SourceTaskStopReason reason,
  ) {
    _retiredResources[resource] ??= reason;
    return cancelResource(resource, reason);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final task in _tasks.values.toList()) {
      task._requestStop(SourceTaskStopReason.runtimeClosed);
    }
    _finished.clear();
  }
}

class SourceTask {
  SourceTask._({
    required this.pluginId,
    required String? pluginVersion,
    required this.method,
    required SourceTaskOrigin origin,
    required SourceTaskObserver? observe,
    required void Function() onResourcesChanged,
    required void Function(Object) checkResourceActive,
  }) : _pluginVersion = pluginVersion,
       _origin = origin,
       _observe = observe,
       _onResourcesChanged = onResourcesChanged,
       _checkResourceActive = checkResourceActive;

  final String taskId = createSourceTaskId();
  final String pluginId;
  final String method;
  final SourceTaskOrigin _origin;
  final SourceTaskObserver? _observe;
  final void Function() _onResourcesChanged;
  final void Function(Object) _checkResourceActive;
  final DateTime _createdAt = DateTime.now().toUtc();
  final Stopwatch _clock = Stopwatch();
  final Set<SourceScriptEngine> _engines = {};
  final Set<Future<SourceTaskCancelReceipt> Function(SourceTaskStopReason)>
  _stopHandlers = {};
  final _stopped = Completer<void>();
  final _finished = Completer<void>();
  SourceTaskCancelReceipt? _stopReceipt;
  SourceTaskStopReason? _stopReason;
  bool _settling = false;
  Object? _resource;
  bool _serviceOwned = false;
  bool get survivesSourceChange =>
      _origin.readerSession != null ||
      _origin.downloadSession != null ||
      _origin.serviceLease != null ||
      _origin.retainOnSourceChange ||
      _survivesSourceChange;
  bool _survivesSourceChange = false;
  int _pendingCommits = 0;
  Completer<void>? _commitsSettled;
  String? _pluginVersion;
  String? _runtimeId;
  SourceTaskState _state = SourceTaskState.created;
  DateTime? _startedAt;
  DateTime? _endedAt;
  DateTime? _cancelRequestedAt;
  DateTime? _settledAt;
  Future<void> get whenStopped => _stopped.future;

  void bindResource(
    Object resource, {
    bool serviceOwned = false,
    bool survivesSourceChange = false,
  }) {
    checkActive();
    _checkResourceActive(resource);
    _origin.downloadSession?.checkResource(resource);
    _origin.serviceLease?.checkResource(resource);
    _resource = resource;
    _serviceOwned = serviceOwned;
    _survivesSourceChange = survivesSourceChange;
  }

  Future<T> runCommit<T>(Future<T> Function() operation) async {
    checkActive();
    if (_pendingCommits++ == 0) _commitsSettled = Completer<void>();
    try {
      return await operation();
    } finally {
      if (--_pendingCommits == 0) _commitsSettled!.complete();
      _onResourcesChanged();
    }
  }

  void retainUntil(Future<void> drain) {
    if (_pendingCommits++ == 0) _commitsSettled = Completer<void>();
    drain.whenComplete(() {
      if (--_pendingCommits == 0) _commitsSettled!.complete();
      _onResourcesChanged();
    }).ignore();
  }

  SourceTaskCancelReceipt requestStop(SourceTaskStopReason reason) =>
      _requestStop(reason);

  SourceTaskCancelled get _failure =>
      _stopReason == SourceTaskStopReason.deadlineExceeded ||
          _stopReason == SourceTaskStopReason.executionTimeout
      ? SourceTaskTimedOut(taskId, _stopReason!, runtimeId: _runtimeId)
      : SourceTaskCancelled(taskId, _stopReason!, runtimeId: _runtimeId);

  void checkActive() {
    if (_stopReason != null) throw _failure;
  }

  void addStopHandler(
    Future<SourceTaskCancelReceipt> Function(SourceTaskStopReason) handler,
  ) {
    checkActive();
    _stopHandlers.add(handler);
  }

  void removeStopHandler(
    Future<SourceTaskCancelReceipt> Function(SourceTaskStopReason) handler,
  ) => _stopHandlers.remove(handler);

  void bindRuntime({
    required String runtimeId,
    required String? pluginVersion,
    SourceScriptEngine? engine,
  }) {
    checkActive();
    if (_state != SourceTaskState.running || _runtimeId != null) {
      throw StateError('source_task_runtime_already_bound_or_finished');
    }
    _runtimeId = runtimeId;
    _pluginVersion = pluginVersion ?? _pluginVersion;
    if (engine != null && _engines.add(engine)) {
      engine.addExecutionListener(_onResourcesChanged);
    }
  }

  SourceTaskCancelReceipt _requestStop(SourceTaskStopReason reason) {
    if (_stopReceipt case final receipt?) return receipt;
    final scriptReceipts = <SourceScriptCancelReceipt>[];
    final resourceReceipts = <SourceTaskCancelReceipt>[];
    final settled = Completer<void>();
    // Install the receipt before observers can re-enter cancellation.
    final receipt = _stopReceipt = SourceTaskCancelReceipt(
      SourceTaskCancelStatus.accepted,
      settled.future,
      sharedResourceCount: () =>
          scriptReceipts.fold(
            0,
            (count, receipt) => count + receipt.sharedResourceCount,
          ) +
          resourceReceipts.fold(
            0,
            (count, receipt) => count + receipt.sharedResourceCount,
          ),
    );
    settled.future.ignore();
    _stopReason = reason;
    _cancelRequestedAt = DateTime.now().toUtc();
    _settling = true;
    if (_endedAt == null) {
      _state = SourceTaskState.cancelRequested;
      _notify(SourceTaskEvent.stateChanged);
    }
    if (!_stopped.isCompleted) _stopped.complete();
    final requests = <Future<void>>[
      for (final engine in _engines)
        Future.sync(() => engine.cancelExecution(taskId, reason.name)).then((
          receipt,
        ) {
          scriptReceipts.add(receipt);
          return receipt.whenSettled;
        }),
      for (final handler in _stopHandlers.toList())
        Future.sync(() => handler(reason)).then((receipt) {
          resourceReceipts.add(receipt);
          return receipt.whenSettled;
        }),
    ];
    Future.wait<void>([
      ...requests,
      _finished.future,
      if (_pendingCommits != 0) _commitsSettled!.future,
    ]).then<void>(
      (_) {
        _settling = false;
        _onResourcesChanged();
        settled.complete();
      },
      onError: (Object error, StackTrace stack) {
        settled.completeError(error, stack);
      },
    );
    return receipt;
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
    stopReason: _stopReason,
    cancelRequestedAt: _cancelRequestedAt,
    settledAt: _settledAt,
    sharedResourceCount: _stopReceipt?.sharedResourceCount ?? 0,
  );

  void _notify(
    SourceTaskEvent event, {
    SourceTaskResultDisposition disposition =
        SourceTaskResultDisposition.current,
    Object? error,
    StackTrace? stack,
  }) {
    try {
      _observe?.call(snapshot, event, disposition, error, stack);
    } catch (_) {
      // Diagnostics cannot affect task execution or resource release.
    }
  }

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
