import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/state/aggregate_search_results_controller.dart';
import 'package:hazuki/features/search/view/search_aggregate_results.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
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
      sourceService: HazukiSourceCapabilities(HazukiSourceService()),
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
}
