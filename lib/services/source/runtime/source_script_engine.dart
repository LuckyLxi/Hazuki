import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:quickjs_engine/quickjs_engine.dart';

import 'source_script_codec.dart';
import 'source_script_worker.dart';
import 'source_host_call_context.dart';
import '../models/source_script_execution.dart';
import '../models/source_task.dart';
import '../interaction/source_ui_scope.dart';
import '../interaction/source_ui_service.dart';

/// An asynchronous proxy. All QuickJS objects belong exclusively to its worker.
class SourceScriptEngine {
  SourceScriptEngine({
    int timeout = 5000,
    int memoryLimit = 64 * 1024 * 1024,
    this.pluginId = '',
    this.inspection = false,
    void Function(dynamic)? hostPromiseRejectionHandler,
  }) : _rejectionHandler = hostPromiseRejectionHandler {
    _codec = SourceScriptCodec(
      encodeCallback: (callback) {
        if (callback is! SourceScriptCallback ||
            !identical(callback._engine, this) ||
            callback._freed) {
          throw StateError('source_script_callback_invalid');
        }
        return callback._id;
      },
      decodeCallback: (id) =>
          SourceScriptCallback._(this, id, _callbackExecutions[id]),
    );
    SourceUiScope.withoutInteractionSync(() => _messages.listen(_receive));
    SourceUiScope.withoutInteractionSync(
      () => _errors.listen(
        (error) => _workerFailed(
          StateError('source_script_worker_failed'),
          StackTrace.fromString('$error'),
        ),
      ),
    );
    SourceUiScope.withoutInteractionSync(
      () => _exit.listen((_) {
        // Let the final worker acknowledgement on the other port arrive first.
        Timer.run(() {
          if (!_acknowledgedClose && _workerFailure == null) {
            _workerFailed(
              StateError('source_script_worker_exited_without_cleanup'),
              StackTrace.current,
            );
          }
          _fail(StateError('source_script_worker_closed'), StackTrace.current);
          _workerExited = true;
          _finishClose();
          _messages.close();
          _errors.close();
          _exit.close();
        });
      }),
    );
    _ready.future.ignore();
    _closed.future.ignore();
    unawaited(
      SourceUiScope.withoutInteraction(
        () =>
            Isolate.spawn(
              runSourceScriptWorker,
              {
                'port': _messages.sendPort,
                'runtimeId': runtimeId,
                'pluginId': pluginId,
                'timeout': timeout,
                'memoryLimit': memoryLimit,
                'inspection': inspection,
              },
              onError: _errors.sendPort,
              onExit: _exit.sendPort,
            ).then<void>(
              (_) {},
              onError: (Object error, StackTrace stack) {
                _workerFailed(error, stack);
                if (!_closed.isCompleted) _closed.completeError(error, stack);
                _messages.close();
                _errors.close();
                _exit.close();
              },
            ),
      ),
    );
  }

  final String runtimeId = createSourceTaskId();
  final String pluginId;
  final bool inspection;
  final void Function(dynamic)? _rejectionHandler;
  final ReceivePort _messages = ReceivePort();
  final ReceivePort _errors = ReceivePort();
  final ReceivePort _exit = ReceivePort();
  final Completer<void> _ready = Completer<void>();
  final Completer<void> _closed = Completer<void>();
  final Map<int, Completer<dynamic>> _pending = {};
  final Map<int, SourceScriptExecution> _callExecutions = {};
  final Map<String, int> _waitingTaskIds = {};
  final Map<int, int> _callTokens = {};
  final Map<int, SourceScriptExecution> _tokenExecutions = {};
  final Map<int, SourceScriptExecution> _callbackExecutions = {};
  final Map<int, SourceHostCallContext> _hostResources = {};
  final Map<String, String> _cancelled = {};
  final Map<String, Completer<void>> _settling = {};
  final Map<String, Set<int>> _settlingResources = {};
  final Set<String> _cancelAcknowledged = {};
  final Map<String, int> _sharedResources = {};
  final Map<String, int> _retainedDiagnostics = {};
  QuickJsTaskControl? _control;
  final Set<int> _handshakes = {};
  late final SourceScriptCodec _codec;
  SendPort? _worker;
  int _sequence = 0;
  int _snapshotSequence = 0;
  bool _closing = false;
  bool _acknowledgedClose = false;
  bool _workerExited = false;
  Object? _workerFailure;
  StackTrace? _workerFailureStack;
  Map<String, dynamic> _snapshot = {};
  Map<String, int> _shutdownDiagnostics = {};
  Map<String, int> get shutdownDiagnostics =>
      Map.unmodifiable(_shutdownDiagnostics);
  void Function()? onSnapshotChanged;
  void Function(Map<String, Object?>)? onDiagnostic;
  final Set<void Function()> _executionListeners = {};

  void addExecutionListener(void Function() listener) =>
      _executionListeners.add(listener);
  void removeExecutionListener(void Function() listener) =>
      _executionListeners.remove(listener);

  bool hasExecutionWork(String taskId) =>
      _waitingTaskIds.containsKey(taskId) ||
      _callExecutions.values.any((e) => e.taskId == taskId) ||
      _tokenExecutions.values.any((e) => e.taskId == taskId) ||
      _hostResources.values.any((e) => e.execution.taskId == taskId);

  void _notifyExecutionListeners() {
    for (final listener in _executionListeners.toList()) {
      try {
        listener();
      } catch (_) {
        // A subscriber must not interfere with native resource cleanup.
      }
    }
  }

  void _diagnose(
    SourceScriptExecution execution,
    String phase, [
    Map<String, Object?> fields = const {},
  ]) {
    try {
      onDiagnostic?.call({
        ...execution.toMap(),
        'runtimeId': runtimeId,
        'phase': phase,
        ...fields,
      });
    } catch (_) {
      /* Diagnostics cannot change execution. */
    }
  }

  dynamic Function(dynamic, SourceHostCallContext)? _handler;
  Future<dynamic> Function(Future<dynamic> Function())? operationGuard;

  Future<void> get ready => _ready.future;
  Future<void> get whenClosed => _closed.future;
  Map<String, dynamic> get snapshot => Map.unmodifiable(_snapshot);
  dynamic cachedValue(String expression) => _snapshot[expression];
  void setMessageHandler(dynamic Function(dynamic) handler) =>
      _handler = (message, _) => handler(message);
  void setContextMessageHandler(
    dynamic Function(dynamic, SourceScriptExecution) handler,
  ) => _handler = (message, context) => handler(message, context.execution);
  void setOperationMessageHandler(
    dynamic Function(dynamic, SourceHostCallContext) handler,
  ) => _handler = handler;

  SourceScriptStopped _stopped(
    SourceScriptExecution execution, {
    int token = 0,
    String? reason,
    bool timedOut = false,
    String? stack,
  }) => SourceScriptStopped(
    execution: execution,
    runtimeId: runtimeId,
    nativeToken: token,
    reason: reason ?? _cancelled[execution.taskId] ?? 'cancelled',
    timedOut:
        timedOut ||
        const {
          'deadlineExceeded',
          'executionTimeout',
        }.contains(reason ?? _cancelled[execution.taskId]),
    stack: stack,
  );

  Future<SourceScriptCancelReceipt> cancelExecution(
    String taskId,
    String reason,
  ) async {
    final existed = _cancelled.containsKey(taskId);
    final known =
        _waitingTaskIds.containsKey(taskId) ||
        _callExecutions.values.any((e) => e.taskId == taskId) ||
        _tokenExecutions.values.any((e) => e.taskId == taskId) ||
        _hostResources.values.any((e) => e.execution.taskId == taskId);
    _cancelled.putIfAbsent(taskId, () => reason);
    final diagnostic = _tokenExecutions.values
        .where((e) => e.taskId == taskId)
        .firstOrNull;
    if (!existed && diagnostic != null) {
      _diagnose(diagnostic, 'cancelRequested', {'reason': reason});
    }
    final settled = _settling.putIfAbsent(taskId, Completer<void>.new);
    for (final entry in _tokenExecutions.entries.toList()) {
      if (entry.value.taskId == taskId) {
        _control?.stopRetained(
          entry.key,
          reason: reason == 'deadlineExceeded' || reason == 'executionTimeout'
              ? QuickJsStopReason.timedOut
              : QuickJsStopReason.cancelled,
        );
      }
    }
    for (final entry in _callExecutions.entries) {
      final completion = _pending[entry.key];
      if (entry.value.taskId == taskId &&
          completion != null &&
          !completion.isCompleted) {
        completion.completeError(
          _stopped(
            entry.value,
            token: _callTokens[entry.key] ?? 0,
            timedOut:
                _cancelled[taskId] == 'deadlineExceeded' ||
                _cancelled[taskId] == 'executionTimeout',
          ),
        );
      }
    }
    if (_closing || _worker == null && !known) {
      _cancelAcknowledged.add(taskId);
    } else {
      _worker?.send({
        'type': 'cancel',
        'runtimeId': runtimeId,
        'taskId': taskId,
        'reason': reason,
      });
    }
    _refreshResources(settlingTaskId: taskId);
    _checkSettled();
    return SourceScriptCancelReceipt(
      existed
          ? SourceScriptCancelStatus.alreadyRequested
          : known
          ? SourceScriptCancelStatus.accepted
          : SourceScriptCancelStatus.notFound,
      settled.future,
      () =>
          (_sharedResources[taskId] ?? 0) +
          _hostResources.values
              .where(
                (resource) =>
                    resource.execution.taskId == taskId &&
                    _control?.workState(resource.workId) ==
                        QuickJsWorkState.retained,
              )
              .length,
    );
  }

  void _refreshResources({String? settlingTaskId}) {
    for (final resource in _hostResources.values.toList()) {
      if (resource.isStopped) continue;
      final stop = _control?.claimStop(resource.workId);
      if (stop != null || _closing) {
        if (settlingTaskId != null) {
          _settlingResources
              .putIfAbsent(settlingTaskId, () => <int>{})
              .add(resource.resourceId);
        }
        resource.stop(
          _stopped(
            resource.execution,
            token: resource.nativeToken,
            reason: _closing ? 'runtimeClosed' : null,
            timedOut: stop == QuickJsStopReason.timedOut,
          ),
        );
        _diagnose(resource.execution, 'resourceStopped', {
          'nativeToken': resource.nativeToken,
          'workId': resource.workId,
          'resourceId': resource.resourceId,
        });
      }
    }
    for (final id in _cancelled.keys) {
      final retained =
          (_sharedResources[id] ?? 0) +
          _hostResources.values
              .where(
                (resource) =>
                    resource.execution.taskId == id &&
                    _control?.workState(resource.workId) ==
                        QuickJsWorkState.retained,
              )
              .length;
      if (_retainedDiagnostics[id] == retained) continue;
      _retainedDiagnostics[id] = retained;
      final execution = _tokenExecutions.values
          .where((e) => e.taskId == id)
          .firstOrNull;
      if (execution != null) {
        _diagnose(execution, 'resourcesRetained', {
          'sharedResourceCount': retained,
        });
      }
    }
  }

  void _checkSettled() {
    for (final entry in _settling.entries) {
      if (entry.value.isCompleted || !_cancelAcknowledged.contains(entry.key)) {
        continue;
      }
      final pending =
          _waitingTaskIds.containsKey(entry.key) ||
          _callExecutions.values.any((e) => e.taskId == entry.key);
      final draining = _hostResources.values.any(
        (resource) =>
            resource.isStopped &&
            (resource.execution.taskId == entry.key ||
                (_settlingResources[entry.key]?.contains(resource.resourceId) ??
                    false)),
      );
      if (!pending && !draining) {
        _settlingResources.remove(entry.key);
        entry.value.complete();
      }
    }
    _notifyExecutionListeners();
  }

  void _finishClose() {
    if (!_workerExited ||
        _closed.isCompleted ||
        _hostResources.values.any((r) => r.requiresDrain)) {
      return;
    }
    _tokenExecutions.clear();
    _callbackExecutions.clear();
    _sharedResources.clear();
    _hostResources.clear();
    _retainedDiagnostics.clear();
    _settlingResources.clear();
    _cancelled.clear();
    _cancelAcknowledged.addAll(_settling.keys);
    _checkSettled();
    _control = null;
    _handler = null;
    operationGuard = null;
    onSnapshotChanged = null;
    onDiagnostic = null;
    _notifyExecutionListeners();
    _executionListeners.clear();
    if (_workerFailure case final error?) {
      _closed.completeError(error, _workerFailureStack);
    } else {
      _closed.complete();
    }
  }

  void _releaseExecution(SourceScriptExecution execution) {
    if (!_tokenExecutions.values.any((e) => e.taskId == execution.taskId) &&
        !_hostResources.values.any(
          (e) => e.execution.taskId == execution.taskId,
        )) {
      SourceUiService.instance.releaseExecution(execution, runtimeId);
    }
    _notifyExecutionListeners();
  }

  Future<dynamic> evaluate(
    String code, {
    String? name,
    SourceScriptExecution? execution,
  }) =>
      _command('evaluate', {'code': code, 'name': name}, execution: execution);

  /// Runs declarations without adopting an intentionally discarded Promise.
  Future<void> execute(
    String code, {
    String? name,
    SourceScriptExecution? execution,
  }) async {
    await _command('execute', {
      'code': code,
      'name': name,
    }, execution: execution);
  }

  Future<dynamic> invoke(
    String code,
    List<dynamic> arguments, {
    SourceScriptExecution? execution,
  }) => _command('invoke', {
    'code': code,
    'arguments': _codec.encode(arguments),
  }, execution: execution);
  Future<void> setGlobal(
    String name,
    dynamic value, {
    SourceScriptExecution? execution,
  }) async {
    await _command('global', {
      'name': name,
      'value': _codec.encode(value),
    }, execution: execution);
  }

  Future<dynamic> _command(
    String kind,
    Map<String, dynamic> arguments, {
    SourceScriptExecution? execution,
  }) {
    Future<dynamic> action() =>
        _sendCommand(kind, arguments, execution: execution);
    return operationGuard?.call(action) ?? action();
  }

  Future<dynamic> _sendCommand(
    String kind,
    Map<String, dynamic> arguments, {
    SourceScriptExecution? execution,
  }) async {
    if (_closing) throw StateError('source_script_engine_closed');
    // Callback cleanup must still run after its owner has cancelled.
    final scope = inspection || kind == 'release'
        ? null
        : SourceUiScope.current;
    final waitingTaskId = execution?.taskId;
    if (waitingTaskId != null) {
      _waitingTaskIds.update(
        waitingTaskId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    try {
      await ready;
    } finally {
      if (waitingTaskId != null) {
        final remaining = _waitingTaskIds[waitingTaskId]! - 1;
        if (remaining == 0) {
          _waitingTaskIds.remove(waitingTaskId);
        } else {
          _waitingTaskIds[waitingTaskId] = remaining;
        }
        _checkSettled();
      }
    }
    if (_closing) throw StateError('source_script_engine_closed');
    if (scope?.reason case final reason?) throw SourceUiCancelled(reason);
    final id = ++_sequence;
    final completion = Completer<dynamic>();
    _pending[id] = completion;
    scope?.runtimeIds.add(runtimeId);
    scope?.pluginIds.add(pluginId);
    final context =
        (execution ??
                SourceScriptExecution(
                  taskId: createSourceTaskId(),
                  pluginId: pluginId,
                  method:
                      arguments['name'] as String? ??
                      RegExp(r'__hazuki_source\.([\w?.]+)')
                          .firstMatch(arguments['code'] as String? ?? '')
                          ?.group(1) ??
                      'script.$kind',
                  pluginVersion: _snapshot['__metadata'] is String
                      ? (jsonDecode(_snapshot['__metadata'] as String)
                                as Map)['version']
                            ?.toString()
                      : null,
                ))
            .withUiScope(scope?.id);
    if (kind != 'release' && _cancelled.containsKey(context.taskId)) {
      _pending.remove(id);
      throw _stopped(context);
    }
    final token = _control!.register();
    _callExecutions[id] = context;
    _callTokens[id] = token;
    _tokenExecutions[token] = context;
    _diagnose(context, 'queued', {'nativeToken': token, 'callId': id});
    completion.future.ignore();
    // Retain before dispatch: the caller can finish before the worker starts.
    // Callback commands inherit their original execution inside the worker.
    if (kind != 'callback') {
      SourceUiService.instance.retainExecution(context, runtimeId);
    }
    _worker!.send({
      'type': kind,
      'id': id,
      'token': token,
      'runtimeId': runtimeId,
      ...arguments,
      'execution': context.toMap(),
    });
    return completion.future;
  }

  void _receive(dynamic raw) {
    final message = raw as Map;
    if (message['runtimeId'] != runtimeId) return;
    switch (message['type']) {
      case 'ready':
        _worker = message['port'] as SendPort;
        _control = QuickJsTaskControl.fromId(message['controlId'] as int);
        if (!_ready.isCompleted) _ready.complete();
        for (final entry in _cancelled.entries) {
          if (_waitingTaskIds.containsKey(entry.key)) {
            _worker!.send({
              'type': 'cancel',
              'runtimeId': runtimeId,
              'taskId': entry.key,
              'reason': entry.value,
            });
          }
        }
        if (_closing) _worker!.send({'type': 'close', 'runtimeId': runtimeId});
      case 'snapshot':
        final sequence = message['sequence'] as int;
        if (!_closing && sequence > _snapshotSequence) {
          _snapshotSequence = sequence;
          _snapshot = Map<String, dynamic>.from(
            _codec.decode(message['value']) as Map,
          );
          onSnapshotChanged?.call();
        }
      case 'result':
        final completion = _pending.remove(message['id']);
        final execution = _callExecutions.remove(message['id']);
        _callTokens.remove(message['id']);
        if (completion == null) return;
        try {
          var value = _codec.decode(message['value']);
          if (value is QuickJsTaskStoppedError && execution != null) {
            value = _stopped(
              execution,
              token: value.taskToken,
              reason:
                  _cancelled[execution.taskId] ??
                  (_tokenExecutions[value.taskToken]?.taskId != execution.taskId
                      ? 'dependencyStopped'
                      : value.reason == QuickJsStopReason.timedOut
                      ? 'executionTimeout'
                      : 'cancelled'),
              timedOut: value.reason == QuickJsStopReason.timedOut,
              stack: value.stack,
            );
          }
          if (execution != null) {
            _diagnose(
              execution,
              value is SourceScriptStopped ? 'stopped' : 'completed',
              {
                'callId': message['id'],
                'failed': message['error'] == true,
                'operationElapsedUs': message['operationElapsedUs'],
                if (value is SourceScriptStopped) 'reason': value.reason,
                if (value is SourceScriptStopped)
                  'nativeToken': value.nativeToken,
                if (value is SourceScriptStopped)
                  'scriptLocation': RegExp(
                    r'(?:[\w.-]+\.js|<eval>):\d+(?::\d+)?',
                  ).firstMatch(value.stack)?.group(0),
              },
            );
          }
          if (completion.isCompleted) {
            _discard(value);
            return;
          }
          if (message['error'] == true) {
            completion.completeError(
              value ?? StateError('source_script_error'),
            );
          } else {
            completion.complete(value);
          }
        } catch (error, stack) {
          if (!completion.isCompleted) completion.completeError(error, stack);
        } finally {
          _refreshResources();
          _checkSettled();
          _finishClose();
        }
      case 'host':
        _handleHost(message);
      case 'executionReleased':
        _tokenExecutions.remove(message['token']);
        _releaseExecution(
          SourceScriptExecution.fromMap(message['execution'] as Map),
        );
      case 'callbackRegistered':
        _callbackExecutions[message['handle'] as int] =
            SourceScriptExecution.fromMap(message['execution'] as Map);
      case 'checkpoint':
      case 'resourceState':
        _sharedResources.addAll(
          Map<String, int>.from(message['shared'] as Map),
        );
        _refreshResources();
        _checkSettled();
      case 'cancelAck':
        _cancelAcknowledged.add(message['taskId'] as String);
        _refreshResources();
        _checkSettled();
      case 'executionStarted':
        _diagnose(
          SourceScriptExecution.fromMap(message['execution'] as Map),
          'running',
          {
            'nativeToken': message['token'],
            'callId': message['id'],
            'queueElapsedUs': message['queueElapsedUs'],
          },
        );
        SourceUiService.instance.retainExecution(
          SourceScriptExecution.fromMap(message['execution'] as Map),
          runtimeId,
        );
      case 'rejection':
        if (!_closing) _rejectionHandler?.call(_codec.decode(message['value']));
      case 'failed':
        _workerFailed(
          _codec.decode(message['value']) as Object,
          StackTrace.current,
        );
      case 'closed':
        _acknowledgedClose = true;
        _shutdownDiagnostics = Map<String, int>.from(
          message['diagnostics'] as Map,
        );
    }
  }

  void _discard(dynamic value, [Set<Object>? seen]) {
    if (value == null || value is num || value is String || value is bool) {
      return;
    }
    seen ??= Set<Object>.identity();
    if (!seen.add(value as Object)) return;
    if (value is SourceScriptCallback) value.free().ignore();
    if (value is List) {
      for (final item in value) {
        _discard(item, seen);
      }
    }
    if (value is Map) {
      for (final entry in value.entries) {
        _discard(entry.key, seen);
        _discard(entry.value, seen);
      }
    }
  }

  void _handleHost(Map message) {
    final id = message['reply'] as int;
    if (_closing || !QuickJsHostReply.active(id)) {
      QuickJsHostReply.close(id);
      return;
    }
    _handshakes.add(id);
    final context = SourceHostCallContext(
      execution: SourceScriptExecution.fromMap(message['execution'] as Map),
      runtimeId: runtimeId,
      nativeToken: message['token'] as int,
      workId: message['work'] as int,
      resourceId: id,
    );
    _hostResources[id] = context;
    var pending = false;
    try {
      _refreshResources();
      context.checkActive();
      final value = _handler?.call(_codec.decode(message['value']), context);
      if (value is Future) {
        pending = true;
        _diagnose(context.execution, 'hostPending', {
          'nativeToken': context.nativeToken,
          'workId': context.workId,
          'resourceId': id,
        });
        _reply(id, {'kind': 'pending'});
        value
            .then<void>(
              (result) {
                if (!_closing && !context.isStopped) {
                  _hostResult(id, result, false);
                } else {
                  _discard(result);
                }
              },
              onError: (Object error, StackTrace stack) {
                if (!_closing && !context.isStopped) {
                  _hostResult(
                    id,
                    error is JSError ? error : JSError(error, stack),
                    true,
                  );
                }
              },
            )
            .whenComplete(() async {
              await context.whenCommitsSettled;
              _hostResources.remove(id);
              _releaseExecution(context.execution);
              _refreshResources();
              _checkSettled();
              _finishClose();
            });
      } else {
        _reply(id, {
          'kind': 'value',
          'value': _codec.encode(value, transferable: false),
        });
      }
    } catch (error, stack) {
      _reply(id, {
        'kind': 'error',
        'value': _codec.encode(
          error is JSError ? error : JSError(error, stack),
          transferable: false,
        ),
      });
    } finally {
      _handshakes.remove(id);
      if (!pending) {
        _hostResources.remove(id);
        _releaseExecution(context.execution);
      }
    }
  }

  void _reply(int id, Map<String, dynamic> response) =>
      QuickJsHostReply.complete(
        id,
        Uint8List.fromList(utf8.encode(jsonEncode(response))),
      );
  void _hostResult(int id, dynamic value, bool error) {
    try {
      _worker?.send({
        'type': 'hostResult',
        'runtimeId': runtimeId,
        'id': id,
        'error': error,
        'value': _codec.encode(value),
      });
    } catch (failure, stack) {
      _worker?.send({
        'type': 'hostResult',
        'runtimeId': runtimeId,
        'id': id,
        'error': true,
        'value': _codec.encode(JSError(failure, stack)),
      });
    }
  }

  void _fail(Object error, StackTrace stack) {
    SourceUiService.instance.cancelRuntime(runtimeId);
    _closing = true;
    _control?.shutdown();
    _refreshResources();
    if (!_ready.isCompleted) _ready.completeError(error, stack);
    for (final completion in _pending.values) {
      if (!completion.isCompleted) completion.completeError(error, stack);
    }
    _pending.clear();
    _callExecutions.clear();
    _callTokens.clear();
    for (final id in _handshakes) {
      QuickJsHostReply.close(id);
    }
    _handshakes.clear();
  }

  void _workerFailed(Object error, StackTrace stack) {
    _workerFailure ??= error;
    _workerFailureStack ??= stack;
    _fail(error, stack);
  }

  Future<void> close() {
    if (!_closing) {
      _fail(StateError('source_script_engine_closed'), StackTrace.current);
      _worker?.send({'type': 'close', 'runtimeId': runtimeId});
    }
    whenClosed.whenComplete(() {
      _cancelAcknowledged.addAll(_settling.keys);
      _checkSettled();
    }).ignore();
    return whenClosed;
  }
}

class SourceScriptCallback {
  SourceScriptCallback._(this._engine, this._id, this._execution);
  final SourceScriptEngine _engine;
  final int _id;
  final SourceScriptExecution? _execution;
  bool _freed = false;
  Future<dynamic> invoke(List<dynamic> arguments) {
    if (_freed) {
      return Future.error(StateError('source_script_callback_released'));
    }
    return _engine._command('callback', {
      'handle': _id,
      'arguments': _engine._codec.encode(arguments),
    }, execution: _execution);
  }

  Future<void> free() async {
    if (_freed) return;
    _freed = true;
    _engine._callbackExecutions.remove(_id);
    if (!_engine._closing) await _engine._command('release', {'handle': _id});
  }
}
