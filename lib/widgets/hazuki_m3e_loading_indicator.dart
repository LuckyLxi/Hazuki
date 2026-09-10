import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

// Derived from loading_indicator_m3e's Apache-2.0-licensed expressive loader.
/// A render-optimized Material 3 Expressive loading indicator.
///
/// This keeps the shapes and timing used by `loading_indicator_m3e`, while
/// painting rotation and morphing in one layer without rebuilding the widget
/// tree or creating transformed path copies on every frame.
class HazukiM3ELoadingIndicator extends StatefulWidget {
  const HazukiM3ELoadingIndicator({
    super.key,
    this.color,
    this.semanticLabel,
    this.semanticValue,
  });

  final Color? color;
  final String? semanticLabel;
  final String? semanticValue;

  @override
  State<HazukiM3ELoadingIndicator> createState() =>
      _HazukiM3ELoadingIndicatorState();
}

class _HazukiM3ELoadingIndicatorState extends State<HazukiM3ELoadingIndicator>
    with TickerProviderStateMixin {
  static const _defaultConstraints = BoxConstraints.tightFor(
    width: 48,
    height: 48,
  );
  static const _globalRotationDuration = Duration(milliseconds: 4666);
  static const _morphInterval = Duration(milliseconds: 650);
  static const _quarterRotation = 90.0;
  static const _fullRotation = 360.0;
  static const _activeSize = 38.0;
  static const _cachedFrameCount = 60;

  static final Simulation _morphSimulation = SpringSimulation(
    SpringDescription.withDampingRatio(ratio: 0.6, stiffness: 200, mass: 1),
    0,
    1,
    5,
    snapToEnd: true,
  );

  static final List<RoundedPolygon> _polygons = <RoundedPolygon>[
    MaterialShapes.softBurst,
    MaterialShapes.cookie9Sided,
    MaterialShapes.pentagon,
    MaterialShapes.pill,
    MaterialShapes.sunny,
    MaterialShapes.cookie4Sided,
    MaterialShapes.oval,
  ];

  static final List<Morph> _morphs = List<Morph>.generate(
    _polygons.length,
    (index) =>
        Morph(_polygons[index], _polygons[(index + 1) % _polygons.length]),
    growable: false,
  );

  static final double _shapeScaleFactor = _calculateScaleFactor(_polygons);
  static final List<List<_CachedMorphFrame?>> _cachedMorphFrames =
      List<List<_CachedMorphFrame?>>.generate(
        _morphs.length,
        (_) => List<_CachedMorphFrame?>.filled(_cachedFrameCount + 1, null),
        growable: false,
      );
  late final AnimationController _morphController;
  late final AnimationController _rotationController;
  late final ValueNotifier<int> _morphIndex;
  late final Listenable _repaint;
  Timer? _morphTimer;
  double _morphRotationTarget = _quarterRotation;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController.unbounded(vsync: this);
    _rotationController = AnimationController(
      duration: _globalRotationDuration,
      vsync: this,
    );
    _morphIndex = ValueNotifier<int>(0);
    _repaint = Listenable.merge(<Listenable>[
      _morphController,
      _rotationController,
      _morphIndex,
    ]);
    _startAnimations();
  }

  @override
  void dispose() {
    _morphTimer?.cancel();
    _morphIndex.dispose();
    _morphController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        ProgressIndicatorTheme.of(context).color ??
        Theme.of(context).colorScheme.primary;

    return Semantics.fromProperties(
      properties: SemanticsProperties(
        label: widget.semanticLabel,
        value: widget.semanticValue,
      ),
      child: RepaintBoundary(
        child: ConstrainedBox(
          constraints: _defaultConstraints,
          child: CustomPaint(
            painter: _HazukiM3EMorphPainter(
              morphs: _morphs,
              morphIndex: _morphIndex,
              morphController: _morphController,
              rotationController: _rotationController,
              morphRotationTarget: () => _morphRotationTarget,
              cachedMorphFrames: _cachedMorphFrames,
              cachedFrameCount: _cachedFrameCount,
              color: color,
              scaleFactor:
                  _shapeScaleFactor *
                  (_activeSize / _defaultConstraints.maxWidth),
              repaint: _repaint,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  void _startAnimations() {
    _rotationController.repeat();
    _morphTimer = Timer.periodic(_morphInterval, (_) => _startMorphCycle());
    _startMorphCycle();
  }

  void _startMorphCycle() {
    if (!mounted) return;
    _morphIndex.value = (_morphIndex.value + 1) % _morphs.length;
    _morphRotationTarget =
        (_morphRotationTarget + _quarterRotation) % _fullRotation;
    _morphController
      ..value = 0
      ..animateWith(_morphSimulation);
  }

  static double _calculateScaleFactor(List<RoundedPolygon> polygons) {
    var scaleFactor = 1.0;
    for (final polygon in polygons) {
      final bounds = polygon.calculateBounds();
      final maxBounds = polygon.calculateMaxBounds();
      final scaleX = (bounds[2] - bounds[0]) / (maxBounds[2] - maxBounds[0]);
      final scaleY = (bounds[3] - bounds[1]) / (maxBounds[3] - maxBounds[1]);
      scaleFactor = math.min(scaleFactor, math.max(scaleX, scaleY));
    }
    return scaleFactor;
  }
}

class _CachedMorphFrame {
  const _CachedMorphFrame({required this.path, required this.bounds});

  final Path path;
  final Rect bounds;
}

class _HazukiM3EMorphPainter extends CustomPainter {
  _HazukiM3EMorphPainter({
    required this.morphs,
    required this.morphIndex,
    required this.morphController,
    required this.rotationController,
    required this.morphRotationTarget,
    required this.cachedMorphFrames,
    required this.cachedFrameCount,
    required this.color,
    required this.scaleFactor,
    required super.repaint,
  }) : _paint = Paint()..color = color;

  final List<Morph> morphs;
  final ValueListenable<int> morphIndex;
  final AnimationController morphController;
  final AnimationController rotationController;
  final double Function() morphRotationTarget;
  final List<List<_CachedMorphFrame?>> cachedMorphFrames;
  final int cachedFrameCount;
  final Color color;
  final double scaleFactor;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = morphController.value.clamp(0.0, 1.0);
    final rotationDegrees =
        progress * 90 + morphRotationTarget() + rotationController.value * 360;
    final index = morphIndex.value;
    final cachedFrames = cachedMorphFrames[index];
    final frameIndex = (progress * cachedFrameCount).round();
    // Cache only the frame being painted. Preparing every morph after frames
    // used to block the UI thread while the comments tab was sliding in.
    final frame = cachedFrames[frameIndex] ??= _createFrame(index, frameIndex);
    final scale = math.min(size.width, size.height) * scaleFactor;

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..rotate(rotationDegrees * math.pi / 180)
      ..scale(scale)
      ..translate(-frame.bounds.center.dx, -frame.bounds.center.dy)
      ..drawPath(frame.path, _paint)
      ..restore();
  }

  _CachedMorphFrame _createFrame(int morphIndex, int frameIndex) {
    final path = morphs[morphIndex].toPath(
      progress: frameIndex / cachedFrameCount,
    );
    return _CachedMorphFrame(path: path, bounds: path.getBounds());
  }

  @override
  bool shouldRepaint(_HazukiM3EMorphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.scaleFactor != scaleFactor;
  }
}
