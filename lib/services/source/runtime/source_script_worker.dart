import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'package:quickjs_engine/quickjs_engine.dart';
import 'source_local_script_bridge.dart';
import 'source_script_codec.dart';

Future<void> runSourceScriptWorker(Map<String, dynamic> configuration) async {
  final worker = _SourceScriptWorker(configuration);
  try {
    worker.start();
  } catch (error, stack) {
    worker.send({
      'type': 'failed',
      'value': worker.codec.encode(JSError(error, stack)),
    });
    await worker.close();
  }
}

class _WorkerTask {
  _WorkerTask(this.execution);
  final Map execution;
  int references = 0;
  bool completed = false;
}

class _SourceScriptWorker {
  _SourceScriptWorker(this.configuration) {
    codec = SourceScriptCodec(
      encodeCallback: (value) {
        if (value is! JSInvokable) {
          throw UnsupportedError('source_script_wire_value_unsupported');
        }
        final id = ++_nextCallback;
        final token = native.taskContext;
        value.dup();
        native.retainTaskContext(token);
        callbacks[id] = (value, token);
        return id;
      },
      decodeCallback: (id) =>
          callbacks[id]?.$1 ??
          (throw StateError('source_script_callback_released')),
    );
  }
  final Map<String, dynamic> configuration;
  final ReceivePort commands = ReceivePort();
  late final SourceScriptCodec codec;
  _SourceQuickJsRuntime? _native;
  _SourceQuickJsRuntime get native => _native!;
  final SourceLocalScriptBridge local = SourceLocalScriptBridge();
  final Queue<Map> queue = Queue();
  final Map<int, _WorkerTask> tasks = {};
  final Map<int, (JSInvokable, int)> callbacks = {};
  final Map<int, Completer<dynamic>> hostCalls = {};
  final Map<Timer, (Completer<void>, int)> delays = {};
  final Map<int, int> calls = {};
  final List<Map<String, dynamic>> results = [];
  int _nextTask = 0;
  int _nextCallback = 0;
  int _snapshotSequence = 0;
  bool draining = false;
  bool closing = false;
  bool pumping = false;
  Future<void>? _closeFuture;
  String get runtimeId => configuration['runtimeId'] as String;

  void send(Map<String, dynamic> message) => (configuration['port'] as SendPort)
      .send({'runtimeId': runtimeId, ...message});

  void start() {
    _native = _SourceQuickJsRuntime(
      timeout: configuration['timeout'] as int,
      memoryLimit: configuration['memoryLimit'] as int,
      taskReferenceHandler: (token, delta) {
        final task = tasks[token];
        if (task == null) return;
        task.references += delta;
        _releaseTask(token);
      },
      hostPromiseRejectionHandler: (reason) {
        if (!closing) {
          send({'type': 'rejection', 'value': codec.encode(reason)});
        }
      },
    );
    _setGlobal('sendMessage', _hostCall);
    native.port.listen((_) {
      if (!closing) _drain();
    });
    commands.listen((raw) {
      final message = raw as Map;
      if (message['runtimeId'] != runtimeId) return;
      if (message['type'] == 'close') {
        unawaited(close());
        return;
      }
      if (closing) return;
      queue.add(message);
      _pump();
    });
    send({'type': 'ready', 'port': commands.sendPort});
  }

  dynamic _evaluate(String code, {String? name}) {
    final result = native.evaluate(code, name: name);
    if (result.isError) throw result.rawResult;
    return result.rawResult;
  }

  void _setGlobal(String name, dynamic value) {
    final setter =
        _evaluate('(key,value)=>{globalThis[key]=value;}') as JSInvokable;
    try {
      setter.invoke([name, value]);
    } finally {
      setter.free();
    }
  }

  void _releaseTask(int token) {
    final task = tasks[token];
    if (task != null && task.completed && task.references == 0) {
      tasks.remove(token);
    }
  }

  void _pump() {
    if (closing || pumping || draining) return;
    pumping = true;
    try {
      if (queue.isEmpty) {
        _drain();
        return;
      }
      final command = queue.removeFirst();
      if (command['type'] == 'hostResult') {
        final completion = hostCalls.remove(command['id']);
        if (completion != null) {
          final value = codec.decode(command['value']);
          if (command['error'] == true) {
            completion.completeError(value);
          } else {
            completion.complete(value);
          }
        }
        // Future settlement first releases native resolvers in Dart microtasks.
        Timer.run(_pump);
        return;
      }
      final id = command['id'] as int;
      final token = ++_nextTask;
      final callbackToken = command['type'] == 'callback'
          ? callbacks[command['handle']]?.$2
          : null;
      tasks[token] = _WorkerTask(
        tasks[callbackToken]?.execution ?? command['execution'] as Map,
      );
      calls[id] = token;
      try {
        final value = native.withTaskContext(token, () {
          switch (command['type']) {
            case 'execute':
              final discarded = _evaluate(
                command['code'] as String,
                name: command['name'] as String?,
              );
              if (discarded is Future) {
                discarded.ignore();
              } else {
                JSRef.freeRecursive(discarded);
              }
              return null;
            case 'evaluate':
              return _evaluate(
                command['code'] as String,
                name: command['name'] as String?,
              );
            case 'invoke':
              final function =
                  _evaluate(command['code'] as String) as JSInvokable;
              try {
                return function.invoke(
                  codec.decode(command['arguments']) as List,
                );
              } finally {
                function.free();
              }
            case 'global':
              _setGlobal(
                command['name'] as String,
                codec.decode(command['value']),
              );
              return null;
            case 'callback':
              final callback = callbacks[command['handle']];
              if (callback == null) {
                throw StateError('source_script_callback_released');
              }
              return native.withTaskContext(
                callback.$2,
                () => callback.$1.invoke(
                  codec.decode(command['arguments']) as List,
                ),
              );
            case 'release':
              _freeCallback(command['handle'] as int);
              return null;
            default:
              throw StateError('source_script_command_invalid');
          }
        });
        if (value is Future) {
          value.then<void>(
            (value) => _result(id, value, false),
            onError: (Object error, StackTrace stack) => _result(
              id,
              error is JSError ? error : JSError(error, stack),
              true,
            ),
          );
        } else {
          _result(id, value, false);
        }
      } catch (error, stack) {
        _result(id, error is JSError ? error : JSError(error, stack), true);
      }
      _drain();
    } finally {
      pumping = false;
    }
  }

  void _result(int id, dynamic value, bool error) {
    if (closing || !calls.containsKey(id)) {
      JSRef.freeRecursive(value);
      return;
    }
    // Encoding callback values must retain the originating execution context.
    final token = calls[id]!;
    final encoded = native.withTaskContext(token, () => codec.encode(value));
    JSRef.freeRecursive(value);
    results.add({'type': 'result', 'id': id, 'value': encoded, 'error': error});
    final task = tasks[token];
    if (task != null) task.completed = true;
    calls.remove(id);
    _releaseTask(token);
    if (!pumping && !draining) _drain();
  }

  void _drain() {
    if (closing || draining) return;
    draining = true;
    void batch() {
      if (closing) {
        draining = false;
        return;
      }
      final clock = Stopwatch()..start();
      var complete = false;
      try {
        for (var i = 0; i < 64 && clock.elapsedMilliseconds < 8; i++) {
          if (native.executePendingJobOnce() == 0) {
            complete = true;
            break;
          }
        }
      } catch (error, stack) {
        complete = true;
        for (final id in calls.keys.toList()) {
          _result(id, error is JSError ? error : JSError(error, stack), true);
        }
      }
      if (!complete) {
        Timer.run(batch);
        return;
      }
      try {
        _publishSnapshot();
      } catch (_) {
        /* Retain the last valid snapshot. */
      }
      for (final result in results) {
        send(result);
      }
      results.clear();
      draining = false;
      if (queue.isNotEmpty) Timer.run(_pump);
    }

    batch();
  }

  void _publishSnapshot() {
    final fields = _snapshotExpressions
        .map((code) => '${jsonEncode(code)}:($code)')
        .join(',');
    final expression =
        '''(() => {if (!globalThis.__hazuki_source) return {}; return {
      $fields,
      __metadata:JSON.stringify((({key,name,version,presentation,settings,translation,account})=>
        ({key,name,version,presentation,settings,translation,supportsAccount:typeof account?.login === "function"}))(globalThis.__hazuki_source))
    };})()''';
    final evaluation = native.withTaskContext(
      0,
      () => native.evaluate(expression, notifyJobs: false),
    );
    if (evaluation.isError) throw evaluation.rawResult;
    final snapshot = evaluation.rawResult;
    send({
      'type': 'snapshot',
      'sequence': ++_snapshotSequence,
      'value': codec.encode(snapshot),
    });
    JSRef.freeRecursive(snapshot);
  }

  dynamic _hostCall(dynamic raw) {
    if (closing) throw StateError('source_script_engine_closed');
    final message = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final method = message?['method'];
    if (message != null && SourceLocalScriptBridge.methods.contains(method)) {
      return local.handle(message);
    }
    if (method == 'delay' && configuration['inspection'] != true) {
      final completer = Completer<void>();
      final token = native.taskContext;
      native.retainTaskContext(token);
      late Timer timer;
      timer = Timer(
        Duration(milliseconds: (message!['time'] as num? ?? 0).toInt()),
        () {
          delays.remove(timer);
          completer.complete();
          native.releaseTaskContext(token);
        },
      );
      delays[timer] = (completer, token);
      return completer.future;
    }
    final id = QuickJsHostReply.create();
    final task = tasks[native.taskContext];
    final execution =
        task?.execution ??
        {
          'taskId': 'runtime:$runtimeId',
          'pluginId': configuration['pluginId'] as String? ?? '',
          'method': 'runtime.internal',
        };
    try {
      send({
        'type': 'host',
        'reply': id,
        'value': codec.encode(raw),
        'execution': execution,
      });
      final response =
          jsonDecode(
                utf8.decode(
                  QuickJsHostReply.wait(
                    id,
                    native.remainingExecutionMilliseconds,
                  ),
                ),
              )
              as Map;
      switch (response['kind']) {
        case 'pending':
          final completion = Completer<dynamic>();
          completion.future.ignore();
          hostCalls[id] = completion;
          return completion.future;
        case 'error':
          throw codec.decode(response['value']);
        case 'value':
          return codec.decode(response['value']);
        default:
          throw StateError('source_host_reply_invalid');
      }
    } finally {
      QuickJsHostReply.close(id);
    }
  }

  void _freeCallback(int id) {
    final value = callbacks.remove(id);
    if (value != null) {
      value.$1.free();
      native.releaseTaskContext(value.$2);
    }
  }

  Future<void> close() => _closeFuture ??= _close();
  Future<void> _close() async {
    closing = true;
    if (_native == null) {
      commands.close();
      return;
    }
    queue.clear();
    results.clear();
    calls.clear();
    for (final completion in hostCalls.values) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('source_script_engine_closed'));
      }
    }
    hostCalls.clear();
    for (final entry in delays.entries) {
      entry.key.cancel();
      if (!entry.value.$1.isCompleted) {
        entry.value.$1.completeError(StateError('source_script_engine_closed'));
      }
      native.releaseTaskContext(entry.value.$2);
    }
    delays.clear();
    // Let host Future resolvers settle and release their native callbacks first.
    await Future<void>.delayed(Duration.zero);
    for (final id in callbacks.keys.toList()) {
      _freeCallback(id);
    }
    local.html.clear();
    native.dispose();
    tasks.clear();
    send({
      'type': 'closed',
      'diagnostics': {
        'nativeRuntimes': QuickJsRuntime2.registeredRuntimeCount,
        'tasks': tasks.length,
        'callbacks': callbacks.length,
        'hostCalls': hostCalls.length,
        'timers': delays.length,
      },
    });
    commands.close();
  }
}

class _SourceQuickJsRuntime extends QuickJsRuntime2 {
  _SourceQuickJsRuntime({
    required super.timeout,
    required super.memoryLimit,
    required super.hostPromiseRejectionHandler,
    required super.taskReferenceHandler,
  });
  @override
  JavascriptRuntime init() => this;
}

const _snapshotExpressions = <String>[
  "!!this.__hazuki_source.comic?.likeComment",
  "!!this.__hazuki_source.comic?.loadComments && this.__hazuki_source.presentation?.commentReplies == true",
  "!!this.__hazuki_source.comic?.sendComment",
  "!!this.__hazuki_source.favorites?.addFolder",
  "!!this.__hazuki_source.favorites?.addOrDelFavorite",
  "!!this.__hazuki_source.favorites?.deleteFolder",
  'typeof this.__hazuki_source.favorites?.renameFolder === "function"',
  "!!this.__hazuki_source.favorites?.loadComics",
  "!!this.__hazuki_source.favorites?.loadFolders",
  "!!this.__hazuki_source.favorites?.loadNext",
  "this.__hazuki_source.favorites?.singleFolderForSingleComic == true",
  "this.__hazuki_source.translation ?? {}",
  "typeof globalThis.__hazuki_source.comic?.loadReadingHistory === \"function\"",
  "typeof globalThis.__hazuki_source.comic?.loadReadingProgress === \"function\"",
  "typeof globalThis.__hazuki_source.comic?.onReadingProgress === \"function\"",
  "typeof this.__hazuki_source.comic?.likeComic === \"function\"",
];
