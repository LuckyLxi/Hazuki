import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/source_meta.dart';
import '../common/source_prefs_keys.dart';
import 'source_cookie_store.dart';
import 'source_secure_session_storage.dart';

class SourceSessionStore {
  SourceSessionStore({
    required this.sourceKey,
    required SourceSecureSessionStorage secureStorage,
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _secureStorage = secureStorage,
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final String sourceKey;
  final SourceSecureSessionStorage _secureStorage;
  final Future<SharedPreferences> Function() _loadPreferences;
  final Map<String, _SecureSourceSessionData> _secureCache =
      <String, _SecureSourceSessionData>{};
  SharedPreferences? prefs;

  void clearMemory() {
    _secureCache.clear();
    prefs = null;
  }

  Future<SharedPreferences> ensurePrefs() async {
    final current = prefs ??= await _loadPreferences();
    await _migrateLegacySessionData(current);
    await _loadSecureSessionData(sourceKey);
    return current;
  }

  Map<String, dynamic> loadSourceStore(String sourceKey) {
    final currentPrefs = prefs;
    if (currentPrefs == null || sourceKey.isEmpty) {
      return {};
    }

    final raw = currentPrefs.getString('source_data_$sourceKey');
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

  Future<void> saveSourceStore(
    String sourceKey,
    Map<String, dynamic> store,
  ) async {
    final currentPrefs = prefs;
    if (currentPrefs == null || sourceKey.isEmpty) {
      return;
    }
    await currentPrefs.setString('source_data_$sourceKey', jsonEncode(store));
  }

  dynamic loadSourceData(String sourceKey, String dataKey) {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty || dataKey.isEmpty) {
      return null;
    }
    if (dataKey == 'account') {
      return _secureDataFor(normalizedSourceKey).account ??
          loadSourceStore(normalizedSourceKey)['account'];
    }
    if (dataKey == 'token') {
      return _secureDataFor(normalizedSourceKey).token ??
          loadSourceStore(normalizedSourceKey)['token'];
    }
    return loadSourceStore(normalizedSourceKey)[dataKey];
  }

  Future<void> saveSourceData(
    String sourceKey,
    String dataKey,
    dynamic data,
  ) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    if (dataKey == 'account') {
      final accountData = _normalizeAccountData(data);
      if (accountData == null) {
        await deleteSourceData(normalizedSourceKey, dataKey);
        return;
      }
      await _secureStorage.write(
        SourceSecureSessionStorageKeys.account(normalizedSourceKey),
        jsonEncode(accountData),
      );
      _secureDataFor(normalizedSourceKey).account = accountData;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    if (dataKey == 'token') {
      final token = data?.toString();
      if (token == null || token.isEmpty) {
        await deleteSourceData(normalizedSourceKey, dataKey);
        return;
      }
      await _secureStorage.write(
        SourceSecureSessionStorageKeys.token(normalizedSourceKey),
        token,
      );
      _secureDataFor(normalizedSourceKey).token = token;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    final store = loadSourceStore(normalizedSourceKey);
    store[dataKey] = data;
    await saveSourceStore(normalizedSourceKey, store);
  }

  Future<void> deleteSourceData(String sourceKey, String dataKey) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty || dataKey.isEmpty) {
      return;
    }
    if (dataKey == 'account') {
      await _secureStorage.delete(
        SourceSecureSessionStorageKeys.account(normalizedSourceKey),
      );
      _secureDataFor(normalizedSourceKey).account = null;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    if (dataKey == 'token') {
      await _secureStorage.delete(
        SourceSecureSessionStorageKeys.token(normalizedSourceKey),
      );
      _secureDataFor(normalizedSourceKey).token = null;
      await _removeLegacySourceDataKey(normalizedSourceKey, dataKey);
      return;
    }
    final store = loadSourceStore(normalizedSourceKey);
    store.remove(dataKey);
    await saveSourceStore(normalizedSourceKey, store);
  }

  dynamic loadSourceSetting({
    required String sourceKey,
    required String settingKey,
    required SourceMeta? sourceMeta,
  }) {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return null;
    }

    final store = loadSourceStore(sourceKey);
    final settings = store['settings'];
    if (settings is Map && settings.containsKey(settingKey)) {
      return settings[settingKey];
    }

    if (sourceMeta?.key == sourceKey) {
      return sourceMeta?.settingsDefaults[settingKey];
    }

    return null;
  }

  Future<void> saveSourceSetting(
    String sourceKey,
    String settingKey,
    dynamic value,
  ) async {
    if (sourceKey.isEmpty || settingKey.isEmpty) {
      return;
    }
    final store = loadSourceStore(sourceKey);
    final settingsRaw = store['settings'];
    final settings = settingsRaw is Map
        ? Map<String, dynamic>.from(settingsRaw)
        : <String, dynamic>{};
    settings[settingKey] = value;
    store['settings'] = settings;
    await saveSourceStore(sourceKey, store);
  }

  List<String>? loadAccountDataSync(
    SourceMeta? sourceMeta, {
    String? fallbackSourceKey,
  }) {
    final key = (sourceMeta?.key ?? fallbackSourceKey ?? sourceKey).trim();
    if (key.isEmpty) {
      return null;
    }

    final accountData = loadSourceData(key, 'account');
    if (accountData is List && accountData.length >= 2) {
      return [accountData[0].toString(), accountData[1].toString()];
    }
    return null;
  }

  List<SourceCookie> loadCookieStore() {
    final raw =
        _secureDataFor(sourceKey).cookiesRaw ??
        prefs?.getString(_cookieStoreKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => SourceCookie.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveCookieStore(List<SourceCookie> cookies) async {
    if (cookies.isEmpty) {
      await _secureStorage.delete(
        SourceSecureSessionStorageKeys.cookies(sourceKey),
      );
      _secureDataFor(sourceKey).cookiesRaw = null;
      await prefs?.remove(_cookieStoreKey);
      return;
    }
    final raw = jsonEncode(cookies.map((e) => e.toMap()).toList());
    await _secureStorage.write(
      SourceSecureSessionStorageKeys.cookies(sourceKey),
      raw,
    );
    _secureDataFor(sourceKey).cookiesRaw = raw;
    await prefs?.remove(_cookieStoreKey);
  }

  String get _cookieStoreKey => 'cookie_store_v2_${sourceKey.trim()}';

  Future<void> _migrateLegacySessionData(SharedPreferences prefs) async {
    await prefs.remove('cookie_store_v1');
    if (prefs.getBool(SourcePrefsKeys.sourceSecureSessionMigration) == true) {
      return;
    }

    var migrationComplete = true;

    for (final key in prefs.getKeys().where(_isSourceDataPrefsKey).toList()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        continue;
      }
      final migratedSourceKey = key.substring('source_data_'.length);
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final sanitized = Map<String, dynamic>.from(decoded);
        var changed = false;

        if (sanitized.containsKey('account')) {
          final accountData = _normalizeAccountData(sanitized['account']);
          if (accountData != null) {
            try {
              await _secureStorage.write(
                SourceSecureSessionStorageKeys.account(migratedSourceKey),
                jsonEncode(accountData),
              );
              _secureDataFor(migratedSourceKey).account = accountData;
              sanitized.remove('account');
              changed = true;
            } catch (_) {
              migrationComplete = false;
            }
          } else {
            sanitized.remove('account');
            changed = true;
          }
        }

        if (sanitized.containsKey('token')) {
          final token = sanitized['token']?.toString();
          if (token != null && token.isNotEmpty) {
            try {
              await _secureStorage.write(
                SourceSecureSessionStorageKeys.token(migratedSourceKey),
                token,
              );
              _secureDataFor(migratedSourceKey).token = token;
              sanitized.remove('token');
              changed = true;
            } catch (_) {
              migrationComplete = false;
            }
          } else {
            sanitized.remove('token');
            changed = true;
          }
        }

        if (changed) {
          await prefs.setString(key, jsonEncode(sanitized));
        }
      } catch (_) {
        migrationComplete = false;
      }
    }

    for (final key in prefs.getKeys().where(_isCookiePrefsKey).toList()) {
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        await prefs.remove(key);
        continue;
      }
      final migratedSourceKey = key.substring('cookie_store_v2_'.length);
      try {
        await _secureStorage.write(
          SourceSecureSessionStorageKeys.cookies(migratedSourceKey),
          raw,
        );
        _secureDataFor(migratedSourceKey).cookiesRaw = raw;
        await prefs.remove(key);
      } catch (_) {
        migrationComplete = false;
      }
    }

    if (migrationComplete) {
      await prefs.setBool(SourcePrefsKeys.sourceSecureSessionMigration, true);
      await prefs.setBool(SourcePrefsKeys.sourceSessionScopeMigration, true);
    }
  }

  Future<void> _loadSecureSessionData(String sourceKey) async {
    final normalizedSourceKey = sourceKey.trim();
    if (normalizedSourceKey.isEmpty) {
      return;
    }
    final data = _secureDataFor(normalizedSourceKey);
    data.account = _decodeAccountData(
      await _safeRead(
        SourceSecureSessionStorageKeys.account(normalizedSourceKey),
      ),
    );
    data.token = await _safeRead(
      SourceSecureSessionStorageKeys.token(normalizedSourceKey),
    );
    data.cookiesRaw = await _safeRead(
      SourceSecureSessionStorageKeys.cookies(normalizedSourceKey),
    );
  }

  Future<String?> _safeRead(String key) async {
    try {
      return await _secureStorage.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeLegacySourceDataKey(
    String sourceKey,
    String dataKey,
  ) async {
    final store = loadSourceStore(sourceKey);
    if (!store.containsKey(dataKey)) {
      return;
    }
    store.remove(dataKey);
    await saveSourceStore(sourceKey, store);
  }

  _SecureSourceSessionData _secureDataFor(String sourceKey) {
    return _secureCache.putIfAbsent(
      sourceKey.trim(),
      _SecureSourceSessionData.new,
    );
  }

  static bool _isSourceDataPrefsKey(String key) {
    return key.startsWith('source_data_');
  }

  static bool _isCookiePrefsKey(String key) {
    return key.startsWith('cookie_store_v2_');
  }

  static List<String>? _normalizeAccountData(dynamic value) {
    if (value is! List || value.length < 2) {
      return null;
    }
    return [value[0].toString(), value[1].toString()];
  }

  static List<String>? _decodeAccountData(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return _normalizeAccountData(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

class _SecureSourceSessionData {
  List<String>? account;
  String? token;
  String? cookiesRaw;
}
