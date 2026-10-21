import 'package:hazuki/services/source/source_capabilities.dart';

/// Controller tests record control requests; source fakes observe the explicit
/// origin cancellation separately. Production always injects the host gateway.
class FakeSourceTaskControl implements SourceTaskControlGateway {
  final List<
    ({String kind, String id, String? pluginId, SourceTaskStopReason reason})
  >
  requests = [];

  Future<SourceTaskCancelReceipt> _record(
    String kind,
    String id,
    SourceTaskStopReason reason, {
    String? pluginId,
  }) async {
    requests.add((kind: kind, id: id, pluginId: pluginId, reason: reason));
    return SourceTaskCancelReceipt(
      SourceTaskCancelStatus.notFound,
      Future<void>.value(),
    );
  }

  @override
  Future<SourceTaskCancelReceipt> cancelTask(
    String taskId,
    SourceTaskStopReason reason,
  ) => _record('task', taskId, reason);
  @override
  Future<SourceTaskCancelReceipt> cancelOwner(
    String ownerId,
    SourceTaskStopReason reason,
  ) => _record('owner', ownerId, reason);
  @override
  Future<SourceTaskCancelReceipt> cancelGroup({
    required String ownerId,
    required String groupId,
    String? pluginId,
    required SourceTaskStopReason reason,
  }) => _record('group', groupId, reason, pluginId: pluginId);
}
