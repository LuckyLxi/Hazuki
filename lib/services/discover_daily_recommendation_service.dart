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

class DiscoverDailyRecommendationService extends ChangeNotifier {
  DiscoverDailyRecommendationService._();

  static final DiscoverDailyRecommendationService instance =
      DiscoverDailyRecommendationService._();

  static const String authorsAssetPath = 'assets/data/authors.txt';
  static const String _cachePayloadKey = 'discover_daily_recommendation_cache';
  static const Duration _cacheTtl = Duration(hours: 1);
  static const int recommendationCount = 7;

  final math.Random _random = math.Random();

  DiscoverDailyRecommendationState _state =
      const DiscoverDailyRecommendationState.disabled();
  Future<void>? _refreshInFlight;

  DiscoverDailyRecommendationState get state => _state;

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
    if (!enabled) {
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

    if (!HazukiSourceService.instance.isInitialized) {
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
        !HazukiSourceService.instance.isInitialized) {
      return;
    }

    final completer = Completer<void>();
    _refreshInFlight = completer.future;
    _setState(_state.copyWith(isRefreshing: true));

    try {
      final generated = await _generateRecommendations();
      if (generated == null || !_state.enabled) {
        return;
      }

      final preloaded = await _preloadRecommendationImages(
        generated.recommendations,
      );
      if (!preloaded || !_state.enabled) {
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
          final bytes = await HazukiSourceService.instance.downloadImageBytes(
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
      _cachePayloadKey,
      jsonEncode(<String, dynamic>{
        'generatedAt': snapshot.generatedAt.toIso8601String(),
        'selectedAuthor': snapshot.selectedAuthor,
        'entries': snapshot.recommendations
            .map((entry) => entry.toJson())
            .toList(),
      }),
    );
  }

  _DiscoverDailyRecommendationSnapshot? _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_cachePayloadKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
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
    return DateTime.now().difference(snapshot.generatedAt) <= _cacheTtl;
  }

  Future<_DiscoverDailyRecommendationSnapshot?>
  _generateRecommendations() async {
    final authors = await _loadAuthors();
    if (authors.isEmpty) {
      return null;
    }

    final author = authors[_random.nextInt(authors.length)];
    final result = await HazukiSourceService.instance.searchComics(
      keyword: author,
      page: 1,
      order: 'mr',
    );
    final sampledComics = _sampleUniqueComics(
      result.comics,
      count: recommendationCount,
    );
    if (sampledComics.length != recommendationCount) {
      return null;
    }

    return _DiscoverDailyRecommendationSnapshot(
      recommendations: sampledComics
          .map(
            (comic) =>
                DiscoverDailyRecommendationEntry(author: author, comic: comic),
          )
          .toList(growable: false),
      selectedAuthor: author,
      generatedAt: DateTime.now(),
    );
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

  List<ExploreComic> _sampleUniqueComics(
    List<ExploreComic> comics, {
    required int count,
  }) {
    final deduped = <String, ExploreComic>{};
    for (final comic in comics) {
      final id = comic.id.trim();
      final title = comic.title.trim();
      final key = id.isNotEmpty ? id : title;
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
  });

  final List<DiscoverDailyRecommendationEntry> recommendations;
  final String selectedAuthor;
  final DateTime generatedAt;
}
