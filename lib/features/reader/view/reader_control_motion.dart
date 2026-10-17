import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Keeps backdrop shader coordinates current when a control moves across an
/// internal repaint boundary. Transform-only updates otherwise retain the old
/// shader uniforms until glass notices the movement after compositing.
class ReaderControlMotion extends SingleChildRenderObjectWidget {
  const ReaderControlMotion({
    super.key,
    required this.position,
    required super.child,
  });

  final Offset position;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReaderControlMotion(position);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderReaderControlMotion).position = position;
  }
}

class _RenderReaderControlMotion extends RenderProxyBox {
  _RenderReaderControlMotion(this._position);

  Offset _position;

  set position(Offset value) {
    if (_position == value) return;
    _position = value;
    visitChildren(_repaintSurface);
  }

  void _repaintSurface(RenderObject child) {
    if (child.isRepaintBoundary) {
      child.markNeedsPaint();
    } else {
      child.visitChildren(_repaintSurface);
    }
  }
}

/// The same fractional slide as AnimatedSlide, with the glass repainted in
/// the moving frame rather than one frame after its transform changes.
class ReaderControlSlide extends StatelessWidget {
  const ReaderControlSlide({
    super.key,
    required this.offset,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final Offset offset;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Offset>(
    tween: Tween<Offset>(begin: offset, end: offset),
    duration: duration,
    curve: curve,
    builder: (context, position, child) => FractionalTranslation(
      translation: position,
      child: ReaderControlMotion(position: position, child: child!),
    ),
    child: child,
  );
}
