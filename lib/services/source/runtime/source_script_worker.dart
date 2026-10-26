import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'package:quickjs_engine/quickjs_engine.dart';
import 'source_local_script_bridge.dart';
import 'source_script_codec.dart';
import 'source_host_call_context.dart';

Future<void> runSourceScriptWorker(Map<String, dynamic> configuration) async {
  final worker = _SourceScriptWorker(configuration);
  try {
    worker.start();
  } catch (error, stack) {
    worker.send({
      'type': 'failed',
      'kind': 'bootstrap',
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
  final Stopwatch clock = Stopwatch()..start();
  int startedUs = 0;
}

class _SourceScriptWorker {
  _SourceScriptWorker(this.configuration) {
    codec = SourceScriptCodec(
      encodeCallback: (value) {
        if (value is! JSInvokable) {
          throw UnsupportedError('source_script_wire_value_unsupported');
        }
        final id = ++_nextCallback;
        final work = value.captureWorkContext() ?? native.captureWorkContext();
        final token = work.taskToken;
        value.dup();
        callbacks[id] = (value, work);
        send({
          'type': 'callbackRegistered',
          'handle': id,
          'execution': tasks[token]?.execution ?? _internalExecution,
        });
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
  final Map<int, (JSInvokable, QuickJsWorkContext)> callbacks = {};
  final Map<int, (Completer<dynamic>, QuickJsWorkContext)> hostCalls = {};
  final Map<Timer, (Completer<void>, QuickJsWorkContext)> delays = {};
  final Map<int, int> calls = {};
  // Remote invocations execute in their callback's registration context.
  final Map<int, int> _callbackCallTokens = {};
  final List<Map<String, dynamic>> results = [];
  final Set<int> _completeTokens = {};
  final Set<int> _releaseCandidates = {};
  final Map<String, String> _cancelled = {};
  final Set<String> _cancelPending = {};
  int _nextCallback = 0;
  int _snapshotSequence = 0;
  bool draining = false;
  bool closing = false;
  bool pumping = false;
  // 原生中断过正在执行的 JS 后，在下一个空闲检查点合并执行一次只读探针。
  bool _probeNeeded = false;
  bool _debugProbeFailure = false;

  void _debugFault(String? kind) {
    switch (kind) {
      case 'internalJob':
        _failRuntime(
          StateError('source_runtime_debug_fault'),
          StackTrace.current,
          'internalJob',
        );
      case 'workerError':
        Timer.run(() => throw StateError('source_runtime_debug_fault'));
      case 'exitWithoutCleanup':
        Isolate.exit();
      case 'probe':
        _debugProbeFailure = true;
    }
  }

  Future<void>? _closeFuture;
  String get runtimeId => configuration['runtimeId'] as String;
  Map<String, dynamic> get _internalExecution => {
    'taskId': 'runtime:$runtimeId',
    'pluginId': configuration['pluginId'] as String? ?? '',
    'method': 'runtime.internal',
  };

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
      if (message['type'] == 'debugFault') {
        // 仅供测试注入真实故障路径；release 构建中忽略。
        if (!const bool.fromEnvironment('dart.vm.product')) {
          _debugFault(message['kind'] as String?);
        }
        return;
      }
      if (message['type'] == 'cancel') {
        final taskId = message['taskId'] as String;
        _cancelled[taskId] = message['reason'] as String;
        _cancelPending.add(taskId);
        for (final queued in queue.toList()) {
          if ((queued['execution'] as Map?)?['taskId'] != taskId ||
              queued['type'] == 'release') {
            continue;
          }
          queue.remove(queued);
          calls[queued['id'] as int] = queued['token'] as int;
          _result(
            queued['id'] as int,
            QuickJsTaskStoppedError(
              queued['token'] as int,
              QuickJsStopReason.cancelled,
            ),
            true,
          );
        }
        _reapResources();
        _drain();
        return;
      }
      if (message['type'] != 'hostResult') {
        final token = message['token'] as int;
        tasks[token] = _WorkerTask(message['execution'] as Map);
      }
      if (message['type'] == 'release') {
        final token = message['token'] as int;
        _freeCallback(message['handle'] as int);
        send({
          'type': 'result',
          'id': message['id'],
          'value': codec.encode(null),
          'error': false,
        });
        native.taskControl!.complete(token);
        tasks[token]!.completed = true;
        _releaseTask(token);
        return;
      }
      queue.add(message);
      _pump();
    });
    send({
      'type': 'ready',
      'port': commands.sendPort,
      'controlId': native.taskControl!.controlId,
    });
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
      // JS_ExecutePendingJob releases its final task reference before returning
      // the step. Preserve attribution until the worker has consumed that step.
      if (draining || pumping) {
        _releaseCandidates.add(token);
        return;
      }
      tasks.remove(token);
      send({
        'type': 'executionReleased',
        'execution': task.execution,
        'token': token,
      });
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
          native.withWorkContext(completion.$2, () {
            if (command['error'] == true) {
              completion.$1.completeError(value);
            } else {
              completion.$1.complete(value);
            }
          });
          completion.$2.release();
        }
        // Future settlement first releases native resolvers in Dart microtasks.
        Timer.run(_pump);
        return;
      }
      final id = command['id'] as int;
      final token = command['token'] as int;
      final task = tasks[token]!;
      task.startedUs = task.clock.elapsedMicroseconds;
      send({
        'type': 'executionStarted',
        'execution': task.execution,
        'token': token,
        'id': id,
        'queueElapsedUs': task.startedUs,
      });
      calls[id] = token;
      var entered = false;
      try {
        if (command['type'] != 'release' &&
            _cancelled.containsKey(tasks[token]!.execution['taskId'])) {
          throw QuickJsTaskStoppedError(token, QuickJsStopReason.cancelled);
        }
        entered = true;
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
              _callbackCallTokens[id] = callback.$2.taskToken;
              return native.withWorkContext(
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
        // 排队期间已取消、未进入 JS 的命令不需要探针。
        if (entered && error is QuickJsTaskStoppedError) _probeNeeded = true;
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
    if (error && value is QuickJsTaskStoppedError) {
      native.taskControl!.stopRetained(value.taskToken, reason: value.reason);
    }
    final encoded = native.withTaskContext(token, () => codec.encode(value));
    JSRef.freeRecursive(value);
    results.add({
      'type': 'result',
      'id': id,
      'token': token,
      'value': encoded,
      'error': error,
      'operationElapsedUs': tasks[token] == null
          ? null
          : tasks[token]!.clock.elapsedMicroseconds - tasks[token]!.startedUs,
    });
    final task = tasks[token];
    if (task != null) _completeTokens.add(token);
    calls.remove(id);
    _callbackCallTokens.remove(id);
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
          final step = native.executePendingJobStep();
          if (step.status == QuickJsJobStatus.idle) {
            complete = true;
            break;
          }
          if (step.status == QuickJsJobStatus.failed ||
              step.status == QuickJsJobStatus.stopped) {
            final task = tasks[step.taskToken];
            if (task == null || step.taskToken == 0) {
              throw step.error ??
                  StateError('source_script_internal_job_failed');
            }
            if (step.status == QuickJsJobStatus.stopped) {
              _probeNeeded = true;
              native.taskControl!.stopRetained(
                step.taskToken,
                reason: step.stopReason ?? QuickJsStopReason.cancelled,
              );
            }
            for (final entry in calls.entries.toList()) {
              if (entry.value == step.taskToken ||
                  _callbackCallTokens[entry.key] == step.taskToken) {
                _result(entry.key, step.error, true);
              }
            }
          }
        }
      } catch (error, stack) {
        _failRuntime(error, stack, 'internalJob');
        return;
      }
      try {
        _finishBatch(complete, batch);
      } catch (error, stack) {
        // 清理或检查点自身失败说明运行时状态已不可信，按故障正常关闭。
        _failRuntime(error, stack, 'internalJob');
      }
    }

    batch();
  }

  void _finishBatch(bool complete, void Function() batch) {
    _reapResources();
    _flushCancelled();
    _flushReleasedTasks();
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
    for (final token in _completeTokens.toList()) {
      _completeTokens.remove(token);
      native.taskControl!.complete(token);
      final task = tasks[token];
      if (task != null) task.completed = true;
      _releaseTask(token);
    }
    _reapResources();
    final shared = <String, int>{for (final id in _cancelled.keys) id: 0};
    for (final work in [
      ...callbacks.values.map((e) => e.$2),
      ...delays.values.map((e) => e.$2),
    ]) {
      if (native.taskControl!.workState(work.workId) ==
          QuickJsWorkState.retained) {
        final id = tasks[work.taskToken]?.execution['taskId'] as String?;
        if (id != null) shared[id] = (shared[id] ?? 0) + 1;
      }
    }
    send({'type': 'checkpoint', 'shared': shared});
    for (final id in _cancelPending.toList()) {
      if (calls.values.any(
            (token) => tasks[token]?.execution['taskId'] == id,
          ) ||
          queue.any(
            (command) => (command['execution'] as Map?)?['taskId'] == id,
          )) {
        continue;
      }
      _cancelPending.remove(id);
      send({'type': 'cancelAck', 'taskId': id});
    }
    if (_probeNeeded && _cancelPending.isEmpty) {
      _probeNeeded = false;
      try {
        _probe();
      } catch (error, stack) {
        _failRuntime(error, stack, 'probeFailed');
        return;
      }
    }
    draining = false;
    _flushReleasedTasks();
    if (queue.isNotEmpty) Timer.run(_pump);
  }

  /// 只读健康探针：不运行插件方法，只核对可精确比较的不变量。
  /// 原生 task/work 总数包含主 isolate 预注册和内部 Promise 工作，不能与
  /// worker 表直接相等，因此只检查内部求值与 worker 持有租约的 work。
  void _probe() {
    if (_debugProbeFailure) {
      throw StateError('source_runtime_probe_failed:debug');
    }
    final evaluation = native.withTaskContext(
      0,
      () => native.evaluate('0', notifyJobs: false),
    );
    final value = evaluation.rawResult;
    if (evaluation.isError || value is! num || value != 0) {
      JSRef.freeRecursive(value);
      throw StateError('source_runtime_probe_failed:evaluate');
    }
    for (final work in [
      ...callbacks.values.map((e) => e.$2),
      ...delays.values.map((e) => e.$2),
      ...hostCalls.values.map((e) => e.$2),
    ]) {
      // worker 仍持有租约的 work 在原生侧必须存在。
      if (native.taskControl!.workState(work.workId) ==
          QuickJsWorkState.invalid) {
        throw StateError('source_runtime_probe_failed:work');
      }
    }
    send({'type': 'probe', 'healthy': true});
  }

  void _failRuntime(Object error, StackTrace stack, String kind) {
    if (closing) return;
    draining = false;
    send({
      'type': 'failed',
      'kind': kind,
      'value': codec.encode(error is JSError ? error : JSError(error, stack)),
    });
    unawaited(close());
  }

  void _flushReleasedTasks() {
    final wasDraining = draining;
    final wasPumping = pumping;
    draining = false;
    pumping = false;
    for (final token in _releaseCandidates.toList()) {
      _releaseCandidates.remove(token);
      _releaseTask(token);
    }
    draining = wasDraining;
    pumping = wasPumping;
  }

  // Cancellation acknowledgements and release receipts are control traffic.
  // They must not wait for another task's unbounded microtask checkpoint.
  void _flushCancelled() {
    for (final id in _cancelPending.toList()) {
      if (calls.values.any(
            (token) => tasks[token]?.execution['taskId'] == id,
          ) ||
          queue.any(
            (command) => (command['execution'] as Map?)?['taskId'] == id,
          )) {
        continue;
      }
      for (final result in results.toList()) {
        final token = result['token'] as int;
        if (tasks[token]?.execution['taskId'] != id) continue;
        results.remove(result);
        send(result);
        _completeTokens.remove(token);
        native.taskControl!.complete(token);
        tasks[token]!.completed = true;
        _releaseTask(token);
      }
      _reapResources();
      _cancelPending.remove(id);
      final retained =
          [
                ...callbacks.values.map((e) => e.$2),
                ...delays.values.map((e) => e.$2),
              ]
              .where(
                (work) =>
                    tasks[work.taskToken]?.execution['taskId'] == id &&
                    native.taskControl!.workState(work.workId) ==
                        QuickJsWorkState.retained,
              )
              .length;
      send({
        'type': 'resourceState',
        'shared': {id: retained},
      });
      send({'type': 'cancelAck', 'taskId': id});
    }
  }

  void _reapResources() {
    for (final entry in callbacks.entries.toList()) {
      if (native.taskControl!.claimStop(entry.value.$2.workId) != null) {
        _freeCallback(entry.key);
      }
    }
    for (final entry in delays.entries.toList()) {
      final reason = native.taskControl!.claimStop(entry.value.$2.workId);
      if (reason == null) continue;
      delays.remove(entry.key);
      entry.key.cancel();
      entry.value.$1.completeError(
        QuickJsTaskStoppedError(entry.value.$2.taskToken, reason),
      );
      entry.value.$2.release();
    }
    for (final entry in hostCalls.entries.toList()) {
      final reason = native.taskControl!.claimStop(entry.value.$2.workId);
      if (reason == null) continue;
      hostCalls.remove(entry.key);
      entry.value.$1.completeError(
        QuickJsTaskStoppedError(entry.value.$2.taskToken, reason),
      );
      entry.value.$2.release();
    }
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
    final activeWork = native.captureWorkContext();
    final stopped = native.taskControl!.claimStop(activeWork.workId);
    final activeToken = activeWork.taskToken;
    activeWork.release();
    if (stopped != null) throw QuickJsTaskStoppedError(activeToken, stopped);
    final message = raw is Map ? Map<String, dynamic>.from(raw) : null;
    final method = message?['method'];
    if (message != null && SourceLocalScriptBridge.methods.contains(method)) {
      return local.handle(message);
    }
    if (method == 'delay' && configuration['inspection'] != true) {
      final completer = Completer<void>();
      final work = native.createWorkContext();
      late Timer timer;
      timer = Timer(
        Duration(milliseconds: (message!['time'] as num? ?? 0).toInt()),
        () {
          delays.remove(timer);
          native.withWorkContext(work, completer.complete);
          work.release();
        },
      );
      delays[timer] = (completer, work);
      return QuickJsWorkResult(completer.future, work);
    }
    final work = native.createWorkContext();
    final id = QuickJsHostReply.createForWork(
      native.taskControl!.controlId,
      work.taskToken,
      work.workId,
    );
    final task = tasks[native.taskContext];
    final execution = task?.execution ?? _internalExecution;
    var pending = false;
    try {
      send({
        'type': 'host',
        'reply': id,
        'token': work.taskToken,
        'work': work.workId,
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
          pending = true;
          hostCalls[id] = (completion, work);
          return QuickJsWorkResult(completion.future, work);
        case 'error':
          final error = codec.decode(response['value']);
          if (error is SourceScriptStopped) {
            throw QuickJsTaskStoppedError(
              work.taskToken,
              error.timedOut
                  ? QuickJsStopReason.timedOut
                  : QuickJsStopReason.cancelled,
              error.stack,
            );
          }
          throw error;
        case 'value':
          return codec.decode(response['value']);
        default:
          throw StateError('source_host_reply_invalid');
      }
    } on QuickJsMailboxTimeout catch (_, stack) {
      throw QuickJsTaskStoppedError(
        work.taskToken,
        QuickJsStopReason.timedOut,
        stack.toString(),
      );
    } on QuickJsMailboxStopped catch (error) {
      throw QuickJsTaskStoppedError(
        work.taskToken,
        error.timedOut
            ? QuickJsStopReason.timedOut
            : QuickJsStopReason.cancelled,
      );
    } finally {
      QuickJsHostReply.close(id);
      if (!pending) work.release();
    }
  }

  void _freeCallback(int id) {
    final value = callbacks.remove(id);
    if (value != null) {
      value.$1.free();
      value.$2.release();
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
    _callbackCallTokens.clear();
    native.taskControl!.shutdown();
    for (final completion in hostCalls.values) {
      if (!completion.$1.isCompleted) {
        completion.$1.completeError(StateError('source_script_engine_closed'));
      }
      completion.$2.release();
    }
    hostCalls.clear();
    for (final entry in delays.entries) {
      entry.key.cancel();
      if (!entry.value.$1.isCompleted) {
        entry.value.$1.completeError(StateError('source_script_engine_closed'));
      }
      entry.value.$2.release();
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
    _releaseCandidates.clear();
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
  }) : super(taskControlEnabled: true);
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
];
