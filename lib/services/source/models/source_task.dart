import 'dart:math';

final _taskRandom = Random.secure();

/// Process-independent identities for tasks, owners, groups and engines.
String createSourceTaskId() => List.generate(
  16,
  (_) => _taskRandom.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

enum SourceTaskState { created, running, succeeded, failed }

enum SourceTaskResultDisposition { current, superseded, disposed, timedOut }

/// Ownership remains on the host; only the data fields belong on a worker wire.
class SourceTaskOrigin {
  const SourceTaskOrigin({
    required this.ownerId,
    required this.groupId,
    required this.requestSequence,
    this.resultDisposition,
  });

  factory SourceTaskOrigin.standalone() => SourceTaskOrigin(
    ownerId: createSourceTaskId(),
    groupId: createSourceTaskId(),
    requestSequence: 0,
  );

  final String ownerId;
  final String groupId;
  final int requestSequence;

  /// Observes result usefulness without changing execution or cancellation.
  /// This callback is local to the host and must never cross an isolate port.
  final SourceTaskResultDisposition Function()? resultDisposition;
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
  };
}
