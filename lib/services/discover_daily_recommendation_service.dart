import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_preferences.dart';
import '../models/hazuki_models.dart';
import 'hazuki_source_service.dart';

class DiscoverDailyRecommendationEntry {
  const DiscoverDailyRecommendationEntry({
    required this.author,
    required this.comic,
  });

  final String author;
  final ExploreComic comic;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'author': author,
      'comic': <String, dynamic>{
        'id': comic.id,
        'sourceKey': comic.sourceKey,
        'title': comic.title,
        'subTitle': comic.subTitle,
        'cover': comic.cover,
      },
    };
  }

  static DiscoverDailyRecommendationEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final comicRaw = map['comic'];
    if (comicRaw is! Map) {
      return null;
    }
    final comicMap = Map<String, dynamic>.from(comicRaw);
    final author = (map['author'] ?? '').toString().trim();
    final comic = ExploreComic(
      id: (comicMap['id'] ?? '').toString(),
      sourceKey: (comicMap['sourceKey'] ?? '').toString(),
      title: (comicMap['title'] ?? '').toString(),
      subTitle: (comicMap['subTitle'] ?? '').toString(),
      cover: (comicMap['cover'] ?? '').toString(),
    );
    if (author.isEmpty ||
        comic.id.trim().isEmpty ||
        comic.title.trim().isEmpty) {
      return null;
    }
    return DiscoverDailyRecommendationEntry(author: author, comic: comic);
  }
}

class DiscoverDailyRecommendationState {
  const DiscoverDailyRecommendationState({
    required this.enabled,
    this.displayedRecommendations = const <DiscoverDailyRecommendationEntry>[],
    this.pendingRecommendations = const <DiscoverDailyRecommendationEntry>[],
    this.selectedAuthor,
    this.generatedAt,
    this.pendingSelectedAuthor,
    this.pendingGeneratedAt,
    this.isRefreshing = false,
    this.isPendingReady = false,
  });

  const DiscoverDailyRecommendationState.disabled() : this(enabled: false);

  final bool enabled;
  final List<DiscoverDailyRecommendationEntry> displayedRecommendations;
  final List<DiscoverDailyRecommendationEntry> pendingRecommendations;
  final String? selectedAuthor;
  final DateTime? generatedAt;
  final String? pendingSelectedAuthor;
  final DateTime? pendingGeneratedAt;
  final bool isRefreshing;
  final bool isPendingReady;

  List<DiscoverDailyRecommendationEntry> get recommendations =>
      displayedRecommendations;

  bool get hasRecommendations => enabled && displayedRecommendations.isNotEmpty;

  bool get hasPendingRecommendations => pendingRecommendations.isNotEmpty;

  DiscoverDailyRecommendationState copyWith({
    bool? enabled,
    List<DiscoverDailyRecommendationEntry>? displayedRecommendations,
    List<DiscoverDailyRecommendationEntry>? pendingRecommendations,
    Object? selectedAuthor = _discoverRecommendationUnset,
    Object? generatedAt = _discoverRecommendationUnset,
    Object? pendingSelectedAuthor = _discoverRecommendationUnset,
    Object? pendingGeneratedAt = _discoverRecommendationUnset,
    bool? isRefreshing,
    bool? isPendingReady,
  }) {
    return DiscoverDailyRecommendationState(
      enabled: enabled ?? this.enabled,
      displayedRecommendations:
          displayedRecommendations ?? this.displayedRecommendations,
      pendingRecommendations:
          pendingRecommendations ?? this.pendingRecommendations,
      selectedAuthor: selectedAuthor == _discoverRecommendationUnset
          ? this.selectedAuthor
          : selectedAuthor as String?,
      generatedAt: generatedAt == _discoverRecommendationUnset
          ? this.generatedAt
          : generatedAt as DateTime?,
      pendingSelectedAuthor:
          pendingSelectedAuthor == _discoverRecommendationUnset
          ? this.pendingSelectedAuthor
          : pendingSelectedAuthor as String?,
      pendingGeneratedAt: pendingGeneratedAt == _discoverRecommendationUnset
          ? this.pendingGeneratedAt
          : pendingGeneratedAt as DateTime?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isPendingReady: isPendingReady ?? this.isPendingReady,
    );
  }
}

const Object _discoverRecommendationUnset = Object();

@visibleForTesting
String extractDiscoverRecommendationAuthor(ComicDetailsData details) {
  final authors = normalizeDiscoverRecommendationMetaValues(
    details.tags.keys
        .where(_isDiscoverRecommendationAuthorKey)
        .expand((key) => details.tags[key] ?? const <String>[])
        .toList(),
  );
  return authors.join(' / ').trim();
}

@visibleForTesting
List<String> normalizeDiscoverRecommendationMetaValues(List<String> rawValues) {
  final values = <String>[];
  final seen = <String>{};
  for (final raw in rawValues) {
    final parts = raw
        .trim()
        .replaceFirst(
          RegExp('^(author|authors|\\u4f5c\\u8005)\\s*[:\\uFF1A]\\s*'),
          '',
        )
        .split(RegExp('[\\n,\\uFF0C/]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    for (final part in parts) {
      if (seen.add(part)) {
        values.add(part);
      }
    }
  }
  return values;
}

bool _isDiscoverRecommendationAuthorKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'author' ||
      normalized == 'authors' ||
      key.trim() == '\u4f5c\u8005';
}

class DiscoverDailyRecommendationService extends ChangeNotifier {
  DiscoverDailyRecommendationService({required HazukiSourceService source})
    : _source = source {
    _source.addListener(_handleSourceChanged);
  }

  final HazukiSourceService _source;

  static const String authorsAssetPath = 'assets/data/authors.txt';
  static const String _cachePayloadKey = 'discover_daily_recommendation_cache';
  static const int _cacheSchemaVersion = 2;
  static const Duration _cacheTtl = Duration(minutes: 15);
  static const int recommendationCount = 7;

  final math.Random _random = math.Random();

  DiscoverDailyRecommendationState _state =
      const DiscoverDailyRecommendationState.disabled();
  Future<void>? _refreshInFlight;

  DiscoverDailyRecommendationState get state => _state;

  bool get _supportsActiveSource => _source.isActiveJmSource;

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      hazukiDiscoverDailyRecommendationEnabledPreferenceKey,
      enabled,
    );
    if (!enabled) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    if (!_supportsActiveSource) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    _setState(_state.copyWith(enabled: true));
  }

  Future<bool> loadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          hazukiDiscoverDailyRecommendationEnabledPreferenceKey,
        ) ??
        false;
  }

  Future<DiscoverDailyRecommendationState> ensurePrepared({
    required bool enabled,
  }) async {
    if (!enabled || !_supportsActiveSource) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return _state;
    }

    if (_state.isPendingReady && _state.hasPendingRecommendations) {
      _setState(_state.copyWith(enabled: true, isRefreshing: false));
      return _state;
    }

    if (_state.hasRecommendations) {
      _setState(_state.copyWith(enabled: true));
      if (!_isDisplayedFresh(_state)) {
        unawaited(_refreshPendingRecommendations());
      }
      return _state;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);
    if (cached != null) {
      _setState(_snapshotToDisplayedState(cached));
      if (!_isCacheFresh(cached)) {
        unawaited(_refreshPendingRecommendations(prefs: prefs));
      }
      return _state;
    }

    if (!_source.isInitialized) {
      _setState(const DiscoverDailyRecommendationState(enabled: true));
      return _state;
    }

    final generated = await _generateRecommendations();
    if (generated == null) {
      _setState(const DiscoverDailyRecommendationState(enabled: true));
      return _state;
    }

    await _persistSnapshot(prefs, generated);
    _setState(_snapshotToDisplayedState(generated));
    return _state;
  }

  Future<void> promotePendingRecommendations() async {
    if (!_state.isPendingReady || !_state.hasPendingRecommendations) {
      return;
    }
    _setState(
      DiscoverDailyRecommendationState(
        enabled: _state.enabled,
        displayedRecommendations: _state.pendingRecommendations,
        selectedAuthor: _state.pendingSelectedAuthor,
        generatedAt: _state.pendingGeneratedAt,
        isRefreshing: false,
        isPendingReady: false,
      ),
    );
  }

  void _setState(DiscoverDailyRecommendationState next) {
    _state = DiscoverDailyRecommendationState(
      enabled: next.enabled,
      displayedRecommendations:
          List<DiscoverDailyRecommendationEntry>.unmodifiable(
            next.displayedRecommendations,
          ),
      pendingRecommendations:
          List<DiscoverDailyRecommendationEntry>.unmodifiable(
            next.pendingRecommendations,
          ),
      selectedAuthor: next.selectedAuthor,
      generatedAt: next.generatedAt,
      pendingSelectedAuthor: next.pendingSelectedAuthor,
      pendingGeneratedAt: next.pendingGeneratedAt,
      isRefreshing: next.isRefreshing,
      isPendingReady: next.isPendingReady,
    );
    notifyListeners();
  }

  DiscoverDailyRecommendationState _snapshotToDisplayedState(
    _DiscoverDailyRecommendationSnapshot snapshot,
  ) {
    return DiscoverDailyRecommendationState(
      enabled: true,
      displayedRecommendations: snapshot.recommendations,
      selectedAuthor: snapshot.selectedAuthor,
      generatedAt: snapshot.generatedAt,
      isRefreshing: false,
      isPendingReady: false,
    );
  }

  Future<void> _refreshPendingRecommendations({
    SharedPreferences? prefs,
  }) async {
    if (_refreshInFlight != null ||
        !_state.enabled ||
        _state.isPendingReady ||
        !_supportsActiveSource ||
        !_source.isInitialized) {
      return;
    }

    final completer = Completer<void>();
    _refreshInFlight = completer.future;
    _setState(_state.copyWith(isRefreshing: true));

    try {
      final generated = await _generateRecommendations();
      if (generated == null || !_state.enabled || !_supportsActiveSource) {
        return;
      }

      final preloaded = await _preloadRecommendationImages(
        generated.recommendations,
      );
      if (!preloaded || !_state.enabled || !_supportsActiveSource) {
        return;
      }

      final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
      await _persistSnapshot(resolvedPrefs, generated);
      _setState(
        _state.copyWith(
          pendingRecommendations: generated.recommendations,
          pendingSelectedAuthor: generated.selectedAuthor,
          pendingGeneratedAt: generated.generatedAt,
          isRefreshing: false,
          isPendingReady: true,
        ),
      );
    } finally {
      _refreshInFlight = null;
      if (!_state.isPendingReady) {
        _setState(_state.copyWith(isRefreshing: false));
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<bool> _preloadRecommendationImages(
    List<DiscoverDailyRecommendationEntry> recommendations,
  ) async {
    final imageUrls = recommendations
        .map((entry) => entry.comic.cover.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (imageUrls.length != recommendations.length) {
      return false;
    }
    try {
      await Future.wait(
        imageUrls.map((url) async {
          final bytes = await _source.downloadImageBytes(
            url,
            keepInMemory: true,
          );
          if (bytes.isEmpty) {
            throw Exception('recommendation_cover_empty');
          }
        }),
        eagerError: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistSnapshot(
    SharedPreferences prefs,
    _DiscoverDailyRecommendationSnapshot snapshot,
  ) {
    return prefs.setString(
      _sourceCachePayloadKey(snapshot.sourceKey),
      jsonEncode(<String, dynamic>{
        'version': _cacheSchemaVersion,
        'sourceKey': snapshot.sourceKey,
        'generatedAt': snapshot.generatedAt.toIso8601String(),
        'selectedAuthor': snapshot.selectedAuthor,
        'entries': snapshot.recommendations
            .map((entry) => entry.toJson())
            .toList(),
      }),
    );
  }

  _DiscoverDailyRecommendationSnapshot? _readCache(SharedPreferences prefs) {
    final activeSourceKey = _source.activeSourceKey;
    final hasActiveSourceKey = activeSourceKey.trim().isNotEmpty;
    final candidates = <String>[
      if (hasActiveSourceKey) _sourceCachePayloadKey(activeSourceKey),
      _cachePayloadKey,
      if (!hasActiveSourceKey)
        ...prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('${_cachePayloadKey}_') &&
                  key != _cachePayloadKey,
            )
            .toList()
          ..sort(),
    ];

    _DiscoverDailyRecommendationSnapshot? newestFallback;
    for (final key in candidates) {
      final snapshot = _parseCachePayload(
        prefs.getString(key),
        activeSourceKey: activeSourceKey,
      );
      if (snapshot == null) {
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

  _DiscoverDailyRecommendationSnapshot? _parseCachePayload(
    String? raw, {
    required String activeSourceKey,
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
      final sourceKey = (map['sourceKey'] ?? activeSourceKey).toString().trim();
      final generatedAt = DateTime.tryParse(
        (map['generatedAt'] ?? '').toString(),
      )?.toLocal();
      final selectedAuthor = (map['selectedAuthor'] ?? '').toString().trim();
      final entriesRaw = map['entries'];
      final entries = entriesRaw is List
          ? entriesRaw
                .map(DiscoverDailyRecommendationEntry.fromJson)
                .whereType<DiscoverDailyRecommendationEntry>()
                .toList(growable: false)
          : const <DiscoverDailyRecommendationEntry>[];
      if (generatedAt == null ||
          selectedAuthor.isEmpty ||
          entries.length != recommendationCount) {
        return null;
      }
      return _DiscoverDailyRecommendationSnapshot(
        recommendations: entries,
        selectedAuthor: selectedAuthor,
        generatedAt: generatedAt,
        sourceKey: sourceKey,
        schemaVersion: version,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isDisplayedFresh(DiscoverDailyRecommendationState state) {
    final generatedAt = state.generatedAt;
    if (generatedAt == null) {
      return false;
    }
    return DateTime.now().difference(generatedAt) <= _cacheTtl;
  }

  bool _isCacheFresh(_DiscoverDailyRecommendationSnapshot snapshot) {
    return snapshot.schemaVersion == _cacheSchemaVersion &&
        DateTime.now().difference(snapshot.generatedAt) <= _cacheTtl;
  }

  Future<_DiscoverDailyRecommendationSnapshot?>
  _generateRecommendations() async {
    if (!_supportsActiveSource) {
      return null;
    }
    final authors = await _loadAuthors();
    if (authors.isEmpty) {
      return null;
    }

    final author = authors[_random.nextInt(authors.length)];
    final result = await _source.searchComics(
      keyword: author,
      page: 1,
      order: 'mr',
    );
    if (!_supportsActiveSource) {
      return null;
    }
    final sampledComics = _sampleUniqueComics(
      result.comics,
      count: recommendationCount,
    );
    if (sampledComics.length != recommendationCount) {
      return null;
    }
    final recommendations = await _buildRecommendationEntries(
      sampledComics,
      fallbackAuthor: author,
    );
    if (recommendations.length != recommendationCount) {
      return null;
    }

    return _DiscoverDailyRecommendationSnapshot(
      recommendations: recommendations,
      selectedAuthor: author,
      generatedAt: DateTime.now(),
      sourceKey: _source.activeSourceKey,
      schemaVersion: _cacheSchemaVersion,
    );
  }

  void _handleSourceChanged() {
    if (!_supportsActiveSource) {
      _setState(const DiscoverDailyRecommendationState.disabled());
      return;
    }
    unawaited(_restoreForActiveSource());
  }

  Future<void> _restoreForActiveSource() async {
    final enabled = await loadEnabled();
    await ensurePrepared(enabled: enabled);
  }

  @override
  void dispose() {
    _source.removeListener(_handleSourceChanged);
    super.dispose();
  }

  String _sourceCachePayloadKey(String sourceKey) {
    final normalized = sourceKey.trim();
    if (normalized.isEmpty) {
      return _cachePayloadKey;
    }
    return '${_cachePayloadKey}_$normalized';
  }

  Future<List<String>> _loadAuthors() async {
    final raw = await rootBundle.loadString(authorsAssetPath);
    final lines = const LineSplitter().convert(raw);
    final authors = <String>[];
    for (final line in lines) {
      final normalized = line
          .replaceFirst(RegExp(r'^\s*\d+\s*[.\s、]*'), '')
          .trim();
      if (normalized.isEmpty) {
        continue;
      }
      authors.add(normalized);
    }
    return authors;
  }

  Future<List<DiscoverDailyRecommendationEntry>> _buildRecommendationEntries(
    List<ExploreComic> comics, {
    required String fallbackAuthor,
  }) async {
    final entries = <DiscoverDailyRecommendationEntry>[];
    for (final comic in comics) {
      final author = await _loadComicAuthor(comic);
      final resolvedAuthor = author.isEmpty ? fallbackAuthor : author;
      if (resolvedAuthor.isEmpty) {
        continue;
      }
      entries.add(
        DiscoverDailyRecommendationEntry(author: resolvedAuthor, comic: comic),
      );
      if (entries.length == recommendationCount) {
        break;
      }
    }
    return entries;
  }

  Future<String> _loadComicAuthor(ExploreComic comic) async {
    try {
      final details = await _source.loadComicDetails(
        comic.id,
        sourceKey: comic.sourceKey,
      );
      return extractDiscoverRecommendationAuthor(details);
    } catch (_) {
      return '';
    }
  }

  List<ExploreComic> _sampleUniqueComics(
    List<ExploreComic> comics, {
    required int count,
  }) {
    final deduped = <String, ExploreComic>{};
    for (final comic in comics) {
      final id = comic.id.trim();
      final title = comic.title.trim();
      final key = SourceScopedComicId(
        sourceKey: comic.sourceKey,
        comicId: id.isNotEmpty ? id : title,
      ).storageKey;
      if (key.isEmpty || deduped.containsKey(key)) {
        continue;
      }
      deduped[key] = comic;
    }
    final candidates = deduped.values.toList(growable: true)..shuffle(_random);
    if (candidates.length < count) {
      return const <ExploreComic>[];
    }
    return candidates.take(count).toList(growable: false);
  }
}

class _DiscoverDailyRecommendationSnapshot {
  const _DiscoverDailyRecommendationSnapshot({
    required this.recommendations,
    required this.selectedAuthor,
    required this.generatedAt,
    required this.sourceKey,
    required this.schemaVersion,
  });

  final List<DiscoverDailyRecommendationEntry> recommendations;
  final String selectedAuthor;
  final DateTime generatedAt;
  final String sourceKey;
  final int schemaVersion;
}
