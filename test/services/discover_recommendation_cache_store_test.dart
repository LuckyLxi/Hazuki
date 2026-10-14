import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/discover_daily_recommendation_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Source extends Mock implements SourceDailyRecommendationGateway {}

Map<String, dynamic> _payload({
  String? sourceKey = 'jm',
  String? entrySourceKey = 'jm',
  DateTime? generatedAt,
}) => {
  'version': 2,
  'sourceKey': ?sourceKey,
  'generatedAt': (generatedAt ?? DateTime.now()).toIso8601String(),
  'selectedAuthor': 'Author',
  'entries': List.generate(
    7,
    (index) => {
      'author': 'Author',
      'comic': {
        'id': '$index',
        'sourceKey': ?entrySourceKey,
        'title': 'Comic $index',
        'subTitle': '',
        'cover': 'cover$index',
      },
    },
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = SharedPreferencesDiscoverDailyRecommendationCacheStore();
  const globalKey = 'discover_daily_recommendation_cache';

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final sourceKey in ['jm', '', null]) {
    test('legacy cache with source $sourceKey belongs only to JM', () async {
      SharedPreferences.setMockInitialValues({
        globalKey: jsonEncode(
          _payload(sourceKey: sourceKey, entrySourceKey: sourceKey),
        ),
      });

      expect(await store.readSnapshot(activeSourceKey: 'books'), isNull);
      final snapshot = await store.readSnapshot(activeSourceKey: 'jm');
      expect(snapshot, isNotNull);
      expect(snapshot!.sourceKey, 'jm');
      expect(
        snapshot.recommendations.map((entry) => entry.comic.sourceKey),
        everyElement('jm'),
      );
    });
  }

  test('source scoped cache takes precedence over the legacy cache', () async {
    SharedPreferences.setMockInitialValues({
      globalKey: jsonEncode(_payload()),
      '${globalKey}_books': jsonEncode(
        _payload(sourceKey: 'books', entrySourceKey: 'books'),
      ),
    });

    final snapshot = await store.readSnapshot(activeSourceKey: 'books');
    expect(snapshot!.sourceKey, 'books');
    expect(
      snapshot.recommendations.map((entry) => entry.comic.sourceKey),
      everyElement('books'),
    );
  });

  test('explicit global cache ownership is preserved', () async {
    SharedPreferences.setMockInitialValues({
      globalKey: jsonEncode(
        _payload(sourceKey: 'books', entrySourceKey: 'books'),
      ),
    });

    expect(await store.readSnapshot(activeSourceKey: 'jm'), isNull);
    expect(
      (await store.readSnapshot(activeSourceKey: 'books'))!.sourceKey,
      'books',
    );
  });

  test('storage key supplies missing scoped source identifiers', () async {
    SharedPreferences.setMockInitialValues({
      '${globalKey}_books': jsonEncode(
        _payload(sourceKey: null, entrySourceKey: ''),
      ),
    });

    final snapshot = await store.readSnapshot(activeSourceKey: 'books');
    expect(snapshot!.sourceKey, 'books');
    expect(
      snapshot.recommendations.map((entry) => entry.comic.sourceKey),
      everyElement('books'),
    );
  });

  test('a scoped cache rejects a conflicting snapshot source', () async {
    SharedPreferences.setMockInitialValues({
      '${globalKey}_books': jsonEncode(_payload()),
    });

    expect(await store.readSnapshot(activeSourceKey: 'books'), isNull);
    expect(await store.readSnapshot(activeSourceKey: ''), isNull);
  });

  test('a cache rejects a comic belonging to another source', () async {
    final payload = _payload(sourceKey: 'books', entrySourceKey: 'books');
    ((payload['entries'] as List).first['comic'] as Map)['sourceKey'] = 'jm';
    SharedPreferences.setMockInitialValues({
      '${globalKey}_books': jsonEncode(payload),
    });

    expect(await store.readSnapshot(activeSourceKey: 'books'), isNull);
  });

  test('unselected source fallback retains the newest valid owner', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      globalKey: jsonEncode(
        _payload(sourceKey: '', entrySourceKey: '', generatedAt: now),
      ),
      '${globalKey}_books': jsonEncode(
        _payload(
          sourceKey: null,
          entrySourceKey: null,
          generatedAt: now.add(const Duration(minutes: 1)),
        ),
      ),
    });

    final snapshot = await store.readSnapshot(activeSourceKey: '');
    expect(snapshot!.sourceKey, 'books');
    expect(
      snapshot.recommendations.map((entry) => entry.comic.sourceKey),
      everyElement('books'),
    );
  });

  test(
    'a new recommendation source never displays the legacy JM cache',
    () async {
      SharedPreferences.setMockInitialValues({
        globalKey: jsonEncode(_payload()),
      });
      final source = _Source();
      when(() => source.activeSourceKey).thenReturn('books');
      when(() => source.supportsDailyRecommendation).thenReturn(true);
      when(
        () => source.dailyRecommendationForSource('books'),
      ).thenReturn(const DailyRecommendationConfig(searchOrder: 'recent'));
      when(() => source.isInitialized).thenReturn(false);
      final service = DiscoverDailyRecommendationService(source: source);
      addTearDown(service.dispose);

      final state = await service.ensurePrepared(enabled: true);
      expect(state.enabled, isTrue);
      expect(state.displayedRecommendations, isEmpty);
    },
  );
}
