import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/home/view/home_content_stack.dart';
import 'package:hazuki/features/home/view/home_drawer_snapshot.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  for (final closing in [false, true]) {
    for (final startDuringDrawer in [false, true]) {
      testWidgets('tab transition keeps painting with closing=$closing, '
          'startsDuringDrawer=$startDuringDrawer', (tester) async {
        await tester.runAsync(HazukiLiquidGlass.initialize);
        addTearDown(() => HazukiLiquidGlass.setEnabled(false));
        final drawer = AnimationController(
          vsync: tester,
          value: closing ? 1 : 0,
          duration: const Duration(milliseconds: 600),
        );
        addTearDown(drawer.dispose);
        final tab = ValueNotifier(0);
        final contentAnimating = ValueNotifier(false);
        addTearDown(tab.dispose);
        addTearDown(contentAnimating.dispose);
        final repaint = ChangeNotifier();
        addTearDown(repaint.dispose);
        final paints = [0, 0];
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: rootKey,
            child: MaterialApp(
              home: HomeDrawerSnapshot(
                animation: drawer,
                contentAnimating: contentAnimating,
                child: ValueListenableBuilder<int>(
                  valueListenable: tab,
                  builder: (context, currentIndex, _) => HomeContentStack(
                    currentIndex: currentIndex,
                    onTransitionChanged: (value) =>
                        contentAnimating.value = value,
                    discoverChild: CustomPaint(
                      painter: _PaintCounter(
                        repaint,
                        () => paints[0]++,
                        color: Colors.red,
                      ),
                    ),
                    favoriteChild: CustomPaint(
                      painter: _PaintCounter(repaint, () => paints[1]++),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (!startDuringDrawer) {
          tab.value = 1;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 32));
        }
        if (closing) {
          drawer.reverse();
        } else {
          drawer.forward();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        if (startDuringDrawer) {
          expect(_snapshot(tester).allowSnapshotting, isTrue);
          tab.value = 1;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(_snapshot(tester).allowSnapshotting, isFalse);

        Future<List<int>> raster() async => (await tester.runAsync(() async {
          final boundary =
              rootKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            return (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
          } finally {
            image.dispose();
          }
        }))!;

        final first = await raster();
        final cachedPaints = List<int>.of(paints);
        repaint.notifyListeners();
        await tester.pump(const Duration(milliseconds: 64));
        expect(
          await raster(),
          isNot(orderedEquals(first)),
          reason: 'the tab transition must visibly advance during the drawer',
        );
        expect(
          paints[0] + paints[1],
          greaterThan(cachedPaints[0] + cachedPaints[1]),
          reason:
              'changing content must keep painting while snapshotting is off',
        );
        // Opacity has finished at 220ms, but the slide continues until 240ms.
        await tester.pump(
          Duration(milliseconds: startDuringDrawer ? 144 : 112),
        );
        expect(contentAnimating.value, isTrue);
        expect(_snapshot(tester).allowSnapshotting, isFalse);
        await tester.pump(const Duration(milliseconds: 32));
        await tester.pump();
        expect(contentAnimating.value, isFalse);
        expect(
          _snapshot(tester).allowSnapshotting,
          isFalse,
          reason: 'do not capture a new full-page raster late in the motion',
        );
        await tester.pumpAndSettle();
        expect(_snapshot(tester).allowSnapshotting, isFalse);
        if (closing) {
          drawer.forward();
        } else {
          drawer.reverse();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          _snapshot(tester).allowSnapshotting,
          isTrue,
          reason: 'the next drawer motion can cache the stationary tab again',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'rapid tab switches avoid recapturing in the current drawer motion',
    (tester) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));
      final drawer = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
      );
      addTearDown(drawer.dispose);
      final tab = ValueNotifier(0);
      final contentAnimating = ValueNotifier(false);
      addTearDown(tab.dispose);
      addTearDown(contentAnimating.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeDrawerSnapshot(
            animation: drawer,
            contentAnimating: contentAnimating,
            child: ValueListenableBuilder<int>(
              valueListenable: tab,
              builder: (context, currentIndex, _) => HomeContentStack(
                currentIndex: currentIndex,
                onTransitionChanged: (value) => contentAnimating.value = value,
                discoverChild: const Text('Discover'),
                favoriteChild: const Text('Favorites'),
              ),
            ),
          ),
        ),
      );
      drawer.forward();
      tab.value = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      tab.value = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(contentAnimating.value, isTrue);
      expect(_snapshot(tester).allowSnapshotting, isFalse);
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump();
      expect(contentAnimating.value, isFalse);
      expect(_snapshot(tester).allowSnapshotting, isFalse);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cache waits for all visible scroll animations to finish', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    final drawer = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 600),
    );
    addTearDown(drawer.dispose);
    final horizontal = PageController();
    final vertical = PageController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDrawerSnapshot(
          animation: drawer,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: horizontal,
                  children: const [Text('A'), Text('B')],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: vertical,
                  scrollDirection: Axis.vertical,
                  children: const [Text('C'), Text('D')],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    horizontal.animateToPage(
      1,
      duration: const Duration(milliseconds: 80),
      curve: Curves.linear,
    );
    vertical.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
    );
    drawer.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(horizontal.position.isScrollingNotifier.value, isFalse);
    expect(vertical.position.isScrollingNotifier.value, isTrue);
    expect(_snapshot(tester).allowSnapshotting, isFalse);
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump();
    expect(_snapshot(tester).allowSnapshotting, isTrue);
    await tester.pumpAndSettle();
    expect(_snapshot(tester).allowSnapshotting, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling content stays live while the header keeps its cache', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    final drawer = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 600),
    );
    addTearDown(drawer.dispose);
    final pages = PageController();
    addTearDown(pages.dispose);
    const bodyKey = ValueKey('body-snapshot');
    const headerKey = ValueKey('header-snapshot');
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDrawerSnapshot(
          key: bodyKey,
          animation: drawer,
          child: Column(
            children: [
              HomeDrawerSnapshot(
                key: headerKey,
                animation: drawer,
                child: const Text('Header'),
              ),
              Expanded(
                child: PageView(
                  controller: pages,
                  children: const [Text('First'), Text('Second')],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    SnapshotController controller(Key key) => tester
        .widget<GlassSnapshot>(
          find
              .descendant(
                of: find.byKey(key),
                matching: find.byType(GlassSnapshot),
              )
              .first,
        )
        .controller;
    drawer.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller(bodyKey).allowSnapshotting, isTrue);
    pages.animateToPage(
      1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.linear,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 48));
    expect(controller(bodyKey).allowSnapshotting, isFalse);
    expect(controller(headerKey).allowSnapshotting, isTrue);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    expect(
      controller(bodyKey).allowSnapshotting,
      isTrue,
      reason: 'a stationary page can reuse its raster again',
    );
    await tester.pumpAndSettle();
    expect(controller(bodyKey).allowSnapshotting, isFalse);
    expect(controller(headerKey).allowSnapshotting, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hidden autoplay carousel does not prevent Favorites caching', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    final drawer = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 210),
    );
    addTearDown(drawer.dispose);
    final pages = PageController();
    addTearDown(pages.dispose);
    final opacity = ValueNotifier(0.0);
    addTearDown(opacity.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDrawerSnapshot(
          animation: drawer,
          child: Stack(
            children: [
              ValueListenableBuilder<double>(
                valueListenable: opacity,
                builder: (context, value, child) => AnimatedOpacity(
                  opacity: value,
                  duration: const Duration(milliseconds: 220),
                  child: child,
                ),
                child: PageView(
                  controller: pages,
                  children: const [Text('First'), Text('Second')],
                ),
              ),
              const Text('Favorites'),
            ],
          ),
        ),
      ),
    );
    pages.animateToPage(
      1,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.linear,
    );
    drawer.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_snapshot(tester).allowSnapshotting, isTrue);
    opacity.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(
      _snapshot(tester).allowSnapshotting,
      isFalse,
      reason: 'the moving carousel must stay live when its tab becomes visible',
    );
    await tester.pumpAndSettle();
    expect(_snapshot(tester).allowSnapshotting, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final tab in ['Discover', 'Favorites']) {
    testWidgets('$tab reuses its raster on drawer open and close', (
      tester,
    ) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 210),
        reverseDuration: const Duration(milliseconds: 160),
      );
      addTearDown(animation.dispose);
      final repaint = ChangeNotifier();
      addTearDown(repaint.dispose);
      var paints = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: animation,
            child: HomeDrawerSnapshot(
              animation: animation,
              child: CustomPaint(
                painter: _PaintCounter(repaint, () => paints++),
                child: Text(tab),
              ),
            ),
            builder: (context, child) => Transform.translate(
              offset: Offset(18 * animation.value, 0),
              child: Transform.scale(
                scale: 1 - 0.035 * animation.value,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
          ),
        ),
      );
      final page = tester.element(find.text(tab));

      for (final open in [true, false]) {
        if (open) {
          animation.forward();
        } else {
          animation.reverse();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(_snapshot(tester).allowSnapshotting, isTrue);
        final cachedPaints = paints;
        for (var i = 0; i < 4; i++) {
          repaint.notifyListeners();
          await tester.pump(const Duration(milliseconds: 16));
          expect(paints, cachedPaints);
        }
        await tester.pumpAndSettle();
        expect(_snapshot(tester).allowSnapshotting, isFalse);
        final livePaints = paints;
        repaint.notifyListeners();
        await tester.pump();
        expect(paints, greaterThan(livePaints));
        expect(tester.element(find.text(tab)), same(page));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reversing mid-animation keeps the cache until resting', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 210),
      reverseDuration: const Duration(milliseconds: 160),
    );
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDrawerSnapshot(
          animation: animation,
          child: const Text('Home'),
        ),
      ),
    );
    animation.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final snapshot = _snapshot(tester);
    animation.reverse();
    await tester.pump(const Duration(milliseconds: 16));
    expect(_snapshot(tester), same(snapshot));
    expect(snapshot.allowSnapshotting, isTrue);
    await tester.pumpAndSettle();
    expect(snapshot.allowSnapshotting, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final enabled in [false, true]) {
    testWidgets('cache honors glass availability and enabled=$enabled', (
      tester,
    ) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 210),
      );
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeDrawerSnapshot(
            animation: animation,
            enabled: enabled,
            child: const Text('Home'),
          ),
        ),
      );
      final page = tester.element(find.text('Home'));
      animation.forward();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_snapshot(tester).allowSnapshotting, enabled);
      await HazukiLiquidGlass.setEnabled(false);
      await tester.pump();
      expect(_snapshot(tester).allowSnapshotting, isFalse);
      expect(tester.element(find.text('Home')), same(page));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending capture does not outlive its widget', (tester) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    addTearDown(() => HazukiLiquidGlass.setEnabled(false));
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 210),
    );
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeDrawerSnapshot(
          animation: animation,
          child: const Text('Home'),
        ),
      ),
    );
    animation.forward();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drawer avatar flies without a second avatar in the cached page',
    (tester) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));
      final animation = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 210),
        reverseDuration: const Duration(milliseconds: 160),
      );
      addTearDown(animation.dispose);
      final rootKey = GlobalKey();
      const homeAvatarKey = ValueKey('home-avatar');
      Widget avatar({Key? key}) => Hero(
        key: key,
        tag: 'avatar',
        child: const SizedBox(
          width: 80,
          height: 80,
          child: ColoredBox(color: Colors.red),
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: rootKey,
          child: MaterialApp(
            home: AnimatedBuilder(
              animation: animation,
              child: HomeDrawerSnapshot(
                animation: animation,
                child: Scaffold(
                  backgroundColor: Colors.white,
                  body: Align(
                    alignment: Alignment.topRight,
                    child: avatar(key: homeAvatarKey),
                  ),
                ),
              ),
              builder: (context, child) => Transform.translate(
                offset: Offset(18 * animation.value, 0),
                child: Transform.scale(
                  scale: 1 - 0.035 * animation.value,
                  alignment: Alignment.centerRight,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      Future<void> expectEmptyHomeAvatar() async {
        final point =
            tester.getTopLeft(find.byKey(homeAvatarKey)) + const Offset(30, 30);
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final color = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset =
                (point.dy.floor() * image.width + point.dx.floor()) * 4;
            return Color.fromARGB(
              pixels.getUint8(offset + 3),
              pixels.getUint8(offset),
              pixels.getUint8(offset + 1),
              pixels.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        });
        expect(color, Colors.white);
      }

      animation.forward();
      navigator.push(
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: const Duration(milliseconds: 210),
          reverseTransitionDuration: const Duration(milliseconds: 160),
          pageBuilder: (_, animation, secondaryAnimation) => Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 300,
              child: Scaffold(
                backgroundColor: Colors.white,
                body: Align(alignment: Alignment.bottomLeft, child: avatar()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_snapshot(tester).allowSnapshotting, isTrue);
      await expectEmptyHomeAvatar();
      await tester.pumpAndSettle();

      animation.reverse();
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_snapshot(tester).allowSnapshotting, isTrue);
      await expectEmptyHomeAvatar();
      await tester.pumpAndSettle();
      expect(_snapshot(tester).allowSnapshotting, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

SnapshotController _snapshot(WidgetTester tester) =>
    tester.widget<GlassSnapshot>(find.byType(GlassSnapshot)).controller;

class _PaintCounter extends CustomPainter {
  _PaintCounter(Listenable repaint, this.onPaint, {this.color = Colors.blue})
    : super(repaint: repaint);

  final VoidCallback onPaint;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
