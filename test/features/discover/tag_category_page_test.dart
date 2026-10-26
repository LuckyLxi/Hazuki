import '../../support/fake_source_task_control.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_destination_route.dart';
import 'package:hazuki/features/discover/view/discover_section_page.dart';
import 'package:hazuki/features/discover/view/discover_section_page_widgets.dart';
import 'package:hazuki/features/discover/view/tag_category_page.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';
import 'package:hazuki/widgets/windows_comic_detail_presentation_scope.dart';
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
    when(
      () => categorySource.loadCategoryTagGroups(
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer(
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
        taskOrigin: any(named: 'taskOrigin'),
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
          taskControl: FakeSourceTaskControl(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adventure'));
    await tester.pumpAndSettle();
    expect(find.byType(DiscoverSectionPage), findsOneWidget);
  }

  for (final openResultDetail in [false, true]) {
    testWidgets('Windows special tag returns to the original detail '
        '(open result: $openResultDetail)', (tester) async {
      if (!useWindowsComicDetailPanel) return;
      final controller = WindowsComicDetailController.instance;
      controller.close();
      addTearDown(controller.close);
      final navigatorKey = GlobalKey<NavigatorState>();
      when(
        () => discoverSource.loadCategoryComicsByViewMore(
          viewMoreUrl: any(named: 'viewMoreUrl'),
          page: any(named: 'page'),
          order: any(named: 'order'),
          orders: any(named: 'orders'),
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer(
        (_) async => const CategoryComicsResult(comics: [], maxPage: 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(platform: TargetPlatform.windows),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => WindowsComicDetailPresentationScope(
            panelBuilder:
                (
                  comic,
                  heroTag, {
                  required shouldAnimatePanelReveal,
                  required isRestoringPreviousDetail,
                  required initialTabIndex,
                  required showHomeAction,
                  required onBackRequested,
                  required onHomeRequested,
                }) => Material(
                  child: Column(
                    children: [
                      Text('Detail ${comic.id}'),
                      TextButton(
                        onPressed: onBackRequested,
                        child: const Text('Close detail'),
                      ),
                      Builder(
                        builder: (context) => TextButton(
                          onPressed: () => Navigator.of(context).push<void>(
                            buildComicDetailDestinationRoute(
                              context,
                              (_) => DiscoverSectionPage(
                                taskControl: FakeSourceTaskControl(),
                                section: const ExploreSection(
                                  title: 'Adventure',
                                  comics: [],
                                  viewMoreUrl: 'category:Adventure',
                                ),
                                comicDetailPageBuilder: (_, _) =>
                                    const SizedBox.shrink(),
                                sourceService: discoverSource,
                              ),
                            ),
                          ),
                          child: const Text('Special tag'),
                        ),
                      ),
                    ],
                  ),
                ),
            child: child!,
          ),
          home: const WindowsComicDetailHost(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      );
      const root = ExploreComic(id: 'root', title: '', subTitle: '', cover: '');
      const original = ExploreComic(
        id: 'original',
        title: '',
        subTitle: '',
        cover: '',
      );
      controller.open(root, 'root-hero');
      controller.pushRelated(original, 'original-hero', historyTabIndex: 2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Special tag'));
      await tester.pumpAndSettle();

      expect(find.text('Detail original'), findsNothing);
      expect(find.text('Popular').hitTestable(), findsOneWidget);
      if (openResultDetail) {
        controller.open(
          const ExploreComic(id: 'result', title: '', subTitle: '', cover: ''),
          'result-hero',
        );
        await tester.pumpAndSettle();
        expect(find.text('Detail result'), findsOneWidget);
        await tester.tap(find.text('Close detail'));
        await tester.pumpAndSettle();
        expect(find.text('Popular').hitTestable(), findsOneWidget);
      }

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Detail original'), findsOneWidget);
      expect(controller.entry?.heroTag, 'original-hero');
      expect(controller.canGoBack, isTrue);
      await tester.tap(find.text('Close detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail root'), findsOneWidget);
      expect(controller.entry?.initialTabIndex, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
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
          taskOrigin: any(named: 'taskOrigin'),
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
          taskOrigin: any(named: 'taskOrigin'),
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
          taskOrigin: any(named: 'taskOrigin'),
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
        taskOrigin: any(named: 'taskOrigin'),
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
        taskOrigin: any(named: 'taskOrigin'),
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
        taskOrigin: any(named: 'taskOrigin'),
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
          taskControl: FakeSourceTaskControl(),
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
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filters wait for the page transition and skip loading rebuilds',
    (tester) async {
      final result = Completer<CategoryComicsResult>();
      when(
        () => discoverSource.loadCategoryComicsByViewMore(
          viewMoreUrl: any(named: 'viewMoreUrl'),
          page: any(named: 'page'),
          order: any(named: 'order'),
          orders: any(named: 'orders'),
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer((_) => result.future);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TagCategoryPage(
            searchPageBuilder: (_) => const SizedBox.shrink(),
            comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
            categorySource: categorySource,
            discoverSource: discoverSource,
            taskControl: FakeSourceTaskControl(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adventure'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 筛选项已在动画中途返回，但筛选栏要等过渡结束才插入
      final group = find.byKey(
        const ValueKey<String>('discover_section_sort_group_0'),
      );
      expect(find.byType(DiscoverSectionPage), findsOneWidget);
      expect(group, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(group, findsOneWidget);

      var sortBarRebuilds = 0;
      final previousCallback = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousCallback?.call(element, builtOnce);
        if (element.widget is DiscoverSectionSortBar) {
          sortBarRebuilds++;
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

      result.complete(
        CategoryComicsResult(
          comics: List.generate(
            6,
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
      await tester.pumpAndSettle();

      expect(find.text('Comic 0'), findsOneWidget);
      expect(sortBarRebuilds, 0);
      expect(find.text('Popular').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('groups reveal one by one without rebuilding shown tags', (
    tester,
  ) async {
    when(
      () => categorySource.loadCategoryTagGroups(
        taskOrigin: any(named: 'taskOrigin'),
      ),
    ).thenAnswer(
      (_) async => [
        for (var group = 0; group < 4; group++)
          CategoryTagGroup(
            name: 'Group $group',
            tags: [for (var tag = 0; tag < 3; tag++) 'Tag $group-$tag'],
            itemType: 'search',
          ),
      ],
    );
    var tagBuilds = 0;
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      // 每个标签只应构建一次；已显示的标签被重建会让次数超过标签总数
      if (element.widget is ActionChip) tagBuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousCallback);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TagCategoryPage(
          searchPageBuilder: (_) => const SizedBox.shrink(),
          comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
          categorySource: categorySource,
          discoverSource: discoverSource,
          taskControl: FakeSourceTaskControl(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Group 0'), findsOneWidget);
    expect(find.text('Group 3'), findsNothing);

    await tester.pumpAndSettle();
    for (var group = 0; group < 4; group++) {
      expect(find.text('Group $group'), findsOneWidget);
    }
    expect(tagBuilds, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'groups fade in while revealing but not when scrolled into view',
    (tester) async {
      when(
        () => categorySource.loadCategoryTagGroups(
          taskOrigin: any(named: 'taskOrigin'),
        ),
      ).thenAnswer(
        (_) async => [
          for (var group = 0; group < 30; group++)
            CategoryTagGroup(
              name: 'Group $group',
              tags: [for (var tag = 0; tag < 6; tag++) 'Tag $group-$tag'],
              itemType: 'search',
            ),
        ],
      );
      double groupOpacity(String name) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text(name),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TagCategoryPage(
            searchPageBuilder: (_) => const SizedBox.shrink(),
            comicDetailPageBuilder: (_, _) => const SizedBox.shrink(),
            categorySource: categorySource,
            discoverSource: discoverSource,
            taskControl: FakeSourceTaskControl(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(groupOpacity('Group 0'), lessThan(1));

      await tester.pumpAndSettle();
      expect(groupOpacity('Group 0'), 1);
      expect(find.text('Group 29'), findsNothing);

      // 展开结束后滚动带出的分组直接显示，不再播放出现动画
      await tester.dragUntilVisible(
        find.text('Group 29'),
        find.byType(ListView),
        const Offset(0, -400),
      );
      await tester.pump();
      expect(groupOpacity('Group 29'), 1);
      expect(tester.takeException(), isNull);
    },
  );
}
