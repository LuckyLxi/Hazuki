import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

@immutable
class FavoriteFoldersMorphOrigin {
  const FavoriteFoldersMorphOrigin({
    required this.rect,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    this.borderRadius = 15,
    this.iconSize = 22,
    this.borderColor,
    this.resolveReturnRect,
  });

  final Rect rect;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final double borderRadius;
  final double iconSize;
  final Color? borderColor;

  /// Reads the current button bounds after layout when closing. The opening
  /// bounds remain fixed even if the button moves or its widget is replaced.
  final Rect? Function()? resolveReturnRect;
}

class FavoriteFoldersMorphScope extends InheritedWidget {
  const FavoriteFoldersMorphScope({
    super.key,
    required this.origin,
    required this.animation,
    required super.child,
  });

  final FavoriteFoldersMorphOrigin origin;
  final Animation<double> animation;

  static FavoriteFoldersMorphScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FavoriteFoldersMorphScope>();

  @override
  bool updateShouldNotify(FavoriteFoldersMorphScope oldWidget) =>
      origin != oldWidget.origin || animation != oldWidget.animation;
}

/// Keeps the dialog's contents at their natural layout size while its painted
/// surface moves and changes shape from the originating button and back.
class FavoriteFoldersButtonMorph extends StatelessWidget {
  const FavoriteFoldersButtonMorph({
    super.key,
    required this.origin,
    required this.animation,
    required this.surfaceColor,
    required this.outlineColor,
    required this.borderRadius,
    required this.shadowBlurRadius,
    this.surface,
    required this.child,
  });

  final FavoriteFoldersMorphOrigin origin;
  final Animation<double> animation;
  final Color surfaceColor;
  final Color outlineColor;
  final double borderRadius;
  final double shadowBlurRadius;

  /// An optional refractive backing, painted independently of content opacity.
  final Widget? surface;
  final Widget? child;

  @override
  Widget build(BuildContext context) => _FavoriteFoldersMorphLayout(this);
}

class _FavoriteFoldersMorphLayout extends MultiChildRenderObjectWidget {
  _FavoriteFoldersMorphLayout(this.configuration)
    : super(children: [?configuration.surface, ?configuration.child]);

  final FavoriteFoldersButtonMorph configuration;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFavoriteFoldersButtonMorph(configuration);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderFavoriteFoldersButtonMorph).update(configuration);
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFavoriteFoldersButtonMorph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderFavoriteFoldersButtonMorph(this._configuration);

  FavoriteFoldersButtonMorph _configuration;
  bool _reversing = false;
  double _reverseStartValue = 1;
  double _reverseStartProgress = 1;
  Rect? _reverseStartRect;
  Rect? _returnTargetRect;
  Rect? _returnStartRect;
  double _returnRetargetTime = 0;

  RenderBox? get child => _configuration.child == null ? null : lastChild;
  RenderBox? get surface => _configuration.surface == null ? null : firstChild;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      child?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  void performLayout() {
    child?.layout(constraints, parentUsesSize: true);
    size = child?.size ?? constraints.smallest;
    // Size the lens to the moving surface rather than stretching its shader.
    // Only dimensions are needed during layout; ancestor paint transforms may
    // not have their sizes yet, so defer global coordinate lookup until paint.
    final surfaceSize = _resolveRect(
      Offset.zero & _configuration.origin.rect.size,
      Offset.zero & size,
      _reverseStartRect,
    ).size;
    surface?.layout(BoxConstraints.tight(surfaceSize));
  }

  static const _morphEnd = 0.6;
  // This pulse peaks at 1/3 and returns with zero velocity. Its slope at
  // arrival is shared by the morph, rather than restarting from a standstill.
  static const _pulseSlope = 6.75;

  void update(FavoriteFoldersButtonMorph configuration) {
    if (attached && configuration.animation != _configuration.animation) {
      _configuration.animation.removeListener(_handleTick);
      _configuration.animation.removeStatusListener(_handleStatus);
      configuration.animation.addListener(_handleTick);
      configuration.animation.addStatusListener(_handleStatus);
      _reversing = false;
      _reverseStartRect = null;
      _returnTargetRect = null;
      _returnStartRect = null;
    }
    _configuration = configuration;
    if (attached) _handleStatus(configuration.animation.status);
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _configuration.animation.addListener(_handleTick);
    _configuration.animation.addStatusListener(_handleStatus);
    _handleStatus(_configuration.animation.status);
  }

  @override
  void detach() {
    _configuration.animation.removeListener(_handleTick);
    _configuration.animation.removeStatusListener(_handleStatus);
    super.detach();
  }

  void _handleTick() {
    if (surface != null) markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && !_reversing) {
      // Capture the painted state so closing during expansion does not jump.
      _reverseStartRect = hasSize
          ? _currentRect.shift(localToGlobal(Offset.zero))
          : null;
      _reverseStartProgress = _progress;
      _reverseStartValue = _configuration.animation.value;
      _returnTargetRect = null;
      _returnStartRect = null;
      _reversing = true;
    } else if (status == AnimationStatus.forward) {
      _reversing = false;
    }
    _handleTick();
  }

  double get _reverseTime => _reverseStartValue == 0
      ? 1
      : (1 - _configuration.animation.value / _reverseStartValue).clamp(
          0.0,
          1.0,
        );

  double get _progress {
    final time = _reversing ? _reverseTime : _configuration.animation.value;
    final morph = Curves.easeInOutCubic.transform(
      (time / _morphEnd).clamp(0.0, 1.0),
    );
    return _reversing ? _reverseStartProgress * (1 - morph) : morph;
  }

  double get _shapeScale =>
      _currentRect.width /
      Rect.lerp(_sourceRect, Offset.zero & size, _progress)!.width;

  Rect get _sourceRect =>
      (_reversing ? _returnRect : _configuration.origin.rect).shift(
        -localToGlobal(Offset.zero),
      );

  Rect get _returnRect {
    final next =
        _configuration.origin.resolveReturnRect?.call() ??
        _returnTargetRect ??
        _configuration.origin.rect;
    if (_returnTargetRect == null) {
      _returnTargetRect = next;
    } else if (_returnTargetRect != next) {
      // Retarget from the current position rather than jumping when a late
      // profile update lays out a new username during the closing animation.
      _returnStartRect = _interpolatedReturnRect;
      _returnRetargetTime = _reverseTime;
      _returnTargetRect = next;
    }
    return _interpolatedReturnRect;
  }

  Rect get _interpolatedReturnRect {
    final start = _returnStartRect;
    final target = _returnTargetRect!;
    if (start == null || _returnRetargetTime >= 1) return target;
    final progress =
        ((_reverseTime - _returnRetargetTime) / (1 - _returnRetargetTime))
            .clamp(0.0, 1.0);
    return Rect.lerp(start, target, Curves.easeOutCubic.transform(progress))!;
  }

  Rect get _currentRect => _resolveRect(
    _sourceRect,
    Offset.zero & size,
    _reverseStartRect?.shift(-localToGlobal(Offset.zero)),
  );

  Rect _resolveRect(Rect source, Rect dialog, Rect? reverseStartRect) {
    final time = _reversing ? _reverseTime : _configuration.animation.value;
    final start = _reversing
        ? reverseStartRect ?? Rect.lerp(source, dialog, _reverseStartProgress)!
        : source;
    final end = _reversing ? source : dialog;
    final amplitude = _reversing ? -0.06 * _reverseStartProgress : 0.035;
    if (time < _morphEnd) {
      final t = time / _morphEnd;
      final position = Curves.easeInOutCubic.transform(t);
      // Cubic Hermite interpolation starts at rest and reaches the destination
      // with precisely the pulse's incoming size velocity on both axes.
      final tangent = amplitude * _pulseSlope * _morphEnd / (1 - _morphEnd);
      double dimension(double from, double to) =>
          from +
          (to - from) * t * t * (3 - 2 * t) +
          to * tangent * t * t * (t - 1);
      return Rect.fromCenter(
        center: Offset.lerp(start.center, end.center, position)!,
        width: dimension(start.width, end.width),
        height: dimension(start.height, end.height),
      );
    }
    final t = ((time - _morphEnd) / (1 - _morphEnd)).clamp(0.0, 1.0);
    final scale = 1 + amplitude * _pulseSlope * t * (1 - t) * (1 - t);
    return Rect.fromCenter(
      center: end.center,
      width: end.width * scale,
      height: end.height * scale,
    );
  }

  Matrix4 get _childTransform {
    final rect = _currentRect;
    return Matrix4.diagonal3Values(
      rect.width / size.width,
      rect.height / size.height,
      1,
    )..setTranslationRaw(rect.left, rect.top, 0);
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  Rect get paintBounds => hasSize && attached
      ? (Offset.zero & size).expandToInclude(_sourceRect).inflate(48)
      : super.paintBounds;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (child == surface) {
      final rect = _currentRect;
      transform.multiply(Matrix4.translationValues(rect.left, rect.top, 0));
    } else {
      transform.multiply(_childTransform);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _configuration.animation.value == 1 &&
      child != null &&
      child!.hitTest(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || size.isEmpty) return;
    final progress = _progress;
    final origin = _configuration.origin;
    final rect = _currentRect;
    final radius =
        (origin.borderRadius +
            (_configuration.borderRadius - origin.borderRadius) * progress) *
        _shapeScale;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paintedShape = shape.shift(offset);
    final canvas = context.canvas;
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.18 * progress),
      blurRadius: _configuration.shadowBlurRadius * progress,
      spreadRadius: -6 * progress,
      offset: Offset(0, 18 * progress),
    );
    canvas.drawRRect(
      paintedShape.shift(shadow.offset).inflate(shadow.spreadRadius),
      shadow.toPaint(),
    );
    if (surface != null) {
      context.pushClipRRect(
        needsCompositing,
        offset,
        rect,
        shape,
        (context, offset) =>
            context.paintChild(surface!, offset + rect.topLeft),
      );
    } else {
      canvas.drawRRect(
        paintedShape,
        Paint()
          ..color = Color.lerp(
            origin.backgroundColor,
            _configuration.surfaceColor,
            progress,
          )!,
      );
    }
    final contentOpacity = const Interval(
      0.18,
      0.8,
      curve: Curves.easeOutCubic,
    ).transform(progress);
    if (contentOpacity > 0) {
      context.pushClipRRect(
        needsCompositing,
        offset,
        rect,
        shape,
        (context, offset) => context.pushTransform(
          needsCompositing,
          offset,
          _childTransform,
          (context, offset) => context.pushOpacity(
            offset,
            (contentOpacity * 255).round(),
            (context, offset) => context.paintChild(child!, offset),
          ),
        ),
      );
    }
    final foregroundCanvas = context.canvas;
    foregroundCanvas.drawRRect(
      paintedShape.deflate(0.5),
      Paint()
        ..color = Color.lerp(
          origin.borderColor ??
              _configuration.outlineColor.withValues(alpha: 0),
          _configuration.outlineColor,
          progress,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final iconOpacity = 1 - (progress / 0.22).clamp(0.0, 1.0);
    if (iconOpacity > 0) {
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(origin.icon.codePoint),
          style: TextStyle(
            fontFamily: origin.icon.fontFamily,
            fontSize: origin.iconSize * _shapeScale,
            color: origin.foregroundColor.withValues(alpha: iconOpacity),
          ),
        ),
      )..layout();
      painter.paint(
        foregroundCanvas,
        rect.center + offset - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }
}
