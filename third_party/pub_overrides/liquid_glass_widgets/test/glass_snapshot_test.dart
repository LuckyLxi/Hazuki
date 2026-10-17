import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// Engine tests exercise the render objects without requiring Impeller.
import 'package:liquid_glass_widgets/src/engine/liquid_glass_layer.dart';
import 'package:liquid_glass_widgets/src/engine/rendering/liquid_glass_render_object.dart';

void main() {
  for (final displacement in [const Offset(-120, 24), const Offset(100, 24)]) {
    testWidgets('snapshot removes route displacement $displacement from glass',
        (tester) async {
      final controller = SnapshotController();
      final link = GeometryRenderLink();
      addTearDown(controller.dispose);
      addTearDown(link.dispose);
      final probeKey = GlobalKey();
      var paints = 0;
      final captureOrigin = displacement;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: displacement,
                child: SizedBox(
                  width: 320,
                  height: 480,
                  child: GlassSnapshot(
                    controller: controller,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 40, top: 70),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: RepaintBoundary(
                          child: _LayerProbe(
                            key: probeKey,
                            link: link,
                            captureOrigin: captureOrigin,
                            child: CustomPaint(
                              painter: _PaintCounter(() => paints++),
                              child: const SizedBox(width: 140, height: 56),
                            ),
                          ),
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
      final layer = probeKey.currentContext!.findRenderObject()!
          as RenderLiquidGlassLayer;
      Offset origin() =>
          MatrixUtils.transformPoint(layer.matteTransform, Offset.zero);
      const localOrigin = Offset(40, 70);
      expect(origin(), displacement + localOrigin);
      expect(layer.captureOriginInScreenSpace, captureOrigin);
      final livePaints = paints;

      controller.allowSnapshotting = true;
      await tester.pump();
      expect(origin(), localOrigin);
      expect(layer.desiredMatteSize, const Size(320, 480));
      expect(layer.enclosingBackdropPassRect(),
          const Rect.fromLTWH(0, 0, 320, 480));
      expect(layer.captureOriginInScreenSpace, Offset.zero);
      expect(layer.positionInRenderTarget(displacement + localOrigin),
          localOrigin);
      // Hit testing and Hero geometry must still use the real screen position.
      expect(layer.localToGlobal(Offset.zero), displacement + localOrigin);
      expect(paints, greaterThan(livePaints),
          reason: 'retained layers must repaint in snapshot coordinates');
      final snapshotPaints = paints;

      controller.allowSnapshotting = false;
      await tester.pump();
      expect(origin(), displacement + localOrigin);
      expect(layer.captureOriginInScreenSpace, captureOrigin);
      expect(paints, greaterThan(snapshotPaints),
          reason: 'screen-space uniforms must be restored after the snapshot');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('snapshot clips nested backdrop passes in snapshot coordinates',
      (tester) async {
    final controller = SnapshotController(allowSnapshotting: true);
    final link = GeometryRenderLink();
    addTearDown(controller.dispose);
    addTearDown(link.dispose);
    final probeKey = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Transform.translate(
            offset: const Offset(-120, 0),
            child: GlassSnapshot(
              controller: controller,
              child: Padding(
                padding: const EdgeInsets.only(left: 40, top: 70),
                child: BackdropFilter(
                  filter: ColorFilter.mode(
                      const Color(0xFFFFFFFF), BlendMode.srcOver),
                  child: _LayerProbe(
                    key: probeKey,
                    link: link,
                    captureOrigin: Offset.zero,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final layer =
        probeKey.currentContext!.findRenderObject()! as RenderLiquidGlassLayer;
    expect(layer.enclosingBackdropPassRect(),
        const Rect.fromLTWH(40, 70, 760, 530));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _LayerProbe extends SingleChildRenderObjectWidget {
  const _LayerProbe({
    super.key,
    required this.link,
    required this.captureOrigin,
    required super.child,
  });

  final GeometryRenderLink link;
  final Offset captureOrigin;

  @override
  RenderLiquidGlassLayer createRenderObject(BuildContext context) =>
      RenderLiquidGlassLayer(
        renderShader: null,
        devicePixelRatio: 1,
        settings: const LiquidGlassSettings(),
        shadows: const [],
        link: link,
        captureOriginInScreenSpace: captureOrigin,
      );
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0088FF));
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
