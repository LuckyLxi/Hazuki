import 'source_runtime_facade.dart';

class LineSettingsCapability {
  LineSettingsCapability(this._facade);

  final HazukiSourceFacade _facade;

  Future<Map<String, dynamic>> getSnapshot() async {
    final engine = _facade.js.engine;
    final sourceMeta = _facade.sourceMeta;
    if (engine == null || sourceMeta == null) {
      throw Exception('source_not_initialized');
    }

    final store = _facade.session.loadSourceStore(sourceMeta.key);
    final settingsInStore = store['settings'];
    final settingsMap = settingsInStore is Map
        ? Map<String, dynamic>.from(settingsInStore)
        : <String, dynamic>{};

    String readSelectSetting(String key, String fallback) {
      final raw = settingsMap.containsKey(key)
          ? settingsMap[key]
          : sourceMeta.settingsDefaults[key];
      final normalized = raw?.toString().trim() ?? '';
      if (normalized.isEmpty) {
        return fallback;
      }
      return normalized;
    }

    final refreshRaw = settingsMap.containsKey('refreshDomainsOnStart')
        ? settingsMap['refreshDomainsOnStart']
        : sourceMeta.settingsDefaults['refreshDomainsOnStart'];

    final dynamic domainsRaw = engine.evaluate(
      'Array.isArray(JM?.apiDomains) ? JM.apiDomains.slice() : []',
    );
    final domainsResolved = await _facade.js.resolve(domainsRaw);
    final apiDomains = <String>[];
    if (domainsResolved is List) {
      for (final item in domainsResolved) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          apiDomains.add(text);
        }
      }
    }

    final dynamic imageStreamOptionsCountRaw = engine.evaluate(
      'this.__hazuki_source.settings?.imageStream?.options?.length ?? 4',
    );
    final imageStreamOptionsCount =
        _facade.js.asInt(imageStreamOptionsCountRaw) ?? 4;

    final dynamic imageHostRaw = engine.evaluate('JM?.imageUrl ?? ""');
    final imageHost = imageHostRaw?.toString() ?? '';

    final apiDomain = readSelectSetting('apiDomain', '1');
    final imageStream = readSelectSetting('imageStream', '1');
    final refreshDomainsOnStart = _facade.js.asBool(refreshRaw);

    return {
      'apiDomain': apiDomain,
      'imageStream': imageStream,
      'refreshDomainsOnStart': refreshDomainsOnStart,
      'apiDomains': apiDomains,
      'imageStreamOptionsCount': imageStreamOptionsCount < 1
          ? 1
          : imageStreamOptionsCount,
      'imageHost': imageHost,
    };
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final sourceMeta = _facade.sourceMeta;
    if (sourceMeta == null) {
      throw Exception('source_not_initialized');
    }
    await _facade.saveSourceSetting(sourceMeta.key, key, value);
  }

  Future<void> refresh({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
  }) async {
    final engine = _facade.js.engine;
    if (engine == null) {
      throw Exception('source_not_initialized');
    }

    if (refreshApiDomains) {
      final hasRefreshApi = _facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.refreshApiDomains'),
      );
      if (hasRefreshApi) {
        final dynamic result = engine.evaluate(
          'this.__hazuki_source.refreshApiDomains(false)',
          name: 'source_refresh_api_domains.js',
        );
        await _facade.js.resolve(result);
      }
    }

    if (refreshImageHost) {
      final hasRefreshImg = _facade.js.asBool(
        engine.evaluate('!!this.__hazuki_source.refreshImgUrl'),
      );
      if (hasRefreshImg) {
        final dynamic result = engine.evaluate(
          'this.__hazuki_source.refreshImgUrl(false)',
          name: 'source_refresh_image_host.js',
        );
        await _facade.js.resolve(result);
      }
    }
  }
}
