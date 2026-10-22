import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

final _taskRandom = Random.secure();

/// Process-independent identities for tasks, owners, groups and engines.
String createSourceTaskId() => List.generate(
  16,
  (_) => _taskRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

enum SourceTaskState {
  created,
  running,
  cancelRequested,
  succeeded,
  failed,
  cancelled,
  timedOut,
}

enum SourceTaskStopReason {
  user,
  superseded,
  ownerDisposed,
  sourceChanged,
  pluginDisabled,
  pluginUpdated,
  deadlineExceeded,
  executionTimeout,
  runtimeClosed,
}

class SourceTaskCancelled implements Exception {
  const SourceTaskCancelled(this.taskId, this.reason, {this.runtimeId});
  final String taskId;
  final String? runtimeId;
  final SourceTaskStopReason reason;
  @override
  String toString() => 'source_task_cancelled:${reason.name}';
}

class SourceTaskTimedOut extends SourceTaskCancelled {
  const SourceTaskTimedOut(super.taskId, super.reason, {super.runtimeId});
  @override
  String toString() => 'source_task_timeout:${reason.name}';
}

bool isSourceTaskCancellation(Object error) =>
    error is SourceTaskCancelled && error is! SourceTaskTimedOut;

/// Explicit host-only request lifetime, including gaps between service calls.
class SourceTaskCancellation extends ChangeNotifier {
  SourceTaskStopReason? _reason;
  final _stopped = Completer<void>();
  SourceTaskStopReason? get reason => _reason;
  Future<void> get whenStopped => _stopped.future;

  void cancel(SourceTaskStopReason reason) {
    if (_reason != null) return;
    _reason = reason;
    _stopped.complete();
    notifyListeners();
  }
}

enum SourceTaskResultDisposition { current, superseded, disposed, timedOut }

/// Ownership remains on the host; only the data fields belong on a worker wire.
class SourceTaskOrigin {
  const SourceTaskOrigin({
    required this.ownerId,
    required this.groupId,
    required this.requestSequence,
    this.resultDisposition,
    this.cancellation,
    this.workTimeout,
    this.readerSession,
    this.retainOnSourceChange = false,
  });

  factory SourceTaskOrigin.standalone() => SourceTaskOrigin(
    ownerId: createSourceTaskId(),
    groupId: createSourceTaskId(),
    requestSequence: 0,
  );

  final String ownerId;
  final String groupId;
  final int requestSequence;
  final SourceTaskCancellation? cancellation;
  final Duration? workTimeout;
  final SourceReaderSession? readerSession;
  final bool retainOnSourceChange;

  /// Observes result usefulness without changing execution or cancellation.
  /// This callback is local to the host and must never cross an isolate port.
  final SourceTaskResultDisposition Function()? resultDisposition;
}

/// A host-only reading lease. Cancellation never grants interaction authority.
class SourceReaderSession {
  SourceReaderSession(this.sourceKey, this._release);
  final String id = createSourceTaskId();
  final String sourceKey;
  final void Function() _release;
  final SourceTaskCancellation cancellation = SourceTaskCancellation();
  bool _released = false;

  void checkActive() {
    if (cancellation.reason case final reason?) {
      throw SourceTaskCancelled(id, reason);
    }
  }

  void close([
    SourceTaskStopReason reason = SourceTaskStopReason.ownerDisposed,
  ]) {
    if (_released) return;
    _released = true;
    cancellation.cancel(reason);
    _release();
  }
}

class SourceTaskSnapshot {
  const SourceTaskSnapshot({
    required this.taskId,
    required this.pluginId,
    required this.pluginVersion,
    required this.method,
    required this.ownerId,
    required this.groupId,
    required this.requestSequence,
    required this.runtimeId,
    required this.state,
    required this.createdAt,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    this.stopReason,
    this.cancelRequestedAt,
    this.settledAt,
    this.sharedResourceCount = 0,
  });

  final String taskId;
  final String pluginId;
  final String? pluginVersion;
  final String method;
  final String ownerId;
  final String groupId;
  final int requestSequence;
  final String? runtimeId;
  final SourceTaskState state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final Duration duration;
  final SourceTaskStopReason? stopReason;
  final DateTime? cancelRequestedAt;
  final DateTime? settledAt;
  final int sharedResourceCount;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'pluginId': pluginId,
    'pluginVersion': pluginVersion,
    'method': method,
    'ownerId': ownerId,
    'groupId': groupId,
    'requestSequence': requestSequence,
    'runtimeId': runtimeId,
    'state': state.name,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'durationMs': duration.inMicroseconds / 1000,
    if (stopReason != null) 'stopReason': stopReason!.name,
    if (cancelRequestedAt != null)
      'cancelRequestedAt': cancelRequestedAt!.toIso8601String(),
    if (settledAt != null) 'settledAt': settledAt!.toIso8601String(),
    'sharedResourceCount': sharedResourceCount,
  };
}
