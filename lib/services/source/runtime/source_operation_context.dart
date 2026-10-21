import '../models/source_script_execution.dart';
import 'source_script_engine.dart';
import 'source_task_registry.dart';
import '../models/source_task.dart';
import '../interaction/source_ui_scope.dart';
import 'source_host_call_context.dart';
import '../account/source_login_interaction.dart';

void rethrowSourceOperationStop(Object error) {
  if (error is SourceTaskCancelled ||
      (error is SourceScriptStopped && error.reason != 'dependencyStopped') ||
      error is SourceUiCancelled ||
      error is SourceLoginCancelled) {
    throw error;
  }
}

/// Explicit identity for all commands and commits in one service operation.
class SourceOperationContext {
  SourceOperationContext(
    this.task, {
    required this.canCache,
    this.resource,
    this.serviceOwned = false,
  });
  final SourceTask task;
  final Object? resource;
  final bool serviceOwned;
  final bool Function() canCache;

  void checkActive() {
    task.checkActive();
    if (task.snapshot.endedAt != null) {
      throw StateError('source_operation_already_finished');
    }
  }

  SourceScriptExecution get execution =>
      SourceScriptExecution.fromTask(task.snapshot);

  void bind(SourceScriptEngine engine) {
    checkActive();
    if (task.snapshot.runtimeId == null) {
      task.bindRuntime(
        runtimeId: engine.runtimeId,
        pluginVersion: task.snapshot.pluginVersion,
        engine: engine,
      );
    } else if (task.snapshot.runtimeId != engine.runtimeId) {
      throw StateError('source_operation_runtime_changed');
    }
  }

  Future<dynamic> evaluate(
    SourceScriptEngine engine,
    String code, {
    String? name,
  }) async {
    bind(engine);
    final result = await engine.evaluate(
      code,
      name: name,
      execution: execution,
      retainAdmittedWork: serviceOwned,
    );
    checkActive();
    return result;
  }

  Future<dynamic> invoke(
    SourceScriptEngine engine,
    String code,
    List<dynamic> arguments,
  ) async {
    bind(engine);
    final result = await engine.invoke(
      code,
      arguments,
      execution: execution,
      retainAdmittedWork: serviceOwned,
    );
    checkActive();
    return result;
  }

  Future<T> commit<T>(Future<T> Function() operation) {
    checkActive();
    return task.runCommit(operation);
  }

  Future<T> resolve<T>(Future<T> result) async {
    final value = await result;
    checkActive();
    return value;
  }
}
