import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../widgets/windows_custom_title_bar.dart';
import 'appearance_settings.dart';
import 'windows_title_bar_controller.dart';

typedef ThemeRevealLogCallback =
    void Function(String title, {String level, Map<String, Object?>? content});

class HazukiThemeRevealSupport {
  HazukiThemeRevealSupport({
    required TickerProvider vsync,
    required bool Function() isMounted,
    required VoidCallback requestRebuild,
    required ThemeRevealLogCallback logEvent,
  }) : _isMounted = isMounted,
       _requestRebuild = requestRebuild,
       _logEvent = logEvent {
    controller =
        AnimationController(vsync: vsync, duration: _themeRevealDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) {
              clearOverlay();
            }
          });
  }

  static const _themeRevealSnapshotTimeout = Duration(milliseconds: 180);
  static const _themeRevealDuration = Duration(milliseconds: 920);

  final bool Function() _isMounted;
  final VoidCallback _requestRebuild;
  final ThemeRevealLogCallback _logEvent;

  final GlobalKey repaintBoundaryKey = GlobalKey();
  late final AnimationController controller;

  ui.Image? revealImage;
  Offset? revealCenter;
  bool _clearingRevealOverlay = false;

  Future<void> updateAppearance({
    required AppearanceSettingsData current,
    required AppearanceSettingsData next,
    required Future<void> Function(AppearanceSettingsData next) applyTheme,
    required Brightness Function(ThemeMode mode) resolveThemeBrightness,
    Offset? revealOrigin,
  }) async {
    final shouldAnimate =
        revealOrigin != null &&
        resolveThemeBrightness(current.themeMode) !=
            resolveThemeBrightness(next.themeMode);

    _logEvent(
      'Theme update requested',
      content: {
        'fromThemeMode': current.themeMode.name,
        'toThemeMode': next.themeMode.name,
        'fromBrightness': resolveThemeBrightness(current.themeMode).name,
        'toBrightness': resolveThemeBrightness(next.themeMode).name,
        'hasRevealOrigin': revealOrigin != null,
        'shouldAnimateReveal': shouldAnimate,
        if (revealOrigin != null) ...{
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      },
    );

    if (!shouldAnimate) {
      _logEvent(
        'Theme update applying without reveal animation',
        content: {'targetThemeMode': next.themeMode.name},
      );
      await applyTheme(next);
      _logEvent(
        'Theme update finished without reveal animation',
        content: {'activeThemeMode': next.themeMode.name},
      );
      return;
    }

    clearOverlay();
    final snapshot = await _captureSnapshot(revealOrigin);
    if (snapshot != null && _isMounted()) {
      revealImage = snapshot.image;
      revealCenter = snapshot.center;
      _requestRebuild();
      _logEvent(
        'Theme reveal snapshot captured',
        content: {
          'centerX': snapshot.center.dx.round(),
          'centerY': snapshot.center.dy.round(),
          'imageWidth': snapshot.image.width,
          'imageHeight': snapshot.image.height,
        },
      );
    } else {
      _logEvent(
        'Theme reveal snapshot unavailable',
        level: 'warning',
        content: {'reason': 'snapshot_null_or_unmounted'},
      );
    }

    await applyTheme(next);
    _logEvent(
      'Theme controller update completed',
      content: {'activeThemeMode': next.themeMode.name},
    );

    if (snapshot == null || !_isMounted()) {
      _logEvent(
        'Theme reveal animation skipped after update',
        level: 'warning',
        content: {
          'snapshotAvailable': snapshot != null,
          'mounted': _isMounted(),
        },
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted() || revealImage == null) {
        _logEvent(
          'Theme reveal animation start skipped',
          level: 'warning',
          content: {
            'mounted': _isMounted(),
            'hasRevealImage': revealImage != null,
          },
        );
        return;
      }
      _logEvent(
        'Theme reveal animation started',
        content: {
          'centerX': revealCenter?.dx.round(),
          'centerY': revealCenter?.dy.round(),
        },
      );
      controller.forward();
    });
  }

  void dispose() {
    controller.dispose();
    revealImage?.dispose();
  }

  void clearOverlay() {
    if (_clearingRevealOverlay) {
      return;
    }
    _clearingRevealOverlay = true;

    try {
      final hadOverlay = revealImage != null || revealCenter != null;
      controller.reset();
      final image = revealImage;
      revealImage = null;
      revealCenter = null;
      if (_isMounted()) {
        _requestRebuild();
        if (image != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            image.dispose();
          });
        }
      } else {
        image?.dispose();
      }
      if (hadOverlay) {
        _logEvent('Theme reveal overlay cleared');
      }
    } finally {
      _clearingRevealOverlay = false;
    }
  }

  Future<ThemeRevealSnapshot?> _captureSnapshot(Offset revealOrigin) async {
    final boundary = await _findRepaintBoundary();
    if (boundary == null) {
      _logEvent(
        'Theme reveal boundary not found',
        level: 'warning',
        content: {
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      );
      return null;
    }

    try {
      final pixelRatio =
          View.maybeOf(repaintBoundaryKey.currentContext!)?.devicePixelRatio ??
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;
      _logEvent(
        'Theme reveal snapshot capture started',
        content: {
          'pixelRatio': pixelRatio,
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      );
      final image = await boundary
          .toImage(pixelRatio: pixelRatio)
          .timeout(_themeRevealSnapshotTimeout);
      final localCenter = boundary.globalToLocal(revealOrigin);
      return ThemeRevealSnapshot(image: image, center: localCenter);
    } on TimeoutException {
      _logEvent(
        'Theme reveal snapshot capture timed out',
        level: 'warning',
        content: {
          'timeoutMs': _themeRevealSnapshotTimeout.inMilliseconds,
          'originX': revealOrigin.dx.round(),
          'originY': revealOrigin.dy.round(),
        },
      );
      return null;
    } catch (error, stackTrace) {
      _logEvent(
        'Theme reveal snapshot capture failed',
        level: 'error',
        content: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      return null;
    }
  }

  Future<RenderRepaintBoundary?> _findRepaintBoundary() async {
    RenderRepaintBoundary? boundary() =>
        repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    var candidate = boundary();
    if (candidate == null) {
      _logEvent('Theme reveal boundary lookup returned null', level: 'warning');
      return null;
    }
    // Wait for the current frame to finish painting so the captured image
    // reflects the latest visible theme state.
    await WidgetsBinding.instance.endOfFrame;
    candidate = boundary();
    _logEvent(
      'Theme reveal boundary resolved',
      content: {
        'width': candidate?.size.width.round(),
        'height': candidate?.size.height.round(),
      },
    );
    return candidate;
  }
}

class HazukiWindowFrame extends StatelessWidget {
  const HazukiWindowFrame({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final effectiveChild = child ?? const SizedBox.shrink();
    final titleBarController = HazukiWindowsTitleBarScope.of(context);
    return ListenableBuilder(
      listenable: titleBarController,
      builder: (context, _) {
        if (!titleBarController.shouldShowCustomTitleBar) {
          return effectiveChild;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            effectiveChild,
            Positioned(
              top: 0,
              right: 0,
              child: TextSelectionTheme(
                data: const TextSelectionThemeData(
                  selectionColor: Colors.transparent,
                  selectionHandleColor: Colors.transparent,
                ),
                child: const HazukiWindowsCustomTitleBar(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ThemeRevealSnapshot {
  const ThemeRevealSnapshot({required this.image, required this.center});

  final ui.Image image;
  final Offset center;
}

class ThemeRevealOverlay extends StatelessWidget {
  const ThemeRevealOverlay({
    super.key,
    required this.image,
    required this.center,
    required this.progress,
  });

  static const Curve _radiusCurve = Cubic(0.22, 0.0, 0.12, 1.0);
  static const Curve _overlayFadeCurve = Cubic(0.3, 0.0, 0.18, 1.0);
  static const double _radiusStartDelay = 0.025;

  final ui.Image image;
  final Offset center;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final delayedProgress =
            ((progress - _radiusStartDelay) / (1 - _radiusStartDelay)).clamp(
              0.0,
              1.0,
            );
        final radiusProgress = _radiusCurve.transform(delayedProgress);
        final overlayOpacity =
            1 -
            _overlayFadeCurve.transform(
              const Interval(0.68, 1.0).transform(progress),
            );
        final radius = _resolveRevealRadius(size, center, radiusProgress);
        return Opacity(
          opacity: overlayOpacity.clamp(0.0, 1.0),
          child: CustomPaint(
            size: size,
            painter: _ThemeRevealPainter(
              image: image,
              center: center,
              radius: radius,
            ),
          ),
        );
      },
    );
  }

  double _resolveRevealRadius(Size size, Offset center, double progress) {
    final distances = <double>[
      (center - Offset.zero).distance,
      (center - Offset(size.width, 0)).distance,
      (center - Offset(0, size.height)).distance,
      (center - Offset(size.width, size.height)).distance,
    ];
    final maxDistance = distances.reduce(math.max);
    final overscan = math.max(size.longestSide * 0.08, 18.0);
    return (maxDistance + overscan) * progress;
  }
}

class _ThemeRevealPainter extends CustomPainter {
  const _ThemeRevealPainter({
    required this.image,
    required this.center,
    required this.radius,
  });

  final ui.Image image;
  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final destination = Offset.zero & size;
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.saveLayer(destination, Paint());
    canvas.drawImageRect(image, source, destination, Paint());
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..blendMode = BlendMode.clear
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ThemeRevealPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius;
  }
}

// ignore: unused_element
class _ThemeRevealClipper extends CustomClipper<Path> {
  const _ThemeRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    // Use even-odd fill so the reveal circle is punched out of the captured
    // snapshot while the radius expands outward.
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _ThemeRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
