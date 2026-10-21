import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  for (final dpr in [1.0, 1.5, 2.0, 3.0]) {
    testWidgets('Windows lens follows Android circular arc at DPR $dpr',
        (tester) async {
      await tester.runAsync(() async {
        final program = await ui.FragmentProgram.fromAsset(
            'shaders/lightweight_glass.frag');
        for (final model in [
          GlassLensModel.circularArc,
          GlassLensModel.circularArcWithDepth,
        ]) {
          final shader = program.fragmentShader();
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..scale(dpr);
          canvas.drawRect(
            const Rect.fromLTWH(0, 0, 320, 160),
            Paint()
              ..shader = ui.Gradient.linear(
                Offset.zero,
                const Offset(0, 160),
                [Colors.black, const Color(0xFF008000)],
              ),
          );
          final picture = recorder.endRecording();
          final backdrop =
              await picture.toImage((320 * dpr).round(), (160 * dpr).round());
          picture.dispose();
          final uniforms = <double>[
            240, 64, 40 * dpr, 20 * dpr,
            0, 0, 0, 0, // No tint.
            72, 0, -1, 0, // No directional light.
            0, 1, 1.18, 0,
            32, dpr, dpr, 0,
            0, 0, 1, 0.85,
            0, 0, 0, 0,
            40, 20, 320, 160,
            0, 0, 1, // No absorption/Fresnel; clear body.
            model.index.toDouble(), 24, 0, 0, 0, 0,
          ];
          for (var i = 0; i < uniforms.length; i++) {
            shader.setFloat(i, uniforms[i]);
          }
          shader.setImageSampler(0, backdrop,
              filterQuality: FilterQuality.medium);
          final outputRecorder = ui.PictureRecorder();
          Canvas(outputRecorder).drawRect(
            Rect.fromLTWH(40 * dpr, 20 * dpr, 240 * dpr, 64 * dpr),
            Paint()..shader = shader,
          );
          final outputPicture = outputRecorder.endRecording();
          final image = await outputPicture.toImage(
              (320 * dpr).round(), (160 * dpr).round());
          outputPicture.dispose();
          try {
            final pixels = (await image.toByteData())!;
            for (final depth in [2, 6, 12, 18, 26, 32]) {
              final x = (120 * dpr).floor();
              final y = ((20 + depth) * dpr).floor();
              final logicalY = (y + 0.5) / dpr;
              final slope = (1 - (logicalY - 20) / 24).clamp(0.0, 1.0);
              final displacement = 24 * (1 - math.sqrt(1 - slope * slope));
              var direction = const Offset(0, -1);
              if (model == GlassLensModel.circularArcWithDepth) {
                final radial = Offset((x + 0.5) / dpr - 160, logicalY - 52);
                direction += radial / radial.distance;
                direction /= direction.distance;
              }
              final sampleY = logicalY - direction.dy * displacement;
              final offset = (y * image.width + x) * 4;
              expect(
                  pixels.getUint8(offset + 1), closeTo(sampleY / 160 * 128, 2),
                  reason: '$model, depth=$depth, DPR=$dpr');
              expect(pixels.getUint8(offset + 3), 255);
            }
          } finally {
            image.dispose();
            shader.dispose();
            backdrop.dispose();
          }
        }
      });
    });
  }

  testWidgets('shared backdrop refreshes nested repaints and settles when idle',
      (tester) async {
    await tester.runAsync(LightweightLiquidGlass.preWarm);
    final color = ValueNotifier<Color>(Colors.red);
    addTearDown(color.dispose);
    final resultKey = GlobalKey();
    late ui.Image? Function() latestBackdrop;
    await tester.pumpWidget(MaterialApp(
      home: GlassBackdropScope(
        child: Builder(builder: (context) {
          final data = GlassBackdropScope.maybeOf(context)!;
          latestBackdrop = () => data.image;
          return RepaintBoundary(
            key: resultKey,
            child: Stack(fit: StackFit.expand, children: [
              GlassBackdropSource(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<Color>(
                    valueListenable: color,
                    builder: (_, value, __) => ColoredBox(
                      color: value,
                      child: const Align(
                        alignment: Alignment.bottomRight,
                        child: AdaptiveGlass(
                          shape: LiquidRoundedRectangle(borderRadius: 20),
                          settings: LiquidGlassSettings(
                            lensModel: GlassLensModel.circularArc,
                            refractionAmount: 24,
                            blur: 0,
                          ),
                          child: SizedBox(width: 100, height: 50),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final x in [20.0, 160.0])
                Positioned(
                  left: x,
                  top: 20,
                  child: const RepaintBoundary(
                    child: AdaptiveGlass(
                      shape: LiquidRoundedRectangle(borderRadius: 20),
                      settings: LiquidGlassSettings(
                        lensModel: GlassLensModel.circularArc,
                        thickness: 72,
                        refractionAmount: 24,
                        blur: 0,
                        saturation: 1,
                        lightIntensity: 0,
                        fresnelStrength: 0,
                        shadowElevation: 0,
                        bodyMode: GlassBodyMode.clear,
                      ),
                      child: SizedBox(width: 120, height: 64),
                    ),
                  ),
                ),
            ]),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    final firstBackdrop = latestBackdrop();
    expect(firstBackdrop, isNotNull);
    Future<void> expectColor(Color expected) async {
      final boundary =
          resultKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final pixels = (await image.toByteData())!;
          for (final x in [80, 220]) {
            final offset = (52 * image.width + x) * 4;
            expect(pixels.getUint8(offset), (expected.r * 255).round());
            expect(pixels.getUint8(offset + 1), (expected.g * 255).round());
            expect(pixels.getUint8(offset + 2), (expected.b * 255).round());
          }
          const previewDirectory =
              String.fromEnvironment('HAZUKI_GLASS_PREVIEW_DIR');
          if (previewDirectory.isNotEmpty) {
            final bytes =
                (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final file = File('$previewDirectory/windows-backdrop.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
          }
        } finally {
          image.dispose();
        }
      });
    }

    await expectColor(Colors.red);
    color.value = Colors.blue;
    await tester.pumpAndSettle();
    expect(latestBackdrop(), isNot(same(firstBackdrop)));
    await expectColor(Colors.blue);
    color.value = Colors.black;
    await tester.pumpAndSettle();
    await expectColor(Colors.black);
    final idleBackdrop = latestBackdrop();
    await tester.pump(const Duration(seconds: 1));
    expect(latestBackdrop(), same(idleBackdrop));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('Windows scaffold renders circular material, dark=$dark',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(640, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(LightweightLiquidGlass.preWarm);
      final key = GlobalKey();
      final settings = LiquidGlassSettings(
        thickness: 72,
        blur: 2,
        refractiveIndex: 1.18,
        lensModel: GlassLensModel.circularArc,
        refractionAmount: 24,
        chromaticAberration: 0,
        lightAngle: math.pi * 0.75,
        lightIntensity: 0.65,
        fresnelStrength: 1.2,
        edgeAbsorption: dark ? 0.14 : 0.12,
        rimShade: dark ? 0.45 : 0.65,
        rimShadeEnds: dark ? 0 : 0.2,
        rimLight: dark ? 1.05 : 0.85,
        saturation: 1.15,
        glassColor: dark ? const Color(0x291D1B20) : const Color(0x29F3EDF7),
        bodyMode: GlassBodyMode.clear,
        shadowElevation: 0,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: GlassScaffold(
            enableBackdropRefraction: true,
            edgeFade: false,
            body: const CustomPaint(painter: _PreviewBackdrop()),
            bodyOverlays: [
              for (final rect in [
                const Rect.fromLTWH(32, 30, 56, 56),
                const Rect.fromLTWH(200, 30, 240, 64),
                const Rect.fromLTWH(50, 260, 540, 64),
              ])
                Positioned.fromRect(
                  rect: rect,
                  child: AdaptiveGlass(
                    shape: const LiquidRoundedRectangle(borderRadius: 32),
                    settings: settings,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
      const previewDirectory =
          String.fromEnvironment('HAZUKI_GLASS_PREVIEW_DIR');
      if (previewDirectory.isEmpty) return;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final file =
              File('$previewDirectory/windows-${dark ? 'dark' : 'light'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    });
  }
}

class _PreviewBackdrop extends CustomPainter {
  const _PreviewBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
            Offset.zero, size.bottomRight(Offset.zero), [
          const Color(0xFF336E86),
          const Color(0xFFBC7861),
          const Color(0xFF443B70)
        ], [
          0,
          0.5,
          1
        ]),
    );
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          Paint()..color = Colors.white38);
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), Paint()..color = Colors.white38);
    }
    canvas.drawCircle(
        const Offset(310, 60), 32, Paint()..color = const Color(0x88F2C681));
  }

  @override
  bool shouldRepaint(_PreviewBackdrop oldDelegate) => false;
}
