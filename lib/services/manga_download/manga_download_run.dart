import 'dart:async';

import '../source/source_capabilities.dart';

/// One execution, including its admitted disk IO and source-resource drain.
class MangaDownloadRun {
  MangaDownloadRun({
    required this.ownerId,
    required this.isCurrent,
    required this.control,
    this.session,
  }) {
    _settled.future.ignore();
  }

  final String ownerId;
  final String groupId = createSourceTaskId();
  final bool Function() isCurrent;
  final SourceTaskControlGateway? control;
  final SourceDownloadSession? session;
  final SourceTaskCancellation cancellation = SourceTaskCancellation();
  final Completer<void> _settled = Completer<void>();
  Future<void> get whenSettled => _settled.future;
  Future<void>? _sourceDrain;
  int _sequence = 0;

  SourceTaskOrigin get origin => SourceTaskOrigin(
    ownerId: ownerId,
    groupId: groupId,
    requestSequence: ++_sequence,
    cancellation: cancellation,
    downloadSession: session,
    retainOnSourceChange: true,
  );

  void checkActive() {
    session?.checkActive();
    if (!isCurrent() && cancellation.reason == null) {
      stop(SourceTaskStopReason.superseded);
    }
    if (cancellation.reason case final reason?) {
      throw SourceTaskCancelled(groupId, reason);
    }
  }

  void stop(SourceTaskStopReason reason) {
    cancellation.cancel(reason);
    _sourceDrain ??= _cancelSource(reason);
    _sourceDrain!.ignore();
  }

  Future<void> _cancelSource(SourceTaskStopReason reason) async {
    final receipt = await control?.cancelGroup(
      ownerId: ownerId,
      groupId: groupId,
      reason: reason,
    );
    await receipt?.whenSettled;
  }

  /// The executor awaits every admitted commit before finishing this run.
  Future<T> commit<T>(
    Future<T> Function() operation, {
    bool checkAfter = true,
  }) async {
    checkActive();
    final result = await operation();
    if (checkAfter) checkActive();
    return result;
  }

  Future<void> finish() async {
    try {
      stop(cancellation.reason ?? SourceTaskStopReason.ownerDisposed);
      await _sourceDrain;
    } catch (error, stack) {
      if (!_settled.isCompleted) _settled.completeError(error, stack);
      rethrow;
    } finally {
      session?.close(cancellation.reason ?? SourceTaskStopReason.ownerDisposed);
      if (!_settled.isCompleted) _settled.complete();
    }
  }
}
