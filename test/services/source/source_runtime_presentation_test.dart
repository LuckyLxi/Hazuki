import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/state/aggregate_search_results_controller.dart';
import 'package:hazuki/features/search/state/search_results_controller.dart';
import 'package:hazuki/features/search/support/search_contracts.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/adapters/hazuki_source_content_adapters.dart';
import 'package:hazuki/services/source/content/source_content_operations.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/runtime/source_runtime_view.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:mocktail/mocktail.dart';

class _Content extends Mock implements SourceContentOperations {}

class _Operations extends Mock implements SourceRuntimeOperations {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late HazukiSourceSearchAdapter source;
  setUp(() {
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'custom',
          name: 'Custom',
          fileName: 'custom.js',
          presentation: {
            'showTags': true,
            'searchOrders': {'old': 'Old'},
            'searchDefaultOrder': 'old',
          },
        ),
      ],
      defaultSourceKey: 'custom',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    source = HazukiSourceSearchAdapter(
      runtime: SourceRuntimeViewService(
        runtimeHost: host,
        runtimeOperations: _Operations(),
      ),
      content: _Content(),
    );
  });
  tearDown(() => host.dispose());

  void updatePresentation([String sourceKey = 'custom']) {
    host.handleFor(sourceKey).runtime.sourceMeta = SourceMeta(
      name: 'Custom',
      key: sourceKey,
      version: '1.0',
      supportsAccount: false,
      settingsDefaults: {},
      presentation: {
        'searchOrders': {
          'score': {'zh': '评分', 'en': 'Score'},
        },
        'searchDefaultOrder': 'score',
        'favoriteOrderLabels': {'recent': 'Recent'},
      },
    );
    host.notifyActiveRuntimeChanged(sourceKey);
  }

  test(
    'page choices and labels share runtime declarations without losing installed fields',
    () async {
      final controller = SearchResultsController(
        initialOrder: '',
        sourceService: source,
      );
      addTearDown(controller.dispose);
      expect(controller.searchOrder, 'old');
      updatePresentation();
      expect(controller.searchOrder, 'score');
      final presentation = host.runtimeRegistry.presentationFor('custom');
      expect(presentation['showTags'], isTrue);
      expect(presentation['favoriteOrderLabels'], {'recent': 'Recent'});
      expect(source.allowedSources.single.presentation, presentation);
      expect(
        host.runtimeRegistry.displayPresentationFor('custom'),
        presentation,
      );
      await host.replaceCatalog([]);
      expect(source.allowedSources, isEmpty);
      expect(host.runtimeRegistry.presentationFor('custom'), isEmpty);
      expect(host.runtimeRegistry.displayPresentationFor('custom'), isEmpty);
    },
  );

  for (final pendingPage in [1, 3]) {
    test(
      'single-source runtime order changes discard pending page $pendingPage and restart pagination',
      () async {
        final oldResult = Completer<SearchComicsResult>();
        final newResult = Completer<SearchComicsResult>();
        final requests = <(String, int)>[];
        final controller = SearchResultsController(
          initialOrder: '',
          sourceService: source,
          searchPageLoader:
              ({required keyword, required page, required order}) {
                expect(keyword, 'test');
                requests.add((order, page));
                if (order == 'old' && page == pendingPage) {
                  return oldResult.future;
                }
                if (order == 'score' && page == 1) return newResult.future;
                return Future.value(_searchResult('$order-$page'));
              },
        );
        addTearDown(controller.dispose);
        final messages = SearchMessages(
          timeout: 'timeout',
          failed: (error) => error,
        );
        if (pendingPage > 1) {
          await controller.search(messages, keyword: 'test', page: 1);
          await controller.loadMoreSearch(messages);
        }
        final pending = pendingPage == 1
            ? controller.search(messages, keyword: 'test', page: 1)
            : controller.loadMoreSearch(messages);

        updatePresentation();
        expect(controller.searchOrder, 'score');
        expect(requests.last, ('score', 1));
        expect(controller.searchComics, isEmpty);
        expect(controller.searchPage, 1);
        expect(controller.searchMaxPage, isNull);
        expect(controller.searchLoading, isTrue);
        expect(controller.searchLoadingMore, isFalse);

        newResult.complete(_searchResult('new', maxPage: 3));
        await Future<void>.delayed(Duration.zero);
        oldResult.complete(_searchResult('stale'));
        await pending;
        expect(controller.searchComics.single.id, 'new');
        expect(controller.searchPage, 1);
        expect(controller.searchMaxPage, 3);
        expect(controller.searchHasMore, isTrue);
        expect(controller.searchLoading, isFalse);
        expect(controller.searchLoadingMore, isFalse);
        expect(controller.searchErrorMessage, isNull);

        await controller.loadMoreSearch(messages);
        expect(requests.last, ('score', 2));
        expect(controller.searchComics.map((comic) => comic.id), [
          'new',
          'score-2',
        ]);
      },
    );
  }

  test('runtime sort changes preserve an active direct ID lookup', () async {
    final requests = <String>[];
    final controller = SearchResultsController(
      initialOrder: '',
      sourceService: source,
      searchPageLoader:
          ({required keyword, required page, required order}) async {
            requests.add(keyword);
            return _searchResult('previous');
          },
    );
    addTearDown(controller.dispose);
    await controller.search(
      SearchMessages(timeout: 'timeout', failed: (error) => error),
      keyword: 'previous',
      page: 1,
    );
    final token = controller.prepareDirectIdLookup('123');

    updatePresentation();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isCurrentRequest(token), isTrue);
    expect(controller.searchLoading, isTrue);
    expect(requests, ['previous']);
    controller.finishDirectIdLookup(token);
    expect(controller.searchLoading, isFalse);
  });

  for (final sourceKey in ['custom', 'other']) {
    test(
      'aggregate runtime order changes for $sourceKey reload with new options and discard the old result',
      () async {
        if (sourceKey == 'other') {
          await host.replaceCatalog([
            host.catalog.single,
            const SourceCatalogEntry(
              key: 'other',
              name: 'Other',
              fileName: 'other.js',
              presentation: {
                'searchOrders': {'old': 'Old'},
                'searchDefaultOrder': 'old',
              },
            ),
          ]);
        }
        final oldResult = Completer<SearchComicsResult>();
        final requests = <(String, String)>[];
        final targetSourceKey = sourceKey;
        final controller = AggregateSearchResultsController.withLoader(
          sourceService: source,
          loader:
              ({
                required sourceKey,
                required keyword,
                required page,
                required order,
              }) {
                requests.add((sourceKey, order));
                if (sourceKey == targetSourceKey && order == 'old') {
                  return oldResult.future;
                }
                return Future.value(
                  const SearchComicsResult(
                    comics: [
                      ExploreComic(
                        id: 'new',
                        title: 'New',
                        subTitle: '',
                        cover: '',
                      ),
                    ],
                    maxPage: 1,
                  ),
                );
              },
        );
        addTearDown(controller.dispose);
        final pending = controller.search(
          SearchMessages(timeout: 'timeout', failed: (error) => error),
          'test',
        );
        updatePresentation(sourceKey);
        await Future<void>.delayed(Duration.zero);
        oldResult.complete(
          const SearchComicsResult(
            comics: [
              ExploreComic(id: 'old', title: 'Old', subTitle: '', cover: ''),
            ],
            maxPage: 1,
          ),
        );
        await pending;
        final section = controller.sections.singleWhere(
          (section) => section.source.key == sourceKey,
        );
        expect(
          requests
              .where((request) => request.$1 == sourceKey)
              .map((request) => request.$2),
          ['old', 'score'],
        );
        expect(section.source.presentation['searchDefaultOrder'], 'score');
        expect(section.order, 'score');
        expect(section.comics.single.id, 'new');
        expect(section.loading, isFalse);
        if (sourceKey == 'other') {
          expect(host.activeSourceKey, 'custom');
          expect(requests.where((request) => request.$1 == 'custom'), [
            ('custom', 'old'),
          ]);
        }
      },
    );
  }
}

SearchComicsResult _searchResult(String id, {int maxPage = 9}) =>
    SearchComicsResult(
      comics: [ExploreComic(id: id, title: id, subTitle: '', cover: '')],
      maxPage: maxPage,
    );
