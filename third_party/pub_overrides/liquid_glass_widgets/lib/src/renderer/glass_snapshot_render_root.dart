import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A shader renderer whose cached coordinates depend on its render target.
abstract interface class GlassSnapshotAware {
  void onSnapshotTargetChanged();
}

/// The coordinate origin of a SnapshotWidget's offscreen render target.
class RenderGlassSnapshotRoot extends RenderProxyBox {
  RenderGlassSnapshotRoot({required SnapshotController controller})
      : _controller = controller;

  SnapshotController _controller;
  bool get isSnapshotting => _controller.allowSnapshotting;

  set controller(SnapshotController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.removeListener(_invalidatePaint);
    _controller = value;
    if (attached) _controller.addListener(_invalidatePaint);
    _invalidatePaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(_invalidatePaint);
  }

  @override
  void detach() {
    _controller.removeListener(_invalidatePaint);
    super.detach();
  }

  void _invalidatePaint() {
    // A retained glass layer may still contain screen-space shader uniforms.
    // Repaint boundaries must update when entering AND leaving the local
    // target, even if their content and layout have not changed.
    void invalidate(RenderObject node) {
      node.visitChildren(invalidate);
      if (node case final GlassSnapshotAware aware) {
        aware.onSnapshotTargetChanged();
      }
    }

    invalidate(this);
    markNeedsPaint();
  }

  static RenderGlassSnapshotRoot? of(RenderObject descendant) {
    RenderObject? node = descendant.parent;
    while (node != null) {
      if (node is RenderGlassSnapshotRoot && node.isSnapshotting) return node;
      node = node.parent;
    }
    return null;
  }
}
