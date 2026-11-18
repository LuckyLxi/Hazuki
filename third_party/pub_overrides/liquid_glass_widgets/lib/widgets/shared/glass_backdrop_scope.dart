import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Shares a content texture between glass surfaces on renderers without shader
/// image filters. Keep the surfaces outside [GlassBackdropSource].
class GlassBackdropScope extends StatefulWidget {
  /// Creates a scope for a background source and its floating controls.
  const GlassBackdropScope({required this.child, super.key});

  /// The content and the controls which sample it.
  final Widget child;

  /// The nearest shared backdrop, if any.
  static GlassBackdropData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackdropTheme>()?.data;

  @override
  State<GlassBackdropScope> createState() => _GlassBackdropScopeState();
}

class _GlassBackdropScopeState extends State<GlassBackdropScope> {
  final GlassBackdropData _data = GlassBackdropData();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _BackdropTheme(data: _data, child: widget.child);
}

class _BackdropTheme extends InheritedTheme {
  const _BackdropTheme({required this.data, required super.child});

  final GlassBackdropData data;

  @override
  bool updateShouldNotify(_BackdropTheme oldWidget) => data != oldWidget.data;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      _BackdropTheme(data: data, child: child);
}

/// Marks content behind the glass, excluding the glass itself from the capture.
class GlassBackdropSource extends StatelessWidget {
  /// Creates a repaint-driven backdrop source. No continuous ticker is used.
  const GlassBackdropSource({required this.child, super.key});

  /// Scrolling or animated content behind the floating controls.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = GlassBackdropScope.maybeOf(context);
    if (data == null) return child;
    return _BackdropBoundary(
      data: data,
      pixelRatio: View.of(context).devicePixelRatio,
      child: child,
    );
  }
}

/// Shared GPU texture. Changes repaint consumers without rebuilding their child.
class GlassBackdropData extends ChangeNotifier {
  /// Creates an initially empty backdrop.
  GlassBackdropData();

  _RenderBackdropBoundary? _source;
  ui.Image? _image;
  bool _pending = false;
  bool _capturing = false;
  bool _disposed = false;

  /// Latest content image, at the source's device pixel ratio.
  ui.Image? get image => _image;

  /// Source used to map controls into the captured content's local coordinates.
  RenderBox? get source => _source;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _scheduleCapture();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _image?.dispose();
      _image = null;
    }
  }

  void _scheduleCapture() {
    if (_disposed || _pending || _capturing || !hasListeners) return;
    _pending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      final source = _source;
      if (_disposed || !hasListeners || source == null || !source.canCapture) {
        return;
      }
      _capturing = true;
      try {
        final next = source.toImageSync(pixelRatio: source.pixelRatio);
        final previous = _image;
        _image = next;
        notifyListeners();
        previous?.dispose();
      } catch (error) {
        // The live backdrop path remains usable if the GPU cannot allocate a
        // capture (for example, while its window surface is being recreated).
        _image?.dispose();
        _image = null;
        notifyListeners();
        debugPrint('[GlassBackdrop] Capture failed: $error');
      } finally {
        _capturing = false;
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _source = null;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}

class _BackdropBoundary extends SingleChildRenderObjectWidget {
  const _BackdropBoundary({
    required this.data,
    required this.pixelRatio,
    required super.child,
  });

  final GlassBackdropData data;
  final double pixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBackdropBoundary(data, pixelRatio);

  @override
  void updateRenderObject(
      BuildContext context, _RenderBackdropBoundary object) {
    if (object.pixelRatio != pixelRatio) {
      object.pixelRatio = pixelRatio;
      object.markNeedsPaint();
    }
  }
}

class _RenderBackdropBoundary extends RenderRepaintBoundary {
  _RenderBackdropBoundary(this.data, this.pixelRatio) {
    data._source = this;
  }

  final GlassBackdropData data;
  double pixelRatio;

  bool get canCapture => attached && hasSize && !size.isEmpty && layer != null;

  @override
  OffsetLayer updateCompositedLayer({covariant _BackdropLayer? oldLayer}) =>
      oldLayer ?? _BackdropLayer(data._scheduleCapture);

  @override
  void dispose() {
    if (data._source == this) data._source = null;
    super.dispose();
  }
}

class _BackdropLayer extends OffsetLayer {
  _BackdropLayer(this.onContentChanged);

  final VoidCallback onContentChanged;
  int? _lastContentHash;

  @override
  void addToScene(ui.SceneBuilder builder) {
    super.addToScene(builder);
    // Glass transform trackers request composition even when they paint
    // nothing new. Only actual display lists, transforms or effects invalidate
    // the texture, including changes inside nested repaint boundaries.
    final contentHash = Object.hashAll(_contentProperties(this));
    if (_lastContentHash != contentHash) {
      _lastContentHash = contentHash;
      onContentChanged();
    }
  }

  Iterable<Object?> _contentProperties(Layer layer) sync* {
    yield layer;
    if (layer is PictureLayer) yield layer.picture;
    if (layer is OffsetLayer) yield layer.offset;
    if (layer is TransformLayer) {
      yield Object.hashAll(layer.transform?.storage ?? const <double>[]);
    }
    if (layer is OpacityLayer) yield layer.alpha;
    if (layer is ClipRectLayer) {
      yield layer.clipRect;
      yield layer.clipBehavior;
    }
    if (layer is ClipRRectLayer) {
      yield layer.clipRRect;
      yield layer.clipBehavior;
    }
    if (layer is ClipRSuperellipseLayer) {
      yield layer.clipRSuperellipse;
      yield layer.clipBehavior;
    }
    if (layer is ClipPathLayer) {
      yield layer.clipPath;
      yield layer.clipBehavior;
    }
    if (layer is ColorFilterLayer) yield layer.colorFilter;
    if (layer is ImageFilterLayer) yield layer.imageFilter;
    if (layer is BackdropFilterLayer) {
      yield layer.filter;
      yield layer.blendMode;
    }
    if (layer is ShaderMaskLayer) {
      yield layer.shader;
      yield layer.maskRect;
      yield layer.blendMode;
    }
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        yield* _contentProperties(child);
        child = child.nextSibling;
      }
    }
  }
}
