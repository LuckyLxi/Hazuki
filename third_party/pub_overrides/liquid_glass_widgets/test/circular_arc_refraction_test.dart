import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  test('circular refraction survives transitions and fades with visibility',
      () {
    expect(const LiquidGlassSettings().effectiveRefractionAmount, 0);
    const lens = LiquidGlassSettings(
      lensModel: GlassLensModel.circularArc,
      refractionAmount: 24,
    );
    expect(lens.copyWith(visibility: 0).effectiveRefractionAmount, 0);
    expect(lens.copyWith(visibility: 0.5).effectiveRefractionAmount, 12);
    expect(lens.copyWithPinch(0.4).refractionAmount, 24);
    expect(lens.copyWith(blur: 4).lensModel, GlassLensModel.circularArc);
    expect(
      LiquidGlassSettings.lerp(const LiquidGlassSettings(), lens, 0.5)
          .refractionAmount,
      12,
    );
    expect({lens, lens.copyWith(), const LiquidGlassSettings()}, hasLength(2));
    expect(
      const LiquidGlassSettings(refractionAmount: -1).effectiveRefractionAmount,
      0,
    );
  });

  for (final dpr in [1.0, 2.0, 3.0]) {
    for (final captureOffset in [Offset.zero, const Offset(20, 10)]) {
      for (final model in [
        GlassLensModel.circularArc,
        GlassLensModel.circularArcWithDepth
      ]) {
        testWidgets(
            '$model follows reference curve at DPR $dpr, '
            'capture=$captureOffset', (tester) async {
          await tester.runAsync(() async {
            final renderProgram = await ui.FragmentProgram.fromAsset(
              'shaders/liquid_glass_render.frag',
            );
            final geometryProgram = await ui.FragmentProgram.fromAsset(
              'shaders/liquid_glass_geometry_blended.frag',
            );
            final image = await _renderLens(
              renderProgram,
              geometryProgram,
              dpr,
              captureOffset,
              model,
            );
            try {
              final pixels = (await image.toByteData())!;
              // The backdrop encodes its sample y-coordinate in the green
              // channel. Check the real geometry + render shaders against the
              // reference's circular-arc equation, including the flat centre.
              for (final depth in [2, 6, 12, 18, 26, 32]) {
                final y = ((20 + depth) * dpr).floor();
                final logicalY = (y + 0.5) / dpr;
                final distance = logicalY - 20;
                final slope = (1 - distance / 24).clamp(0.0, 1.0);
                final displacement = 24 * (1 - math.sqrt(1 - slope * slope));
                final logicalX = ((120 * dpr).floor() + 0.5) / dpr;
                var direction = const Offset(0, -1);
                if (model == GlassLensModel.circularArcWithDepth) {
                  final radial = Offset(logicalX - 160, logicalY - 52);
                  direction += radial / radial.distance;
                  direction /= direction.distance;
                }
                final sampledY =
                    logicalY + captureOffset.dy - direction.dy * displacement;
                final pixel = (y * image.width + (120 * dpr).floor()) * 4;
                expect(
                  pixels.getUint8(pixel + 1),
                  closeTo(sampledY / 160 * 255, 2),
                  reason:
                      'depth=$depth must follow the circular arc at DPR $dpr',
                );
                final sampledX =
                    logicalX + captureOffset.dx - direction.dx * displacement;
                expect(
                    pixels.getUint8(pixel), closeTo(sampledX / 320 * 255, 2));
              }
            } finally {
              image.dispose();
            }
            const previewDirectory =
                String.fromEnvironment('HAZUKI_GLASS_PREVIEW_DIR');
            if (previewDirectory.isNotEmpty &&
                dpr == 3 &&
                captureOffset == Offset.zero &&
                model == GlassLensModel.circularArc) {
              for (final dark in [false, true]) {
                final preview = await _renderLens(
                  renderProgram,
                  geometryProgram,
                  dpr,
                  captureOffset,
                  model,
                  tint:
                      dark ? const Color(0x66211D25) : const Color(0x66F2ECF4),
                );
                try {
                  final bytes = (await preview.toByteData(
                      format: ui.ImageByteFormat.png))!;
                  final file = File(
                      '$previewDirectory/premium-${dark ? 'dark' : 'light'}.png');
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(bytes.buffer.asUint8List());
                } finally {
                  preview.dispose();
                }
              }
            }
          });
        });
      }
    }
  }
}

Future<ui.Image> _renderLens(
  ui.FragmentProgram renderProgram,
  ui.FragmentProgram geometryProgram,
  double dpr,
  Offset captureOffset,
  GlassLensModel model, {
  Color? tint,
}) async {
  final width = (320 * dpr).round();
  final height = (160 * dpr).round();
  const bounds = Rect.fromLTWH(40, 20, 240, 64);
  final backdropRecorder = ui.PictureRecorder();
  final backdropCanvas = Canvas(backdropRecorder);
  backdropCanvas.drawPaint(Paint()
    ..shader = ui.Gradient.linear(
      Offset.zero,
      Offset(width.toDouble(), 0),
      [const Color(0xFF000000), const Color(0xFFFF0000)],
    ));
  if (tint != null) {
    backdropCanvas.drawPaint(Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(width.toDouble(), height.toDouble()),
        [
          const Color(0xFF336E86),
          const Color(0xFFBC7861),
          const Color(0xFF443B70)
        ],
        [0, 0.5, 1],
      ));
    for (var x = 0; x < 320; x += 24) {
      backdropCanvas.drawLine(
          Offset(x * dpr, 0),
          Offset(x * dpr, height.toDouble()),
          Paint()
            ..color = const Color(0x88FFFFFF)
            ..strokeWidth = dpr);
    }
    for (var y = 0; y < 160; y += 24) {
      backdropCanvas.drawLine(
          Offset(0, y * dpr),
          Offset(width.toDouble(), y * dpr),
          Paint()
            ..color = const Color(0x88FFFFFF)
            ..strokeWidth = dpr);
    }
    backdropCanvas.drawCircle(Offset(100 * dpr, 54 * dpr), 32 * dpr,
        Paint()..color = const Color(0x88F2C681));
  }
  if (tint == null) {
    backdropCanvas.drawPaint(Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, height.toDouble()),
        [const Color(0xFF000000), const Color(0xFF00FF00)],
      ));
  }
  final backdropPicture = backdropRecorder.endRecording();
  final backdrop = await backdropPicture.toImage(width, height);
  backdropPicture.dispose();
  ui.Image? blurred;
  if (tint != null) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(
        backdrop,
        Offset.zero,
        Paint()
          ..imageFilter =
              ui.ImageFilter.blur(sigmaX: 4 * dpr, sigmaY: 4 * dpr));
    final picture = recorder.endRecording();
    blurred = await picture.toImage(width, height);
    picture.dispose();
  }

  final geometryShader = geometryProgram.fragmentShader();
  for (var index = 0; index <= 120; index++) {
    geometryShader.setFloat(index, 0);
  }
  final geometryValues = <double>[
    bounds.width * dpr,
    bounds.height * dpr,
    1.18,
    0,
    72 * dpr / 3,
    0,
    1,
    dpr,
    3,
    bounds.width * dpr / 2,
    bounds.height * dpr / 2,
    bounds.width * dpr,
    bounds.height * dpr,
    32 * dpr,
    32 * dpr,
  ];
  for (var index = 0; index < geometryValues.length; index++) {
    geometryShader.setFloat(index, geometryValues[index]);
  }
  final geometryRecorder = ui.PictureRecorder();
  Canvas(geometryRecorder).drawRect(
    Offset.zero & Size(bounds.width * dpr, bounds.height * dpr),
    Paint()..shader = geometryShader,
  );
  final geometryPicture = geometryRecorder.endRecording();
  final geometry = await geometryPicture.toImage(
    (bounds.width * dpr).round(),
    (bounds.height * dpr).round(),
  );
  geometryPicture.dispose();
  geometryShader.dispose();

  final shader = renderProgram.fragmentShader();
  try {
    for (var index = 0; index <= 46; index++) {
      shader.setFloat(index, 0);
    }
    final uniforms = <int, double>{
      0: width.toDouble(),
      1: height.toDouble(),
      2: bounds.left * dpr,
      3: bounds.top * dpr,
      4: bounds.width * dpr,
      5: bounds.height * dpr,
      10: 1.18,
      12: 72 * dpr / 3,
      13: 1,
      16: 1,
      18: -1,
      20: 1,
      26: captureOffset.dx * dpr,
      27: captureOffset.dy * dpr,
      30: dpr / 3,
      33: 1,
      39: 0.2,
      40: model.index.toDouble(),
      44: 1,
      46: 24 * dpr,
    };
    for (final entry in uniforms.entries) {
      shader.setFloat(entry.key, entry.value);
    }
    if (tint != null) {
      shader.setFloat(6, tint.r);
      shader.setFloat(7, tint.g);
      shader.setFloat(8, tint.b);
      shader.setFloat(9, tint.a);
      shader.setFloat(14, 0.55);
      shader.setFloat(16, 1.5);
      shader.setFloat(17, -math.sqrt(0.5));
      shader.setFloat(18, -math.sqrt(0.5));
      shader.setFloat(29, 0.75);
    }
    shader.setImageSampler(0, blurred ?? backdrop);
    shader.setImageSampler(1, geometry);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(backdrop, Offset.zero, Paint());
    canvas.drawRect(
      Rect.fromPoints(bounds.topLeft * dpr, bounds.bottomRight * dpr),
      Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  } finally {
    shader.dispose();
    geometry.dispose();
    blurred?.dispose();
    backdrop.dispose();
  }
}
