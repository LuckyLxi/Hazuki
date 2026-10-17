import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/reader/view/reader_control_surface.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('popover preserves reader backdrop contrast in $brightness', (
      tester,
    ) async {
      await tester.runAsync(HazukiLiquidGlass.initialize);
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));
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
                  height: 360,
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
                      const Positioned(
                        left: 20,
                        top: 58,
                        child: ReaderControlSurface(
                          width: 320,
                          height: 64,
                          borderRadius: 28,
                          fallbackColor: Colors.black54,
                          child: SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        top: 238,
                        child: Builder(
                          builder: (context) => GlassContainer(
                            width: 320,
                            height: 64,
                            useOwnLayer: true,
                            quality: HazukiLiquidGlass.navigationQuality,
                            settings: HazukiLiquidGlass.popoverSettings(
                              context,
                            ),
                            shape: const LiquidRoundedSuperellipse(
                              borderRadius: 28,
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
          final pixels = (await snapshot.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          double luminanceAt(int x, int y) {
            final offset = (y * snapshot.width + x) * 4;
            return Color.fromARGB(
              255,
              pixels.getUint8(offset),
              pixels.getUint8(offset + 1),
              pixels.getUint8(offset + 2),
            ).computeLuminance();
          }

          // A thick white/dark tint loses the artwork's contrast even when
          // its glass rim and transition still render correctly.
          final readerContrast = luminanceAt(112, 90) - luminanceAt(144, 90);
          final popoverContrast = luminanceAt(112, 270) - luminanceAt(144, 270);
          expect(readerContrast, greaterThan(0.6));
          expect(popoverContrast, greaterThan(0.6));
          expect(popoverContrast, closeTo(readerContrast, 0.02));
        } finally {
          snapshot.dispose();
        }
      });
      expect(tester.takeException(), isNull);
    });
  }
}
