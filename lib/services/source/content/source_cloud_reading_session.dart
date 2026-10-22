import 'dart:async';
import 'dart:convert';

import '../account/source_login_interaction.dart';
import '../account/source_login_storage_transaction.dart';
import '../models/source_task.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_load_control.dart';
import '../runtime/source_shared_request.dart';
import '../runtime/source_task_registry.dart';

/// One account generation. Its private runtimes never commit their overlays.
class SourceCloudReadingSession {
  SourceCloudReadingSession(this.host, this.owner, this.identity, this.load);
  final SourceRuntimeHost host;
  final SourceRuntimeHandle owner;
  final String? identity;
  final Future<void> Function(SourceRuntimeHandle)? load;
  final cancellation = SourceTaskCancellation();
  final Set<SourceTask> _tasks = {};
  final Map<SourceRuntimeHandle, SourceLoginStorageTransaction> _private = {};
  SourceSharedRequest<SourceRuntimeHandle>? _initializing;
  SourceRuntimeHandle? _ready;
  Future<void>? _closing;

  void checkActive() {
    if (cancellation.reason case final reason?) {
      throw SourceTaskCancelled('cloud.session', reason);
    }
    if (!host.isCurrentHandle(owner) ||
        owner.isDisposed ||
        owner.sourceKey != host.activeSourceKey ||
        owner.session.loginIdentity != identity) {
      throw const SourceTaskCancelled(
        'cloud.session',
        SourceTaskStopReason.accountChanged,
      );
    }
  }

  void attach(SourceOperationContext context) {
    checkActive();
    _tasks.add(context.task);
  }

  Future<void> release(SourceTask task) async {
    final receipt = await host.tasks.cancelTask(
      task.taskId,
      cancellation.reason ?? SourceTaskStopReason.ownerDisposed,
    );
    try {
      await receipt.whenSettled;
    } finally {
      _tasks.remove(task);
    }
  }

  Future<void> _disposePrivate(SourceRuntimeHandle handle) async {
    _private[handle]?.discard();
    handle.loginCancellation?.cancel();
    final engine = handle.runtime.engine;
    handle.requestDispose();
    if (engine != null) await handle.closeEngine(engine);
    await handle.whenDisposed;
    _private.remove(handle);
  }

  Future<void> close(SourceTaskStopReason reason) {
    if (_closing case final closing?) return closing;
    cancellation.cancel(reason);
    final receipts = _tasks
        .toList()
        .map((task) => task.requestStop(reason))
        .toList();
    final handles = _private.keys.toList();
    for (final handle in handles) {
      _private[handle]!.discard();
    }
    final closing = Future.wait([
      for (final handle in handles) _disposePrivate(handle),
      for (final receipt in receipts) receipt.whenSettled,
    ]).then<void>((_) {});
    closing.ignore();
    _closing = closing;
    return closing;
  }

  Future<SourceRuntimeHandle> reader(SourceOperationContext context) async {
    checkActive();
    if (load == null) return owner;
    if (_ready case final handle?) return handle;
    var pending = _initializing;
    if (pending == null || !pending.available) {
      late final SourceSharedRequest<SourceRuntimeHandle> created;
      created = SourceSharedRequest<SourceRuntimeHandle>(
        pluginId: owner.sourceKey,
        method: 'cloud.initialize',
        drainOperationOnStop: true,
        onUnavailable: () {
          if (identical(_initializing, created)) _initializing = null;
        },
        operation: (request) async {
          checkActive();
          final storage = SourceLoginStorageTransaction(owner.secureStorage);
          final handle =
              SourceRuntimeHandle(
                  sourceKey: owner.sourceKey,
                  secureStorage: storage,
                  tasks: host.tasks,
                  ensureInitialized: (_) async {},
                  notifyRuntimeStateChanged: (_) {},
                )
                ..pluginDirectory = owner.pluginDirectory
                ..loginCancellation = SourceLoginCancellation()
                ..loadControl = SourceRuntimeLoadControl(
                  execution: request.execution,
                  checkActive: () {
                    request.checkActive();
                    checkActive();
                  },
                  bindEngine: request.bindEngine,
                );
          _private[handle] = storage;
          handle.session
            ..prefs = owner.session.prefs
            ..stagedStore = Map<String, dynamic>.from(
              jsonDecode(
                    jsonEncode(owner.session.loadSourceStore(owner.sourceKey)),
                  )
                  as Map,
            );
          var published = false;
          request.addStopHandler((_) {
            if (!published) {
              storage.discard();
              handle.loginCancellation?.cancel();
            }
          });
          try {
            await load!(handle);
            request.checkActive();
            checkActive();
            _ready = handle;
            published = true;
            return handle;
          } finally {
            if (!published) await _disposePrivate(handle);
          }
        },
      );
      _initializing = pending = created;
    }
    final request = pending;
    return context.runChild(
      host.tasks,
      (origin) => host.tasks.run<SourceRuntimeHandle>(
        pluginId: owner.sourceKey,
        method: 'cloud.initialize.wait',
        origin: origin,
        operation: (task) {
          task.bindResource(owner);
          final child = SourceOperationContext(
            task,
            resource: owner,
            canCache: () => false,
          );
          attach(child);
          return request
              .subscribe(task: task)
              .whenComplete(() => _tasks.remove(task));
        },
      ),
    );
  }

  Future<Object?> invoke(
    SourceOperationContext context,
    String method,
    Object argument,
  ) async {
    checkActive();
    context.checkActive();
    final handle = await reader(context);
    checkActive();
    context.checkActive();
    return handle.runOperation(() async {
      final raw = await context.invoke(
        handle.runtime.engine!,
        '(value) => globalThis.__hazuki_source.comic.$method(value)',
        [argument],
      );
      final result = await context.resolve(handle.facade.js.resolve(raw));
      checkActive();
      return result;
    });
  }
}
