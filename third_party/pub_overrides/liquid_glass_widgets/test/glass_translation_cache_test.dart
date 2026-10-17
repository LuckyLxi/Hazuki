import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// Exercise the premium engine's geometry on Skia without a shader backdrop.
import 'package:liquid_glass_widgets/src/engine/liquid_glass.dart';
import 'package:liquid_glass_widgets/src/engine/liquid_glass_blend_group.dart';
import 'package:liquid_glass_widgets/src/engine/liquid_glass_layer.dart';
import 'package:liquid_glass_widgets/src/engine/render_liquid_glass_geometry.dart';
import 'package:liquid_glass_widgets/src/engine/rendering/liquid_glass_render_object.dart';

void main() {
  testWidgets('translation reuses the matte, shape changes rebuild it',
      (tester) async {
    late ui.FragmentShader renderShader;
    late ui.FragmentShader geometryShader;
    await tester.runAsync(() async {
      renderShader = (await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass_render.frag',
      ))
          .fragmentShader();
      geometryShader = (await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass_geometry_blended.frag',
      ))
          .fragmentShader();
    });
    final geometryLink = GeometryRenderLink();
    final shapeLink = GlassGroupLink();
    final layerKey = GlobalKey();
    final geometryKey = GlobalKey();
    late StateSetter update;
    var offset = Offset.zero;
    var shapeOffset = 0.0;
    var shapeTranslation = Offset.zero;
    var groupTranslation = Offset.zero;
    var radius = 24.0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: StatefulBuilder(builder: (context, setState) {
        update = setState;
        return Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: offset,
            child: RepaintBoundary(
              child: _LayerProbe(
                key: layerKey,
                shader: renderShader,
                link: geometryLink,
                child: Transform.translate(
                  offset: groupTranslation,
                  child: _GeometryProbe(
                    key: geometryKey,
                    shader: geometryShader,
                    geometryLink: geometryLink,
                    shapeLink: shapeLink,
                    child: Padding(
                      padding: EdgeInsets.only(left: shapeOffset),
                      child: Transform.translate(
                        offset: shapeTranslation,
                        child: _ShapeProbe(
                          link: shapeLink,
                          radius: radius,
                          child: const SizedBox(width: 240, height: 64),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ));
    await tester.pumpAndSettle();
    final layer = layerKey.currentContext!.findRenderObject()! as _RenderLayer;
    final geometry = geometryKey.currentContext!.findRenderObject()!
        as RenderLiquidGlassBlendGroup;
    final restingMatte = layer.matte;
    expect(restingMatte, isNotNull);

    for (var frame = 1; frame <= 5; frame++) {
      update(() => offset = Offset(0, frame * 8));
      await tester.pump();
      // Let transform tracking deliver the screen-space change, just as it
      // does for AnimatedSlide / Transform.translate in the reader.
      await tester.pump();
      expect(identical(layer.matte, restingMatte), isTrue,
          reason: 'a translation must not allocate another GPU matte');
    }

    update(() => shapeOffset = 12);
    await tester.pumpAndSettle();
    final movedShapeMatte = layer.matte;
    expect(identical(movedShapeMatte, restingMatte), isFalse);
    update(() => radius = 12);
    await tester.pumpAndSettle();
    expect(identical(layer.matte, movedShapeMatte), isFalse);
    final resizedMatte = layer.matte;
    update(() => shapeTranslation = const Offset(8, 0));
    await tester.pumpAndSettle();
    expect(identical(layer.matte, resizedMatte), isFalse,
        reason: 'a shape moving inside a shared surface still changes its SDF');
    final translatedShapeMatte = layer.matte;
    update(() => groupTranslation = const Offset(0, 8));
    await tester.pumpAndSettle();
    expect(identical(layer.matte, translatedShapeMatte), isFalse,
        reason: 'geometry moving relative to its layer must update the matte');
    expect(geometry.link.hasShapes, isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    geometryLink.dispose();
    shapeLink.dispose();
    renderShader.dispose();
    geometryShader.dispose();
  });
}

class _LayerProbe extends SingleChildRenderObjectWidget {
  const _LayerProbe({
    super.key,
    required this.shader,
    required this.link,
    required super.child,
  });

  final ui.FragmentShader shader;
  final GeometryRenderLink link;

  @override
  _RenderLayer createRenderObject(BuildContext context) => _RenderLayer(
        renderShader: shader,
        devicePixelRatio: 1,
        settings: const LiquidGlassSettings(),
        shadows: const [],
        link: link,
      );
}

class _RenderLayer extends RenderLiquidGlassLayer {
  _RenderLayer({
    required super.renderShader,
    required super.devicePixelRatio,
    required super.settings,
    required super.shadows,
    required super.link,
  });

  ui.Image? get matte => geometryImage;

  @override
  void paintLiquidGlass(
    PaintingContext context,
    Offset offset,
    List<(RenderLiquidGlassGeometry, GeometryCache, Matrix4)> shapes,
    Rect boundingBox,
  ) {
    paintShapeContents(context, offset, shapes, insideGlass: false);
  }
}

class _GeometryProbe extends SingleChildRenderObjectWidget {
  const _GeometryProbe({
    super.key,
    required this.shader,
    required this.geometryLink,
    required this.shapeLink,
    required super.child,
  });

  final ui.FragmentShader shader;
  final GeometryRenderLink geometryLink;
  final GlassGroupLink shapeLink;

  @override
  RenderLiquidGlassBlendGroup createRenderObject(BuildContext context) =>
      RenderLiquidGlassBlendGroup(
        renderLink: geometryLink,
        devicePixelRatio: 1,
        geometryShader: shader,
        settings: const LiquidGlassSettings(),
        link: shapeLink,
        blend: 0,
      );
}

class _ShapeProbe extends SingleChildRenderObjectWidget {
  const _ShapeProbe({
    required this.link,
    required this.radius,
    required super.child,
  });

  final GlassGroupLink link;
  final double radius;

  @override
  RenderLiquidGlass createRenderObject(BuildContext context) =>
      RenderLiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        glassContainsChild: false,
        blendGroupLink: link,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderLiquidGlass renderObject) {
    renderObject.shape = LiquidRoundedSuperellipse(borderRadius: radius);
  }
}
