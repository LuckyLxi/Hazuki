import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/source_task.dart';

class SourceUiCancelled implements Exception {
  const SourceUiCancelled(this.reason);
  final String reason;
  @override
  String toString() => 'plugin_ui_cancelled:$reason';
}

bool isSourceUiCancellation(Object error) =>
    error is SourceUiCancelled ||
    error.toString().contains('plugin_ui_cancelled');

/// Host-owned interaction lifetime. Only [id] crosses the worker boundary.
class SourceUiScope extends ChangeNotifier {
  SourceUiScope({
    this.owner,
    this.controllerOwner,
    this.onCancelled,
    this.waitingTimeout = const Duration(minutes: 5),
  });
  static final Object _zoneKey = Object();
  static final Object _disabledKey = Object();
  static bool get interactionDisabled => Zone.current[_disabledKey] == true;
  static SourceUiScope? get current {
    final scope = Zone.current[_zoneKey] as SourceUiScope?;
    return scope?.finished == true ? null : scope;
  }

  final String id = createSourceTaskId();
  final Object? owner;
  final Object? controllerOwner;
  final VoidCallback? onCancelled;
  final Duration waitingTimeout;
  final _cancelled = Completer<void>();
  final _waitingClock = Stopwatch();
  Timer? _waitingLimit;
  bool _foreground = true;
  bool waiting = false;
  String? reason;
  Object? failure;
  bool finished = false;
  final Set<String> runtimeIds = {};
  final Set<String> pluginIds = {};
  bool get available => !finished && reason == null;
  Future<void> get whenCancelled => _cancelled.future;

  Future<T> enter<T>(Future<T> Function() operation) =>
      runZoned(operation, zoneValues: {_zoneKey: this});

  /// Detaches background work from its caller's cancellation and wait budget.
  /// The legacy name does not prohibit the plugin from requesting its own UI.
  static Future<T> withoutInteraction<T>(Future<T> Function() operation) =>
      runZoned(operation, zoneValues: {_zoneKey: null, _disabledKey: true});

  static T withoutInteractionSync<T>(T Function() operation) =>
      runZoned(operation, zoneValues: {_zoneKey: null, _disabledKey: true});

  static Timer timer(Duration duration, VoidCallback callback) =>
      _SourceUiTimer(current, duration, callback);

  void setWaiting(bool value) {
    if (waiting == value || finished) return;
    waiting = value;
    _waitingLimit?.cancel();
    if (value && _foreground) {
      _waitingClock.start();
      final remaining = waitingTimeout - _waitingClock.elapsed;
      _waitingLimit = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () => cancel('timeout'),
      );
    } else {
      _waitingClock.stop();
    }
    notifyListeners();
  }

  /// Time away from the app does not consume the user's interaction budget.
  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (!waiting || finished) return;
    waiting = false;
    setWaiting(true);
  }

  void cancel(String value, {Object? error}) {
    if (finished || reason != null && !(reason == 'user' && value != 'user')) {
      return;
    }
    reason = value;
    failure = error;
    _waitingLimit?.cancel();
    _waitingClock.stop();
    waiting = false;
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
    onCancelled?.call();
    notifyListeners();
  }

  /// Unlike Future.timeout, human input does not consume the work budget.
  static Future<T> timeout<T>(
    Future<T> future,
    Duration duration, {
    FutureOr<T> Function()? onTimeout,
  }) {
    final scope = current;
    if (scope == null) return future.timeout(duration, onTimeout: onTimeout);
    final result = Completer<T>();
    final clock = Stopwatch();
    Timer? timer;
    late void Function() changed;
    void stop() {
      timer?.cancel();
      clock.stop();
      scope.removeListener(changed);
    }

    void expired() async {
      if (result.isCompleted) return;
      stop();
      try {
        if (onTimeout == null) {
          throw TimeoutException('Source operation', duration);
        }
        result.complete(await Future<T>.sync(onTimeout));
      } catch (error, stack) {
        scope.cancel('timeout', error: error);
        if (!result.isCompleted) result.completeError(error, stack);
      }
    }

    changed = () {
      if (result.isCompleted) return;
      timer?.cancel();
      clock.stop();
      if (scope.reason != null && scope.reason != 'user') {
        stop();
        result.completeError(scope.failure ?? SourceUiCancelled(scope.reason!));
      } else if (!scope.waiting) {
        final remaining = duration - clock.elapsed;
        clock.start();
        timer = Timer(
          remaining.isNegative ? Duration.zero : remaining,
          expired,
        );
      }
    };
    scope.addListener(changed);
    changed();
    future.then(
      (value) {
        if (result.isCompleted) return;
        stop();
        result.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (result.isCompleted) return;
        stop();
        result.completeError(error, stack);
      },
    );
    return result.future;
  }

  void finish() {
    if (finished) return;
    finished = true;
    _waitingLimit?.cancel();
    _waitingClock.stop();
    notifyListeners();
  }
}

class _SourceUiTimer implements Timer {
  _SourceUiTimer(this.scope, this.duration, this.callback) {
    scope?.addListener(_changed);
    _changed();
  }
  final SourceUiScope? scope;
  final Duration duration;
  final VoidCallback callback;
  final _clock = Stopwatch();
  Timer? _timer;
  bool _active = true;
  int _tick = 0;
  @override
  bool get isActive => _active;
  @override
  int get tick => _tick;
  void _changed() {
    if (!_active) return;
    _timer?.cancel();
    _clock.stop();
    if (scope?.finished == true ||
        scope?.reason != null && scope?.reason != 'user') {
      cancel();
      return;
    }
    if (scope?.waiting != true) {
      final remaining = duration - _clock.elapsed;
      _clock.start();
      _timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
        _tick = 1;
        cancel();
        callback();
      });
    }
  }

  @override
  void cancel() {
    if (!_active) return;
    _active = false;
    _timer?.cancel();
    _clock.stop();
    scope?.removeListener(_changed);
  }
}
