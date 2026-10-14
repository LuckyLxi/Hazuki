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
  late List<String> lookups;
  late _Source source;
  late AggregateSearchResultsController aggregate;
  final messages = SearchMessages(
    timeout: 'Timeout',
    failed: (e) => 'Failed: $e',
  );

  setUp(() {
    source = _Source();
    when(() => source.activeSourceKey).thenReturn('jm');
    when(() => source.allowedSources).thenReturn([]);
    when(() => source.directComicIdRulesForSource(any())).thenReturn(null);
    when(() => source.directComicIdRulesForSource('jm')).thenReturn(
      DirectComicIdRules.parse({
        'patterns': [r'^(?:jm)?(\d{2,})$'],
        'extractDigits': true,
      }),
    );
    details = Completer<ComicDetailsData>();
    events = [];
    lookups = [];
    results = SearchResultsController(
      initialOrder: 'mr',
      sourceService: source,
      comicDetailsLoader: (id, {required sourceKey}) {
        lookups.add('$sourceKey:$id');
        return details.future;
      },
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
    aggregate = AggregateSearchResultsController(sourceService: source);
    addTearDown(results.dispose);
    addTearDown(aggregate.dispose);
    coordinator = SearchSubmissionCoordinator(
      results: results,
      sourceService: source,
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

  test(
    'single-source ID lookup accepts an arbitrary source identity',
    () async {
      when(() => source.activeSourceKey).thenReturn('books');
      when(() => source.directComicIdRulesForSource('books')).thenReturn(
        DirectComicIdRules.parse({
          'patterns': [r'book-(\d+)'],
          'extractDigits': false,
        }),
      );
      final pending = coordinator.submit(
        keyword: 'BOOK-12345',
        aggregate: false,
        activeSourceKey: 'books',
        messages: messages,
      );
      expect(lookups, ['books:12345']);
      details.complete(_details);
      await pending;
      expect(events, ['history:BOOK-12345', 'open:12345']);
    },
  );

  test(
    'aggregate ID lookup uses the only matching participating source',
    () async {
      aggregate.sections.add(
        AggregateSearchSectionState(
          source: const SourceCatalogEntry(
            key: 'books',
            name: 'Books',
            fileName: 'books.js',
          ),
        ),
      );
      when(() => source.directComicIdRulesForSource('books')).thenReturn(
        DirectComicIdRules.parse({
          'patterns': [r'(\d+)'],
          'extractDigits': false,
        }),
      );
      final pending = coordinator.submit(
        keyword: '12345',
        aggregate: true,
        activeSourceKey: 'jm',
        messages: messages,
      );
      expect(lookups, ['books:12345']);
      details.complete(_details);
      await pending;
      expect(events, ['history:12345', 'open:12345']);
    },
  );

  test(
    'multiple matching plugins fall back to normal aggregate search',
    () async {
      for (final key in ['jm', 'books']) {
        aggregate.sections.add(
          AggregateSearchSectionState(
            source: SourceCatalogEntry(
              key: key,
              name: key,
              fileName: '$key.js',
            ),
          ),
        );
        when(() => source.directComicIdRulesForSource(key)).thenReturn(
          DirectComicIdRules.parse({
            'patterns': [r'(\d+)'],
            'extractDigits': false,
          }),
        );
        when(
          () => source.searchComics(
            keyword: '12345',
            page: 1,
            order: '',
            sourceKey: key,
          ),
        ).thenAnswer(
          (_) async => const SearchComicsResult(comics: [], maxPage: 1),
        );
      }
      await coordinator.submit(
        keyword: '12345',
        aggregate: true,
        activeSourceKey: 'jm',
        messages: messages,
      );
      expect(lookups, isEmpty);
      expect(events, ['history:12345']);
      for (final key in ['jm', 'books']) {
        verify(
          () => source.searchComics(
            keyword: '12345',
            page: 1,
            order: '',
            sourceKey: key,
          ),
        ).called(1);
      }
    },
  );

  test('missing new rules leave normal keyword search enabled', () async {
    when(() => source.directComicIdRulesForSource('jm')).thenReturn(null);
    await submit('12345');
    expect(lookups, isEmpty);
    expect(events, ['history:12345', 'search:12345']);
  });

  test('switching sources discards a pending ID lookup', () async {
    final pending = submit('12345');
    when(() => source.activeSourceKey).thenReturn('books');
    details.complete(_details);
    await pending;
    expect(events, isEmpty);
  });
}
