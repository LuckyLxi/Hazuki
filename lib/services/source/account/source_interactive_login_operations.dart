import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../models/source_task.dart';
import 'dart:async';
import 'dart:convert';

import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';
import 'source_login_interaction.dart';
import 'source_login_side_data_operations.dart';
import 'source_login_storage_transaction.dart';
import '../interaction/source_ui_scope.dart';
import '../interaction/source_ui_service.dart';

class SourceInteractiveLoginOperations
    implements SourceInteractiveAccountGateway {
  SourceInteractiveLoginOperations({
    required this.host,
    required this.loadRuntime,
    this.readLoginMethods,
  });
  final SourceRuntimeHost host;
  final Future<void> Function(SourceRuntimeHandle) loadRuntime;
  final Future<List<SourceLoginMethod>> Function(
    String sourceKey,
    SourceOperationContext context,
  )?
  readLoginMethods;
  final Set<String> _running = {};
  final Map<String, SourceLoginCancellation> _cancellations = {};

  @override
  void cancelPendingLogin() => _cancellations[host.activeSourceKey]?.cancel();

  @override
  Future<List<SourceLoginMethod>> loadLoginMethods({
    SourceTaskOrigin? taskOrigin,
  }) => runSourceOperation(host, host.activeHandle, 'account.loginMethods', (
    context,
  ) async {
    final handle = host.activeHandle;
    if (readLoginMethods != null) {
      return readLoginMethods!(handle.sourceKey, context);
    }
    await handle.facade.ensureInitialized();
    return SourceLoginMethod.parse(
      await context.evaluate(
        handle.runtime.engine!,
        'this.__hazuki_source.account?.loginMethods',
      ),
    );
  }, origin: taskOrigin);

  @override
  Future<void> loginInteractive({
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
    SourceTaskOrigin? taskOrigin,
  }) async {
    try {
      await runSourceOperation(
        host,
        host.activeHandle,
        'account.loginInteractive',
        (context) async {
          void stop() {
            if (!cancellation.isCleanupCancellation) {
              context.task.requestStop(SourceTaskStopReason.user);
            }
          }

          cancellation.addListener(stop);
          context.task.whenStopped.then((_) => cancellation.cancel());
          if (cancellation.isCancelled) stop();
          try {
            return await context.commit(
              () => _loginInteractiveWithTask(
                context,
                account: account,
                password: password,
                method: method,
                present: present,
                cancellation: cancellation,
              ),
            );
          } finally {
            cancellation.removeListener(stop);
          }
        },
        origin: taskOrigin,
        sensitiveValues: [account, password],
      );
    } on SourceTaskCancelled {
      cancellation.cancel();
      throw const SourceLoginCancelled();
    }
  }

  Future<void> _loginInteractiveWithTask(
    SourceOperationContext context, {
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
  }) async {
    try {
      await SourceUiService.instance.run(
        () => _loginInteractive(
          context,
          account: account,
          password: password,
          method: method,
          present: present,
          cancellation: cancellation,
        ),
        present: (dialog) async {
          if (dialog.browserRequest != null) {
            dialog.markShown();
            final result = await present({
              ...dialog.browserRequest!,
              'type': 'browserAuthorization',
              'sourceName': dialog.sourceName,
            }, dialog.browserCancellation);
            dialog.completeBrowser(result);
            return;
          }
          await present({
            'type': 'pluginDialog',
            'session': dialog,
          }, cancellation);
        },
      );
    } catch (error) {
      if (isSourceUiCancellation(error)) {
        cancellation.cancel();
        throw const SourceLoginCancelled();
      }
      rethrow;
    }
  }

  Future<void> _loginInteractive(
    SourceOperationContext context, {
    required String account,
    required String password,
    required String method,
    required SourceLoginPresenter present,
    required SourceLoginCancellation cancellation,
  }) async {
    final original = context.resource as SourceRuntimeHandle;
    final key = original.sourceKey;
    if (!_running.add(key)) throw StateError('login_already_running');
    _cancellations[key] = cancellation;
    final storage = SourceLoginStorageTransaction(original.secureStorage);
    SourceRuntimeHandle? attempt;
    var successful = false;
    void abortNetwork() => attempt?.dio.close(force: true);
    cancellation.addListener(abortNetwork);
    void checkSource() {
      if (host.activeSourceKey != key ||
          !host.isCurrentHandle(original) ||
          !host.runtimeRegistry.isAllowedSourceKey(key)) {
        context.task.requestStop(SourceTaskStopReason.sourceChanged);
        cancellation.cancel();
      }
    }

    host.addListener(checkSource);
    host.runtimeRegistry.addListener(checkSource);
    try {
      cancellation.check();
      await original.session.ensurePrefs();
      checkSource();
      cancellation.check();
      final initialStore = original.session.loadSourceStore(key);
      final local = attempt =
          SourceRuntimeHandle(
              sourceKey: key,
              secureStorage: storage,
              ensureInitialized: (_) async {},
              notifyRuntimeStateChanged: (_) {},
            )
            ..pluginDirectory = original.pluginDirectory
            ..loginCancellation = cancellation
            ..loginPresenter = present;
      local.session
        ..prefs = original.session.prefs
        ..stagedStore = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(initialStore)) as Map,
        );
      Future<void> run() async {
        await loadRuntime(local);
        cancellation.check();
        final engine = local.runtime.engine!;
        final methods = SourceLoginMethod.parse(
          await context.evaluate(
            engine,
            'this.__hazuki_source.account?.loginMethods',
          ),
        );
        if (!methods.any((m) => m.id == method)) {
          throw StateError('login_method_unavailable');
        }
        final result = await local.facade.js.resolve(
          context.invoke(
            engine,
            '''(account, password, method) =>
          this.__hazuki_source.account.login(account, password, __hazukiCreateLoginContext(method))''',
            [account, password, method],
          ),
        );
        SourceUiService.instance.closeRuntimeInteractions(engine.runtimeId);
        cancellation.check();
        await SourceLoginSideDataOperations(
          runtimeHost: host,
        ).persistLoginSideData(local.facade, sourceKey: key, result: result);
        final selected = methods.singleWhere((m) => m.id == method);
        if (selected.input == 'none') {
          await local.facade.deleteSourceData(key, 'account');
        } else {
          await local.facade.saveSourceData(key, 'account', [
            account,
            password,
          ]);
        }
        // An independent marker also identifies account changes in queued work.
        await local.facade.saveSourceData(
          key,
          'login_session',
          DateTime.now().microsecondsSinceEpoch.toString(),
        );
        await local.facade.saveSourceData(key, 'interactive_login', true);
        await local.facade.saveSourceData(key, 'login_method', method);
      }

      await Future.any<void>([
        run(),
        cancellation.whenCancelled.then(
          (_) => throw const SourceLoginCancelled(),
        ),
      ]);
      checkSource();
      cancellation.check();
      final currentStore = original.session.loadSourceStore(key);
      final merged = Map<String, dynamic>.from(currentStore);
      final staged = local.session.stagedStore!;
      for (final name in {...initialStore.keys, ...staged.keys}) {
        if (jsonEncode(initialStore[name]) != jsonEncode(staged[name]) ||
            initialStore.containsKey(name) != staged.containsKey(name)) {
          if (staged.containsKey(name)) {
            merged[name] = staged[name];
          } else {
            merged.remove(name);
          }
        }
      }
      await storage.commit(cancellation.check);
      try {
        cancellation.check();
        await original.session.saveSourceStore(key, merged);
        cancellation.check();
      } catch (_) {
        await storage.rollback();
        await original.session.saveSourceStore(key, currentStore);
        rethrow;
      }
      host.removeListener(checkSource);
      host.runtimeRegistry.removeListener(checkSource);
      final replacement = host.recreateSourceRuntime(
        key,
        expectedHandle: original,
      );
      await replacement.session.ensurePrefs();
      host.notifyActiveRuntimeChanged(key);
      successful = true;
    } finally {
      final local = attempt;
      if (local != null) {
        for (final runtimeId in {
          ...local.loadingRuntimeIds,
          if (local.runtime.engine != null) local.runtime.engine!.runtimeId,
        }) {
          SourceUiService.instance.closeRuntimeInteractions(runtimeId);
        }
      }
      if (!successful) cancellation.cancelForCleanup();
      storage.discard();
      host.removeListener(checkSource);
      host.runtimeRegistry.removeListener(checkSource);
      attempt?.requestDispose();
      // This private runtime has no other accepted work to preserve on cancel.
      // A plugin may still be awaiting a host interaction that never settles.
      await attempt?.runtime.engine?.close();
      await attempt?.whenDisposed;
      cancellation.removeListener(abortNetwork);
      _running.remove(key);
      _cancellations.remove(key);
    }
  }
}
