import 'dart:async';

import '../services/source/gateways/source_task_control_gateway.dart';
import '../services/source/models/source_task.dart';

/// An explicit request group; pagination keeps the group until replacement.
class SourceTaskOwner {
  SourceTaskOwner(this.control, {this.readerSession, String? ownerId})
    : ownerId = ownerId ?? createSourceTaskId();
  final SourceTaskControlGateway? control;
  final SourceReaderSession? readerSession;
  final String ownerId;
  String _groupId = createSourceTaskId();
  SourceTaskCancellation _signal = SourceTaskCancellation();
  int _sequence = 0;
  int generation = 0;

  SourceTaskOrigin origin({Duration? workTimeout}) => SourceTaskOrigin(
    ownerId: ownerId,
    groupId: _groupId,
    requestSequence: ++_sequence,
    cancellation: _signal,
    workTimeout: workTimeout,
    readerSession: readerSession,
  );

  void restart([
    SourceTaskStopReason reason = SourceTaskStopReason.superseded,
  ]) {
    generation++;
    _signal.cancel(reason);
    unawaited(
      control?.cancelGroup(ownerId: ownerId, groupId: _groupId, reason: reason),
    );
    _groupId = createSourceTaskId();
    _signal = SourceTaskCancellation();
  }

  void dispose([
    SourceTaskStopReason reason = SourceTaskStopReason.ownerDisposed,
  ]) {
    _signal.cancel(reason);
    unawaited(control?.cancelOwner(ownerId, reason));
  }
}
