import 'dart:math' as math;

import 'package:flutter/material.dart';

class SunMoonIcon extends StatefulWidget {
  const SunMoonIcon({
    super.key,
    required this.isDark,
    this.size = 28,
    this.sunColor,
    this.moonColor,
    this.duration = const Duration(milliseconds: 600),
  });

  final bool isDark;
  final double size;
  final Color? sunColor;
  final Color? moonColor;
  final Duration duration;

  @override
  State<SunMoonIcon> createState() => _SunMoonIconState();
}

class _SunMoonIconState extends State<SunMoonIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _rotation;
  late Animation<double> _rayOpacity;
  late Animation<double> _crescentProgress;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.isDark ? 1 : 0,
    );
    _buildAnimations();
  }

  @override
  void didUpdateWidget(covariant SunMoonIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.isDark != widget.isDark) {
      if (widget.isDark) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  void _buildAnimations() {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _rotation = Tween<double>(begin: 0, end: math.pi).animate(curve);

    _rayOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 60),
    ]).animate(_controller);

    _crescentProgress = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 30),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 70,
      ),
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.85,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sunColor = widget.sunColor ?? const Color(0xFFF5A623);
    final moonColor = widget.moonColor ?? const Color(0xFFB0C4DE);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.rotate(
          angle: _rotation.value,
          child: Transform.scale(
            scale: _scale.value,
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _SunMoonPainter(
                progress: _controller.value,
                rayOpacity: _rayOpacity.value,
                crescentProgress: _crescentProgress.value,
                sunColor: sunColor,
                moonColor: moonColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SunMoonPainter extends CustomPainter {
  const _SunMoonPainter({
    required this.progress,
    required this.rayOpacity,
    required this.crescentProgress,
    required this.sunColor,
    required this.moonColor,
  });

  final double progress;
  final double rayOpacity;
  final double crescentProgress;
  final Color sunColor;
  final Color moonColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final bodyRadius = r * 0.50;
    final bodyColor = Color.lerp(sunColor, moonColor, progress)!;
    final fillPaint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.fill;

    if (rayOpacity > 0) {
      final rayPaint = Paint()
        ..color = sunColor.withValues(alpha: rayOpacity)
        ..strokeWidth = size.width * 0.08
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      const rayCount = 8;
      final innerR = bodyRadius + r * 0.10;
      final outerR = bodyRadius + r * 0.24;

      for (var i = 0; i < rayCount; i++) {
        final angle = (2 * math.pi / rayCount) * i;
        final from = Offset(
          center.dx + innerR * math.cos(angle),
          center.dy + innerR * math.sin(angle),
        );
        final to = Offset(
          center.dx + outerR * math.cos(angle),
          center.dy + outerR * math.sin(angle),
        );
        canvas.drawLine(from, to, rayPaint);
      }
    }

    if (crescentProgress > 0.01) {
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.saveLayer(rect, Paint());
      canvas.drawCircle(center, bodyRadius, fillPaint);

      final offset = bodyRadius * 0.60 * crescentProgress;
      final maskPaint = Paint()
        ..color = const Color(0xFF000000)
        ..blendMode = BlendMode.dstOut;
      canvas.drawCircle(
        Offset(center.dx - offset * 0.85, center.dy + offset * 0.6),
        bodyRadius * 0.85,
        maskPaint,
      );

      canvas.restore();
      return;
    }

    canvas.drawCircle(center, bodyRadius, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SunMoonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rayOpacity != rayOpacity ||
        oldDelegate.crescentProgress != crescentProgress ||
        oldDelegate.sunColor != sunColor ||
        oldDelegate.moonColor != moonColor;
  }
}
