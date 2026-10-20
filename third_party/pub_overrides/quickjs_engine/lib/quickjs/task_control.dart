part of 'quickjs_runtime2.dart';

enum QuickJsStopReason { cancelled, timedOut }

enum QuickJsStopRequest { invalid, accepted, alreadyRequested, completed }

enum QuickJsJobStatus { idle, executed, failed, stopped }

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
  int get taskCount => jsTaskCount(controlId, 1);
  int get workCount => jsTaskCount(controlId, 2);
  int get sharedRetainedWorkCount => jsTaskCount(controlId, 3);
  static int get activeControlCount => jsTaskCount(0, 0);
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
