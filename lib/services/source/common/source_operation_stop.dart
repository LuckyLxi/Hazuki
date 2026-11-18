import '../account/source_login_interaction.dart';
import '../interaction/source_ui_scope.dart';
import '../models/source_task.dart';
import '../runtime/source_host_call_context.dart';

void rethrowSourceOperationStop(Object error) {
  if (error is SourceTaskCancelled ||
      (error is SourceScriptStopped && error.reason != 'dependencyStopped') ||
      error is SourceUiCancelled ||
      error is SourceLoginCancelled) {
    throw error;
  }
}
