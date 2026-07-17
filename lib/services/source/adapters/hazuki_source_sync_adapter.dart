import '../gateways/source_sync_gateway.dart';
import '../runtime/source_runtime_operations.dart';
import '../runtime/source_runtime_view.dart';

class HazukiSourceSyncAdapter implements SourceSyncGateway {
  const HazukiSourceSyncAdapter({
    required SourceRuntimeView runtime,
    required SourceRuntimeOperations runtimeOperations,
  }) : _runtime = runtime,
       _runtimeOperations = runtimeOperations;

  final SourceRuntimeView _runtime;
  final SourceRuntimeOperations _runtimeOperations;

  @override
  String get activeSourceKey => _runtime.activeSourceKey;
  @override
  Future<bool> hasCustomEditedActiveSource() =>
      _runtimeOperations.hasCustomEditedActiveSource();
  @override
  Future<String?> readLocalActiveSourceIfExists() =>
      _runtimeOperations.readLocalActiveSourceIfExists();
  @override
  Future<void> writeLocalActiveSource(String content) =>
      _runtimeOperations.writeLocalActiveSource(content);
  @override
  Future<void> reloadFromLocalSourceFiles() =>
      _runtimeOperations.reloadFromLocalSourceFiles();
}
