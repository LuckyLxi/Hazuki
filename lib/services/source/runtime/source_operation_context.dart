import '../models/source_script_execution.dart';
import 'source_script_engine.dart';
import 'source_task_registry.dart';
import '../models/source_task.dart';
import '../interaction/source_ui_scope.dart';
import 'source_host_call_context.dart';
import '../account/source_login_interaction.dart';
import '../gateways/source_task_control_gateway.dart';

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
    this.retainAdmittedWork = false,
  });
  final SourceTask task;
  final Object? resource;
  final bool serviceOwned;
  final bool retainAdmittedWork;
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
      retainAdmittedWork: serviceOwned || retainAdmittedWork,
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
      retainAdmittedWork: serviceOwned || retainAdmittedWork,
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

  /// Links a separately subscribed resource to this operation, including drain.
  Future<T> runChild<T>(
    SourceTaskRegistry registry,
    Future<T> Function(SourceTaskOrigin) operation, {
    SourceReaderSession? readerSession,
    SourceDownloadSession? downloadSession,
  }) async {
    checkActive();
    final signal = SourceTaskCancellation();
    final group = createSourceTaskId();
    Future<SourceTaskCancelReceipt> stop(SourceTaskStopReason reason) async {
      signal.cancel(reason);
      final receipt = await registry.cancelGroup(
        ownerId: task.snapshot.ownerId,
        groupId: group,
        reason: reason,
      );
      task.retainUntil(receipt.whenSettled);
      return receipt;
    }

    task.addStopHandler(stop);
    try {
      return await operation(
        SourceTaskOrigin(
          ownerId: task.snapshot.ownerId,
          groupId: group,
          requestSequence: task.snapshot.requestSequence,
          cancellation: signal,
          readerSession: readerSession,
          downloadSession: downloadSession,
          retainOnSourceChange: task.survivesSourceChange,
        ),
      );
    } finally {
      task.removeStopHandler(stop);
      // The child may have delivered bytes while its exclusive resources drain.
      final receipt = await registry.cancelGroup(
        ownerId: task.snapshot.ownerId,
        groupId: group,
        reason: signal.reason ?? SourceTaskStopReason.ownerDisposed,
      );
      task.retainUntil(receipt.whenSettled);
    }
  }
}
