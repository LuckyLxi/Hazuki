import 'package:flutter/widgets.dart';

import '../../src/renderer/glass_snapshot_render_root.dart';

/// A page snapshot that keeps premium glass aligned with its shape and content.
///
/// SnapshotWidget rasterizes in local coordinates. Premium glass must use that
/// same origin instead of including an ancestor route's screen translation.
class GlassSnapshot extends StatelessWidget {
  /// Creates a glass-aware snapshot, controlled like Flutter's SnapshotWidget.
  const GlassSnapshot({
    super.key,
    required this.controller,
    this.mode = SnapshotMode.permissive,
    this.autoresize = true,
    required this.child,
  });

  /// Controls snapshot capture and release.
  final SnapshotController controller;

  /// How unsupported platform views are handled.
  final SnapshotMode mode;

  /// Whether resizing the page refreshes its snapshot.
  final bool autoresize;

  /// The complete page, including the backdrop behind its glass surfaces.
  final Widget child;

  @override
  Widget build(BuildContext context) => _SnapshotRoot(
        controller: controller,
        child: SnapshotWidget(
          controller: controller,
          mode: mode,
          autoresize: autoresize,
          child: child,
        ),
      );
}

class _SnapshotRoot extends SingleChildRenderObjectWidget {
  const _SnapshotRoot({required this.controller, required super.child});

  final SnapshotController controller;

  @override
  RenderGlassSnapshotRoot createRenderObject(BuildContext context) =>
      RenderGlassSnapshotRoot(controller: controller);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassSnapshotRoot renderObject,
  ) {
    renderObject.controller = controller;
  }
}
