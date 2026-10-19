import 'dart:async';

import 'package:flutter/foundation.dart';

/// Staggers visible entries in arrival order, including newly visible pages.
class FavoriteEntryAnimationQueue {
  static const interval = Duration(milliseconds: 45);

  final Map<Object, VoidCallback> _pending = {};
  Timer? _timer;
  bool _disposed = false;

  void schedule(Object token, VoidCallback onStart) {
    if (_disposed) return;
    _pending.putIfAbsent(token, () => onStart);
    if (_timer == null) _startNext();
  }

  void cancel(Object token) => _pending.remove(token);

  void _startNext() {
    _timer = null;
    if (_disposed || _pending.isEmpty) return;
    final token = _pending.keys.first;
    final onStart = _pending.remove(token)!;
    onStart();
    if (!_disposed) _timer = Timer(interval, _startNext);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending.clear();
  }
}
