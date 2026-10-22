import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../account/source_browser_authorization.dart';
import '../account/source_login_interaction.dart';
import '../models/source_script_execution.dart';
import '../models/source_task.dart';
import 'source_dialog_model.dart';
import 'source_ui_scope.dart';

typedef SourceDialogPresenter =
    Future<void> Function(SourceDialogSession dialog);

/// A feature controller owns its requests even when their plugin is shared.
class SourceUiOwner {
  SourceUiOwner();
  Object? _routeOwner;
  final Set<SourceUiScope> _scopes = {};
  final Set<SourceUiScope> _serviceScopes = {};
  bool wasCancelled = false;
  bool _disposed = false;

  void restart() {
    cancel('superseded');
    wasCancelled = false;
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_disposed) return Future.error(const SourceUiCancelled('ownerGone'));
    SourceUiScope? entered;
    final value = await SourceUiService.instance.run(() {
      entered = SourceUiScope.current;
      return operation();
    }, owner: this);
    final reason = entered?.reason;
    if (reason != null) throw SourceUiCancelled(reason);
    return value;
  }

  Future<T> runBackground<T>(Future<T> Function() operation) =>
      SourceUiScope.withoutInteraction(operation);

  void cancel(String reason) {
    for (final scope in _scopes.toList()) {
      scope.cancel(reason);
    }
  }

  void dispose() {
    _disposed = true;
    cancel('ownerGone');
    for (final scope in _serviceScopes.toList()) {
      scope.cancel('ownerGone');
    }
  }
}

class SourceUiService {
  SourceUiService({
    this.queueTimeout = const Duration(seconds: 60),
    this.interactionTimeout = const Duration(minutes: 5),
  });
  static final instance = SourceUiService();
  final Duration queueTimeout;
  final Duration interactionTimeout;
  SourceDialogPresenter? presenter;
  Object? Function()? captureOwner;
  bool Function(Object?)? canPresent;
  bool Function(Object?)? isOwnerAvailable;
  final Map<String, SourceUiScope> _scopes = {};
  final Map<(String, String), SourceUiScope> _executionScopes = {};
  final Map<(String, String), SourceUiScope> _contextScopes = {};
  final Set<SourceUiScope> _releasedScopes = {};
  final Map<String, SourceDialogPresenter> _presenters = {};
  final Map<String, SourceDialogSession> _dialogs = {};
  final Queue<SourceDialogSession> _queue = Queue();
  SourceDialogSession? _visible;
  bool _foreground = true;
  Completer<void>? _foregroundResumed;
  final Map<SourceUiScope, int> _browserAuthorizations = {};
  bool _pumping = false;

  Iterable<SourceUiScope> get scopes => List.unmodifiable(_scopes.values);

  SourceUiScope? _findScope(
    SourceScriptExecution execution,
    String runtimeId,
  ) =>
      _executionScopes[(runtimeId, execution.taskId)] ??
      _scopes[execution.uiScopeId] ??
      _contextScopes[(runtimeId, execution.taskId)];

  void retainExecution(SourceScriptExecution execution, String runtimeId) {
    final scope = _scopes[execution.uiScopeId];
    if (scope != null) {
      _contextScopes[(runtimeId, execution.taskId)] = scope;
    }
  }

  SourceUiScope _scopeFor(SourceScriptExecution execution, String runtimeId) {
    final existing = _findScope(execution, runtimeId);
    if (existing != null && (!existing.finished || existing.reason != null)) {
      return existing;
    }
    final scope = SourceUiScope(waitingTimeout: interactionTimeout)
      ..runtimeIds.add(runtimeId)
      ..pluginIds.add(execution.pluginId)
      ..setForeground(_foreground);
    _executionScopes[(runtimeId, execution.taskId)] = scope;
    _scopes[scope.id] = scope;
    scope.addListener(() {
      if (scope.reason == null && !scope.finished) return;
      for (final dialog in _dialogs.values.toList()) {
        if (identical(dialog.scope, scope)) {
          dialog.close(scope.reason ?? 'operationFinished');
        }
      }
    });
    return scope;
  }

  /// Called after QuickJS releases all promises and callbacks for this task.
  void releaseExecution(SourceScriptExecution execution, String runtimeId) {
    _contextScopes.remove((runtimeId, execution.taskId));
    final scope = _executionScopes[(runtimeId, execution.taskId)];
    if (scope == null) return;
    _releasedScopes.add(scope);
    _releaseScopeIfIdle(scope);
  }

  void _releaseScopeIfIdle(SourceUiScope scope) {
    if (!_releasedScopes.contains(scope) ||
        _browserAuthorizations.containsKey(scope) ||
        _dialogs.values.any((d) => identical(d.scope, scope) && !d.isClosed)) {
      return;
    }
    _releasedScopes.remove(scope);
    _executionScopes.removeWhere((_, value) => identical(value, scope));
    _scopes.remove(scope.id);
    _dialogs.removeWhere((_, dialog) => identical(dialog.scope, scope));
    scheduleMicrotask(() {
      scope.finish();
      scope.dispose();
    });
  }

  void _refreshWaiting(SourceUiScope scope) {
    scope.setWaiting(
      _dialogs.values.any((d) => identical(d.scope, scope) && d._waiting),
    );
  }

  void checkExecution(SourceScriptExecution execution, String runtimeId) {
    final scope = _findScope(execution, runtimeId);
    if (scope == null) {
      if (execution.uiScopeId != null) {
        throw const SourceUiCancelled('operationFinished');
      }
      return;
    }
    if (scope.reason != null) throw SourceUiCancelled(scope.reason!);
    if (!_foreground && _browserAuthorizations.containsKey(scope)) {
      throw const SourceUiCancelled('background');
    }
    if (!scope.runtimeIds.contains(runtimeId)) {
      throw const SourceUiCancelled('ownerGone');
    }
  }

  /// Android autofill/credential providers can stop the activity while the
  /// owned WebView is still authorizing. Defer its result until foreground;
  /// explicit operation/runtime cancellation still wins.
  Future<T> runBrowserAuthorization<T>(
    Future<T> Function() operation, {
    required SourceScriptExecution? execution,
    required String? runtimeId,
    required Duration timeout,
    SourceUiScope? interactionScope,
  }) async {
    final scope =
        interactionScope ??
        (execution != null && runtimeId != null
            ? _scopeFor(execution, runtimeId)
            : SourceUiScope.current);
    if (scope == null) return operation();
    if (execution != null && runtimeId != null) {
      checkExecution(execution, runtimeId);
    }
    _browserAuthorizations.update(
      scope,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    final elapsed = Stopwatch()..start();
    Future<T> authorize() async {
      final value = await operation();
      while (!_foreground) {
        final remaining = timeout - elapsed.elapsed;
        await Future.any<void>([
          (_foregroundResumed ??= Completer<void>()).future,
          scope.whenCancelled.then<void>(
            (_) => throw SourceUiCancelled(scope.reason ?? 'operationFinished'),
          ),
        ]).timeout(
          remaining.isNegative ? Duration.zero : remaining,
          onTimeout: () {
            scope.cancel('timeout');
            throw const SourceUiCancelled('timeout');
          },
        );
      }
      if (!scope.available) {
        throw SourceUiCancelled(scope.reason ?? 'operationFinished');
      }
      return value;
    }

    try {
      return await Future.any<T>([
        authorize(),
        scope.whenCancelled.then<T>(
          (_) => throw SourceUiCancelled(scope.reason ?? 'operationFinished'),
        ),
      ]);
    } finally {
      final remaining = _browserAuthorizations[scope]! - 1;
      if (remaining == 0) {
        _browserAuthorizations.remove(scope);
        _releaseScopeIfIdle(scope);
      } else {
        _browserAuthorizations[scope] = remaining;
      }
    }
  }

  Future<T> run<T>(
    Future<T> Function() operation, {
    SourceUiOwner? owner,
    SourceDialogPresenter? present,
    bool captureRouteOwner = true,
    bool abortOnScopeCancellation = true,
    bool inheritCurrent = true,
    Object? routeOwner,
    SourceUiOwner? serviceLifetimeOwner,
  }) async {
    final current = SourceUiScope.current;
    if (inheritCurrent &&
        current?.available == true &&
        present == null &&
        (owner == null || identical(current!.controllerOwner, owner))) {
      return operation();
    }
    if (owner != null) owner._routeOwner ??= captureOwner?.call();
    final scope = SourceUiScope(
      waitingTimeout: interactionTimeout,
      owner:
          routeOwner ??
          owner?._routeOwner ??
          (captureRouteOwner ? captureOwner?.call() : null),
      controllerOwner: owner,
      onCancelled: () {
        owner?.wasCancelled = true;
      },
    );
    scope.setForeground(_foreground);
    _scopes[scope.id] = scope;
    if (present != null) _presenters[scope.id] = present;
    owner?._scopes.add(scope);
    serviceLifetimeOwner?._serviceScopes.add(scope);
    if (serviceLifetimeOwner?._disposed == true) scope.cancel('ownerGone');
    void changed() {
      if (scope.reason == null && !scope.finished) return;
      for (final dialog in _dialogs.values.toList()) {
        if (identical(dialog.scope, scope)) {
          dialog.close(scope.reason ?? 'operationFinished');
        }
      }
    }

    scope.addListener(changed);
    final aborted = Completer<T>();
    void abort() {
      if (scope.reason != null &&
          scope.reason != 'user' &&
          !aborted.isCompleted) {
        aborted.completeError(
          scope.failure ?? SourceUiCancelled(scope.reason!),
        );
      }
    }

    if (abortOnScopeCancellation) scope.addListener(abort);
    try {
      final value = await (abortOnScopeCancellation
          ? Future.any([scope.enter(operation), aborted.future])
          : scope.enter(operation));
      if (abortOnScopeCancellation &&
          scope.reason != null &&
          scope.reason != 'user') {
        throw scope.failure ?? SourceUiCancelled(scope.reason!);
      }
      return value;
    } catch (error) {
      if (abortOnScopeCancellation && scope.reason != null) {
        throw scope.failure ?? SourceUiCancelled(scope.reason!);
      }
      rethrow;
    } finally {
      scope.finish();
      scope.removeListener(changed);
      scope.removeListener(abort);
      _scopes.remove(scope.id);
      _presenters.remove(scope.id);
      owner?._scopes.remove(scope);
      serviceLifetimeOwner?._serviceScopes.remove(scope);
      _dialogs.removeWhere((_, dialog) => identical(dialog.scope, scope));
      scope.dispose();
    }
  }

  SourceDialogSession browserSession(
    String id,
    SourceScriptExecution execution,
    String runtimeId,
  ) {
    final dialog = _dialogs[id];
    if (dialog == null ||
        dialog.browserRequest == null ||
        dialog.pluginId != execution.pluginId ||
        dialog.runtimeId != runtimeId) {
      throw StateError('plugin_ui_unavailable');
    }
    return dialog;
  }

  dynamic handle(
    Map<String, dynamic> request,
    SourceScriptExecution execution,
    String runtimeId,
    String sourceName, {
    Map<String, dynamic> translation = const {},
  }) {
    if (request['method'] == 'ui_browser_result' ||
        request['method'] == 'ui_browser_close') {
      final dialog = browserSession(
        request['id']?.toString() ?? '',
        execution,
        runtimeId,
      );
      if (request['method'] == 'ui_browser_result') {
        return dialog._browserResult.future;
      }
      if (!dialog.isClosed) {
        dialog.completeBrowser({'status': 'closed', 'reason': 'plugin'});
      }
      return dialog._presenting
          ? dialog._dismissed.future
          : Future<void>.value();
    }
    final existing = _findScope(execution, runtimeId);
    final available =
        (existing == null ||
            (existing.available ||
                    existing.finished && existing.reason == null) &&
                existing.runtimeIds.contains(runtimeId)) &&
        (presenter != null || _presenters.containsKey(existing?.id));
    if (request['method'] == 'ui_available') return available;
    final scope = _scopeFor(execution, runtimeId);
    if (!scope.runtimeIds.contains(runtimeId)) {
      throw StateError('plugin_ui_unavailable');
    }
    if (request['method'] == 'ui_open' ||
        request['method'] == 'ui_browser' ||
        request['method'] == 'ui_browser_create') {
      if (!available) {
        if (scope.reason != null) throw SourceUiCancelled(scope.reason!);
        throw StateError('plugin_ui_unavailable');
      }
      final browser = request['method'] != 'ui_open'
          ? dialogMap(request['options'])
          : null;
      if (browser != null) SourceBrowserAuthorizationOptions.parse(browser);
      final model = SourceDialogModel.parse(
        browser == null
            ? request['options']
            : {
                'title': browser['title'] ?? '',
                'content': [],
                'buttons': [
                  {'id': 'close', 'text': ''},
                ],
              },
      );
      final dialog = SourceDialogSession._(
        this,
        scope,
        execution.pluginId,
        runtimeId,
        sourceName,
        model,
        translation,
        browser,
      );
      _dialogs[dialog.id] = dialog;
      _queue.add(dialog);
      dialog._setWaiting(true);
      dialog._updateQueueTimer();
      unawaited(_pump());
      if (request['method'] == 'ui_browser_create') return dialog.id;
      return browser == null
          ? dialog._shown.future
          : dialog._browserResult.future;
    }
    final dialog = _dialogs[request['id']];
    if (dialog == null ||
        !identical(dialog.scope, scope) ||
        dialog.pluginId != execution.pluginId ||
        dialog.runtimeId != runtimeId) {
      throw StateError('plugin_ui_unavailable');
    }
    return switch (request['method']) {
      'ui_next_event' => dialog.nextEvent(),
      'ui_update' => dialog.update(dialogMap(request['patch'])),
      'ui_close' => dialog.close('plugin'),
      _ => throw StateError('plugin_ui_invalid_method'),
    };
  }

  void setForeground(bool value) {
    _foreground = value;
    for (final scope in scopes) {
      scope.setForeground(value);
    }
    for (final dialog in _queue) {
      dialog._updateQueueTimer();
    }
    if (value) {
      final resumed = _foregroundResumed;
      _foregroundResumed = null;
      resumed?.complete();
      schedulePump();
    }
  }

  void cancelRuntime(String runtimeId) {
    for (final scope in scopes) {
      if (scope.runtimeIds.contains(runtimeId)) scope.cancel('runtimeDisposed');
    }
    for (final dialog in _dialogs.values.toList()) {
      if (dialog.runtimeId == runtimeId && !dialog.isClosed) {
        dialog.scope.cancel('runtimeDisposed');
      }
    }
    for (final entry in _executionScopes.entries.toList()) {
      if (entry.key.$1 == runtimeId) {
        final scope = entry.value;
        scope.cancel('runtimeDisposed');
        _releasedScopes.add(scope);
        _releaseScopeIfIdle(scope);
      }
    }
    _contextScopes.removeWhere((key, _) => key.$1 == runtimeId);
  }

  void closeRuntimeInteractions(String runtimeId) {
    for (final dialog in _dialogs.values.toList()) {
      if (dialog.runtimeId == runtimeId) dialog.close('operationFinished');
    }
    // A verified private login runtime is retired before its enclosing login
    // operation returns. Its normal teardown must not cancel the committed login.
    for (final scope in scopes) {
      scope.runtimeIds.remove(runtimeId);
    }
  }

  void cancelPlugin(String pluginId, String reason) {
    for (final scope in scopes) {
      if (scope.pluginIds.contains(pluginId) &&
          !(reason == 'sourceChanged' && scope.survivesSourceChange)) {
        scope.cancel(reason);
      }
    }
    for (final dialog in _dialogs.values.toList()) {
      if (dialog.pluginId == pluginId &&
          !dialog.isClosed &&
          !(reason == 'sourceChanged' && dialog.scope.survivesSourceChange)) {
        dialog.scope.cancel(reason);
      }
    }
  }

  void cancelAll(String reason) {
    for (final scope in scopes) {
      scope.cancel(reason);
    }
  }

  void schedulePump() => scheduleMicrotask(() => unawaited(_pump()));

  Future<void> _pump() async {
    if (_pumping || _visible != null || !_foreground) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty && _foreground) {
        final dialog = _queue.first;
        if (dialog.isClosed) {
          _queue.removeFirst();
          continue;
        }
        final present = _presenters[dialog.scope.id] ?? presenter;
        if (present == null) return;
        if (!_presenters.containsKey(dialog.scope.id) &&
            canPresent?.call(dialog.scope.owner) == false) {
          return;
        }
        _queue.removeFirst();
        _visible = dialog;
        dialog._presenting = true;
        dialog._queueTimer?.cancel();
        dialog._queueClock.stop();
        try {
          // The presenter completes _shown after attaching its route/container.
          await present(dialog);
        } catch (error, stack) {
          if (dialog.browserRequest != null && error is! SourceLoginCancelled) {
            if (!dialog._browserResult.isCompleted) {
              dialog._browserResult.completeError(error, stack);
            }
            dialog.close('error');
          }
          if (dialog.browserRequest == null && !dialog._shown.isCompleted) {
            dialog._shown.completeError(error, stack);
          }
        } finally {
          dialog.close('user');
          dialog._release();
          _visible = null;
          dialog._dismissed.complete();
        }
      }
    } finally {
      _pumping = false;
    }
  }

  void detach() {
    presenter = null;
    captureOwner = null;
    canPresent = null;
    isOwnerAvailable = null;
    for (final scope in scopes) {
      scope.cancel('ownerGone');
    }
    for (final scope in _executionScopes.values.toSet().toList()) {
      _releasedScopes.add(scope);
      _releaseScopeIfIdle(scope);
    }
  }
}

class SourceDialogSession extends ChangeNotifier {
  SourceDialogSession._(
    this.service,
    this.scope,
    this.pluginId,
    this.runtimeId,
    this.sourceName,
    this.model,
    this.translation,
    this.browserRequest,
  ) : values = model.initialValues {
    if (browserRequest != null) _browserResult.future.ignore();
  }
  final SourceUiService service;
  final SourceUiScope scope;
  final String pluginId;
  final String runtimeId;
  final String sourceName;
  final Map<String, dynamic> translation;
  final Map<String, dynamic>? browserRequest;
  final SourceLoginCancellation browserCancellation = SourceLoginCancellation();
  final _browserResult = Completer<Object?>();
  final String id = createSourceTaskId();
  SourceDialogModel model;
  Map<String, Object> values;
  // Null denotes the host's localized required-field error.
  final Map<String, Object?> fieldErrors = {};
  final _shown = Completer<String>();
  final _closed = Completer<void>();
  final _dismissed = Completer<void>();
  Completer<Map<String, Object?>>? _waiter;
  Map<String, Object?>? _event;
  Map<String, Object?>? _closedEvent;
  Timer? _queueTimer;
  final _queueClock = Stopwatch();
  bool _waiting = false;
  bool busy = false;
  bool _presenting = false;
  bool get isClosed => _closedEvent != null;
  Future<void> get whenClosed => _closed.future;

  void _setWaiting(bool value) {
    _waiting = value;
    service._refreshWaiting(scope);
  }

  void _updateQueueTimer() {
    _queueTimer?.cancel();
    _queueClock.stop();
    if (isClosed || _presenting || !service._foreground) return;
    final remaining = service.queueTimeout - _queueClock.elapsed;
    _queueClock.start();
    _queueTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => close('timeout'),
    );
  }

  void completeBrowser(Object? result) {
    if (!_browserResult.isCompleted) _browserResult.complete(result);
    close('plugin');
  }

  void markShown() {
    if (!_shown.isCompleted) _shown.complete(id);
  }

  Future<Map<String, Object?>> nextEvent() {
    if (isClosed) return Future.value(_closedEvent!);
    if (_waiter != null) throw StateError('plugin_ui_wait_in_progress');
    if (_event != null) {
      final event = _event!;
      _event = null;
      _setWaiting(false);
      return Future.value(event);
    }
    _setWaiting(true);
    _waiter = Completer<Map<String, Object?>>();
    return _waiter!.future;
  }

  void setValue(String id, Object value) {
    if (isClosed || busy) return;
    final c = model.content.firstWhere((c) => c.id == id);
    c.validateValue(value);
    values[id] = value;
    fieldErrors.remove(id);
    if (c.data['notifyChange'] == true &&
        const {'select', 'toggle'}.contains(c.type)) {
      _emit('change', id);
    }
    notifyListeners();
  }

  void action(String id) {
    if (isClosed || busy) return;
    final button = model.buttons.firstWhere((b) => b['id'] == id);
    if (button['enabled'] == false) return;
    fieldErrors.clear();
    if (button['validate'] == true) {
      for (final c in model.content.where((c) => c.interactive)) {
        final value = values[c.id];
        final empty = value is String
            ? value.trim().isEmpty
            : value is List && value.isEmpty;
        if (c.data['required'] == true && empty ||
            c.type == 'clickImage' &&
                (value as List).length !=
                    (c.data['pointCount'] ??
                        (value.isEmpty ? 1 : value.length))) {
          fieldErrors[c.id] = null;
        }
      }
    }
    if (fieldErrors.isNotEmpty) {
      notifyListeners();
      return;
    }
    _emit('action', id);
    notifyListeners();
  }

  void _emit(String type, String id) {
    busy = true;
    final event = <String, Object?>{
      'type': type,
      'id': id,
      'values': {
        for (final entry in values.entries)
          entry.key: entry.value is List
              ? (entry.value as List)
                    .map((v) => v is Map ? Map<String, Object?>.from(v) : v)
                    .toList()
              : entry.value,
      },
    };
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null) {
      _setWaiting(false);
      waiter.complete(event);
    } else {
      _event = event;
    }
  }

  void update(Map<String, dynamic> patch) {
    if (isClosed) throw StateError('plugin_ui_closed');
    if (patch['busy'] != null && patch['busy'] is! bool) invalidDialog();
    final next = model.patch(patch);
    final overrides = patch.containsKey('values')
        ? dialogMap(patch['values'])
        : <String, dynamic>{};
    final nextValues = next.initialValues;
    final old = {for (final c in model.content) c.id: c};
    for (final c in next.content.where((c) => c.interactive)) {
      if (old[c.id]?.type == c.type) {
        final previous = values[c.id]!;
        if (c.type != 'clickImage' || listEquals(old[c.id]?.image, c.image)) {
          // Changed option lists can legitimately invalidate the old selection.
          try {
            c.validateValue(previous);
            nextValues[c.id] = previous;
          } on FormatException {
            /* Use the new default. */
          }
        }
      }
      if (overrides.containsKey(c.id)) {
        c.validateValue(overrides[c.id]);
        nextValues[c.id] = overrides.remove(c.id) as Object;
      }
    }
    if (overrides.isNotEmpty) invalidDialog();
    final errors = patch.containsKey('fieldErrors')
        ? parseDialogFieldErrors(patch['fieldErrors'], next)
        : <String, Object>{};
    model = next;
    values = nextValues;
    busy = patch['busy'] == true || _event != null;
    fieldErrors
      ..clear()
      ..addAll(errors);
    notifyListeners();
  }

  void close(String reason) {
    if (isClosed) return;
    _queueTimer?.cancel();
    _queueClock.stop();
    _closedEvent = {'type': 'closed', 'reason': reason};
    _event = null;
    if (browserRequest != null) {
      if (!_browserResult.isCompleted) {
        _browserResult.completeError(SourceUiCancelled(reason));
      }
      browserCancellation.cancel();
    } else if (!_shown.isCompleted) {
      _shown.completeError(SourceUiCancelled(reason));
    }
    _waiter?.complete(_closedEvent);
    _waiter = null;
    _setWaiting(false);
    if (reason == 'user') scope.cancel('user');
    _closed.complete();
    notifyListeners();
    if (!_presenting) _release();
    service.schedulePump();
    service._releaseScopeIfIdle(scope);
  }

  void _release() {
    values = {};
    fieldErrors.clear();
    // Closed handles retain only their terminal event, not large image buffers.
    model = SourceDialogModel.parse({
      'title': '',
      'content': [],
      'buttons': [
        {'id': 'closed', 'text': ''},
      ],
    });
  }
}
