import '../debug/source_task_log_recorder.dart';
import '../interaction/source_ui_service.dart';
import '../interaction/source_ui_scope.dart';
import '../models/source_task.dart';
import 'source_operation_context.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';

Future<T> runSourceOperation<T>(
  SourceRuntimeHost host,
  SourceRuntimeHandle handle,
  String method,
  Future<T> Function(SourceOperationContext) operation, {
  SourceTaskOrigin? origin,
  bool serviceOwned = false,
  bool retainOnSourceChange = false,
  List<String> sensitiveValues = const [],
}) {
  host.checkReaderSession(handle.sourceKey, origin);
  final version = host.catalog
      .where((entry) => entry.normalizedKey == handle.sourceKey)
      .firstOrNull
      ?.pluginVersion;
  final recorder = SourceTaskLogRecorder(host.logStore);
  final routeOwner =
      SourceUiScope.current?.owner ??
      SourceUiService.instance.captureOwner?.call();
  final caller = SourceUiScope.current?.controllerOwner;
  return host.tasks.run<T>(
    pluginId: handle.sourceKey,
    pluginVersion: version,
    method: method,
    origin:
        origin ??
        (serviceOwned
            ? SourceTaskOrigin(
                ownerId: host.serviceTaskOwnerId,
                groupId: createSourceTaskId(),
                requestSequence: 0,
              )
            : null),
    linkUiCancellation: !serviceOwned,
    observe: (task, event, disposition, error, stack) => recorder.record(
      task,
      event,
      disposition,
      error,
      stack,
      sensitiveValues: sensitiveValues,
    ),
    operation: (task) {
      task.bindResource(
        handle,
        serviceOwned: serviceOwned,
        survivesSourceChange: retainOnSourceChange,
      );
      final identity = handle.session.loginIdentity;
      final context = SourceOperationContext(
        task,
        resource: handle,
        serviceOwned: serviceOwned,
        retainAdmittedWork:
            retainOnSourceChange || origin?.downloadSession != null,
        canCache: () =>
            host.isCurrentHandle(handle) &&
            handle.session.loginIdentity == identity,
      );
      Future<T> run() => handle.runOperation(() async {
        context.checkActive();
        final T result;
        try {
          result = await operation(context);
        } on SourceUiCancelled catch (error) {
          task.requestStop(
            error.reason == 'timeout'
                ? SourceTaskStopReason.deadlineExceeded
                : SourceTaskStopReason.user,
          );
          context.checkActive();
          rethrow;
        }
        context.checkActive();
        return result;
      });
      if (!serviceOwned) return run();
      Future<T> runService() async {
        final scope = SourceUiScope.current;
        var waiting = scope?.waiting == true;
        void changed() {
          final reason = scope?.reason;
          if (reason != null &&
              (waiting || reason == 'user' || reason == 'timeout')) {
            task.requestStop(switch (reason) {
              'ownerGone' => SourceTaskStopReason.ownerDisposed,
              'sourceChanged' => SourceTaskStopReason.sourceChanged,
              'runtimeDisposed' => SourceTaskStopReason.runtimeClosed,
              'timeout' => SourceTaskStopReason.deadlineExceeded,
              _ => SourceTaskStopReason.user,
            });
          }
          waiting = scope?.waiting == true;
        }

        scope?.addListener(changed);
        try {
          return await run();
        } finally {
          scope?.removeListener(changed);
          // Residual native callbacks retain identity, never fresh UI authority.
          scope?.cancel('operationFinished');
        }
      }

      // Keep the original UI authority while allowing noninteractive admitted
      // work to finish after that authority is revoked.
      return SourceUiService.instance.run(
        runService,
        abortOnScopeCancellation: false,
        inheritCurrent: false,
        routeOwner: routeOwner,
        captureRouteOwner: false,
        serviceLifetimeOwner: caller is SourceUiOwner ? caller : null,
      );
    },
  );
}
