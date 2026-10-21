import 'dart:async';

import '../services/source/gateways/source_task_control_gateway.dart';
import '../services/source/models/source_task.dart';

/// An explicit request group; pagination keeps the group until replacement.
class SourceTaskOwner {
  SourceTaskOwner(this.control);
  final SourceTaskControlGateway control;
  final String ownerId = createSourceTaskId();
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
  );

  void restart([
    SourceTaskStopReason reason = SourceTaskStopReason.superseded,
  ]) {
    generation++;
    _signal.cancel(reason);
    unawaited(
      control.cancelGroup(ownerId: ownerId, groupId: _groupId, reason: reason),
    );
    _groupId = createSourceTaskId();
    _signal = SourceTaskCancellation();
  }

  void dispose() {
    _signal.cancel(SourceTaskStopReason.ownerDisposed);
    unawaited(control.cancelOwner(ownerId, SourceTaskStopReason.ownerDisposed));
  }
}
