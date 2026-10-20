import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:quickjs_engine/quickjs_engine.dart';

import 'source_script_codec.dart';
import 'source_script_worker.dart';
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
      decodeCallback: (id) => SourceScriptCallback._(this, id),
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
          if (!_closed.isCompleted) {
            if (_workerFailure case final error?) {
              _closed.completeError(error, _workerFailureStack);
            } else {
              _closed.complete();
            }
          }
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
  final Set<int> _handshakes = {};
  late final SourceScriptCodec _codec;
  SendPort? _worker;
  int _sequence = 0;
  int _snapshotSequence = 0;
  bool _closing = false;
  bool _acknowledgedClose = false;
  Object? _workerFailure;
  StackTrace? _workerFailureStack;
  Map<String, dynamic> _snapshot = {};
  Map<String, int> _shutdownDiagnostics = {};
  Map<String, int> get shutdownDiagnostics =>
      Map.unmodifiable(_shutdownDiagnostics);
  void Function()? onSnapshotChanged;
  dynamic Function(dynamic, SourceScriptExecution)? _handler;
  Future<dynamic> Function(Future<dynamic> Function())? operationGuard;

  Future<void> get ready => _ready.future;
  Future<void> get whenClosed => _closed.future;
  Map<String, dynamic> get snapshot => Map.unmodifiable(_snapshot);
  dynamic cachedValue(String expression) => _snapshot[expression];
  void setMessageHandler(dynamic Function(dynamic) handler) =>
      _handler = (message, _) => handler(message);
  void setContextMessageHandler(
    dynamic Function(dynamic, SourceScriptExecution) handler,
  ) => _handler = handler;

  Future<dynamic> evaluate(
    String code, {
    String? name,
    SourceScriptExecution? execution,
  }) =>
      _command('evaluate', {'code': code, 'name': name}, execution: execution);

  /// Runs declarations without adopting an intentionally discarded Promise.
  Future<void> execute(String code, {String? name}) async {
    await _command('execute', {'code': code, 'name': name});
  }

  Future<dynamic> invoke(
    String code,
    List<dynamic> arguments, {
    SourceScriptExecution? execution,
  }) => _command('invoke', {
    'code': code,
    'arguments': _codec.encode(arguments),
  }, execution: execution);
  Future<void> setGlobal(String name, dynamic value) async {
    await _command('global', {'name': name, 'value': _codec.encode(value)});
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
    await ready;
    if (_closing) throw StateError('source_script_engine_closed');
    final id = ++_sequence;
    final completion = Completer<dynamic>();
    _pending[id] = completion;
    final scope = inspection ? null : SourceUiScope.current;
    scope?.runtimeIds.add(runtimeId);
    _worker!.send({
      'type': kind,
      'id': id,
      'runtimeId': runtimeId,
      ...arguments,
      'execution':
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
              .withUiScope(scope?.id)
              .toMap(),
    });
    return completion.future;
  }

  void _receive(dynamic raw) {
    final message = raw as Map;
    if (message['runtimeId'] != runtimeId) return;
    switch (message['type']) {
      case 'ready':
        _worker = message['port'] as SendPort;
        if (!_ready.isCompleted) _ready.complete();
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
        if (completion == null) return;
        try {
          final value = _codec.decode(message['value']);
          if (message['error'] == true) {
            completion.completeError(
              value ?? StateError('source_script_error'),
            );
          } else {
            completion.complete(value);
          }
        } catch (error, stack) {
          completion.completeError(error, stack);
        }
      case 'host':
        _handleHost(message);
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

  void _handleHost(Map message) {
    final id = message['reply'] as int;
    if (_closing || !QuickJsHostReply.active(id)) {
      QuickJsHostReply.close(id);
      return;
    }
    _handshakes.add(id);
    try {
      final value = _handler?.call(
        _codec.decode(message['value']),
        SourceScriptExecution.fromMap(message['execution'] as Map),
      );
      if (value is Future) {
        _reply(id, {'kind': 'pending'});
        value.then<void>(
          (result) {
            if (!_closing) _hostResult(id, result, false);
          },
          onError: (Object error, StackTrace stack) {
            if (!_closing) {
              _hostResult(
                id,
                error is JSError ? error : JSError(error, stack),
                true,
              );
            }
          },
        );
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
    if (!_ready.isCompleted) _ready.completeError(error, stack);
    for (final completion in _pending.values) {
      completion.completeError(error, stack);
    }
    _pending.clear();
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
    return whenClosed;
  }
}

class SourceScriptCallback {
  SourceScriptCallback._(this._engine, this._id);
  final SourceScriptEngine _engine;
  final int _id;
  bool _freed = false;
  Future<dynamic> invoke(List<dynamic> arguments) {
    if (_freed) {
      return Future.error(StateError('source_script_callback_released'));
    }
    return _engine._command('callback', {
      'handle': _id,
      'arguments': _engine._codec.encode(arguments),
    });
  }

  Future<void> free() async {
    if (_freed) return;
    _freed = true;
    if (!_engine._closing) await _engine._command('release', {'handle': _id});
  }
}
