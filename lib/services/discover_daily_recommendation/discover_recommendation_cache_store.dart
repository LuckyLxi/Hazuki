import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/preferences/hazuki_preference_keys.dart';
import 'discover_recommendation_models.dart';
import 'discover_recommendation_config.dart';

const _discoverDailyRecommendationCachePayloadKey =
    hazukiDiscoverDailyRecommendationCachePreferenceKey;

abstract interface class DiscoverDailyRecommendationCacheStore {
  Future<void> setEnabled(bool enabled);
  Future<bool> loadEnabled();
  Future<void> persistSnapshot(DiscoverDailyRecommendationSnapshot snapshot);
  Future<DiscoverDailyRecommendationSnapshot?> readSnapshot({
    required String activeSourceKey,
  });
}

class SharedPreferencesDiscoverDailyRecommendationCacheStore
    implements DiscoverDailyRecommendationCacheStore {
  SharedPreferencesDiscoverDailyRecommendationCacheStore();

  final _sessionSnapshots = <String, DiscoverDailyRecommendationSnapshot>{};
  late final Future<SharedPreferences> _preferences = _loadPreferences();

  Future<SharedPreferences> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Earlier versions persisted plugin recommendations. Never restore them
    // into a new app session, including caches belonging to inactive sources.
    for (final key in prefs.getKeys()) {
      if (key != _discoverDailyRecommendationCachePayloadKey &&
          !key.startsWith('${_discoverDailyRecommendationCachePayloadKey}_')) {
        continue;
      }
      final snapshot = _parseCachePayload(
        prefs.getString(key),
        fallbackSourceKey: 'jm',
      );
      if (snapshot?.configurationKey == 'plugin') {
        await prefs.remove(key);
      }
    }
    return prefs;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(
      hazukiDiscoverDailyRecommendationEnabledPreferenceKey,
      enabled,
    );
  }

  @override
  Future<bool> loadEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool(
          hazukiDiscoverDailyRecommendationEnabledPreferenceKey,
        ) ??
        false;
  }

  @override
  Future<void> persistSnapshot(
    DiscoverDailyRecommendationSnapshot snapshot,
  ) async {
    final prefs = await _preferences;
    final sourceKey = snapshot.sourceKey.trim();
    if (snapshot.configurationKey == 'plugin') {
      _sessionSnapshots[sourceKey] = snapshot;
      await prefs.remove(_sourceCachePayloadKey(sourceKey));
      return;
    }
    _sessionSnapshots.remove(sourceKey);
    await prefs.setString(
      _sourceCachePayloadKey(snapshot.sourceKey),
      jsonEncode(<String, dynamic>{
        'version': DiscoverDailyRecommendationConfig.cacheSchemaVersion,
        'sourceKey': snapshot.sourceKey,
        'generatedAt': snapshot.generatedAt.toIso8601String(),
        'selectedAuthor': snapshot.selectedAuthor,
        'configurationKey': snapshot.configurationKey,
        'entries': snapshot.recommendations
            .map((entry) => entry.toJson())
            .toList(),
      }),
    );
  }

  @override
  Future<DiscoverDailyRecommendationSnapshot?> readSnapshot({
    required String activeSourceKey,
  }) async {
    final prefs = await _preferences;
    final normalizedActiveSourceKey = activeSourceKey.trim();
    final sessionSnapshot = _sessionSnapshots[normalizedActiveSourceKey];
    if (sessionSnapshot != null) return sessionSnapshot;
    final hasActiveSourceKey = normalizedActiveSourceKey.isNotEmpty;
    final candidates = <String>[
      if (hasActiveSourceKey) _sourceCachePayloadKey(activeSourceKey),
      _discoverDailyRecommendationCachePayloadKey,
      if (!hasActiveSourceKey)
        ...prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith(
                    '${_discoverDailyRecommendationCachePayloadKey}_',
                  ) &&
                  key != _discoverDailyRecommendationCachePayloadKey,
            )
            .toList()
          ..sort(),
    ];

    DiscoverDailyRecommendationSnapshot? newestFallback;
    for (final key in candidates) {
      final scopedSourceKey = key == _discoverDailyRecommendationCachePayloadKey
          ? null
          : key.substring(
              _discoverDailyRecommendationCachePayloadKey.length + 1,
            );
      final snapshot = _parseCachePayload(
        prefs.getString(key),
        // The original global cache contained only JM recommendations.
        fallbackSourceKey: scopedSourceKey ?? 'jm',
      );
      if (snapshot == null ||
          (scopedSourceKey != null && snapshot.sourceKey != scopedSourceKey) ||
          (hasActiveSourceKey &&
              snapshot.sourceKey != normalizedActiveSourceKey)) {
        continue;
      }
      if (hasActiveSourceKey) {
        return snapshot;
      }
      final currentFallback = newestFallback;
      if (currentFallback == null ||
          snapshot.generatedAt.isAfter(currentFallback.generatedAt)) {
        newestFallback = snapshot;
      }
    }
    return newestFallback;
  }

  static String _sourceCachePayloadKey(String sourceKey) {
    final normalized = sourceKey.trim();
    if (normalized.isEmpty) {
      return _discoverDailyRecommendationCachePayloadKey;
    }
    return '${_discoverDailyRecommendationCachePayloadKey}_$normalized';
  }

  static DiscoverDailyRecommendationSnapshot? _parseCachePayload(
    String? raw, {
    required String fallbackSourceKey,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final version = map['version'] is int ? map['version'] as int : 1;
      final declaredSourceKey = (map['sourceKey'] ?? '').toString().trim();
      final sourceKey = declaredSourceKey.isEmpty
          ? fallbackSourceKey
          : declaredSourceKey;
      final generatedAt = DateTime.tryParse(
        (map['generatedAt'] ?? '').toString(),
      )?.toLocal();
      final selectedAuthor = (map['selectedAuthor'] ?? '').toString().trim();
      final entriesRaw = map['entries'];
      final entries = entriesRaw is List
          ? entriesRaw
                .map(
                  (entry) => DiscoverDailyRecommendationEntry.fromJson(
                    entry,
                    fallbackSourceKey: sourceKey,
                  ),
                )
                .whereType<DiscoverDailyRecommendationEntry>()
                .toList(growable: false)
          : const <DiscoverDailyRecommendationEntry>[];
      if (sourceKey.isEmpty ||
          generatedAt == null ||
          entriesRaw is! List ||
          entries.length != entriesRaw.length ||
          entries.any((entry) => entry.comic.sourceKey != sourceKey)) {
        return null;
      }
      return DiscoverDailyRecommendationSnapshot(
        recommendations: entries,
        selectedAuthor: selectedAuthor,
        generatedAt: generatedAt,
        sourceKey: sourceKey,
        schemaVersion: version,
        configurationKey: (map['configurationKey'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
