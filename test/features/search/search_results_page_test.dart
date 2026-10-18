import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_destination_route.dart';
import 'package:hazuki/features/search/view/search_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/search_history_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/source_catalog_fixtures.dart';

class _Source extends Mock implements SourceSearchGateway {}

class _History extends Mock implements SearchHistoryService {}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final layout in ['list', 'grid3']) {
      testWidgets(
        'tag search reveals $layout results after the $platform transition',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            hazukiSearchComicLayoutPreferenceKey: layout,
          });
          final source = _Source();
          final history = _History();
          when(() => source.activeSourceKey).thenReturn('jm');
          when(
            () => source.allowedSources,
          ).thenReturn([hazukiAllowedSourceCatalog.first]);
          when(() => source.supportsDirectComicId).thenReturn(false);
          when(
            () => source.sourceRuntimeState,
          ).thenReturn(const SourceRuntimeState.idle());
          when(
            () => source.directComicIdRulesForSource(any()),
          ).thenReturn(null);
          when(() => history.add('Action')).thenAnswer((_) async {});
          when(
            () => source.searchComics(
              keyword: any(named: 'keyword'),
              page: any(named: 'page'),
              order: any(named: 'order'),
              sourceKey: any(named: 'sourceKey'),
            ),
          ).thenAnswer(
            (_) async => const SearchComicsResult(
              comics: [
                ExploreComic(
                  id: '1',
                  title: 'Action comic',
                  subTitle: '',
                  cover: '',
                  sourceKey: 'jm',
                ),
              ],
              maxPage: 1,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      buildComicDetailDestinationRoute(
                        context,
                        (_) => SearchPage(
                          sourceService: source,
                          historyService: history,
                          initialKeyword: 'Action',
                          comicDetailPageBuilder: (_, _) => const SizedBox(),
                        ),
                      ),
                    ),
                    child: const Text('Action tag'),
                  ),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Action tag'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1));
          final route = ModalRoute.of(tester.element(find.byType(SearchPage)))!;
          await tester.pump(route.transitionDuration ~/ 2);
          expect(route.animation!.isCompleted, isFalse);
          expect(find.text('Action comic'), findsNothing);

          await tester.pump(route.transitionDuration ~/ 2);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          expect(route.animation!.isCompleted, isTrue);
          final opacityFinder = find.byKey(
            ValueKey(
              'search-${layout == 'list' ? 'list' : 'grid'}-entry-opacity-jm-1',
            ),
          );
          expect(
            tester.widget<Opacity>(opacityFinder).opacity,
            inExclusiveRange(0, 1),
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
          verify(() => history.add('Action')).called(1);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 500));
        },
      );
    }
  }

  testWidgets('disposing during tag navigation cancels the initial search', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final source = _Source();
    final history = _History();
    when(() => source.activeSourceKey).thenReturn('jm');
    when(
      () => source.allowedSources,
    ).thenReturn([hazukiAllowedSourceCatalog.first]);
    when(() => source.supportsDirectComicId).thenReturn(false);
    when(
      () => source.sourceRuntimeState,
    ).thenReturn(const SourceRuntimeState.idle());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              buildComicDetailDestinationRoute(
                context,
                (_) => SearchPage(
                  sourceService: source,
                  historyService: history,
                  initialKeyword: 'Action',
                  comicDetailPageBuilder: (_, _) => const SizedBox(),
                ),
              ),
            ),
            child: const Text('Action tag'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Action tag'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => history.add(any()));
    verifyNever(
      () => source.searchComics(
        keyword: any(named: 'keyword'),
        page: any(named: 'page'),
        order: any(named: 'order'),
        sourceKey: any(named: 'sourceKey'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final aggregate in [false, true]) {
    testWidgets(
      '${aggregate ? 'aggregate' : 'single-source'} keyword search stays loading '
      'from the first frame through history recording',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          hazukiAggregateSearchEnabledPreferenceKey: aggregate,
        });
        final source = _Source();
        final history = _History();
        final historyRecorded = Completer<void>();
        final response = Completer<SearchComicsResult>();
        when(() => source.activeSourceKey).thenReturn('jm');
        when(
          () => source.allowedSources,
        ).thenReturn([hazukiAllowedSourceCatalog.first]);
        when(() => source.supportsDirectComicId).thenReturn(false);
        when(
          () => source.sourceRuntimeState,
        ).thenReturn(const SourceRuntimeState.idle());
        when(() => source.directComicIdRulesForSource(any())).thenReturn(null);
        when(
          () => history.add('Action'),
        ).thenAnswer((_) => historyRecorded.future);
        when(
          () => source.searchComics(
            keyword: any(named: 'keyword'),
            page: any(named: 'page'),
            order: any(named: 'order'),
            sourceKey: any(named: 'sourceKey'),
          ),
        ).thenAnswer((_) => response.future);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SearchPage(
              sourceService: source,
              historyService: history,
              initialKeyword: '  Action  ',
              comicDetailPageBuilder: (_, _) => const SizedBox(),
            ),
          ),
        );

        expect(find.byKey(const ValueKey('search-idle')), findsNothing);
        expect(find.byKey(const ValueKey('search-loading')), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 600));

        verify(() => history.add('Action')).called(1);
        expect(find.byKey(const ValueKey('search-idle')), findsNothing);
        expect(find.byKey(const ValueKey('search-loading')), findsOneWidget);
        verifyNever(
          () => source.searchComics(
            keyword: any(named: 'keyword'),
            page: any(named: 'page'),
            order: any(named: 'order'),
            sourceKey: any(named: 'sourceKey'),
          ),
        );

        historyRecorded.complete();
        await tester.pump();

        verify(
          () => source.searchComics(
            keyword: 'Action',
            page: 1,
            order: 'mr',
            sourceKey: aggregate ? 'jm' : '',
          ),
        ).called(1);
        expect(find.byKey(const ValueKey('search-idle')), findsNothing);
        expect(
          find.byKey(ValueKey(aggregate ? 'loading' : 'search-loading')),
          findsOneWidget,
        );

        response.complete(
          const SearchComicsResult(
            comics: [
              ExploreComic(
                id: '1',
                title: 'Action comic',
                subTitle: '',
                cover: '',
                sourceKey: 'jm',
              ),
            ],
            maxPage: 1,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Action comic'), findsOneWidget);
        expect(find.byKey(const ValueKey('search-idle')), findsNothing);
        expect(find.byKey(const ValueKey('search-loading')), findsNothing);
        expect(find.byKey(const ValueKey('loading')), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  }
}
