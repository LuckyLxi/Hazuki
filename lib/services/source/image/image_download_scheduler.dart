import 'dart:async';
import 'dart:collection';

import '../models/source_task.dart';

/// Limits concurrent image downloads and orders pending work.
class ImageDownloadScheduler {
  ImageDownloadScheduler({int maxConcurrent = 4})
    : assert(maxConcurrent > 0),
      _maxConcurrent = maxConcurrent;

  final int _maxConcurrent;
  int _activeCount = 0;
  final Queue<_ImageDownloadWaiter> _waiters = Queue<_ImageDownloadWaiter>();

  Future<T> schedule<T>(
    String key, {
    required bool priority,
    required Future<T> Function() task,
    SourceTaskCancellation? cancellation,
  }) async {
    void checkActive() {
      if (cancellation?.reason case final reason?) {
        throw SourceTaskCancelled(key, reason);
      }
    }

    checkActive();
    await _acquire(key, priority: priority, cancellation: cancellation);
    try {
      checkActive();
      return await task();
    } finally {
      _release();
    }
  }

  void promote(String key) {
    _ImageDownloadWaiter? pending;
    for (final waiter in _waiters) {
      if (waiter.key == key) {
        pending = waiter;
        break;
      }
    }
    if (pending == null || pending.completer.isCompleted) return;
    if (_waiters.remove(pending)) {
      _waiters.addFirst(pending);
    }
  }

  Future<void> _acquire(
    String key, {
    required bool priority,
    SourceTaskCancellation? cancellation,
  }) async {
    if (_activeCount < _maxConcurrent) {
      _activeCount++;
      return;
    }
    final waiter = _ImageDownloadWaiter(key);
    if (priority) {
      _waiters.addFirst(waiter);
    } else {
      _waiters.addLast(waiter);
    }
    void stopped() {
      if (cancellation?.reason case final reason?) {
        // A granted waiter owns its permit; schedule's finally releases it.
        if (_waiters.remove(waiter)) {
          waiter.completer.completeError(SourceTaskCancelled(key, reason));
        }
      }
    }

    cancellation?.addListener(stopped);
    try {
      stopped();
      await waiter.completer.future;
    } finally {
      cancellation?.removeListener(stopped);
    }
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (!next.completer.isCompleted) next.completer.complete();
      return;
    }
    if (_activeCount > 0) _activeCount--;
  }
}

class _ImageDownloadWaiter {
  _ImageDownloadWaiter(this.key);

  final String key;
  final Completer<void> completer = Completer<void>();
}
