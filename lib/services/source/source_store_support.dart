part of '../hazuki_source_service.dart';

extension _SourceStoreSupport on HazukiSourceService {
  Map<String, dynamic> _loadSourceStore(String sourceKey) {
    final prefs = _prefs;
    if (prefs == null || sourceKey.isEmpty) {
      return {};
    }

    final raw = prefs.getString('source_data_$sourceKey');
    if (raw == null || raw.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveSourceStore(
    String sourceKey,
    Map<String, dynamic> store,
  ) async {
    final prefs = _prefs;
    if (prefs == null || sourceKey.isEmpty) {
      return;
    }
    await prefs.setString('source_data_$sourceKey', jsonEncode(store));
  }

  dynamic _loadSourceData(String sourceKey, String dataKey) {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return null;
    }
    final store = _loadSourceStore(sourceKey);
    return store[dataKey];
  }

  Future<void> _saveSourceData(
    String sourceKey,
    String dataKey,
    dynamic data,
  ) async {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    final store = _loadSourceStore(sourceKey);
    store[dataKey] = data;
    await _saveSourceStore(sourceKey, store);
  }

  Future<void> _saveSourceSetting(
    String sourceKey,
    String settingKey,
    dynamic value,
  ) async {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return;
    }
    final store = _loadSourceStore(sourceKey);
    final settingsRaw = store['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};
    settings[settingKey] = value;
    store['settings'] = settings;
    await _saveSourceStore(sourceKey, store);
  }

  Future<void> _deleteSourceData(String sourceKey, String dataKey) async {
    if (sourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    final store = _loadSourceStore(sourceKey);
    store.remove(dataKey);
    await _saveSourceStore(sourceKey, store);
  }

  dynamic _loadSourceSetting(String sourceKey, String settingKey) {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return null;
    }

    final store = _loadSourceStore(sourceKey);
    final settings = store['settings'];
    if (settings is Map && settings.containsKey(settingKey)) {
      return settings[settingKey];
    }

    if (_sourceMeta?.key == sourceKey) {
      return _sourceMeta?.settingsDefaults[settingKey];
    }

    return null;
  }

  List<String>? _loadAccountDataSync() {
    final key = _sourceMeta?.key;
    if (key == null) {
      return null;
    }

    final accountData = _loadSourceData(key, 'account');
    if (accountData is List && accountData.length >= 2) {
      return [accountData[0].toString(), accountData[1].toString()];
    }
    return null;
  }
}
