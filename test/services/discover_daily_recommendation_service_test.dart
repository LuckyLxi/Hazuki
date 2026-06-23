import 'dart:convert';
import 'dart:math' as math;
import 'package:hazuki/app/service_locator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await ensureTestServiceLocator();
  });
  group('Discover daily recommendation author metadata', () {
    test('extracts author values from comic detail tags', () {
      const details = ComicDetailsData(
        id: '100',
        title: 'Comic',
        subTitle: '',
        cover: '',
        description: '',
        updateTime: '',
        likesCount: '',
        chapters: <String, String>{'1': 'Chapter 1'},
        tags: <String, List<String>>{
          '\u4f5c\u8005': <String>['\u4f5c\u8005\uFF1AAlice / Bob'],
          'tags': <String>['Tag'],
        },
        recommend: <ExploreComic>[],
        isFavorite: false,
        subId: '',
      );

      expect(extractDiscoverRecommendationAuthor(details), 'Alice / Bob');
    });

    test('deduplicates comma separated author values', () {
      const details = ComicDetailsData(
        id: '101',
        title: 'Comic',
        subTitle: '',
        cover: '',
        description: '',
        updateTime: '',
        likesCount: '',
        chapters: <String, String>{'1': 'Chapter 1'},
        tags: <String, List<String>>{
          'authors': <String>['Alice, Bob', 'Alice'],
        },
        recommend: <ExploreComic>[],
        isFavorite: false,
        subId: '',
      );

      expect(extractDiscoverRecommendationAuthor(details), 'Alice / Bob');
    });
  });

  group('Discover daily recommendation merging', () {
    test(
      'replaces the same number of entries in a complete previous group',
      () {
        final previous = _recommendationEntries('Old', 7);
        final incoming = _recommendationEntries('New', 3, idOffset: 100);

        final merged = mergeDiscoverRecommendationEntries(
          previous: previous,
          incoming: incoming,
          count: 7,
          random: math.Random(1),
        );

        expect(merged, hasLength(7));
        expect(merged.where((entry) => entry.author == 'New'), hasLength(3));
        expect(merged.where((entry) => entry.author == 'Old'), hasLength(4));
      },
    );

    test(
      'accumulates partial groups until seven unique comics are available',
      () {
        final first = mergeDiscoverRecommendationEntries(
          previous: const <DiscoverDailyRecommendationEntry>[],
          incoming: _recommendationEntries('First', 3),
          count: 7,
          random: math.Random(1),
        );
        final completed = mergeDiscoverRecommendationEntries(
          previous: first,
          incoming: _recommendationEntries('Second', 4, idOffset: 100),
          count: 7,
          random: math.Random(2),
        );

        expect(first, hasLength(3));
        expect(completed, hasLength(7));
        expect(
          completed.where((entry) => entry.author == 'First'),
          hasLength(3),
        );
        expect(
          completed.where((entry) => entry.author == 'Second'),
          hasLength(4),
        );
      },
    );

    test('does not replace an old entry with the same comic', () {
      final previous = _recommendationEntries('Old', 7);
      final incoming = <DiscoverDailyRecommendationEntry>[
        previous.first,
        ..._recommendationEntries('New', 2, idOffset: 100),
      ];

      final merged = mergeDiscoverRecommendationEntries(
        previous: previous,
        incoming: incoming,
        count: 7,
        random: math.Random(1),
      );

      expect(merged, hasLength(7));
      expect(merged.where((entry) => entry.author == 'New'), hasLength(2));
      expect(merged.map((entry) => entry.comic.id).toSet(), hasLength(7));
    });
  });

  group('Discover daily recommendation search limits', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test('stops after three consecutive search failures', () async {
      final source = _SearchCountingSource(throwOnSearch: true);
      final service = DiscoverDailyRecommendationService(
        source: HazukiSourceDailyRecommendationAdapter(source),
      );
      addTearDown(source.dispose);
      addTearDown(service.dispose);

      final state = await service.ensurePrepared(enabled: true);

      expect(source.searchCalls, 3);
      expect(state.hasRecommendations, isFalse);
    });

    test('limits attempts when searches return no comics', () async {
      final source = _SearchCountingSource();
      final service = DiscoverDailyRecommendationService(
        source: HazukiSourceDailyRecommendationAdapter(source),
      );
      addTearDown(source.dispose);
      addTearDown(service.dispose);

      final state = await service.ensurePrepared(enabled: true);

      expect(source.searchCalls, 20);
      expect(state.hasRecommendations, isFalse);
    });

    test('stops retrying when the active source changes', () async {
      final source = _SearchCountingSource(switchSourceOnFirstSearch: true);
      final service = DiscoverDailyRecommendationService(
        source: HazukiSourceDailyRecommendationAdapter(source),
      );
      addTearDown(source.dispose);
      addTearDown(service.dispose);

      await service.ensurePrepared(enabled: true);

      expect(source.searchCalls, 1);
    });
  });

  group('Discover daily recommendation cache restore', () {
    tearDown(() async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await sl<DiscoverDailyRecommendationService>().ensurePrepared(
        enabled: false,
      );
    });

    test(
      'restores source scoped cache before source runtime is ready',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'discover_daily_recommendation_cache_jm': _cachePayload(
            sourceKey: 'jm',
            titlePrefix: 'Scoped',
          ),
        });
        await sl<DiscoverDailyRecommendationService>().ensurePrepared(
          enabled: false,
        );

        final state = await sl<DiscoverDailyRecommendationService>()
            .ensurePrepared(enabled: true);

        expect(state.hasRecommendations, isTrue);
        expect(state.displayedRecommendations, hasLength(7));
        expect(state.displayedRecommendations.first.comic.title, 'Scoped 1');
      },
    );

    test('restores legacy cache without schema version immediately', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'discover_daily_recommendation_cache': _cachePayload(
          includeVersion: false,
          sourceKey: '',
          titlePrefix: 'Legacy',
        ),
      });
      await sl<DiscoverDailyRecommendationService>().ensurePrepared(
        enabled: false,
      );

      final state = await sl<DiscoverDailyRecommendationService>()
          .ensurePrepared(enabled: true);

      expect(state.hasRecommendations, isTrue);
      expect(state.displayedRecommendations, hasLength(7));
      expect(state.displayedRecommendations.first.comic.title, 'Legacy 1');
    });

    test(
      'restores newest source scoped cache when source runtime is unavailable',
      () async {
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues(<String, Object>{
          'discover_daily_recommendation_cache': _cachePayload(
            sourceKey: '',
            titlePrefix: 'Old',
            generatedAt: now.subtract(const Duration(minutes: 25)),
          ),
          'discover_daily_recommendation_cache_jm': _cachePayload(
            sourceKey: 'jm',
            titlePrefix: 'Fresh',
            generatedAt: now,
          ),
        });
        await sl<DiscoverDailyRecommendationService>().ensurePrepared(
          enabled: false,
        );

        final state = await sl<DiscoverDailyRecommendationService>()
            .ensurePrepared(enabled: true);

        expect(state.hasRecommendations, isTrue);
        expect(state.selectedAuthor, 'Fresh Author');
        expect(state.displayedRecommendations.first.comic.title, 'Fresh 1');
      },
    );

    test(
      'stays disabled on non-JM sources even when preference is enabled',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'discover_daily_recommendation_cache_copy_manga': _cachePayload(
            sourceKey: 'copy_manga',
            titlePrefix: 'Copy',
          ),
        });
        await sl<HazukiSourceService>().activateSource('copy_manga');

        final state = await sl<DiscoverDailyRecommendationService>()
            .ensurePrepared(enabled: true);

        expect(state.enabled, isFalse);
        expect(state.hasRecommendations, isFalse);
      },
    );
  });
}

class _SearchCountingSource extends HazukiSourceService {
  _SearchCountingSource({
    this.throwOnSearch = false,
    this.switchSourceOnFirstSearch = false,
  }) : super(secureSessionStorage: MemorySourceSecureSessionStorage());

  final bool throwOnSearch;
  final bool switchSourceOnFirstSearch;
  int searchCalls = 0;
  String _activeSourceKey = 'jm';

  @override
  String get activeSourceKey => _activeSourceKey;

  @override
  bool get isActiveJmSource => _activeSourceKey == 'jm';

  @override
  bool get isInitialized => true;

  @override
  Future<SearchComicsResult> searchComics({
    required String keyword,
    required int page,
    String order = 'mr',
    String sourceKey = '',
  }) async {
    searchCalls++;
    if (switchSourceOnFirstSearch && searchCalls == 1) {
      _activeSourceKey = 'copy_manga';
      throw Exception('source_changed');
    }
    if (throwOnSearch) {
      throw Exception('search_failed');
    }
    return const SearchComicsResult(comics: <ExploreComic>[], maxPage: 0);
  }
}

List<DiscoverDailyRecommendationEntry> _recommendationEntries(
  String author,
  int count, {
  int idOffset = 0,
}) {
  return List<DiscoverDailyRecommendationEntry>.generate(count, (index) {
    final id = idOffset + index + 1;
    return DiscoverDailyRecommendationEntry(
      author: author,
      comic: ExploreComic(
        id: '$id',
        sourceKey: 'jm',
        title: '$author $id',
        subTitle: '',
        cover: 'https://example.com/$id.jpg',
      ),
    );
  });
}

String _cachePayload({
  required String sourceKey,
  required String titlePrefix,
  bool includeVersion = true,
  DateTime? generatedAt,
}) {
  return jsonEncode(<String, dynamic>{
    if (includeVersion) 'version': 2,
    'sourceKey': sourceKey,
    'generatedAt': (generatedAt ?? DateTime.now()).toIso8601String(),
    'selectedAuthor': '$titlePrefix Author',
    'entries': List<Object>.generate(7, (index) {
      final id = index + 1;
      return <String, Object>{
        'author': '$titlePrefix Author',
        'comic': <String, Object>{
          'id': '$id',
          'sourceKey': sourceKey,
          'title': '$titlePrefix $id',
          'subTitle': 'Subtitle $id',
          'cover': 'https://example.com/$id.jpg',
        },
      };
    }),
  });
}
