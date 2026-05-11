import 'dart:convert';
import 'package:hazuki/app/service_locator.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/test_service_locator.dart';

void main() {
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
