import 'package:flutter/foundation.dart';
import '../../models/hazuki_models.dart';

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

@immutable
class DiscoverDailyRecommendationSnapshot {
  const DiscoverDailyRecommendationSnapshot({
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
