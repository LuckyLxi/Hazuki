import 'dart:async';

import 'package:quickjs_engine/quickjs_engine.dart';

/// Preserves the source SDK's native values, callbacks and Promise semantics.
class SourceScriptEngine {
  SourceScriptEngine({
    int timeout = 5000,
    int memoryLimit = 64 * 1024 * 1024,
    void Function(dynamic)? hostPromiseRejectionHandler,
  }) : _runtime = _SourceQuickJsRuntime(
         timeout: timeout,
         memoryLimit: memoryLimit,
         hostPromiseRejectionHandler: hostPromiseRejectionHandler ?? (_) {},
       ) {
    // QuickJsRuntime2.dispatch() drains once; its FFI bridge posts a wake-up
    // after evaluation and callback completion. Listen for every wake-up.
    _runtime.port.listen((_) => _drainJobs());
  }

  final QuickJsRuntime2 _runtime;
  final _pendingResults = <Completer<dynamic>>{};
  int _pendingHostCalls = 0;
  bool _closed = false;
  bool _disposed = false;

  dynamic evaluate(String code, {String? name}) {
    _ensureOpen();
    final result = _runtime.evaluate(code, name: name);
    if (result.isError) throw result.rawResult;
    final value = result.rawResult;
    return value is Future ? _trackResult(value) : value;
  }

  Future<dynamic> _trackResult(Future<dynamic> value) {
    final completer = Completer<dynamic>();
    // Script evaluation may intentionally discard its completion value.
    completer.future.ignore();
    _pendingResults.add(completer);
    value.then<void>(
      (result) {
        _pendingResults.remove(completer);
        if (!completer.isCompleted) completer.complete(result);
      },
      onError: (Object error, StackTrace stack) {
        _pendingResults.remove(completer);
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    return completer.future;
  }

  void _drainJobs() {
    try {
      _runtime.executePendingJob();
    } catch (error, stack) {
      // A native interruption can abort a job before QuickJS rejects its
      // Promise. Finish Dart callers instead of leaving them waiting forever.
      _failPending(error, stack);
    }
  }

  void _failPending(Object error, StackTrace stack) {
    for (final completer in _pendingResults) {
      completer.completeError(error, stack);
    }
    _pendingResults.clear();
  }

  void setGlobal(String name, dynamic value) {
    final setter =
        evaluate('(key, value) => { globalThis[key] = value; }') as JSInvokable;
    try {
      setter.invoke([name, value]);
    } finally {
      setter.free();
    }
  }

  void setMessageHandler(dynamic Function(dynamic message) handler) {
    setGlobal('sendMessage', (dynamic message) {
      _ensureOpen();
      final result = handler(message);
      if (result is! Future) return result;
      _pendingHostCalls++;
      return result.whenComplete(() {
        // The package still has to resolve/reject its native Promise and free
        // callback references after this Future completes.
        Timer.run(() {
          _pendingHostCalls--;
          if (_closed) _disposeIfIdle();
        });
      });
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _disposeIfIdle();
  }

  dynamic invoke(String code, List<dynamic> arguments) {
    final function = evaluate(code) as JSInvokable;
    try {
      final value = function.invoke(arguments);
      return value is Future ? _trackResult(value) : value;
    } finally {
      function.free();
    }
  }

  void _ensureOpen() {
    if (_closed) throw StateError('source_script_engine_closed');
  }

  void _disposeIfIdle() {
    if (_disposed || _pendingHostCalls != 0) return;
    _disposed = true;
    _failPending(StateError('source_script_engine_closed'), StackTrace.current);
    _runtime.dispose();
  }
}

/// Hazuki installs its own sendMessage, console and timer APIs from init.js.
class _SourceQuickJsRuntime extends QuickJsRuntime2 {
  _SourceQuickJsRuntime({
    required super.timeout,
    required super.memoryLimit,
    required super.hostPromiseRejectionHandler,
  });

  @override
  JavascriptRuntime init() => this;
}
