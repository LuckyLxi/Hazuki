import 'dart:math' as math;
import '../source/source_capabilities.dart';
import '../../models/hazuki_models.dart';
import 'discover_recommendation_models.dart';
import 'discover_recommendation_config.dart';
import 'discover_recommendation_policy.dart';
import 'discover_recommendation_authors.dart';

abstract interface class DiscoverDailyRecommendationCandidateGenerator {
  Future<DiscoverDailyRecommendationSnapshot?> generate({
    required List<DiscoverDailyRecommendationEntry> previous,
  });
}

class SourceDiscoverDailyRecommendationCandidateGenerator
    implements DiscoverDailyRecommendationCandidateGenerator {
  SourceDiscoverDailyRecommendationCandidateGenerator({
    required SourceDailyRecommendationGateway source,
    required math.Random random,
    this.authorsAssetPath = DiscoverDailyRecommendationConfig.authorsAssetPath,
    Future<List<String>> Function()? loadAuthors,
    DateTime Function()? now,
  }) : _source = source,
       _random = random,
       _now = now ?? DateTime.now,
       _loadAuthors =
           loadAuthors ??
           AssetDiscoverRecommendationAuthors(assetPath: authorsAssetPath).load;

  final SourceDailyRecommendationGateway _source;
  final math.Random _random;
  final String authorsAssetPath;
  final Future<List<String>> Function() _loadAuthors;
  final DateTime Function() _now;

  bool get _supportsActiveSource => _source.isActiveJmSource;

  @override
  Future<DiscoverDailyRecommendationSnapshot?> generate({
    required List<DiscoverDailyRecommendationEntry> previous,
  }) async {
    if (!_supportsActiveSource) {
      return null;
    }
    final sourceKey = _source.activeSourceKey.trim();
    bool hasSameActiveSource() {
      return _supportsActiveSource &&
          _source.activeSourceKey.trim() == sourceKey;
    }

    final authors = await _loadAuthors();
    if (authors.isEmpty || !hasSameActiveSource()) {
      return null;
    }

    final shuffledAuthors = authors.toSet().toList(growable: true)
      ..shuffle(_random);
    var recommendations = previous;
    final contributingAuthors = <String>[];
    var authorSearchAttempts = 0;
    var consecutiveSearchFailures = 0;

    for (final author in shuffledAuthors) {
      if (!hasSameActiveSource()) {
        return null;
      }
      if (authorSearchAttempts >=
          DiscoverDailyRecommendationConfig.maxAuthorSearchAttempts) {
        break;
      }
      authorSearchAttempts++;

      SearchComicsResult result;
      try {
        result = await _source.searchComics(
          keyword: author,
          page: 1,
          order: 'mr',
          sourceKey: sourceKey,
        );
      } catch (_) {
        if (!hasSameActiveSource()) {
          return null;
        }
        consecutiveSearchFailures++;
        if (consecutiveSearchFailures >=
            DiscoverDailyRecommendationConfig.maxConsecutiveSearchFailures) {
          break;
        }
        continue;
      }
      consecutiveSearchFailures = 0;
      if (!hasSameActiveSource()) {
        return null;
      }

      final candidates = uniqueShuffledDiscoverRecommendationComics(
        result.comics,
        random: _random,
      );
      if (candidates.isEmpty) {
        continue;
      }

      final replacesWholeGroup =
          candidates.length >=
              DiscoverDailyRecommendationConfig.recommendationCount &&
          (recommendations.isEmpty || previous.isNotEmpty);
      final existingKeys = recommendations
          .map((entry) => discoverRecommendationComicKey(entry.comic))
          .toSet();
      final eligibleCandidates = replacesWholeGroup
          ? candidates
          : candidates
                .where(
                  (comic) => !existingKeys.contains(
                    discoverRecommendationComicKey(comic),
                  ),
                )
                .toList(growable: false);
      if (eligibleCandidates.isEmpty) {
        continue;
      }
      final needed = replacesWholeGroup
          ? DiscoverDailyRecommendationConfig.recommendationCount
          : previous.isEmpty
          ? DiscoverDailyRecommendationConfig.recommendationCount -
                recommendations.length
          : eligibleCandidates.length;
      final sampledComics = eligibleCandidates
          .take(needed)
          .toList(growable: false);
      final incoming = await _buildRecommendationEntries(
        sampledComics,
        fallbackAuthor: author,
      );
      if (!hasSameActiveSource()) {
        return null;
      }
      if (incoming.isEmpty) {
        continue;
      }

      recommendations = mergeDiscoverRecommendationEntries(
        previous: recommendations,
        incoming: incoming,
        count: DiscoverDailyRecommendationConfig.recommendationCount,
        random: _random,
      );
      contributingAuthors.add(author);
      if (recommendations.length ==
          DiscoverDailyRecommendationConfig.recommendationCount) {
        break;
      }
    }

    if (!hasSameActiveSource() ||
        recommendations.length !=
            DiscoverDailyRecommendationConfig.recommendationCount ||
        contributingAuthors.isEmpty) {
      return null;
    }

    return DiscoverDailyRecommendationSnapshot(
      recommendations: recommendations,
      selectedAuthor: contributingAuthors.join(' / '),
      generatedAt: _now(),
      sourceKey: sourceKey,
      schemaVersion: DiscoverDailyRecommendationConfig.cacheSchemaVersion,
    );
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
      if (entries.length ==
          DiscoverDailyRecommendationConfig.recommendationCount) {
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
}
