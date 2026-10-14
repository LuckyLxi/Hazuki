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

List<DiscoverDailyRecommendationEntry> _entries({String sourceKey = 'jm'}) =>
    List.generate(
      7,
      (index) => DiscoverDailyRecommendationEntry(
        author: 'author',
        comic: ExploreComic(
          id: '$index',
          sourceKey: sourceKey,
          title: '$index',
          subTitle: '',
          cover: 'cover$index',
        ),
      ),
    );

void main() {
  registerFallbackValue(() {});
  late _Source source;
  setUp(() {
    source = _Source();
    when(() => source.activeSourceKey).thenReturn('jm');
    when(
      () => source.dailyRecommendationForSource('jm'),
    ).thenReturn(const DailyRecommendationConfig(searchOrder: 'mr'));
    when(() => source.supportsDailyRecommendation).thenReturn(true);
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
      when(() => source.supportsDailyRecommendation).thenReturn(false);
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

  test(
    'recommendations use their own capability and plugin search order',
    () async {
      when(() => source.activeSourceKey).thenReturn('arbitrary');
      when(() => source.supportsDirectComicId).thenReturn(false);
      when(
        () => source.dailyRecommendationForSource('arbitrary'),
      ).thenReturn(const DailyRecommendationConfig(searchOrder: 'popular'));
      when(
        () => source.searchComics(
          keyword: 'author',
          page: 1,
          order: 'popular',
          sourceKey: 'arbitrary',
        ),
      ).thenAnswer(
        (_) async => SearchComicsResult(
          comics: _entries(sourceKey: 'arbitrary').map((e) => e.comic).toList(),
          maxPage: 1,
        ),
      );
      when(
        () => source.loadComicDetails(any(), sourceKey: 'arbitrary'),
      ).thenThrow(StateError('use author fallback'));
      final generator = SourceDiscoverDailyRecommendationCandidateGenerator(
        source: source,
        random: Random(1),
        loadAuthors: () async => ['author'],
      );
      final snapshot = await generator.generate(previous: const []);
      expect(snapshot!.sourceKey, 'arbitrary');
      expect(snapshot.recommendations, hasLength(7));
      verify(
        () => source.searchComics(
          keyword: 'author',
          page: 1,
          order: 'popular',
          sourceKey: 'arbitrary',
        ),
      ).called(1);
    },
  );

  test(
    'ID matching capability cannot enable recommendations without config',
    () async {
      when(() => source.supportsDirectComicId).thenReturn(true);
      when(() => source.supportsDailyRecommendation).thenReturn(false);
      when(() => source.dailyRecommendationForSource('jm')).thenReturn(null);
      var loadedAuthors = false;
      final generator = SourceDiscoverDailyRecommendationCandidateGenerator(
        source: source,
        random: Random(1),
        loadAuthors: () async {
          loadedAuthors = true;
          return ['author'];
        },
      );
      expect(await generator.generate(previous: const []), isNull);
      expect(loadedAuthors, isFalse);
      final cache = _Cache();
      final service = DiscoverDailyRecommendationService(
        source: source,
        cacheStore: cache,
      );
      addTearDown(service.dispose);
      final state = await service.ensurePrepared(enabled: true);
      expect(state.enabled, isFalse);
      verifyNever(() => cache.readSnapshot(activeSourceKey: 'jm'));
    },
  );

  test(
    'switching to an unsupported source discards an in-flight cache read',
    () async {
      late void Function() onSourceChanged;
      when(() => source.addListener(any())).thenAnswer((invocation) {
        onSourceChanged =
            invocation.positionalArguments.first as void Function();
      });
      final cache = _Cache();
      final pending = Completer<DiscoverDailyRecommendationSnapshot?>();
      when(
        () => cache.readSnapshot(activeSourceKey: 'jm'),
      ).thenAnswer((_) => pending.future);
      final service = DiscoverDailyRecommendationService(
        source: source,
        cacheStore: cache,
      );
      addTearDown(service.dispose);
      final prepared = service.ensurePrepared(enabled: true);
      when(() => source.activeSourceKey).thenReturn('old_plugin');
      when(() => source.supportsDailyRecommendation).thenReturn(false);
      onSourceChanged();
      pending.complete(
        DiscoverDailyRecommendationSnapshot(
          recommendations: _entries(),
          selectedAuthor: 'author',
          generatedAt: DateTime.now(),
          sourceKey: 'jm',
          schemaVersion: 2,
        ),
      );
      await prepared;
      expect(service.state.enabled, isFalse);
      expect(service.state.displayedRecommendations, isEmpty);
    },
  );

  test(
    'switching between supported sources restores only the new cache',
    () async {
      late void Function() onSourceChanged;
      when(() => source.addListener(any())).thenAnswer((invocation) {
        onSourceChanged =
            invocation.positionalArguments.first as void Function();
      });
      final cache = _Cache();
      final oldCache = Completer<DiscoverDailyRecommendationSnapshot?>();
      when(() => cache.loadEnabled()).thenAnswer((_) async => true);
      when(
        () => cache.readSnapshot(activeSourceKey: 'jm'),
      ).thenAnswer((_) => oldCache.future);
      when(
        () => source.dailyRecommendationForSource('books'),
      ).thenReturn(const DailyRecommendationConfig(searchOrder: 'recent'));
      when(() => cache.readSnapshot(activeSourceKey: 'books')).thenAnswer(
        (_) async => DiscoverDailyRecommendationSnapshot(
          recommendations: _entries(sourceKey: 'books'),
          selectedAuthor: 'author',
          generatedAt: DateTime.now(),
          sourceKey: 'books',
          schemaVersion: 2,
        ),
      );
      final service = DiscoverDailyRecommendationService(
        source: source,
        cacheStore: cache,
      );
      addTearDown(service.dispose);
      final prepared = service.ensurePrepared(enabled: true);
      when(() => source.activeSourceKey).thenReturn('books');
      onSourceChanged();
      await Future<void>.delayed(Duration.zero);
      expect(
        service.state.displayedRecommendations.map((e) => e.comic.sourceKey),
        everyElement('books'),
      );
      oldCache.complete(
        DiscoverDailyRecommendationSnapshot(
          recommendations: _entries(),
          selectedAuthor: 'author',
          generatedAt: DateTime.now(),
          sourceKey: 'jm',
          schemaVersion: 2,
        ),
      );
      await prepared;
      expect(service.state.displayedRecommendations, hasLength(7));
      expect(
        service.state.displayedRecommendations.map((e) => e.comic.sourceKey),
        everyElement('books'),
      );
    },
  );

  test(
    'disabling during generation prevents stale results from being saved',
    () async {
      final cache = _Cache();
      final generator = _Generator();
      final pending = Completer<DiscoverDailyRecommendationSnapshot?>();
      when(
        () => cache.readSnapshot(activeSourceKey: 'jm'),
      ).thenAnswer((_) async => null);
      when(() => cache.setEnabled(false)).thenAnswer((_) async {});
      when(
        () => generator.generate(previous: any(named: 'previous')),
      ).thenAnswer((_) => pending.future);
      final service = DiscoverDailyRecommendationService(
        source: source,
        cacheStore: cache,
        candidateGenerator: generator,
      );
      addTearDown(service.dispose);
      final prepared = service.ensurePrepared(enabled: true);
      await Future<void>.delayed(Duration.zero);
      await service.setEnabled(false);
      final snapshot = DiscoverDailyRecommendationSnapshot(
        recommendations: _entries(),
        selectedAuthor: 'author',
        generatedAt: DateTime.now(),
        sourceKey: 'jm',
        schemaVersion: 2,
      );
      pending.complete(snapshot);
      await prepared;
      expect(service.state.enabled, isFalse);
      verifyNever(() => cache.persistSnapshot(snapshot));
    },
  );

  for (final mismatch in ['snapshot', 'entry']) {
    test('service rejects a cache with a foreign $mismatch source', () async {
      when(() => source.isInitialized).thenReturn(false);
      final cache = _Cache();
      when(() => cache.readSnapshot(activeSourceKey: 'jm')).thenAnswer(
        (_) async => DiscoverDailyRecommendationSnapshot(
          recommendations: _entries(
            sourceKey: mismatch == 'entry' ? 'books' : 'jm',
          ),
          selectedAuthor: 'author',
          generatedAt: DateTime.now(),
          sourceKey: mismatch == 'snapshot' ? 'books' : 'jm',
          schemaVersion: 2,
        ),
      );
      final service = DiscoverDailyRecommendationService(
        source: source,
        cacheStore: cache,
      );
      addTearDown(service.dispose);

      final state = await service.ensurePrepared(enabled: true);
      expect(state.enabled, isTrue);
      expect(state.displayedRecommendations, isEmpty);
    });
  }
}
