import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/home/view/home_bottom_navigation.dart';
import 'package:hazuki/features/reader/view/reader_control_surface.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  const outputDirectory = String.fromEnvironment('HAZUKI_GLASS_PREVIEW_DIR');
  setUpAll(() async {
    if (outputDirectory.isEmpty) return;
    // Real fonts are optional for exported previews; ordinary widget tests
    // retain Flutter's portable test font.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final font = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/${entry.value}',
      );
      final loader = FontLoader(entry.key)
        ..addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      testWidgets('floating controls remain usable in ${brightness.name}, '
          'highContrast=$highContrast', (tester) async {
        await tester.runAsync(HazukiLiquidGlass.initialize);
        await tester.binding.setSurfaceSize(const Size(390, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final previewKey = GlobalKey();
        var selectedIndex = 0;
        var readerActionPressed = false;

        await tester.pumpWidget(
          HazukiLiquidGlass.wrap(
            child: MaterialApp(
              theme: ThemeData(
                brightness: brightness,
                colorSchemeSeed: const Color(0xFF6750A4),
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, 760),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  highContrast: highContrast,
                ),
                child: RepaintBoundary(
                  key: previewKey,
                  child: Material(
                    child: StatefulBuilder(
                      builder: (context, setState) => GlassScaffold(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        enableBackgroundSampling: false,
                        topEdgeFade: false,
                        bottomEdgeFade: false,
                        contentAwareBrightness: false,
                        bottomBarHeight:
                            HomeBottomNavigation.floatingBarHeight +
                            HomeBottomNavigation.floatingVerticalPadding * 2,
                        body: Stack(
                          children: [
                            const Positioned.fill(
                              child: CustomPaint(painter: _BackdropPainter()),
                            ),
                            Positioned(
                              left: 24,
                              right: 24,
                              top: 70,
                              child: Text(
                                'Discover',
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 240,
                              child: ReaderControlSurface(
                                borderRadius: 30,
                                fallbackColor: Colors.black54,
                                padding: const EdgeInsets.all(8),
                                child: TextButton.icon(
                                  onPressed: () => readerActionPressed = true,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        ReaderControlSurface.foregroundColor(
                                          context,
                                        ),
                                  ),
                                  icon: const Icon(Icons.menu_book_rounded),
                                  label: const Text('Continue reading'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        bottomBar: HomeBottomNavigation(
                          currentIndex: selectedIndex,
                          onDestinationSelected: (index) =>
                              setState(() => selectedIndex = index),
                          discoverLabel: 'Discover',
                          favoriteLabel: 'Favorites',
                          showBackToTop: true,
                          backToTopLabel: 'Back to top',
                          onBackToTopPressed: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();

        final bar = find.byType(GlassTabBar);
        final readerAction = find.text('Continue reading');
        final barRect = tester.getRect(bar);
        expect(barRect.bottom, lessThanOrEqualTo(760 - 24));
        expect(tester.getRect(readerAction).overlaps(barRect), isFalse);

        await tester.tap(readerAction);
        expect(readerActionPressed, isTrue);
        await tester.tap(find.byIcon(Icons.favorite_border).first);
        await tester.pumpAndSettle();
        expect(selectedIndex, 1);
        final navigation = tester.widget<GlassTabBar>(bar);
        expect(
          navigation.unselectedIconColor,
          brightness == Brightness.dark ? Colors.white : Colors.black87,
        );
        expect(tester.takeException(), isNull);

        if (outputDirectory.isNotEmpty && !highContrast) {
          await tester.runAsync(() async {
            final boundary =
                previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final snapshot = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = await snapshot.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$outputDirectory/glass-${brightness.name}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
            } finally {
              snapshot.dispose();
            }
          });
        }
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('scrolling light and dark content keeps ${brightness.name} '
        'navigation material stable', (tester) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      late BuildContext glassContext;
      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Material(
              child: Builder(
                builder: (context) {
                  glassContext = context;
                  return GlassScaffold(
                    edgeFade: false,
                    enableBackgroundSampling: false,
                    // Even a sampling ancestor must not recolour navigation.
                    contentAwareBrightness: true,
                    body: ListView.builder(
                      controller: scrollController,
                      itemExtent: 1000,
                      itemCount: 6,
                      itemBuilder: (context, index) => ColoredBox(
                        color: index.isEven ? Colors.black : Colors.white,
                      ),
                    ),
                    bottomBar: HomeBottomNavigation(
                      currentIndex: 0,
                      onDestinationSelected: (_) {},
                      discoverLabel: 'Discover',
                      favoriteLabel: 'Favorites',
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final barFinder = find.byType(GlassTabBar);
      final initialBar = tester.widget<GlassTabBar>(barFinder);
      final initialSettings = initialBar.settings;
      final initialQuality = initialBar.quality;

      // Slow app frames must not silently replace the shader renderer either.
      expect(GlassAdaptiveScopeData.maybeOf(glassContext), isNull);
      expect(find.byType(GlassAdaptiveScope), findsNothing);
      tester.binding.platformDispatcher.onReportTimings?.call([
        for (var frame = 0; frame < 600; frame++)
          ui.FrameTiming(
            vsyncStart: frame * 100000,
            buildStart: frame * 100000,
            buildFinish: frame * 100000 + 1000,
            rasterStart: frame * 100000 + 1000,
            rasterFinish: frame * 100000 + 81000,
            rasterFinishWallTime: frame * 100000 + 81000,
          ),
      ]);

      for (var section = 0; section < 4; section++) {
        scrollController.jumpTo(section * 1000);
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pumpAndSettle();
        final bar = tester.widget<GlassTabBar>(barFinder);
        expect(bar.unselectedIconColor, initialBar.unselectedIconColor);
        expect(bar.selectedIconColor, initialBar.selectedIconColor);
        expect(bar.indicatorColor, initialBar.indicatorColor);
        expect(bar.settings, initialSettings);
        expect(bar.quality, initialQuality);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('navigation glass has a clear ${brightness.name} bevel', (
      tester,
    ) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      final snapshotKey = GlobalKey();
      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Center(
              child: RepaintBoundary(
                key: snapshotKey,
                child: SizedBox(
                  width: 360,
                  height: 180,
                  child: ColoredBox(
                    color: const Color(0xFF808080),
                    child: Center(
                      child: Builder(
                        builder: (context) => GlassContainer(
                          width: 320,
                          height: 64,
                          useOwnLayer: true,
                          quality: GlassQuality.standard,
                          settings: HazukiLiquidGlass.navigationSettings(
                            context,
                          ),
                          shape: const LiquidRoundedSuperellipse(
                            borderRadius: 30,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            snapshotKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final snapshot = await boundary.toImage();
        try {
          final bytes = (await snapshot.toByteData())!;
          double luminanceAt(int x, int y) {
            final pixel = (y * snapshot.width + x) * 4;
            return Color.fromARGB(
              255,
              bytes.getUint8(pixel),
              bytes.getUint8(pixel + 1),
              bytes.getUint8(pixel + 2),
            ).computeLuminance();
          }

          final backdrop = luminanceAt(10, 90);
          final body = luminanceAt(180, 90);
          if (brightness == Brightness.light) {
            expect(body, greaterThan(backdrop + 0.03));
          } else {
            expect(body, lessThan(backdrop - 0.025));
          }
          // Tint should identify the theme without masking the backdrop.
          expect((body - backdrop).abs(), lessThan(0.09));
          // A narrow reflection and inset shade give the edge optical depth.
          final lip = luminanceAt(180, 58);
          final bevel = luminanceAt(180, 60);
          expect(lip, greaterThan(bevel + 0.02));
          expect(bevel, lessThan(body - 0.01));
        } finally {
          snapshot.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    });
  }

  for (final (brightness, reader) in [
    for (final brightness in Brightness.values)
      for (final reader in [false, true]) (brightness, reader),
  ]) {
    testWidgets(
      '${brightness.name} ${reader ? 'reader' : 'clear'} glass preserves '
      'backdrop structure',
      (tester) async {
        await tester.runAsync(HazukiLiquidGlass.initialize);
        final snapshotKey = GlobalKey();
        await tester.pumpWidget(
          HazukiLiquidGlass.wrap(
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Center(
                child: RepaintBoundary(
                  key: snapshotKey,
                  child: SizedBox(
                    width: 360,
                    height: 180,
                    child: Stack(
                      children: [
                        for (var i = 0; i < 12; i++)
                          Positioned(
                            left: i * 32,
                            top: 0,
                            bottom: 0,
                            width: 32,
                            child: ColoredBox(
                              color: i.isEven ? Colors.black : Colors.white,
                            ),
                          ),
                        Center(
                          child: reader
                              ? const ReaderControlSurface(
                                  width: 320,
                                  height: 64,
                                  borderRadius: 30,
                                  fallbackColor: Colors.black54,
                                  child: SizedBox.expand(),
                                )
                              : Builder(
                                  builder: (context) => GlassContainer(
                                    width: 320,
                                    height: 64,
                                    useOwnLayer: true,
                                    quality: GlassQuality.standard,
                                    settings: HazukiLiquidGlass.surfaceSettings(
                                      context,
                                      quality: GlassQuality.standard,
                                    ),
                                    shape: const LiquidRoundedSuperellipse(
                                      borderRadius: 30,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              snapshotKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final snapshot = await boundary.toImage();
          try {
            final bytes = (await snapshot.toByteData())!;
            double luminanceAt(int x) {
              final pixel = (90 * snapshot.width + x) * 4;
              return Color.fromARGB(
                255,
                bytes.getUint8(pixel),
                bytes.getUint8(pixel + 1),
                bytes.getUint8(pixel + 2),
              ).computeLuminance();
            }

            // Broad artwork remains distinct under the light 2px blur.
            // Sample well inside adjacent stripes, clear of the glass rim.
            expect(
              luminanceAt(112) - luminanceAt(144),
              greaterThan(reader ? 0.6 : 0.75),
            );
          } finally {
            snapshot.dispose();
          }
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('navigation tint follows the app theme container colour', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      HazukiLiquidGlass.wrap(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, themeMode, _) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: themeMode,
            home: Builder(
              builder: (context) {
                pageContext = context;
                return Scaffold(
                  bottomNavigationBar: HomeBottomNavigation(
                    currentIndex: 0,
                    onDestinationSelected: (_) {},
                    discoverLabel: 'Discover',
                    favoriteLabel: 'Favorites',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final barFinder = find.byType(GlassTabBar);
    final lightColor = tester
        .widget<GlassTabBar>(barFinder)
        .settings!
        .glassColor;
    expect(
      lightColor,
      Theme.of(
        pageContext,
      ).colorScheme.surfaceContainer.withValues(alpha: 0.16),
    );

    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    final darkColor = tester
        .widget<GlassTabBar>(barFinder)
        .settings!
        .glassColor;
    expect(
      darkColor,
      Theme.of(
        pageContext,
      ).colorScheme.surfaceContainer.withValues(alpha: 0.16),
    );
    expect(
      lightColor.computeLuminance(),
      greaterThan(darkColor.computeLuminance()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('light reader controls remain readable over a white page', (
    tester,
  ) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);
    final snapshotKey = GlobalKey();
    await tester.pumpWidget(
      HazukiLiquidGlass.wrap(
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Center(
            child: RepaintBoundary(
              key: snapshotKey,
              child: const SizedBox(
                width: 360,
                height: 180,
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: ReaderControlSurface(
                      width: 320,
                      height: 64,
                      borderRadius: 30,
                      fallbackColor: Colors.black54,
                      child: Icon(
                        Icons.menu_book_rounded,
                        key: ValueKey('reader-icon'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final iconRect = tester.getRect(find.byKey(const ValueKey('reader-icon')));
    final snapshotRect = tester.getRect(find.byKey(snapshotKey));
    await tester.runAsync(() async {
      final boundary =
          snapshotKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final snapshot = await boundary.toImage();
      try {
        final bytes = await snapshot.toByteData();
        // Sample inside the glass body, clear of the icon and rounded rim.
        final pixel = (90 * snapshot.width + 70) * 4;
        final background = Color.fromARGB(
          255,
          bytes!.getUint8(pixel),
          bytes.getUint8(pixel + 1),
          bytes.getUint8(pixel + 2),
        );
        // The glass body must stay translucent even on a white page.
        expect(background.computeLuminance(), greaterThan(0.35));
        // Contrast is supplied around the glyph instead of by an opaque body.
        final localIcon = iconRect.shift(-snapshotRect.topLeft).inflate(3);
        var darkest = 1.0;
        for (var y = localIcon.top.floor(); y < localIcon.bottom.ceil(); y++) {
          for (
            var x = localIcon.left.floor();
            x < localIcon.right.ceil();
            x++
          ) {
            final pixel = (y * snapshot.width + x) * 4;
            final color = Color.fromARGB(
              255,
              bytes.getUint8(pixel),
              bytes.getUint8(pixel + 1),
              bytes.getUint8(pixel + 2),
            );
            final luminance = color.computeLuminance();
            if (luminance < darkest) darkest = luminance;
          }
        }
        final contrast = 1.05 / (darkest + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      } finally {
        snapshot.dispose();
      }
    });
    expect(tester.takeException(), isNull);
  });
}

/// Deliberately includes fine lines and both light and dark artwork, making
/// backdrop blur, colour retention and foreground contrast visible in previews.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const colours = [Color(0xFF376F8A), Color(0xFFBC7861), Color(0xFF665A91)];
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 2; column++) {
        final rect = Rect.fromLTWH(
          24 + column * (size.width - 36) / 2,
          142 + row * 210,
          (size.width - 60) / 2,
          190,
        );
        canvas.save();
        canvas.clipRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colours[(row + column) % 3], const Color(0xFF202735)],
            ).createShader(rect),
        );
        canvas.drawCircle(
          rect.center.translate(12, -24),
          54,
          Paint()..color = const Color(0x70F5CC99),
        );
        for (var line = 0; line < 7; line++) {
          canvas.drawLine(
            rect.bottomLeft.translate(-30, -line * 18),
            rect.topRight.translate(30, line * 22),
            Paint()
              ..color = const Color(0x55FFFFFF)
              ..strokeWidth = 2,
          );
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}
