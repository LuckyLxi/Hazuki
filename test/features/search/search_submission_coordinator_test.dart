import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hazuki/features/search/state/search_results_controller.dart';
import 'package:hazuki/features/search/state/aggregate_search_results_controller.dart';
import 'package:hazuki/features/search/support/search_contracts.dart';
import 'package:hazuki/features/search/support/search_submission_coordinator.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Source extends Mock implements SourceSearchGateway {}

const _details = ComicDetailsData(
  id: '12345',
  title: 'Comic',
  subTitle: '',
  cover: '',
  description: '',
  updateTime: '',
  likesCount: '',
  chapters: {},
  tags: {},
  recommend: [],
  isFavorite: false,
  subId: '',
  sourceKey: 'jm',
);

void main() {
  late Completer<ComicDetailsData> details;
  late SearchSubmissionCoordinator coordinator;
  late SearchResultsController results;
  late List<String> events;
  final messages = SearchMessages(
    timeout: 'Timeout',
    failed: (e) => 'Failed: $e',
  );

  setUp(() {
    final source = _Source();
    when(() => source.activeSourceKey).thenReturn('jm');
    when(() => source.allowedSources).thenReturn([]);
    details = Completer<ComicDetailsData>();
    events = [];
    results = SearchResultsController(
      initialOrder: 'mr',
      sourceService: source,
      comicDetailsLoader: (id, {required sourceKey}) => details.future,
      searchPageLoader:
          ({required keyword, required page, required order}) async {
            events.add('search:$keyword');
            return SearchComicsResult(
              comics: [
                ExploreComic(
                  id: keyword,
                  title: keyword,
                  subTitle: '',
                  cover: '',
                ),
              ],
              maxPage: 1,
            );
          },
    );
    final aggregate = AggregateSearchResultsController(sourceService: source);
    addTearDown(results.dispose);
    addTearDown(aggregate.dispose);
    coordinator = SearchSubmissionCoordinator(
      results: results,
      aggregateResults: aggregate,
      recordHistory: (keyword) async {
        events.add('history:$keyword');
      },
      openComic: (comic) async {
        events.add('open:${comic.id}');
      },
      isActive: () => true,
    );
  });

  Future<void> submit(String keyword) => coordinator.submit(
    keyword: keyword,
    aggregate: false,
    activeSourceKey: 'jm',
    messages: messages,
  );

  test(
    'direct lookup records history and opens details without keyword search',
    () async {
      final pending = submit('12345');
      expect(results.searchLoading, isTrue);
      details.complete(_details);
      await pending;
      expect(events, ['history:12345', 'open:12345']);
      expect(results.searchLoading, isFalse);
    },
  );

  test(
    'failed direct lookup falls back to keyword search without a widget tree',
    () async {
      final pending = submit('12345');
      details.completeError(StateError('missing comic'));
      await pending;
      expect(events, ['history:12345', 'search:12345']);
      expect(results.searchComics.single.id, '12345');
      expect(results.searchLoading, isFalse);
    },
  );

  test(
    'new submission prevents old direct lookup from navigating or adding history',
    () async {
      final pending = submit('12345');
      await submit('new keyword');
      details.complete(_details);
      await pending;
      expect(events, ['history:new keyword', 'search:new keyword']);
      expect(results.searchComics.single.id, 'new keyword');
    },
  );

  test('clearing a search invalidates its pending direct lookup', () async {
    final pending = submit('12345');
    coordinator.invalidate();
    results.clearSearchData();
    details.complete(_details);
    await pending;
    expect(events, isEmpty);
    expect(results.searchKeyword, isEmpty);
    expect(results.searchLoading, isFalse);
  });
}
