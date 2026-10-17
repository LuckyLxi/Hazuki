import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/reader/view/reader_control_motion.dart';

void main() {
  testWidgets(
    'glass slide matches AnimatedSlide and paints in the moving frame',
    (tester) async {
      const duration = Duration(milliseconds: 360);
      const curve = Curves.easeOutBack;
      final glassKey = GlobalKey();
      final referenceKey = GlobalKey();
      var offset = Offset.zero;
      late StateSetter update;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 100,
                    child: ReaderControlSlide(
                      offset: offset,
                      duration: duration,
                      curve: curve,
                      child: _PositionProbe(key: glassKey),
                    ),
                  ),
                  Positioned(
                    left: 300,
                    top: 100,
                    child: AnimatedSlide(
                      offset: offset,
                      duration: duration,
                      curve: curve,
                      child: SizedBox(
                        key: referenceKey,
                        width: 140,
                        height: 64,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final probe =
          glassKey.currentContext!.findRenderObject()! as _RenderProbe;
      final initialLayouts = probe.layouts;

      for (final target in [const Offset(0, -1), Offset.zero]) {
        update(() => offset = target);
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final current = probe.localToGlobal(Offset.zero);
          expect(
            probe.paintedOrigin,
            current,
            reason: 'shader coordinates must be current before compositing',
          );
          expect(current.dy, tester.getTopLeft(find.byKey(referenceKey)).dy);
          expect(
            probe.layouts,
            initialLayouts,
            reason: 'moving glass must not relayout its controls',
          );
        }
        // Reverse before settling, as repeated reader taps do.
      }
      await tester.pumpAndSettle();
      expect(probe.paintedOrigin, const Offset(0, 100));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pixel translations refresh a retained surface in the same frame',
    (tester) async {
      final probeKey = GlobalKey();
      var position = Offset.zero;
      late StateSetter update;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Transform.translate(
                  offset: position,
                  child: ReaderControlMotion(
                    position: position,
                    child: _PositionProbe(key: probeKey),
                  ),
                );
              },
            ),
          ),
        ),
      );
      final probe =
          probeKey.currentContext!.findRenderObject()! as _RenderProbe;
      final initialLayouts = probe.layouts;
      for (final next in [
        const Offset(0, 12),
        const Offset(0, 80),
        const Offset(0, 40),
        Offset.zero,
      ]) {
        update(() => position = next);
        await tester.pump();
        expect(probe.paintedOrigin, next);
        expect(probe.layouts, initialLayouts);
      }
      expect(tester.takeException(), isNull);
    },
  );
}

class _PositionProbe extends SingleChildRenderObjectWidget {
  const _PositionProbe({super.key})
    : super(child: const SizedBox(width: 140, height: 64));

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe();
}

class _RenderProbe extends RenderProxyBox {
  Offset? paintedOrigin;
  var layouts = 0;

  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    paintedOrigin = localToGlobal(Offset.zero);
    super.paint(context, offset);
  }
}
