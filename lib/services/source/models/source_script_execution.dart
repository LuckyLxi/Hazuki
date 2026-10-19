import 'source_task.dart';

/// Plain execution identity; never contains page callbacks or script arguments.
class SourceScriptExecution {
  const SourceScriptExecution({
    required this.taskId,
    required this.pluginId,
    required this.method,
    this.pluginVersion,
    this.ownerId,
    this.groupId,
    this.requestSequence,
  });
  factory SourceScriptExecution.fromTask(SourceTaskSnapshot task) =>
      SourceScriptExecution.fromMap(task.toJson());
  factory SourceScriptExecution.fromMap(Map<dynamic, dynamic> value) =>
      SourceScriptExecution(
        taskId: value['taskId'] as String,
        pluginId: value['pluginId'] as String,
        method: value['method'] as String,
        pluginVersion: value['pluginVersion'] as String?,
        ownerId: value['ownerId'] as String?,
        groupId: value['groupId'] as String?,
        requestSequence: value['requestSequence'] as int?,
      );
  final String taskId;
  final String pluginId;
  final String method;
  final String? pluginVersion;
  final String? ownerId;
  final String? groupId;
  final int? requestSequence;
  Map<String, Object?> toMap() => {
    'taskId': taskId,
    'pluginId': pluginId,
    'pluginVersion': pluginVersion,
    'method': method,
    'ownerId': ownerId,
    'groupId': groupId,
    'requestSequence': requestSequence,
  };
}
