import '../gateways/source_sync_gateway.dart';
import 'hazuki_source_adapter_base.dart';

class HazukiSourceSyncAdapter extends HazukiSourceAdapterBase
    implements SourceSyncGateway {
  const HazukiSourceSyncAdapter(super.source);

  @override
  String get activeSourceKey => source.activeSourceKey;
  @override
  Future<bool> hasCustomEditedActiveSource() =>
      source.hasCustomEditedActiveSource();
  @override
  Future<String?> readLocalActiveSourceIfExists() =>
      source.readLocalActiveSourceIfExists();
  @override
  Future<void> writeLocalActiveSource(String content) =>
      source.writeLocalActiveSource(content);
  @override
  Future<void> reloadFromLocalSourceFiles() =>
      source.reloadFromLocalSourceFiles();
}
