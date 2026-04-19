import 'dart:convert';
import 'dart:math' as math;

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
    required this.recommendations,
    this.selectedAuthor,
    this.generatedAt,
  });

  const DiscoverDailyRecommendationState.disabled()
    : this(
        enabled: false,
        recommendations: const <DiscoverDailyRecommendationEntry>[],
      );

  final bool enabled;
  final List<DiscoverDailyRecommendationEntry> recommendations;
  final String? selectedAuthor;
  final DateTime? generatedAt;

  bool get hasRecommendations => enabled && recommendations.isNotEmpty;
}

class DiscoverDailyRecommendationService {
  DiscoverDailyRecommendationService._();

  static final DiscoverDailyRecommendationService instance =
      DiscoverDailyRecommendationService._();

  static const String authorsAssetPath = 'assets/data/authors.txt';
  static const String _cachePayloadKey = 'discover_daily_recommendation_cache';
  static const Duration _cacheTtl = Duration(hours: 2);
  static const int recommendationCount = 7;

  final math.Random _random = math.Random();

  DiscoverDailyRecommendationState _state =
      const DiscoverDailyRecommendationState.disabled();
  bool _sessionResolved = false;

  DiscoverDailyRecommendationState get state => _state;

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      hazukiDiscoverDailyRecommendationEnabledPreferenceKey,
      enabled,
    );
    _state = DiscoverDailyRecommendationState(
      enabled: enabled,
      recommendations: _state.recommendations,
      selectedAuthor: _state.selectedAuthor,
      generatedAt: _state.generatedAt,
    );
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
      _state = DiscoverDailyRecommendationState(
        enabled: false,
        recommendations: _state.recommendations,
        selectedAuthor: _state.selectedAuthor,
        generatedAt: _state.generatedAt,
      );
      return _state;
    }

    if (_sessionResolved) {
      _state = DiscoverDailyRecommendationState(
        enabled: true,
        recommendations: _state.recommendations,
        selectedAuthor: _state.selectedAuthor,
        generatedAt: _state.generatedAt,
      );
      return _state;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs);
    if (cached != null && _isCacheFresh(cached)) {
      _sessionResolved = true;
      _state = DiscoverDailyRecommendationState(
        enabled: true,
        recommendations: cached.recommendations,
        selectedAuthor: cached.selectedAuthor,
        generatedAt: cached.generatedAt,
      );
      return _state;
    }

    if (!HazukiSourceService.instance.isInitialized) {
      _state = const DiscoverDailyRecommendationState(
        enabled: true,
        recommendations: <DiscoverDailyRecommendationEntry>[],
      );
      return _state;
    }

    _sessionResolved = true;
    final generated = await _generateRecommendations();
    if (generated == null) {
      _state = const DiscoverDailyRecommendationState(
        enabled: true,
        recommendations: <DiscoverDailyRecommendationEntry>[],
      );
      return _state;
    }

    _state = generated;
    await prefs.setString(
      _cachePayloadKey,
      jsonEncode(<String, dynamic>{
        'generatedAt': generated.generatedAt?.toIso8601String(),
        'selectedAuthor': generated.selectedAuthor,
        'entries': generated.recommendations
            .map((entry) => entry.toJson())
            .toList(),
      }),
    );
    return _state;
  }

  DiscoverDailyRecommendationState? _readCache(SharedPreferences prefs) {
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
      return DiscoverDailyRecommendationState(
        enabled: true,
        recommendations: entries,
        selectedAuthor: selectedAuthor,
        generatedAt: generatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isCacheFresh(DiscoverDailyRecommendationState state) {
    final generatedAt = state.generatedAt;
    if (generatedAt == null) {
      return false;
    }
    return DateTime.now().difference(generatedAt) <= _cacheTtl;
  }

  Future<DiscoverDailyRecommendationState?> _generateRecommendations() async {
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

    return DiscoverDailyRecommendationState(
      enabled: true,
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
          .replaceFirst(RegExp(r'^\s*\d+\s*[\.、]\s*'), '')
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
