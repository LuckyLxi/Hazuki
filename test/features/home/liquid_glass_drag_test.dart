import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/src/widgets/surfaces/tab_bar_drag_gesture_mixin.dart';

void main() {
  for (final axis in Axis.values) {
    for (final scale in [1.0, 0.5]) {
      testWidgets('preserves the press origin on $axis at scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _DragHarness(axis: axis, scale: scale),
            ),
          ),
        );

        final track = tester.getRect(find.byKey(const ValueKey('drag-track')));
        final start = axis == Axis.horizontal
            ? Offset(track.left + track.width / 4 + 10 * scale, track.center.dy)
            : Offset(
                track.center.dx,
                track.top + track.height / 4 + 10 * scale,
              );
        final gesture = await tester.startGesture(start);
        final state = tester.state<_DragHarnessState>(
          find.byType(_DragHarness),
        );
        expect(state.tabXAlign, -1);

        // Move before Flutter's drag threshold: the off-center press must not
        // become the indicator's center, even with a transformed track.
        await gesture.moveBy(
          axis == Axis.horizontal ? Offset(4 * scale, 0) : Offset(0, 4 * scale),
        );
        await tester.pump();
        expect(state.tabXAlign, closeTo(-1 + 4 / 60, 0.001));

        await gesture.moveBy(
          axis == Axis.horizontal
              ? Offset(24 * scale, 0)
              : Offset(0, 24 * scale),
        );
        await tester.pump();
        expect(state.tabIsDragging, isTrue);
        expect(state.tabXAlign, closeTo(-1 + 28 / 60, 0.001));

        await gesture.cancel();
        await tester.pump();
        expect(state.tabIsTrackingPointer, isFalse);
        expect(state.tabIsDragging, isFalse);
        expect(state.tabXAlign, -1);
      });
    }
  }
}

class _DragHarness extends StatefulWidget {
  const _DragHarness({required this.axis, required this.scale});

  final Axis axis;
  final double scale;

  @override
  State<_DragHarness> createState() => _DragHarnessState();
}

class _DragHarnessState extends State<_DragHarness>
    with TabDragGestureMixin<_DragHarness> {
  final _trackKey = GlobalKey();
  var _index = 0;

  @override
  int get tabCount => 2;
  @override
  int get tabIndex => _index;
  @override
  bool get isPlatformViewBackdrop => false;
  @override
  Axis get tabAxis => widget.axis;
  @override
  BuildContext get tabTrackContext => _trackKey.currentContext!;
  @override
  void notifyTabChanged(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    return Center(
      child: Transform.scale(
        scale: widget.scale,
        child: Listener(
          onPointerDown: (event) => onBarPointerDown(event.position),
          onPointerMove: (event) => onBarPointerMove(event.position),
          onPointerUp: (event) => onBarPointerUp(event.position),
          onPointerCancel: (event) => onBarPointerCancel(event.position),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: horizontal ? onBarDragStart : null,
            onHorizontalDragUpdate: horizontal ? onBarDragUpdate : null,
            onHorizontalDragEnd: horizontal ? onBarDragEnd : null,
            onHorizontalDragCancel: horizontal ? onBarDragCancel : null,
            onVerticalDragStart: horizontal ? null : onBarDragStart,
            onVerticalDragUpdate: horizontal ? null : onBarDragUpdate,
            onVerticalDragEnd: horizontal ? null : onBarDragEnd,
            onVerticalDragCancel: horizontal ? null : onBarDragCancel,
            child: SizedBox(
              key: _trackKey,
              width: horizontal ? 240 : 48,
              height: horizontal ? 48 : 240,
              child: const SizedBox(key: ValueKey('drag-track')),
            ),
          ),
        ),
      ),
    );
  }
}
