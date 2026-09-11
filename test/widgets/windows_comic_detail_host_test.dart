import 'package:hazuki/widgets/windows_comic_detail_presentation_scope.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/comic_detail/view/comic_detail_app_bar.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';
import 'package:hazuki/widgets/windows_comic_detail_host.dart';

void main() {
  final controller = WindowsComicDetailController.instance;
  late WindowsComicDetailPanelBuilder panelBuilder;

  Widget presentationBuilder(BuildContext context, Widget? child) =>
      WindowsComicDetailPresentationScope(
        panelBuilder: panelBuilder,
        child: child!,
      );

  setUp(() {
    controller.close();
    panelBuilder =
        (
          comic,
          heroTag, {
          required shouldAnimatePanelReveal,
          required isRestoringPreviousDetail,
          required initialTabIndex,
          required showHomeAction,
          required onBackRequested,
          required onHomeRequested,
        }) => const ColoredBox(
          key: ValueKey('comic-detail-panel'),
          color: Colors.white,
        );
  });

  tearDown(() {
    controller.close();
  });

  testWidgets(
    'hosts independently handle reveal and follow injected sessions',
    (tester) async {
      if (!Platform.isWindows) return;
      final first = WindowsComicDetailController();
      final second = WindowsComicDetailController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      const comic = ExploreComic(
        id: 'injected',
        title: '',
        subTitle: '',
        cover: '',
      );
      final reveals = <bool>[];
      panelBuilder =
          (
            comic,
            heroTag, {
            required shouldAnimatePanelReveal,
            required isRestoringPreviousDetail,
            required initialTabIndex,
            required showHomeAction,
            required onBackRequested,
            required onHomeRequested,
          }) {
            reveals.add(shouldAnimatePanelReveal);
            return Builder(
              builder: (context) => Text(
                WindowsComicDetailControllerScope.of(context).entry?.comic.id ??
                    comic.id,
              ),
            );
          };
      Widget app(WindowsComicDetailController right) => MaterialApp(
        builder: presentationBuilder,
        home: Row(
          children: [
            Expanded(
              child: WindowsComicDetailHost(
                controller: first,
                child: const SizedBox(),
              ),
            ),
            Expanded(
              child: WindowsComicDetailHost(
                controller: right,
                child: const SizedBox(),
              ),
            ),
          ],
        ),
      );
      await tester.pumpWidget(app(first));
      first.open(comic, 'hero');
      await tester.pump();
      expect(reveals, [true, true]);
      await tester.pumpAndSettle();
      reveals.clear();
      final token = first.beginTemporaryHide();
      await tester.pumpAndSettle();
      reveals.clear();
      first.endTemporaryHide(token);
      await tester.pump();
      expect(reveals, [false, false]);
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(second));
      await tester.pumpAndSettle();
      expect(find.text('injected'), findsOneWidget);
      second.open(
        const ExploreComic(id: 'second', title: '', subTitle: '', cover: ''),
        'second',
      );
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      first.close();
      await tester.pumpAndSettle();
      expect(find.text('injected'), findsNothing);
      expect(find.text('second'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final routeDepth in [0, 1, 2]) {
    testWidgets('detail home returns to root from route depth $routeDepth', (
      tester,
    ) async {
      if (!Platform.isWindows) {
        return;
      }

      final navigatorKey = GlobalKey<NavigatorState>();
      panelBuilder =
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
                Text(comic.id),
                TextButton(
                  onPressed: onBackRequested,
                  child: const Text('Back'),
                ),
                if (showHomeAction)
                  TextButton(
                    onPressed: onHomeRequested,
                    child: const Text('Home'),
                  ),
              ],
            ),
          );
      await tester.pumpWidget(
        MaterialApp(
          builder: presentationBuilder,
          navigatorKey: navigatorKey,
          home: const WindowsComicDetailHost(
            child: Scaffold(body: Text('Root')),
          ),
        ),
      );
      for (var index = 0; index < routeDepth; index++) {
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => WindowsComicDetailHost(
              suppressExistingPanel: true,
              child: Scaffold(body: Text('Destination $index')),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      const original = ExploreComic(
        id: 'original',
        title: 'Original',
        subTitle: '',
        cover: '',
      );
      const related = ExploreComic(
        id: 'related',
        title: 'Related',
        subTitle: '',
        cover: '',
      );
      controller.open(original, 'original-hero');
      await tester.pumpAndSettle();
      controller.pushRelated(related, 'related-hero');
      await tester.pumpAndSettle();

      // Back keeps the destination route and restores the original detail.
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(controller.entry?.comic.id, 'original');
      expect(navigatorKey.currentState!.canPop(), routeDepth > 0);

      controller.pushRelated(related, 'related-hero');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(controller.entry, isNull);
      expect(controller.canGoBack, isFalse);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Windows comic detail panel enters upward and exits downward', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }

    await tester.pumpWidget(
      MaterialApp(
        builder: presentationBuilder,
        home: SizedBox(
          width: 800,
          height: 600,
          child: WindowsComicDetailHost(child: ColoredBox(color: Colors.black)),
        ),
      ),
    );

    controller.open(
      const ExploreComic(
        id: 'comic-id',
        title: 'Comic',
        subTitle: 'Subtitle',
        cover: '',
      ),
      'hero-tag',
    );
    await tester.pump();

    final panel = find.byKey(const ValueKey('comic-detail-panel'));
    final initialTop = tester.getTopLeft(panel).dy;
    expect(initialTop, greaterThan(0));

    await tester.pump(windowsComicDetailPanelAnimationDuration);
    expect(tester.getTopLeft(panel).dy, closeTo(0, 0.01));
    expect(tester.getSize(panel), const Size(800, 600));

    controller.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getTopLeft(panel).dy, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 160));
    expect(panel, findsNothing);
  });

  test('opening another detail cancels a temporary hide', () {
    if (!Platform.isWindows) {
      return;
    }

    controller.open(
      const ExploreComic(
        id: 'original-comic',
        title: 'Original comic',
        subTitle: '',
        cover: '',
      ),
      'original-hero-tag',
    );
    final hideToken = controller.beginTemporaryHide();
    expect(controller.isPanelVisible, isFalse);

    controller.open(
      const ExploreComic(
        id: 'search-result-comic',
        title: 'Search result comic',
        subTitle: '',
        cover: '',
      ),
      'search-result-hero-tag',
    );
    controller.endTemporaryHide(hideToken);

    expect(controller.entry?.comic.id, 'search-result-comic');
    expect(controller.isPanelVisible, isTrue);
  });

  test('related details keep a back stack and home closes the stack', () {
    if (!Platform.isWindows) {
      return;
    }

    controller.open(
      const ExploreComic(
        id: 'original-comic',
        title: 'Original comic',
        subTitle: '',
        cover: '',
      ),
      'original-hero-tag',
    );
    controller.pushRelated(
      const ExploreComic(
        id: 'related-comic',
        title: 'Related comic',
        subTitle: '',
        cover: '',
      ),
      'related-hero-tag',
      historyTabIndex: 2,
    );

    expect(controller.canGoBack, isTrue);
    controller.goBack();
    expect(controller.entry?.comic.id, 'original-comic');
    expect(controller.entry?.initialTabIndex, 2);
    expect(controller.canGoBack, isFalse);

    controller.goBack();
    expect(controller.entry, isNull);

    controller.open(
      const ExploreComic(
        id: 'original-comic',
        title: 'Original comic',
        subTitle: '',
        cover: '',
      ),
      'original-hero-tag',
    );
    controller.pushRelated(
      const ExploreComic(
        id: 'related-comic',
        title: 'Related comic',
        subTitle: '',
        cover: '',
      ),
      'related-hero-tag',
      historyTabIndex: 2,
    );
    controller.close();
    expect(controller.entry, isNull);
    expect(controller.canGoBack, isFalse);
  });

  testWidgets('related detail enters upward over the current detail', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }

    final restoreStateByComic = <String, bool>{};
    panelBuilder =
        (
          comic,
          heroTag, {
          required shouldAnimatePanelReveal,
          required isRestoringPreviousDetail,
          required initialTabIndex,
          required showHomeAction,
          required onBackRequested,
          required onHomeRequested,
        }) {
          restoreStateByComic[comic.id] = isRestoringPreviousDetail;
          return ColoredBox(
            key: ValueKey('comic-detail-panel-${comic.id}'),
            color: Colors.white,
          );
        };
    await tester.pumpWidget(
      MaterialApp(
        builder: presentationBuilder,
        home: SizedBox(
          width: 800,
          height: 600,
          child: WindowsComicDetailHost(child: ColoredBox(color: Colors.black)),
        ),
      ),
    );

    controller.open(
      const ExploreComic(
        id: 'original-comic',
        title: 'Original comic',
        subTitle: '',
        cover: '',
      ),
      'original-hero-tag',
    );
    await tester.pumpAndSettle();
    expect(restoreStateByComic['original-comic'], isFalse);

    controller.pushRelated(
      const ExploreComic(
        id: 'related-comic',
        title: 'Related comic',
        subTitle: '',
        cover: '',
      ),
      'related-hero-tag',
      historyTabIndex: 2,
    );
    await tester.pump();
    expect(restoreStateByComic['related-comic'], isFalse);

    final relatedPanel = find.byKey(
      const ValueKey('comic-detail-panel-related-comic'),
    );
    final originalPanel = find.byKey(
      const ValueKey('comic-detail-panel-original-comic'),
    );
    expect(tester.getTopLeft(relatedPanel).dy, greaterThan(0));
    expect(tester.getTopLeft(originalPanel).dy, closeTo(0, 0.01));

    await tester.pump(const Duration(milliseconds: 140));
    expect(tester.getTopLeft(relatedPanel).dy, greaterThan(0));
    expect(tester.getTopLeft(originalPanel).dy, closeTo(0, 0.01));

    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(relatedPanel).dy, closeTo(0, 0.01));

    controller.goBack();
    await tester.pump();
    expect(restoreStateByComic['original-comic'], isTrue);
    await tester.pump(const Duration(milliseconds: 140));

    final restoredOriginalPanel = find.byKey(
      const ValueKey('comic-detail-panel-original-comic'),
    );
    expect(tester.getTopLeft(restoredOriginalPanel).dy, closeTo(0, 0.01));
    expect(tester.getTopLeft(relatedPanel).dy, greaterThan(0));
  });

  testWidgets(
    'nested search routes restore the original detail and related history',
    (tester) async {
      if (!Platform.isWindows) {
        return;
      }
      final navigatorKey = GlobalKey<NavigatorState>();
      panelBuilder =
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
            key: ValueKey('comic-detail-panel-${comic.id}'),
            child: Text('Detail ${comic.id}'),
          );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          builder: presentationBuilder,
          home: const WindowsComicDetailHost(
            child: Scaffold(body: Text('Home')),
          ),
        ),
      );
      controller.open(
        const ExploreComic(
          id: 'root-detail',
          title: 'Root detail',
          subTitle: '',
          cover: '',
        ),
        'root-detail-hero',
      );
      controller.pushRelated(
        const ExploreComic(
          id: 'first-detail',
          title: 'First detail',
          subTitle: '',
          cover: '',
        ),
        'first-detail-hero',
        historyTabIndex: 2,
      );
      await tester.pumpAndSettle();

      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const WindowsComicDetailHost(
            suppressExistingPanel: true,
            child: Scaffold(body: Text('First search')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First search'), findsOneWidget);

      controller.open(
        const ExploreComic(
          id: 'second-detail',
          title: 'Second detail',
          subTitle: '',
          cover: '',
        ),
        'second-detail-hero',
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail second-detail'), findsOneWidget);

      navigatorKey.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const WindowsComicDetailHost(
            suppressExistingPanel: true,
            child: Scaffold(body: Text('Second search')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second search'), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Detail second-detail'), findsOneWidget);

      controller.close();
      await tester.pumpAndSettle();
      expect(find.text('First search'), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pump();
      expect(controller.entry?.comic.id, 'first-detail');
      expect(find.text('Detail first-detail'), findsWidgets);
      expect(find.text('First search'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.entry?.comic.id, 'first-detail');
      expect(find.text('Detail first-detail'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(controller.canGoBack, isTrue);
      controller.goBack();
      await tester.pumpAndSettle();
      expect(find.text('Detail root-detail'), findsOneWidget);
      expect(controller.entry?.heroTag, 'root-detail-hero');
      expect(controller.entry?.initialTabIndex, 2);
      expect(controller.canGoBack, isFalse);
    },
  );

  testWidgets('nested page suppresses only the detail that was already open', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }

    controller.open(
      const ExploreComic(
        id: 'original-comic',
        title: 'Original comic',
        subTitle: '',
        cover: '',
      ),
      'original-hero-tag',
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: presentationBuilder,
        home: SizedBox(
          width: 800,
          height: 600,
          child: WindowsComicDetailHost(
            suppressExistingPanel: true,
            child: ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('comic-detail-panel')), findsNothing);

    controller.open(
      const ExploreComic(
        id: 'search-result-comic',
        title: 'Search result comic',
        subTitle: '',
        cover: '',
      ),
      'search-result-hero-tag',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('comic-detail-panel')), findsOneWidget);
  });

  testWidgets('covered detail stays fixed behind a route transition', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      return;
    }

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        builder: presentationBuilder,
        navigatorKey: navigatorKey,
        home: const SizedBox(
          width: 800,
          height: 600,
          child: WindowsComicDetailHost(child: ColoredBox(color: Colors.black)),
        ),
      ),
    );
    controller.open(
      const ExploreComic(
        id: 'original-comic',
        title: 'Original comic',
        subTitle: '',
        cover: '',
      ),
      'original-hero-tag',
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.push<void>(
      PageRouteBuilder<void>(
        transitionDuration: windowsComicDetailPanelAnimationDuration,
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ColoredBox(color: Colors.blue),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final panel = find.byKey(const ValueKey('comic-detail-panel'));
    expect(tester.getTopLeft(panel).dy, closeTo(0, 0.01));

    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getTopLeft(panel).dy, closeTo(0, 0.01));
  });

  testWidgets('desktop detail shows home beside back only for related pages', (
    tester,
  ) async {
    var backCount = 0;
    var homeCount = 0;
    final collapsedTitle = ValueNotifier<bool>(false);
    addTearDown(collapsedTitle.dispose);

    Widget buildApp({required bool showHomeAction}) {
      return MaterialApp(
        builder: presentationBuilder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: ComicDetailScrollAwareAppBar(
            collapsedTitleListenable: collapsedTitle,
            appBarComicTitle: 'Comic',
            appBarUpdateTime: '',
            theme: ThemeData(),
            isDesktopPanel: true,
            onCloseRequested: () => backCount += 1,
            showHomeAction: showHomeAction,
            onHomeRequested: () => homeCount += 1,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildApp(showHomeAction: false));
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsNothing);

    await tester.pumpWidget(buildApp(showHomeAction: true));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.tap(find.byIcon(Icons.home_outlined));

    expect(backCount, 1);
    expect(homeCount, 1);
  });
}
