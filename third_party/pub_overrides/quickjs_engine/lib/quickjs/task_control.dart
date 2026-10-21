part of 'quickjs_runtime2.dart';

enum QuickJsStopReason { cancelled, timedOut }

enum QuickJsStopRequest { invalid, accepted, alreadyRequested, completed }

enum QuickJsJobStatus { idle, executed, failed, stopped }

enum QuickJsWorkState { invalid, active, retained, stoppable, stopped }

/// An opaque ID is safe to send to another isolate. No JS pointer is exposed.
class QuickJsTaskControl {
  final int controlId;
  const QuickJsTaskControl.fromId(this.controlId);

  int register() {
    final token = jsTaskRegister(controlId);
    if (token == 0) throw StateError('QuickJS task control is closed');
    return token;
  }

  QuickJsStopRequest requestStop(
    int token, {
    QuickJsStopReason reason = QuickJsStopReason.cancelled,
  }) =>
      QuickJsStopRequest.values[jsTaskStop(controlId, token, reason.index + 1)];
  bool complete(int token) => jsTaskComplete(controlId, token) != 0;
  QuickJsStopRequest stopRetained(
    int token, {
    QuickJsStopReason reason = QuickJsStopReason.cancelled,
  }) =>
      QuickJsStopRequest.values[jsTaskStopRetained(
        controlId,
        token,
        reason.index + 1,
      )];
  QuickJsWorkState workState(int workId) =>
      QuickJsWorkState.values[jsWorkState(controlId, workId)];
  QuickJsStopReason? claimStop(int workId) {
    final reason = jsWorkClaimStop(controlId, workId);
    return reason == 0 ? null : QuickJsStopReason.values[reason - 1];
  }

  void shutdown() => jsTaskShutdown(controlId);
  int get taskCount => jsTaskCount(controlId, 1);
  int get workCount => jsTaskCount(controlId, 2);
  int get sharedRetainedWorkCount => jsTaskCount(controlId, 3);
  static int get activeControlCount => jsTaskCount(0, 0);
}

/// Worker-local lease. Only its integer IDs may be sent across an isolate port.
class QuickJsWorkContext {
  QuickJsWorkContext._(this._runtime, this.taskToken, this.workId)
    : _epoch = runtimeOpaques[_runtime] {
    jsRetainTaskContext(_runtime, taskToken);
    jsRetainWorkContext(_runtime, workId);
  }
  final Pointer<JSRuntime> _runtime;
  final Object? _epoch;
  final int taskToken;
  final int workId;
  bool _released = false;
  bool get _alive =>
      _epoch != null && identical(runtimeOpaques[_runtime], _epoch);
  void release() {
    if (_released) return;
    _released = true;
    if (!_alive) return;
    jsReleaseTaskContext(_runtime, taskToken);
    jsReleaseWorkContext(_runtime, workId);
  }
}

/// Lets a host Future's JS promise depend on its own resource production work.
class QuickJsWorkResult {
  const QuickJsWorkResult(this.value, this.context);
  final dynamic value;
  final QuickJsWorkContext context;
}

class QuickJsTaskStoppedError extends JSError {
  final int taskToken;
  final QuickJsStopReason reason;
  QuickJsTaskStoppedError(this.taskToken, this.reason, [String? stack])
    : super('QuickJS task $taskToken ${reason.name}', stack);
}

class QuickJsJobStep {
  final int taskToken;
  final QuickJsJobStatus status;
  final dynamic error;
  final QuickJsStopReason? stopReason;
  const QuickJsJobStep(
    this.taskToken,
    this.status, {
    this.error,
    this.stopReason,
  });
}
