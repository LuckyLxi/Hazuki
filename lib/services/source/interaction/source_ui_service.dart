import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

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
  final Map<String, SourceDialogPresenter> _presenters = {};
  final Map<String, SourceDialogSession> _dialogs = {};
  final Queue<SourceDialogSession> _queue = Queue();
  SourceDialogSession? _visible;
  bool _foreground = true;
  Completer<void>? _foregroundResumed;
  final Map<SourceUiScope, int> _browserAuthorizations = {};
  bool _pumping = false;

  Iterable<SourceUiScope> get scopes => List.unmodifiable(_scopes.values);

  void checkExecution(SourceScriptExecution execution, String runtimeId) {
    if (execution.uiScopeId == null) return;
    final scope = _scopes[execution.uiScopeId];
    if (scope == null || scope.finished) {
      throw const SourceUiCancelled('operationFinished');
    }
    if (scope.reason != null) throw SourceUiCancelled(scope.reason!);
    if (!_foreground) throw const SourceUiCancelled('background');
    if (!scope.runtimeIds.contains(runtimeId) ||
        isOwnerAvailable?.call(scope.owner) == false) {
      throw const SourceUiCancelled('ownerGone');
    }
  }

  /// Android autofill/credential providers can stop the activity while the
  /// owned WebView is still authorizing. Keep only that operation alive and
  /// defer its result until foreground; route/runtime cancellation still wins.
  Future<T> runBrowserAuthorization<T>(
    Future<T> Function() operation, {
    required SourceScriptExecution? execution,
    required String? runtimeId,
    required Duration timeout,
  }) async {
    final scope = _scopes[execution?.uiScopeId] ?? SourceUiScope.current;
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
        if (!_foreground && scope.available) scope.cancel('background');
      } else {
        _browserAuthorizations[scope] = remaining;
      }
    }
  }

  Future<T> run<T>(
    Future<T> Function() operation, {
    SourceUiOwner? owner,
    SourceDialogPresenter? present,
  }) async {
    if (SourceUiScope.interactionDisabled) return operation();
    final current = SourceUiScope.current;
    if (current?.available == true &&
        present == null &&
        (owner == null || identical(current!.controllerOwner, owner))) {
      return operation();
    }
    if (owner != null) owner._routeOwner ??= captureOwner?.call();
    final scope = SourceUiScope(
      waitingTimeout: interactionTimeout,
      owner: owner?._routeOwner ?? captureOwner?.call(),
      controllerOwner: owner,
      onCancelled: () {
        owner?.wasCancelled = true;
      },
    );
    _scopes[scope.id] = scope;
    if (present != null) _presenters[scope.id] = present;
    owner?._scopes.add(scope);
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

    scope.addListener(abort);
    try {
      final value = await Future.any([scope.enter(operation), aborted.future]);
      if (scope.reason != null && scope.reason != 'user') {
        throw scope.failure ?? SourceUiCancelled(scope.reason!);
      }
      return value;
    } catch (error) {
      if (scope.reason != null) {
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
      _dialogs.removeWhere((_, dialog) => identical(dialog.scope, scope));
      scope.dispose();
    }
  }

  dynamic handle(
    Map<String, dynamic> request,
    SourceScriptExecution execution,
    String runtimeId,
    String sourceName, {
    Map<String, dynamic> translation = const {},
  }) {
    final scope = _scopes[execution.uiScopeId];
    final available =
        scope != null &&
        scope.available &&
        (isOwnerAvailable?.call(scope.owner) != false) &&
        _foreground &&
        (presenter != null || _presenters.containsKey(scope.id)) &&
        scope.runtimeIds.contains(runtimeId);
    if (request['method'] == 'ui_available') return available;
    if (scope == null || !scope.runtimeIds.contains(runtimeId)) {
      throw StateError('plugin_ui_unavailable');
    }
    if (request['method'] == 'ui_open') {
      if (!available) {
        if (scope.reason != null) throw SourceUiCancelled(scope.reason!);
        throw StateError('plugin_ui_unavailable');
      }
      if (_dialogs.values.any(
        (d) => identical(d.scope, scope) && !d.isClosed,
      )) {
        throw StateError('plugin_ui_already_open');
      }
      final model = SourceDialogModel.parse(request['options']);
      final dialog = SourceDialogSession._(
        this,
        scope,
        execution.pluginId,
        runtimeId,
        sourceName,
        model,
        translation,
      );
      _dialogs[dialog.id] = dialog;
      _queue.add(dialog);
      scope.setWaiting(true);
      dialog._queueTimer = Timer(queueTimeout, () => scope.cancel('timeout'));
      unawaited(_pump());
      return dialog._shown.future;
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
    if (!value) {
      for (final scope in scopes) {
        if (!_browserAuthorizations.containsKey(scope)) {
          scope.cancel('background');
        }
      }
    } else {
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
      if (scope.pluginIds.contains(pluginId)) scope.cancel(reason);
    }
    for (final dialog in _dialogs.values.toList()) {
      if (dialog.pluginId == pluginId && !dialog.isClosed) {
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
      while (_queue.isNotEmpty) {
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
        try {
          // The presenter completes _shown after attaching its route/container.
          await present(dialog);
        } catch (error, stack) {
          if (!dialog._shown.isCompleted) {
            dialog._shown.completeError(error, stack);
          }
        } finally {
          dialog.close('user');
          dialog._release();
          _visible = null;
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
  ) : values = model.initialValues;
  final SourceUiService service;
  final SourceUiScope scope;
  final String pluginId;
  final String runtimeId;
  final String sourceName;
  final Map<String, dynamic> translation;
  final String id = createSourceTaskId();
  SourceDialogModel model;
  Map<String, Object> values;
  // Null denotes the host's localized required-field error.
  final Map<String, Object?> fieldErrors = {};
  final _shown = Completer<String>();
  final _closed = Completer<void>();
  Completer<Map<String, Object?>>? _waiter;
  Map<String, Object?>? _event;
  Map<String, Object?>? _closedEvent;
  Timer? _queueTimer;
  bool busy = false;
  bool _presenting = false;
  bool get isClosed => _closedEvent != null;
  Future<void> get whenClosed => _closed.future;

  void markShown() {
    if (!_shown.isCompleted) _shown.complete(id);
  }

  Future<Map<String, Object?>> nextEvent() {
    if (isClosed) return Future.value(_closedEvent!);
    if (_waiter != null) throw StateError('plugin_ui_wait_in_progress');
    if (_event != null) {
      final event = _event!;
      _event = null;
      scope.setWaiting(false);
      return Future.value(event);
    }
    scope.setWaiting(true);
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
      scope.setWaiting(false);
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
    _closedEvent = {'type': 'closed', 'reason': reason};
    _event = null;
    if (!_shown.isCompleted) {
      _shown.completeError(SourceUiCancelled(reason));
    }
    _waiter?.complete(_closedEvent);
    _waiter = null;
    scope.setWaiting(false);
    if (reason == 'user') scope.cancel('user');
    _closed.complete();
    notifyListeners();
    if (!_presenting) _release();
    service.schedulePump();
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
