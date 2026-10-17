import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/discover/view/discover_section_page.dart';
import 'package:hazuki/features/discover/view/discover_section_page_widgets.dart';
import 'package:hazuki/features/discover/view/tag_category_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _MockCategoryGateway extends Mock implements SourceCategoryGateway {}

class _MockDiscoverGateway extends Mock implements SourceDiscoverGateway {}

void main() {
  late _MockCategoryGateway categorySource;
  late _MockDiscoverGateway discoverSource;

  setUp(() {
    categorySource = _MockCategoryGateway();
    discoverSource = _MockDiscoverGateway();
    when(() => categorySource.softwareLogCaptureEnabled).thenReturn(false);
    when(() => categorySource.loadCategoryTagGroups()).thenAnswer(
      (_) async => const [
        CategoryTagGroup(
          name: 'Tags',
          tags: ['Adventure'],
          itemType: 'category',
        ),
      ],
    );
    when(
      () => discoverSource.loadCategoryOptionGroupsByViewMore(
        viewMoreUrl: any(named: 'viewMoreUrl'),
      ),
    ).thenAnswer(
      (_) async => const [
        [
          CategoryRankingOption(value: 'latest', label: 'Latest'),
          CategoryRankingOption(value: 'popular', label: 'Popular'),
        ],
        [CategoryRankingOption(value: 'all', label: 'All')],
      ],
    );
  });

  Future<void> openTag(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TagCategoryPage(
          searchPageBuilder: (_) => const SizedBox.shrink(),
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
          categorySource: categorySource,
          discoverSource: discoverSource,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adventure'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverSectionPage), findsOneWidget);
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('tag filters scroll with comics on ${platform.name}', (
      tester,
    ) async {
      when(
        () => discoverSource.loadCategoryComicsByViewMore(
          viewMoreUrl: any(named: 'viewMoreUrl'),
          page: any(named: 'page'),
          order: any(named: 'order'),
          orders: any(named: 'orders'),
        ),
      ).thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int;
        return CategoryComicsResult(
          comics: List.generate(
            60,
            (index) => ExploreComic(
              id: '$page-$index',
              title: 'Comic $page-$index',
              subTitle: '',
              cover: '',
            ),
          ),
          maxPage: 2,
        );
      });
      await openTag(tester, platform: platform);

      final scrollView = find.byType(CustomScrollView);
      final filters = find.byKey(
        const ValueKey<String>('discover_section_sort_group_0'),
        skipOffstage: false,
      );
      final secondGroup = find.byKey(
        const ValueKey<String>('discover_section_sort_group_1'),
        skipOffstage: false,
      );
      final initialY = tester.getTopLeft(filters).dy;
      final initialSecondY = tester.getTopLeft(secondGroup).dy;
      await tester.drag(scrollView, const Offset(0, -800));
      await tester.pumpAndSettle();

      final controller = tester
          .widget<CustomScrollView>(scrollView)
          .controller!;
      expect(controller.offset, greaterThan(520));
      expect(
        tester.getTopLeft(filters).dy,
        closeTo(initialY - controller.offset, 1),
      );
      expect(
        tester.getTopLeft(secondGroup).dy,
        closeTo(initialSecondY - controller.offset, 1),
      );
      expect(filters.hitTestable(), findsNothing);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      verify(
        () => discoverSource.loadCategoryComicsByViewMore(
          viewMoreUrl: 'category:Adventure',
          page: 2,
          order: 'latest',
          orders: ['latest', 'all'],
        ),
      ).called(1);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(filters.hitTestable(), findsOneWidget);
      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();
      verify(
        () => discoverSource.loadCategoryComicsByViewMore(
          viewMoreUrl: 'category:Adventure',
          page: 1,
          order: 'popular',
          orders: ['popular', 'all'],
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fast vertical scrolling does not rebuild large filter groups', (
    tester,
  ) async {
    when(
      () => discoverSource.loadCategoryOptionGroupsByViewMore(
        viewMoreUrl: any(named: 'viewMoreUrl'),
      ),
    ).thenAnswer(
      (_) async => [
        List.generate(
          500,
          (index) => CategoryRankingOption(
            value: 'filter-$index',
            label: 'Filter option $index',
          ),
        ),
      ],
    );
    when(
      () => discoverSource.loadCategoryComicsByViewMore(
        viewMoreUrl: any(named: 'viewMoreUrl'),
        page: any(named: 'page'),
        order: any(named: 'order'),
        orders: any(named: 'orders'),
      ),
    ).thenAnswer(
      (_) async => CategoryComicsResult(
        comics: List.generate(
          60,
          (index) => ExploreComic(
            id: '$index',
            title: 'Comic $index',
            subTitle: '',
            cover: '',
          ),
        ),
        maxPage: 1,
      ),
    );
    await openTag(tester);
    var sortBarRebuilds = 0;
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      if (element.widget is DiscoverSectionSortBar) {
        sortBarRebuilds++;
      }
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

    final scrollView = find.byType(CustomScrollView);
    await tester.fling(scrollView, const Offset(0, -800), 2500);
    await tester.pumpAndSettle();
    expect(
      tester.widget<CustomScrollView>(scrollView).controller!.offset,
      greaterThan(520),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(sortBarRebuilds, 0);
    expect(find.text('Filter option 0').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters stay usable while loading and after empty results', (
    tester,
  ) async {
    final result = Completer<CategoryComicsResult>();
    when(
      () => discoverSource.loadCategoryComicsByViewMore(
        viewMoreUrl: any(named: 'viewMoreUrl'),
        page: any(named: 'page'),
        order: any(named: 'order'),
        orders: any(named: 'orders'),
      ),
    ).thenAnswer((_) => result.future);

    // Loading indicators animate continuously until the first request finishes.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiscoverSectionPage(
          section: const ExploreSection(
            title: 'Adventure',
            comics: [],
            viewMoreUrl: 'category:Adventure',
          ),
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
          sourceService: discoverSource,
          scrollSortBarWithContent: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Popular').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    result.complete(const CategoryComicsResult(comics: [], maxPage: 1));
    await tester.pumpAndSettle();
    expect(find.text('Popular').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Popular'));
    await tester.pumpAndSettle();
    verify(
      () => discoverSource.loadCategoryComicsByViewMore(
        viewMoreUrl: 'category:Adventure',
        page: 1,
        order: 'popular',
        orders: ['popular', 'all'],
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });
}
