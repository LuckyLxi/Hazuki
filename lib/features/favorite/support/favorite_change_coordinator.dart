import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns external subscriptions and coalesces local changes during a refresh.
class FavoriteChangeCoordinator {
  FavoriteChangeCoordinator({
    required Listenable localChanges,
    required Stream<void> cloudChanges,
    required bool Function() shouldRefreshLocal,
    required bool Function() shouldRefreshCloud,
    required Future<void> Function() refreshLocal,
    required Future<void> Function() refreshCloud,
  }) : _localChanges = localChanges,
       _shouldRefreshLocal = shouldRefreshLocal,
       _shouldRefreshCloud = shouldRefreshCloud,
       _refreshLocal = refreshLocal,
       _refreshCloud = refreshCloud {
    _localChanges.addListener(_onLocalChange);
    _subscription = cloudChanges.listen((_) {
      if (!_disposed && _shouldRefreshCloud()) unawaited(_refreshCloud());
    });
  }

  final Listenable _localChanges;
  final bool Function() _shouldRefreshLocal;
  final bool Function() _shouldRefreshCloud;
  final Future<void> Function() _refreshLocal;
  final Future<void> Function() _refreshCloud;
  late final StreamSubscription<void> _subscription;
  bool _disposed = false;
  bool _running = false;
  bool _queued = false;

  void _onLocalChange() {
    if (_disposed || !_shouldRefreshLocal()) return;
    if (_running) {
      _queued = true;
      return;
    }
    unawaited(_drainLocalChanges());
  }

  Future<void> _drainLocalChanges() async {
    _running = true;
    try {
      do {
        _queued = false;
        await _refreshLocal();
      } while (_queued && !_disposed && _shouldRefreshLocal());
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _localChanges.removeListener(_onLocalChange);
    unawaited(_subscription.cancel());
  }
}
