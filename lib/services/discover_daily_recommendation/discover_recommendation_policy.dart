import 'dart:math' as math;
import '../../models/hazuki_models.dart';
import 'discover_recommendation_models.dart';

String extractDiscoverRecommendationAuthor(ComicDetailsData details) {
  final authors = normalizeDiscoverRecommendationMetaValues(
    details.tags.keys
        .where(_isDiscoverRecommendationAuthorKey)
        .expand((key) => details.tags[key] ?? const <String>[])
        .toList(),
  );
  return authors.join(' / ').trim();
}

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

List<DiscoverDailyRecommendationEntry> mergeDiscoverRecommendationEntries({
  required List<DiscoverDailyRecommendationEntry> previous,
  required List<DiscoverDailyRecommendationEntry> incoming,
  required int count,
  math.Random? random,
}) {
  if (count <= 0) {
    return const <DiscoverDailyRecommendationEntry>[];
  }

  final resolvedRandom = random ?? math.Random();
  final uniqueIncoming = _dedupeRecommendationEntries(incoming);
  if (uniqueIncoming.length >= count) {
    uniqueIncoming.shuffle(resolvedRandom);
    return uniqueIncoming.take(count).toList(growable: false);
  }

  final uniquePrevious = _dedupeRecommendationEntries(previous);
  final previousKeys = uniquePrevious
      .map((entry) => discoverRecommendationComicKey(entry.comic))
      .toSet();
  final newEntries = uniqueIncoming
      .where(
        (entry) =>
            !previousKeys.contains(discoverRecommendationComicKey(entry.comic)),
      )
      .toList(growable: true);

  if (uniquePrevious.length < count) {
    final availableSlots = count - uniquePrevious.length;
    newEntries.shuffle(resolvedRandom);
    final combined = <DiscoverDailyRecommendationEntry>[
      ...uniquePrevious,
      ...newEntries.take(availableSlots),
    ]..shuffle(resolvedRandom);
    return combined;
  }

  newEntries.shuffle(resolvedRandom);
  final replacements = newEntries.take(count).toList(growable: false);
  uniquePrevious.shuffle(resolvedRandom);
  final retainedCount = count - replacements.length;
  final combined = <DiscoverDailyRecommendationEntry>[
    ...uniquePrevious.take(retainedCount),
    ...replacements,
  ]..shuffle(resolvedRandom);
  return combined;
}

List<DiscoverDailyRecommendationEntry> _dedupeRecommendationEntries(
  List<DiscoverDailyRecommendationEntry> entries,
) {
  final deduped = <String, DiscoverDailyRecommendationEntry>{};
  for (final entry in entries) {
    final key = discoverRecommendationComicKey(entry.comic);
    if (key.isNotEmpty) {
      deduped.putIfAbsent(key, () => entry);
    }
  }
  return deduped.values.toList(growable: true);
}

String discoverRecommendationComicKey(ExploreComic comic) {
  final id = comic.id.trim();
  final title = comic.title.trim();
  return SourceScopedComicId(
    sourceKey: comic.sourceKey,
    comicId: id.isNotEmpty ? id : title,
  ).storageKey;
}

List<ExploreComic> uniqueShuffledDiscoverRecommendationComics(
  List<ExploreComic> comics, {
  math.Random? random,
}) {
  final deduped = <String, ExploreComic>{};
  for (final comic in comics) {
    final key = discoverRecommendationComicKey(comic);
    if (key.isEmpty || deduped.containsKey(key)) {
      continue;
    }
    deduped[key] = comic;
  }
  return deduped.values.toList(growable: true)
    ..shuffle(random ?? math.Random());
}
