import 'dart:async';

import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/models/source_task.dart';

import 'search_contracts.dart';

SourceTaskCancelled searchStopError(SourceTaskCancellation lifetime) =>
    lifetime.reason == SourceTaskStopReason.deadlineExceeded
    ? const SourceTaskTimedOut('', SourceTaskStopReason.deadlineExceeded)
    : SourceTaskCancelled('', lifetime.reason!);

Future<T> runSearchOperation<T>(
  Future<T> Function() operation,
  SourceTaskCancellation lifetime,
) {
  if (lifetime.reason != null) return Future.error(searchStopError(lifetime));
  return SourceUiScope.timeout(
    Future.any<T>([
      Future<T>.sync(operation),
      lifetime.whenStopped.then<T>((_) => throw searchStopError(lifetime)),
    ]),
    searchLoadTimeout,
    onTimeout: () {
      lifetime.cancel(SourceTaskStopReason.deadlineExceeded);
      throw searchStopError(lifetime);
    },
  );
}

Future<void> waitForSearchRetry(
  Duration duration,
  SourceTaskCancellation lifetime,
) {
  final result = Completer<void>();
  late final Timer timer;
  void stop() {
    if (lifetime.reason != null && !result.isCompleted) {
      timer.cancel();
      result.completeError(searchStopError(lifetime));
    }
  }

  timer = Timer(duration, () => result.complete());
  lifetime.addListener(stop);
  stop();
  return result.future.whenComplete(() => lifetime.removeListener(stop));
}

bool isSilentSearchStop(Object error) =>
    isSourceUiCancellation(error) || isSourceTaskCancellation(error);

String searchFailureMessage(Object error, SearchMessages messages) =>
    error is SourceTaskTimedOut &&
        error.reason == SourceTaskStopReason.deadlineExceeded
    ? messages.timeout
    : messages.failed('$error');
