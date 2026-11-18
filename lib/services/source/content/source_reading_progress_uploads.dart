import 'dart:async';

import '../models/source_task.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';

const sourceReadingProgressWorkTimeout = Duration(seconds: 30);

/// Account-scoped FIFO. Admission is synchronous; its budget excludes waiting.
class SourceReadingProgressUploads {
  SourceReadingProgressUploads(
    this.host, {
    this.workTimeout = sourceReadingProgressWorkTimeout,
  }) {
    host.addListener(_changed);
    host.runtimeRegistry.addListener(_changed);
  }
  final SourceRuntimeHost host;
  final Duration workTimeout;
  final String _ownerId = createSourceTaskId();
  final Map<String, Future<void>> _queues = {};
  final Set<_Upload> _uploads = {};
  bool _disposed = false;
  Future<void> get whenSettled =>
      Future.wait(_uploads.map((entry) => entry.done.future)).then((_) {});

  void _changed() {
    // Check inactive sources too: their admitted uploads still own leases.
    for (final entry in _uploads.toList()) {
      if (entry.handle.session.loginIdentity != entry.identity) {
        entry.signal.cancel(SourceTaskStopReason.accountChanged);
      } else if (!host.isCurrentHandle(entry.handle)) {
        entry.signal.cancel(SourceTaskStopReason.runtimeClosed);
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    host.removeListener(_changed);
    host.runtimeRegistry.removeListener(_changed);
    for (final entry in _uploads.toList()) {
      entry.signal.cancel(SourceTaskStopReason.ownerDisposed);
    }
  }

  Future<void> report(
    Map<String, Object> progress,
    String sourceKey, {
    SourceTaskOrigin? origin,
  }) {
    if (_disposed) {
      return Future.error(StateError('source_progress_uploads_disposed'));
    }
    if (!host.runtimeRegistry.isAllowedSourceKey(sourceKey)) {
      return Future.value();
    }
    final handle = host.handleFor(sourceKey);
    final identity = handle.session.loginIdentity;
    if (identity == null) return Future.value();
    // No await before the snapshot, lease, registration and FIFO admission.
    final snapshot = Map<String, Object>.unmodifiable(
      (_freeze(progress) as Map).cast<String, Object>(),
    );
    final lease = host.acquireServiceRuntimeLease(handle);
    // 记录接纳时的实例：它故障后该项结束，不转移到重建后的新实例。
    final admittedEngine = handle.runtime.engine;
    final entry = _Upload(handle, identity, lease);
    _uploads.add(entry);
    final previous = _queues[sourceKey] ?? Future<void>.value();
    final caller = origin?.cancellation;
    void callerStopped() {
      if (caller?.reason case final reason?) entry.signal.cancel(reason);
    }

    caller?.addListener(callerStopped);
    callerStopped();
    final work = runSourceOperation<void>(
      host,
      handle,
      'cloud.upload',
      (context) async {
        entry.context = context;
        await Future.any([
          previous,
          context.task.whenStopped.then((_) => context.checkActive()),
        ]);
        context.checkActive();
        _changed();
        context.checkActive();
        await context.withWorkTimeout<void>(workTimeout, () async {
          if (admittedEngine?.failure case final failure?) {
            throw failure.forTask(context.task.taskId);
          }
          final engine = handle.runtime.engine;
          if (engine == null) return;
          handle.hostExecutionGuards[context.task.taskId] = () {
            final reason = handle.session.loginIdentity != identity
                ? SourceTaskStopReason.accountChanged
                : lease.cancellation.reason;
            if (reason == SourceTaskStopReason.accountChanged ||
                reason == SourceTaskStopReason.pluginDisabled ||
                reason == SourceTaskStopReason.pluginUpdated ||
                reason == SourceTaskStopReason.runtimeClosed) {
              entry.signal.cancel(reason!);
              throw SourceTaskCancelled(context.task.taskId, reason);
            }
          };
          if (await context.evaluate(
                engine,
                'typeof this.__hazuki_source.comic?.onReadingProgress === "function"',
              ) !=
              true) {
            return;
          }
          _changed();
          context.checkActive();
          final raw = await context.invoke(
            engine,
            '(progress) => this.__hazuki_source.comic.onReadingProgress(progress)',
            [snapshot],
          );
          await context.resolve(handle.facade.js.resolve(raw));
          _changed();
          context.checkActive();
        });
      },
      origin: SourceTaskOrigin(
        ownerId: origin?.ownerId ?? _ownerId,
        groupId: origin?.groupId ?? createSourceTaskId(),
        requestSequence: origin?.requestSequence ?? 0,
        cancellation: entry.signal,
        serviceLease: lease,
        retainOnSourceChange: true,
        resultDisposition: origin?.resultDisposition,
        workTimeout: origin?.workTimeout,
      ),
      serviceOwned: true,
      retainOnSourceChange: true,
    );
    final result = () async {
      try {
        await work;
      } catch (error) {
        if (error is SourceTaskCancelled) rethrow;
        // Ordinary plugin errors remain best-effort; the registry records failure.
      } finally {
        try {
          if (entry.context case final context?) {
            final receipt = await host.tasks.cancelTask(
              context.task.snapshot.taskId,
              entry.signal.reason ?? SourceTaskStopReason.ownerDisposed,
            );
            await receipt.whenSettled;
          }
        } finally {
          if (entry.context case final context?) {
            handle.hostExecutionGuards.remove(context.task.taskId);
          }
          caller?.removeListener(callerStopped);
          lease.close(
            entry.signal.reason ?? SourceTaskStopReason.ownerDisposed,
          );
          _uploads.remove(entry);
          entry.done.complete();
        }
      }
    }();
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    // Cancellation ends this item promptly without letting its successor
    // overtake an earlier upload that is still executing.
    final tail = Future.wait([previous, settled]).then<void>((_) {});
    _queues[sourceKey] = tail;
    tail.whenComplete(() {
      if (identical(_queues[sourceKey], tail)) _queues.remove(sourceKey);
    });
    return result;
  }
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<Object?, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key, _freeze(item))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

class _Upload {
  _Upload(this.handle, this.identity, this.lease);
  final SourceRuntimeHandle handle;
  final String identity;
  final SourceServiceRuntimeLease lease;
  final signal = SourceTaskCancellation();
  final done = Completer<void>();
  SourceOperationContext? context;
}
