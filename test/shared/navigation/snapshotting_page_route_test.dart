import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/support/search_page_route.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';

void main() {
  Future<void> enableGlass(WidgetTester tester) async {
    await tester.runAsync(() => HazukiLiquidGlass.initialize());
    expect(HazukiLiquidGlass.isAvailable, isTrue);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
  }

  for (final snapshotEntrance in [false, true]) {
    testWidgets('glass background is cached on push and pop, '
        'snapshotEntrance=$snapshotEntrance', (tester) async {
      await enableGlass(tester);
      await tester.pumpWidget(_app());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final route = buildSnapshottingPageRoute<void>(
        allowSnapshotting: snapshotEntrance,
        builder: (_) => const Scaffold(body: Text('Detail')),
      );

      navigator.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isSnapshotting('Home'), isTrue);
      expect(_isSnapshotting('Detail'), snapshotEntrance);
      await tester.pumpAndSettle();
      expect(_isSnapshotting('Home'), isFalse);
      expect(_isSnapshotting('Detail'), isFalse);

      // Even details with live entrance reveals can cache their background
      // when a search/reader destination moves over them.
      navigator.push(
        buildSearchEntryPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Search')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isSnapshotting('Detail'), isTrue);
      expect(_isSnapshotting('Search'), isTrue);
      await tester.pumpAndSettle();
      expect(_isSnapshotting('Detail'), isFalse);
      expect(_isSnapshotting('Search'), isFalse);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isSnapshotting('Detail'), isTrue);
      expect(_isSnapshotting('Search'), isTrue);
      await tester.pumpAndSettle();
      expect(_isSnapshotting('Detail'), isFalse);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isSnapshotting('Home'), isTrue);
      expect(_isSnapshotting('Detail'), snapshotEntrance);
      await tester.pumpAndSettle();
      expect(_isSnapshotting('Home'), isFalse);
      expect(find.text('Detail'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling a back swipe releases both snapshots', (
    tester,
  ) async {
    await enableGlass(tester);
    await tester.pumpWidget(_app());
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      buildSearchEntryPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Search')),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(150, 0));
    await tester.pump();
    expect(navigator.userGestureInProgress, isTrue);
    expect(_isSnapshotting('Home'), isTrue);
    expect(_isSnapshotting('Search'), isTrue);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(navigator.userGestureInProgress, isFalse);
    expect(find.text('Search'), findsOneWidget);
    expect(_isSnapshotting('Home'), isFalse);
    expect(_isSnapshotting('Search'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass toggle updates caching without remounting the route', (
    tester,
  ) async {
    await enableGlass(tester);
    await tester.pumpWidget(_app());
    final homeElement = tester.element(find.text('Home'));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      buildSearchEntryPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Search')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_isSnapshotting('Home'), isTrue);

    await HazukiLiquidGlass.setEnabled(false);
    await tester.pump();
    expect(_isSnapshotting('Home'), isFalse);
    expect(_isSnapshotting('Search'), isTrue);
    expect(tester.element(find.text('Home')), same(homeElement));

    await HazukiLiquidGlass.setEnabled(true);
    await tester.pump();
    expect(_isSnapshotting('Home'), isTrue);
    expect(tester.element(find.text('Home')), same(homeElement));
    await tester.pumpAndSettle();
    expect(_isSnapshotting('Search'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hero flight stays live above the cached glass pages', (
    tester,
  ) async {
    await enableGlass(tester);
    Widget hero(String label, Alignment alignment) => Align(
      alignment: alignment,
      child: Hero(
        tag: 'search',
        flightShuttleBuilder: (_, animation, direction, from, to) =>
            const SizedBox(width: 80, height: 40, child: Text('Flight')),
        child: SizedBox(width: 80, height: 40, child: Text(label)),
      ),
    );

    await tester.pumpWidget(_app(background: hero('Home', Alignment.topLeft)));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      buildSearchEntryPageRoute<void>(
        builder: (_) => Scaffold(
          key: const ValueKey('search-page'),
          body: hero('Search', Alignment.bottomRight),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _isSnapshottingFinder(find.byKey(const ValueKey('home-page'))),
      isTrue,
    );
    expect(
      _isSnapshottingFinder(find.byKey(const ValueKey('search-page'))),
      isTrue,
    );
    final firstPosition = tester.getCenter(find.text('Flight'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getCenter(find.text('Flight')).dx,
      greaterThan(firstPosition.dx),
    );
    expect(_isSnapshotting('Flight'), isFalse);
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final returnPosition = tester.getCenter(find.text('Flight'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getCenter(find.text('Flight')).dx,
      lessThan(returnPosition.dx),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final snapshotEntrance in [false, true]) {
    testWidgets('hero placeholders stay empty in push and pop snapshots, '
        'snapshotEntrance=$snapshotEntrance', (tester) async {
      await enableGlass(tester);
      final rootKey = GlobalKey();
      const homeHeroKey = ValueKey('home-hero');
      const detailHeroKey = ValueKey('detail-hero');
      Widget hero(Key key, Alignment alignment) => Align(
        alignment: alignment,
        child: Hero(
          key: key,
          tag: 'cover',
          child: const SizedBox(
            width: 80,
            height: 80,
            child: ColoredBox(color: Colors.red),
          ),
        ),
      );

      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.android),
            home: RouteTransitionSnapshot(
              child: Scaffold(
                backgroundColor: Colors.white,
                body: hero(homeHeroKey, Alignment.topCenter),
              ),
            ),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final boundary =
          rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      Future<void> expectEmptyPlaceholder(Key key) async {
        // Sample inside the page's original Hero position, away from the
        // moving overlay Hero. Widget visibility alone cannot detect a Hero
        // left behind in the cached raster.
        final point = tester.getTopLeft(find.byKey(key)) + const Offset(40, 20);
        final pixel = await _pixelAt(tester, boundary, point);
        expect(pixel.r, greaterThan(0.8));
        expect(pixel.g, closeTo(pixel.r, 0.01));
        expect(pixel.b, closeTo(pixel.r, 0.01));
      }

      navigator.push(
        buildSnapshottingPageRoute<void>(
          allowSnapshotting: snapshotEntrance,
          builder: (_) => Scaffold(
            backgroundColor: Colors.white,
            body: hero(detailHeroKey, Alignment.bottomLeft),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await expectEmptyPlaceholder(homeHeroKey);
      await tester.pumpAndSettle();

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await expectEmptyPlaceholder(detailHeroKey);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('glass background reuses its raster until the transition ends', (
    tester,
  ) async {
    await enableGlass(tester);
    final repaint = ChangeNotifier();
    addTearDown(repaint.dispose);
    var paints = 0;
    await tester.pumpWidget(
      _app(
        background: CustomPaint(
          painter: _PaintCounter(repaint, () => paints++),
          child: const Text('Home'),
        ),
      ),
    );
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      buildSnapshottingPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final capturedPaints = paints;
    for (var i = 0; i < 5; i++) {
      repaint.notifyListeners();
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(paints, capturedPaints);

    navigator.pop();
    await tester.pumpAndSettle();
    final restoredPaints = paints;
    repaint.notifyListeners();
    await tester.pump();
    expect(paints, greaterThan(restoredPaints));
    expect(_isSnapshotting('Home'), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final glass in [false, true]) {
    for (final snapshotEntrance in [false, true]) {
      testWidgets('Hero endpoints do not scroll during push or pop, '
          'glass=$glass, snapshotEntrance=$snapshotEntrance', (tester) async {
        if (glass) {
          await enableGlass(tester);
        } else {
          await HazukiLiquidGlass.setEnabled(false);
        }
        final homeScroll = ScrollController(initialScrollOffset: 120);
        final detailScroll = ScrollController(initialScrollOffset: 120);
        addTearDown(homeScroll.dispose);
        addTearDown(detailScroll.dispose);

        Widget page(ScrollController controller, double topPadding) => Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                SizedBox(height: topPadding, width: double.infinity),
                Hero(
                  tag: 'cover',
                  flightShuttleBuilder: (_, _, _, _, _) =>
                      const ColoredBox(color: Colors.red),
                  child: const SizedBox(
                    width: 80,
                    height: 120,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 1800),
              ],
            ),
          ),
        );

        await tester.pumpWidget(_app(background: page(homeScroll, 200)));
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          buildSnapshottingPageRoute<void>(
            allowSnapshotting: snapshotEntrance,
            builder: (_) => page(detailScroll, 400),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        Future<void> scrollAt(Offset position, double delta) async {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: position,
              scrollDelta: Offset(0, delta),
            ),
          );
          await tester.pump(const Duration(milliseconds: 16));
        }

        // The entering page is visible along the right edge; the underlying
        // page is visible along the left edge of the horizontal transition.
        for (final delta in [80.0, -80.0]) {
          await scrollAt(const Offset(750, 350), delta);
          expect(detailScroll.offset, 120);
          expect(homeScroll.offset, 120);
          await tester.dragFrom(const Offset(750, 350), Offset(0, delta));
          await tester.pump(const Duration(milliseconds: 16));
          expect(detailScroll.offset, 120);
          expect(homeScroll.offset, 120);
        }
        await tester.pumpAndSettle();
        await scrollAt(const Offset(400, 350), 80);
        expect(detailScroll.offset, greaterThan(120));
        detailScroll.jumpTo(120);

        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        for (final delta in [80.0, -80.0]) {
          await scrollAt(const Offset(20, 350), delta);
          expect(homeScroll.offset, 120);
          expect(detailScroll.offset, 120);
          await tester.dragFrom(const Offset(20, 350), Offset(0, delta));
          await tester.pump(const Duration(milliseconds: 16));
          expect(homeScroll.offset, 120);
          expect(detailScroll.offset, 120);
        }
        await tester.pumpAndSettle();
        await scrollAt(const Offset(400, 350), 80);
        expect(homeScroll.offset, greaterThan(120));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

Widget _app({Widget? background}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.android),
  home: RouteTransitionSnapshot(
    child: Scaffold(
      key: const ValueKey('home-page'),
      body: background ?? const Text('Home'),
    ),
  ),
);

Future<Color> _pixelAt(
  WidgetTester tester,
  RenderRepaintBoundary boundary,
  Offset point,
) async => (await tester.runAsync(() async {
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    return Color.fromARGB(
      data.getUint8(index + 3),
      data.getUint8(index),
      data.getUint8(index + 1),
      data.getUint8(index + 2),
    );
  } finally {
    image.dispose();
  }
}))!;

bool _isSnapshotting(String text) =>
    _isSnapshottingFinder(find.text(text, skipOffstage: false));

bool _isSnapshottingFinder(Finder finder) => find
    .ancestor(
      of: finder,
      matching: find.byType(SnapshotWidget, skipOffstage: false),
    )
    .evaluate()
    .map((element) => element.widget as SnapshotWidget)
    .any((widget) => widget.controller.allowSnapshotting);

class _PaintCounter extends CustomPainter {
  _PaintCounter(Listenable repaint, this.onPaint) : super(repaint: repaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
