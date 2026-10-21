import 'dart:async';

import '../gateways/source_task_control_gateway.dart';
import '../interaction/source_ui_scope.dart';
import '../interaction/source_ui_service.dart';
import '../models/source_script_execution.dart';
import '../models/source_task.dart';
import 'source_script_engine.dart';
import 'source_task_registry.dart';

/// A Dart-side shared producer. Subscriptions never own each other's lifetime.
class SourceSharedRequest<T> {
  SourceSharedRequest({
    required this.pluginId,
    required this.method,
    required Future<T> Function(SourceSharedRequest<T>) operation,
    required void Function() onUnavailable,
  }) : _operation = operation,
       _onUnavailable = onUnavailable;

  final String pluginId;
  final String method;
  final String resourceId = createSourceTaskId();
  final Future<T> Function(SourceSharedRequest<T>) _operation;
  final void Function() _onUnavailable;
  final Map<Object, SourceUiScope?> _subscribers = {};
  final Map<Object, SourceTask?> _subscriberTasks = {};
  final Set<SourceScriptEngine> _engines = {};
  final _result = Completer<T>();
  SourceUiScope? _scope;
  SourceTaskStopReason? _stopReason;
  bool _started = false;
  bool _completed = false;
  Future<void>? _settled;

  bool get available => _stopReason == null && !_completed;
  bool get hasConsumers => _subscribers.isNotEmpty && _stopReason == null;
  SourceScriptExecution get execution => SourceScriptExecution(
    taskId: resourceId,
    pluginId: pluginId,
    method: method,
  );

  void checkActive() {
    if (_stopReason case final reason?) {
      throw SourceTaskCancelled(resourceId, reason);
    }
  }

  void bindEngine(SourceScriptEngine engine) {
    checkActive();
    _engines.add(engine);
    for (final task in _subscriberTasks.values) {
      if (task != null && task.snapshot.runtimeId == null) {
        task.bindRuntime(runtimeId: engine.runtimeId, pluginVersion: null);
      }
    }
  }

  void _waitingChanged() {
    final reason = _scope?.reason;
    if (reason == 'user' || reason == 'timeout') {
      for (final task in _subscriberTasks.values.toList()) {
        task?.requestStop(
          reason == 'user'
              ? SourceTaskStopReason.user
              : SourceTaskStopReason.deadlineExceeded,
        );
      }
      for (final scope in _subscribers.values.toSet()) {
        if (scope != null && !scope.finished && scope.reason == null) {
          scope.cancel(reason!);
        }
      }
    }
    for (final scope in _subscribers.values.toSet()) {
      if (scope != null && !scope.finished && scope.reason == null) {
        scope.setExternalWaiting(this, _scope?.waiting == true);
      }
    }
  }

  /// Existing plugin-requested recovery must not reuse a retired UI scope.
  Future<R> withUiScope<R>(Future<R> Function() operation) {
    checkActive();
    if (SourceUiScope.current?.available == true) return operation();
    return SourceUiScope.withoutInteraction(
      () => SourceUiService.instance.run(
        () async {
          final previous = _scope;
          previous?.removeListener(_waitingChanged);
          _scope = SourceUiScope.current;
          _scope?.addListener(_waitingChanged);
          _waitingChanged();
          try {
            checkActive();
            return await operation();
          } finally {
            _scope?.removeListener(_waitingChanged);
            _scope = previous;
            previous?.addListener(_waitingChanged);
            _waitingChanged();
          }
        },
        captureRouteOwner: false,
        abortOnScopeCancellation: false,
      ),
    );
  }

  void _start() {
    if (_started) return;
    _started = true;
    _result.future.ignore();
    SourceUiScope.withoutInteraction(
      () => SourceUiService.instance.run(
        () async {
          _scope = SourceUiScope.current;
          _scope?.addListener(_waitingChanged);
          try {
            checkActive();
            return await _operation(this);
          } finally {
            _scope?.removeListener(_waitingChanged);
            for (final scope in _subscribers.values.toSet()) {
              if (scope != null && !scope.finished) {
                scope.setExternalWaiting(this, false);
              }
            }
            _scope = null;
          }
        },
        captureRouteOwner: false,
        // Runtime retirement may revoke UI while an admitted request still
        // holds its handle lease. UI checks remain active; await its result.
        abortOnScopeCancellation: false,
      ),
    ).then<void>(
      (value) {
        _completed = true;
        _onUnavailable();
        _result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        _completed = true;
        _onUnavailable();
        _result.completeError(error, stack);
      },
    );
  }

  Future<T> subscribe({SourceTask? task}) async {
    checkActive();
    task?.checkActive();
    final id = Object();
    final scope = SourceUiScope.current;
    _subscribers[id] = scope;
    _subscriberTasks[id] = task;
    if (task != null &&
        _engines.isNotEmpty &&
        task.snapshot.runtimeId == null) {
      task.bindRuntime(runtimeId: _engines.last.runtimeId, pluginVersion: null);
    }
    var detached = false;
    Future<SourceTaskCancelReceipt> detach(SourceTaskStopReason reason) async {
      if (!detached) {
        detached = true;
        _subscribers.remove(id);
        _subscriberTasks.remove(id);
        if (scope != null && !scope.finished) {
          scope.setExternalWaiting(
            this,
            _subscribers.values.contains(scope) && _scope?.waiting == true,
          );
        }
      }
      final retained = _subscribers.isNotEmpty;
      final settled = retained ? Future<void>.value() : _stop(reason);
      return SourceTaskCancelReceipt(
        SourceTaskCancelStatus.accepted,
        settled,
        sharedResourceCount: () =>
            retained && hasConsumers && !_completed ? 1 : 0,
      );
    }

    task?.addStopHandler(detach);
    _start();
    _waitingChanged();
    try {
      if (task == null) return await _result.future;
      return await Future.any<T>([
        _result.future,
        task.whenStopped.then<T>((_) {
          task.checkActive();
          throw StateError('stopped_task_without_reason');
        }),
      ]);
    } finally {
      task?.removeStopHandler(detach);
      final receipt = await detach(SourceTaskStopReason.ownerDisposed);
      // Cancellation's receipt owns draining. A business result stays prompt.
      receipt.whenSettled.ignore();
    }
  }

  Future<void> _stop(SourceTaskStopReason reason) {
    if (_settled case final settled?) return settled;
    _stopReason = reason;
    _onUnavailable();
    final settled = Future.wait([
      for (final engine in _engines)
        engine
            .cancelExecution(resourceId, reason.name)
            .then((receipt) => receipt.whenSettled),
    ]).then<void>((_) {});
    settled.ignore();
    return _settled = settled;
  }
}
