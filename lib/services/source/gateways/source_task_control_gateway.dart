import '../models/source_task.dart';

enum SourceTaskCancelStatus {
  accepted,
  alreadyRequested,
  alreadyFinished,
  notFound,
}

class SourceTaskCancelReceipt {
  SourceTaskCancelReceipt(
    this.status,
    this.whenSettled, {
    int Function()? sharedResourceCount,
  }) : _sharedResourceCount = sharedResourceCount;

  final SourceTaskCancelStatus status;
  final Future<void> whenSettled;
  final int Function()? _sharedResourceCount;
  int get sharedResourceCount => _sharedResourceCount?.call() ?? 0;
}

abstract interface class SourceTaskControlGateway {
  Future<SourceTaskCancelReceipt> cancelTask(
    String taskId,
    SourceTaskStopReason reason,
  );
  Future<SourceTaskCancelReceipt> cancelGroup({
    required String ownerId,
    required String groupId,
    String? pluginId,
    required SourceTaskStopReason reason,
  });
  Future<SourceTaskCancelReceipt> cancelOwner(
    String ownerId,
    SourceTaskStopReason reason,
  );
}
