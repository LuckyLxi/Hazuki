import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/state/aggregate_search_results_controller.dart';
import 'package:hazuki/features/search/view/search_aggregate_results.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

void main() {
  testWidgets('keeps successful source results when another source fails', (
    tester,
  ) async {
    late BuildContext testContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final requestedOrders = <String, String>{};
    final controller = AggregateSearchResultsController.withLoader(
      sourceService: (() {
        final source = SourceRuntimeAssembly();
        return HazukiSourceSearchAdapter(
          runtime: source.testing.runtime,
          content: source.testing.content,
        );
      })(),
      loader:
          ({
            required sourceKey,
            required keyword,
            required page,
            required order,
          }) async {
            requestedOrders[sourceKey] = order;
            if (sourceKey == 'copy_manga') {
              throw Exception('copy unavailable');
            }
            if (sourceKey == hazukiDefaultSourceKey) {
              return SearchComicsResult(
                comics: [
                  ExploreComic(
                    id: '1',
                    title: keyword,
                    subTitle: '',
                    cover: '',
                    sourceKey: sourceKey,
                  ),
                ],
                maxPage: 1,
              );
            }
            return const SearchComicsResult(comics: [], maxPage: 0);
          },
    );
    addTearDown(controller.dispose);

    await controller.search(testContext, 'Hazuki');

    final jm = controller.sections.firstWhere(
      (section) => section.source.normalizedKey == hazukiDefaultSourceKey,
    );
    final copy = controller.sections.firstWhere(
      (section) => section.source.normalizedKey == 'copy_manga',
    );
    final picacg = controller.sections.firstWhere(
      (section) => section.source.normalizedKey == 'picacg',
    );
    expect(jm.comics.single.title, 'Hazuki');
    expect(jm.errorMessage, isNull);
    expect(copy.comics, isEmpty);
    expect(copy.errorMessage, contains('copy unavailable'));
    expect(picacg.comics, isEmpty);
    expect(picacg.errorMessage, isNull);
    expect(requestedOrders, {
      hazukiDefaultSourceKey: 'mr',
      'copy_manga': '-',
      'picacg': 'dd',
    });
  });

  testWidgets('source section exposes a view more action', (tester) async {
    final section =
        AggregateSearchSectionState(source: hazukiAllowedSourceCatalog.first)
          ..comics = const [
            ExploreComic(
              id: '1',
              title: 'Hazuki',
              subTitle: '',
              cover: '',
              sourceKey: hazukiDefaultSourceKey,
            ),
          ];
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    AggregateSearchSectionState? openedSection;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SearchAggregateResultsBody(
            scrollController: scrollController,
            sections: [section],
            onRefresh: () async {},
            onScrollNotification: (_) => false,
            onRetry: (_) {},
            onLoadMore: (_) {},
            onComicTap: (_, _) async {},
            onViewMore: (value) => openedSection = value,
            heroTagBuilder: (comic, salt) => '${comic.id}-$salt',
          ),
        ),
      ),
    );

    final moreButton = find.byKey(
      ValueKey('aggregate-search-more-${section.source.key}'),
    );
    expect(moreButton, findsOneWidget);
    await tester.tap(moreButton);

    expect(openedSection, same(section));
  });

  testWidgets('changing a source section order reloads only that source', (
    tester,
  ) async {
    late BuildContext testContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final requestedOrders = <String>[];
    final controller = AggregateSearchResultsController.withLoader(
      sourceService: (() {
        final source = SourceRuntimeAssembly();
        return HazukiSourceSearchAdapter(
          runtime: source.testing.runtime,
          content: source.testing.content,
        );
      })(),
      loader:
          ({
            required sourceKey,
            required keyword,
            required page,
            required order,
          }) async {
            if (sourceKey == hazukiDefaultSourceKey) {
              requestedOrders.add(order);
            }
            return const SearchComicsResult(comics: [], maxPage: 0);
          },
    );
    addTearDown(controller.dispose);

    await controller.search(testContext, 'Hazuki');
    final section = controller.sections.firstWhere(
      (section) => section.source.normalizedKey == hazukiDefaultSourceKey,
    );

    await controller.changeOrder(testContext, section, 'mv');

    expect(section.order, 'mv');
    expect(requestedOrders, ['mr', 'mv']);
  });

  testWidgets('changing order clears stale results before reloading', (
    tester,
  ) async {
    late BuildContext testContext;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            testContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    final pendingReload = Completer<SearchComicsResult>();
    final source = SourceRuntimeAssembly();
    final controller = AggregateSearchResultsController.withLoader(
      sourceService: HazukiSourceSearchAdapter(
        runtime: source.testing.runtime,
        content: source.testing.content,
      ),
      loader:
          ({
            required sourceKey,
            required keyword,
            required page,
            required order,
          }) async {
            if (sourceKey != hazukiDefaultSourceKey) {
              return const SearchComicsResult(comics: [], maxPage: 0);
            }
            if (order == 'mv') return pendingReload.future;
            return const SearchComicsResult(
              comics: [
                ExploreComic(
                  id: 'old',
                  title: 'Old result',
                  subTitle: '',
                  cover: '',
                  sourceKey: hazukiDefaultSourceKey,
                ),
              ],
              maxPage: 1,
            );
          },
    );
    addTearDown(controller.dispose);

    await controller.search(testContext, 'Hazuki');
    final section = controller.sections.firstWhere(
      (section) => section.source.normalizedKey == hazukiDefaultSourceKey,
    );

    final reload = controller.changeOrder(testContext, section, 'mv');

    expect(section.loading, isTrue);
    expect(section.comics, isEmpty);
    pendingReload.complete(const SearchComicsResult(comics: [], maxPage: 0));
    await reload;
  });

  testWidgets('source section page updates its sort label and empty state', (
    tester,
  ) async {
    final source = SourceRuntimeAssembly();
    final controller = AggregateSearchResultsController.withLoader(
      sourceService: HazukiSourceSearchAdapter(
        runtime: source.testing.runtime,
        content: source.testing.content,
      ),
      loader:
          ({
            required sourceKey,
            required keyword,
            required page,
            required order,
          }) async {
            if (sourceKey != hazukiDefaultSourceKey || order == 'mv') {
              return const SearchComicsResult(comics: [], maxPage: 0);
            }
            return const SearchComicsResult(
              comics: [
                ExploreComic(
                  id: '1',
                  title: 'Hazuki',
                  subTitle: '',
                  cover: '',
                  sourceKey: hazukiDefaultSourceKey,
                ),
              ],
              maxPage: 1,
            );
          },
    );
    addTearDown(controller.dispose);
    final section = controller.sections.firstWhere(
      (section) => section.source.normalizedKey == hazukiDefaultSourceKey,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchAggregateSectionPage(
          controller: controller,
          section: section,
          onComicTap: (_, _) async {},
          heroTagBuilder: (comic, salt) => '${comic.id}-$salt',
        ),
      ),
    );
    final pageContext = tester.element(find.byType(SearchAggregateSectionPage));
    await controller.search(pageContext, 'Hazuki');
    await tester.pump();
    final strings = AppLocalizations.of(pageContext)!;

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuItem<String>), findsNWidgets(7));
    await tester.tap(find.byType(PopupMenuItem<String>).at(1));
    await tester.pumpAndSettle();

    final orderButton = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    expect(section.order, 'mv');
    expect(orderButton.tooltip, strings.searchOrderTotalRanking);
    expect(find.text(strings.searchEmpty), findsOneWidget);
  });
}
