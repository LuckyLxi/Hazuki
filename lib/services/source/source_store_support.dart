part of '../hazuki_source_service.dart';

extension _SourceStoreSupport on HazukiSourceService {
  dynamic _loadSourceData(String sourceKey, String dataKey) {
    return facade.loadSourceData(sourceKey, dataKey);
  }

  Future<void> _saveSourceData(
    String sourceKey,
    String dataKey,
    dynamic data,
  ) async {
    await facade.saveSourceData(sourceKey, dataKey, data);
  }

  Future<void> _deleteSourceData(String sourceKey, String dataKey) async {
    await facade.deleteSourceData(sourceKey, dataKey);
  }

  dynamic _loadSourceSetting(String sourceKey, String settingKey) {
    return facade.loadSourceSetting(sourceKey, settingKey);
  }

  List<String>? _loadAccountDataSync() {
    return facade.loadAccountDataSync();
  }
}
