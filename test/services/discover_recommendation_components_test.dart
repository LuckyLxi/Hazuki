import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceDailyRecommendationGateway {}

class _Cache extends Mock implements DiscoverDailyRecommendationCacheStore {}

class _Generator extends Mock
    implements DiscoverDailyRecommendationCandidateGenerator {}

List<DiscoverDailyRecommendationEntry> _entries() => List.generate(
  7,
  (index) => DiscoverDailyRecommendationEntry(
    author: 'author',
    comic: ExploreComic(
      id: '$index',
      sourceKey: 'jm',
      title: '$index',
      subTitle: '',
      cover: 'cover$index',
    ),
  ),
);

void main() {
  late _Source source;
  setUp(() {
    source = _Source();
    when(() => source.activeSourceKey).thenReturn('jm');
    when(() => source.isActiveJmSource).thenReturn(true);
    when(() => source.isInitialized).thenReturn(true);
  });

  test(
    'generator uses injected authors and timestamp without an asset bundle',
    () async {
      final now = DateTime.utc(2026, 9, 9);
      when(
        () => source.searchComics(
          keyword: 'author',
          page: 1,
          order: 'mr',
          sourceKey: 'jm',
        ),
      ).thenAnswer(
        (_) async => SearchComicsResult(
          comics: _entries().map((e) => e.comic).toList(),
          maxPage: 1,
        ),
      );
      when(
        () => source.loadComicDetails(any(), sourceKey: 'jm'),
      ).thenThrow(StateError('use author fallback'));
      final generator = SourceDiscoverDailyRecommendationCandidateGenerator(
        source: source,
        random: Random(1),
        loadAuthors: () async => ['author'],
        now: () => now,
      );
      final snapshot = await generator.generate(previous: const []);
      expect(snapshot!.recommendations, hasLength(7));
      expect(snapshot.generatedAt, now);
      expect(snapshot.sourceKey, 'jm');
      expect(
        snapshot.recommendations.map((e) => e.author),
        everyElement('author'),
      );
    },
  );

  test(
    'source switch while reading authors prevents candidate searches',
    () async {
      final authors = Completer<List<String>>();
      final generator = SourceDiscoverDailyRecommendationCandidateGenerator(
        source: source,
        random: Random(1),
        loadAuthors: () => authors.future,
      );
      final result = generator.generate(previous: const []);
      when(() => source.activeSourceKey).thenReturn('picacg');
      when(() => source.isActiveJmSource).thenReturn(false);
      authors.complete(['author']);
      expect(await result, isNull);
      verifyNever(
        () => source.searchComics(
          keyword: any(named: 'keyword'),
          page: 1,
          order: 'mr',
          sourceKey: 'jm',
        ),
      );
    },
  );

  test('cache freshness uses the injected clock at the TTL boundary', () async {
    final generatedAt = DateTime.utc(2026, 1, 1);
    var now = generatedAt.add(const Duration(minutes: 15));
    final cache = _Cache();
    final generator = _Generator();
    final pending = Completer<DiscoverDailyRecommendationSnapshot?>();
    when(() => cache.readSnapshot(activeSourceKey: 'jm')).thenAnswer(
      (_) async => DiscoverDailyRecommendationSnapshot(
        recommendations: _entries(),
        selectedAuthor: 'author',
        generatedAt: generatedAt,
        sourceKey: 'jm',
        schemaVersion: 2,
      ),
    );
    when(
      () => generator.generate(previous: any(named: 'previous')),
    ).thenAnswer((_) => pending.future);
    final service = DiscoverDailyRecommendationService(
      source: source,
      cacheStore: cache,
      candidateGenerator: generator,
      now: () => now,
    );
    await service.ensurePrepared(enabled: true);
    verifyNever(() => generator.generate(previous: any(named: 'previous')));
    now = now.add(const Duration(milliseconds: 1));
    await service.ensurePrepared(enabled: true);
    verify(
      () => generator.generate(previous: any(named: 'previous')),
    ).called(1);
    expect(service.state.isRefreshing, isTrue);
    pending.complete(null);
    await Future<void>.delayed(Duration.zero);
    expect(service.state.isRefreshing, isFalse);
    service.dispose();
  });
}
