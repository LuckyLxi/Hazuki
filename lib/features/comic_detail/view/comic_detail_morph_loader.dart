import 'dart:math' as math;

import 'package:flutter/material.dart';

class ShapeMorphingLoader extends StatefulWidget {
  const ShapeMorphingLoader({super.key, this.size = 84});

  final double size;

  @override
  State<ShapeMorphingLoader> createState() => _ShapeMorphingLoaderState();
}

class _ShapeMorphingLoaderState extends State<ShapeMorphingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ShapeMorphingLoaderPainter(
                progress: _controller.value,
                primary: cs.primary,
                secondary: cs.tertiary,
                highlight: cs.surfaceContainerHighest,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShapeMorphingLoaderPainter extends CustomPainter {
  const _ShapeMorphingLoaderPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.highlight,
  });

  final double progress;
  final Color primary;
  final Color secondary;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide;
    final phase = progress * math.pi * 2;
    final waveA = (math.sin(phase) + 1) / 2;
    final waveB = (math.sin(phase + math.pi / 2) + 1) / 2;
    final waveC = (math.sin(phase - math.pi / 3) + 1) / 2;

    final width = base * (0.44 + 0.22 * waveA);
    final height = base * (0.44 + 0.22 * waveB);
    final radius = base * (0.1 + 0.18 * waveC);
    final rotation = math.sin(phase - 0.8) * 0.42;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = primary.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(primary, secondary, 0.18)!,
            Color.lerp(primary, secondary, 0.72)!,
          ],
        ).createShader(rect),
    );

    final highlightRect = Rect.fromCenter(
      center: center.translate(-width * 0.12, -height * 0.16),
      width: width * (0.34 + 0.08 * waveB),
      height: height * (0.18 + 0.06 * waveA),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        highlightRect,
        Radius.circular(highlightRect.height),
      ),
      Paint()..color = highlight.withValues(alpha: 0.42),
    );

    final orbitDistance = base * 0.22;
    final orbitRadius = base * (0.07 + 0.015 * waveC);
    final orbitCenter = center.translate(
      math.cos(phase * 1.4 - math.pi / 3) * orbitDistance,
      math.sin(phase * 1.4 - math.pi / 3) * orbitDistance,
    );
    canvas.drawCircle(
      orbitCenter,
      orbitRadius,
      Paint()..color = secondary.withValues(alpha: 0.86),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapeMorphingLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.highlight != highlight;
  }
}
