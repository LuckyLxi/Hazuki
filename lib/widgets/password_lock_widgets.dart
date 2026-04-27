import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../l10n/l10n.dart';
import '../services/password_lock_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lottie header (设置密码页使用)
// ─────────────────────────────────────────────────────────────────────────────

const String _passwordProtectedAnimationAsset =
    'assets/animations/password_protected.json';

class PasswordLockAnimationCache {
  PasswordLockAnimationCache._();

  static final AssetLottie _provider = AssetLottie(
    _passwordProtectedAnimationAsset,
  );
  static LottieComposition? _composition;
  static Future<LottieComposition>? _loadFuture;

  static LottieComposition? get cachedComposition => _composition;

  static Future<LottieComposition> ensureLoaded({BuildContext? context}) {
    final composition = _composition;
    if (composition != null) return Future.value(composition);
    return _loadFuture ??= _provider
        .load(context: context)
        .then((c) => _composition = c);
  }
}

class PasswordLockAnimationHeader extends StatefulWidget {
  const PasswordLockAnimationHeader({super.key, this.size = 228});

  final double size;

  @override
  State<PasswordLockAnimationHeader> createState() =>
      _PasswordLockAnimationHeaderState();
}

class _PasswordLockAnimationHeaderState
    extends State<PasswordLockAnimationHeader>
    with SingleTickerProviderStateMixin {
  static const double _visibleStartFrame = 62.0;
  static const double _holdFrame = 83.0;

  late final AnimationController _controller = AnimationController(vsync: this);
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    final cached = PasswordLockAnimationCache.cachedComposition;
    if (cached != null) _composition = cached;
    unawaited(_loadComposition());
  }

  Future<void> _loadComposition() async {
    final composition = await PasswordLockAnimationCache.ensureLoaded();
    if (!mounted) return;
    final start = _progressForFrame(composition, _visibleStartFrame);
    final hold = _progressForFrame(composition, _holdFrame);
    final span = math.max(hold - start, 0.0);
    final dur = Duration(
      milliseconds: (composition.duration.inMilliseconds * span).round(),
    );
    _controller.value = start;
    setState(() => _composition = composition);
    await _controller.animateTo(hold, duration: dur, curve: Curves.linear);
  }

  double _progressForFrame(LottieComposition c, double frame) {
    final f = math.max(c.startFrame, math.min(frame, c.endFrame - 1));
    final d = c.durationFrames;
    return d <= 0 ? 1.0 : (f - c.startFrame) / d;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _composition == null
              ? DecoratedBox(
                  key: const ValueKey<String>('placeholder'),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock_person_rounded,
                      size: widget.size * 0.36,
                      color: colorScheme.primary.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : Lottie(
                  key: const ValueKey<String>('lottie'),
                  composition: _composition,
                  controller: _controller,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  repeat: false,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vector lock painter (解锁遮罩使用)
//
// Canvas layout (normalised 0–1):
//   Shackle occupies top ~55 %, body occupies bottom ~58 %,
//   they overlap ~13 % so the shackle legs disappear into the body.
//
//   Body : left=0.18  right=0.82  top=0.46  bottom=0.92
//          → width≈64 %  height≈46 %  (square-ish at typical sizes)
//
//   Shackle: left=0.32  right=0.68  (36 % wide = narrower than body)
//            shackleRadius ≈ 18 % of canvas
//            strokeWidth ≈ 8 % of canvas
//            top (closed) ≈ 14 % from canvas top
// ─────────────────────────────────────────────────────────────────────────────

class _LockPainter extends CustomPainter {
  const _LockPainter({
    required this.shackleOpenFraction,
    required this.bodyColor,
    required this.shackleColor,
    required this.shimmerColor,
    required this.shimmerOpacity,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  final double shackleOpenFraction;
  final Color bodyColor;
  final Color shackleColor;
  final Color shimmerColor;
  final double shimmerOpacity;
  final double offsetX;
  final double offsetY;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Apply offset + scale around canvas center
    final cx = size.width / 2 + offsetX;
    final cy = size.height / 2 + offsetY;
    canvas.translate(cx, cy);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height / 2);

    final w = size.width;
    final h = size.height;

    // ── Body ──────────────────────────────────────────────────────────────────
    final bodyLeft = w * 0.18;
    final bodyTop = h * 0.44;
    final bodyRight = w * 0.82;
    final bodyBottom = h * 0.93;
    final bodyW = bodyRight - bodyLeft;
    final bodyRadius = bodyW * 0.18;

    final bodyRRect = RRect.fromLTRBR(
      bodyLeft,
      bodyTop,
      bodyRight,
      bodyBottom,
      Radius.circular(bodyRadius),
    );

    // ── Shackle ───────────────────────────────────────────────────────────────
    final shackleStroke = w * 0.085;
    final shackleLeft = w * 0.335;
    final shackleRight = w * 0.665;
    final shackleRadius = (shackleRight - shackleLeft) / 2; // ~16.5 % of w

    // Where the legs enter the body (inner bottom of shackle)
    final legBottom = h * 0.515;

    // Top of the U arc (closed / open)
    final arcTopClosed = h * 0.115;
    final arcTopOpen = h * 0.01 - shackleStroke;
    final arcTop =
        arcTopClosed + (arcTopOpen - arcTopClosed) * shackleOpenFraction;

    // Right leg: rises when open (simulates pivot)
    final rightLegBottomOpen = h * 0.30;
    final rightLegBottom =
        legBottom + (rightLegBottomOpen - legBottom) * shackleOpenFraction;

    final shacklePaint = Paint()
      ..color = shackleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = shackleStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shacklePath = Path()
      ..moveTo(shackleLeft, legBottom)
      ..lineTo(shackleLeft, arcTop + shackleRadius)
      ..arcToPoint(
        Offset(shackleRight, arcTop + shackleRadius),
        radius: Radius.circular(shackleRadius),
        clockwise: true,
      )
      ..lineTo(shackleRight, rightLegBottom);

    canvas.drawPath(shacklePath, shacklePaint);

    // ── Body fill (drawn after shackle so it covers leg ends) ─────────────────
    canvas.drawRRect(bodyRRect, Paint()..color = bodyColor);

    // ── Keyhole ───────────────────────────────────────────────────────────────
    final khX = w / 2;
    final khY = (bodyTop + bodyBottom) / 2;
    final khR = bodyW * 0.10;

    canvas.drawCircle(
      Offset(khX, khY - khR * 0.15),
      khR,
      Paint()
        ..color = shackleColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      Offset(khX, khY + khR * 0.65),
      Offset(khX, khY + khR * 1.75),
      Paint()
        ..color = shackleColor.withValues(alpha: 0.22)
        ..strokeWidth = khR * 0.82
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // ── Shimmer overlay ───────────────────────────────────────────────────────
    if (shimmerOpacity > 0) {
      canvas.drawRRect(
        bodyRRect,
        Paint()
          ..color = shimmerColor.withValues(alpha: shimmerOpacity)
          ..style = PaintingStyle.fill,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.shackleOpenFraction != shackleOpenFraction ||
      old.bodyColor != bodyColor ||
      old.shackleColor != shackleColor ||
      old.shimmerColor != shimmerColor ||
      old.shimmerOpacity != shimmerOpacity ||
      old.offsetX != offsetX ||
      old.offsetY != offsetY ||
      old.scale != scale;
}

// ─────────────────────────────────────────────────────────────────────────────
// Gate animation header (解锁遮罩)
// ─────────────────────────────────────────────────────────────────────────────

enum LockGateState { idle, digit, error, lockout, success }

class LockGateAnimationHeader extends StatefulWidget {
  const LockGateAnimationHeader({
    super.key,
    this.size = 180,
    required this.state,
    required this.digitVersion,
  });

  final double size;
  final LockGateState state;
  final int digitVersion;

  @override
  State<LockGateAnimationHeader> createState() =>
      _LockGateAnimationHeaderState();
}

class _LockGateAnimationHeaderState extends State<LockGateAnimationHeader>
    with TickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _successCtrl;

  late Animation<double> _bounceY;
  late Animation<double> _bounceScale;
  late Animation<double> _shakeX;
  late Animation<double> _successShackle;
  late Animation<double> _successScale;

  int _prevDigitVersion = 0;
  LockGateState _prevState = LockGateState.idle;

  void _resetBounce() {
    _bounceCtrl.stop();
    _bounceCtrl.value = 0;
  }

  void _resetShake() {
    _shakeCtrl.stop();
    _shakeCtrl.value = 0;
  }

  void _resetSuccess() {
    _successCtrl.stop();
    _successCtrl.value = 0;
  }

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _bounceY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 7), weight: 28),
      TweenSequenceItem(tween: Tween<double>(begin: 7, end: -3.5), weight: 36),
      TweenSequenceItem(tween: Tween<double>(begin: -3.5, end: 0), weight: 36),
    ]).animate(_bounceCtrl);

    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.05),
        weight: 36,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0),
        weight: 36,
      ),
    ]).animate(_bounceCtrl);

    _shakeX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -11.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -11.0, end: 11.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 11.0, end: -8.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -8.0, end: 8.0),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 8.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeOut));

    _successShackle = Tween<double>(
      begin: 0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.easeOutBack));

    _successScale = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.12),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.12, end: 0.0),
          weight: 65,
        ),
      ],
    ).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.easeInCubic));
  }

  @override
  void didUpdateWidget(covariant LockGateAnimationHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.state == LockGateState.success &&
        _prevState != LockGateState.success) {
      _resetBounce();
      _resetShake();
      _successCtrl.forward(from: 0);
    } else if (widget.state == LockGateState.error &&
        _prevState != LockGateState.error) {
      _resetBounce();
      _resetSuccess();
      _shakeCtrl.forward(from: 0);
    } else if (widget.state == LockGateState.lockout &&
        _prevState != LockGateState.lockout) {
      _resetBounce();
      _resetShake();
      _resetSuccess();
    } else if (widget.state == LockGateState.idle &&
        _prevState != LockGateState.idle) {
      _resetBounce();
      _resetShake();
      _resetSuccess();
    } else if (widget.digitVersion != _prevDigitVersion &&
        widget.state == LockGateState.digit) {
      _resetShake();
      _resetSuccess();
      _bounceCtrl.forward(from: 0);
    }

    _prevDigitVersion = widget.digitVersion;
    _prevState = widget.state;
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _shakeCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceCtrl, _shakeCtrl, _successCtrl]),
        builder: (context, _) {
          final isSuccess =
              _successCtrl.isAnimating || _successCtrl.isCompleted;
          final isError = widget.state == LockGateState.error;
          final isLockout = widget.state == LockGateState.lockout;

          double shackle = 0;
          double scale = 1.0;
          double offsetX = 0;
          double offsetY = 0;
          Color bodyColor;
          Color shackleColor;

          if (isSuccess) {
            shackle = _successShackle.value;
            scale = _successScale.value;
            final t = math.min(_successCtrl.value * 2.5, 1.0);
            bodyColor = Color.lerp(
              colorScheme.primaryContainer,
              Colors.green.shade400,
              t,
            )!;
            shackleColor = Color.lerp(
              colorScheme.primary,
              Colors.green.shade600,
              t,
            )!;
          } else if (isError && _shakeCtrl.isAnimating) {
            offsetX = _shakeX.value;
            final t = _shakeCtrl.value < 0.5
                ? _shakeCtrl.value * 2
                : (1 - _shakeCtrl.value) * 2;
            bodyColor = Color.lerp(
              colorScheme.primaryContainer,
              colorScheme.errorContainer,
              t,
            )!;
            shackleColor = Color.lerp(
              colorScheme.primary,
              colorScheme.error,
              t,
            )!;
          } else if (isLockout) {
            bodyColor = colorScheme.errorContainer;
            shackleColor = colorScheme.error;
          } else {
            offsetY = _bounceY.value;
            scale = _bounceScale.value;
            bodyColor = colorScheme.primaryContainer;
            shackleColor = colorScheme.primary;
          }

          // Extra top padding so shackle is never clipped
          return SizedBox(
            width: widget.size,
            height: widget.size + widget.size * 0.08,
            child: CustomPaint(
              painter: _LockPainter(
                shackleOpenFraction: shackle,
                bodyColor: bodyColor,
                shackleColor: shackleColor,
                shimmerColor: Colors.transparent,
                shimmerOpacity: 0,
                offsetX: offsetX,
                offsetY: offsetY + widget.size * 0.04,
                scale: scale,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filled boxes indicator
// ─────────────────────────────────────────────────────────────────────────────

class PasswordLockFilledBoxes extends StatelessWidget {
  const PasswordLockFilledBoxes({
    super.key,
    required this.length,
    this.maxLength = 4,
    this.highlightError = false,
  });

  final int length;
  final int maxLength;
  final bool highlightError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(maxLength, (index) {
        final filled = index < length;
        final accentColor = highlightError
            ? colorScheme.error
            : colorScheme.primary;
        return Padding(
          padding: EdgeInsets.only(right: index == maxLength - 1 ? 0 : 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            width: 52,
            height: 60,
            decoration: BoxDecoration(
              color: filled
                  ? accentColor.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: filled
                    ? accentColor.withValues(alpha: 0.7)
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
                width: filled ? 1.6 : 1,
              ),
            ),
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                scale: filled ? 1 : 0.4,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: filled ? 1 : 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Numeric keypad
// ─────────────────────────────────────────────────────────────────────────────

class PasswordLockNumericKeypad extends StatelessWidget {
  const PasswordLockNumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.onBiometricPressed,
    this.showBiometricButton = false,
    this.enabled = true,
    this.maxWidth = 360,
    this.buttonHeight = 74,
    this.spacing = 12,
    this.borderRadius = 22,
    this.digitFontSize = 28,
    this.letterFontSize = 15,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback? onBiometricPressed;
  final bool showBiometricButton;
  final bool enabled;
  final double maxWidth;
  final double buttonHeight;
  final double spacing;
  final double borderRadius;
  final double digitFontSize;
  final double letterFontSize;

  static const Map<String, String> _letters = <String, String>{
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        children: [
          _buildRow(context, const ['1', '2', '3']),
          SizedBox(height: spacing),
          _buildRow(context, const ['4', '5', '6']),
          SizedBox(height: spacing),
          _buildRow(context, const ['7', '8', '9']),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: showBiometricButton
                    ? _PasswordKeyButton(
                        icon: Icons.fingerprint_rounded,
                        onPressed: enabled ? onBiometricPressed : null,
                        buttonHeight: buttonHeight,
                        borderRadius: borderRadius,
                      )
                    : SizedBox(height: buttonHeight),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _PasswordDigitButton(
                  digit: '0',
                  letters: _letters['0']!,
                  enabled: enabled,
                  onPressed: () => onDigitPressed('0'),
                  buttonHeight: buttonHeight,
                  borderRadius: borderRadius,
                  digitFontSize: digitFontSize,
                  letterFontSize: letterFontSize,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _PasswordKeyButton(
                  icon: Icons.backspace_outlined,
                  onPressed: enabled ? onBackspacePressed : null,
                  buttonHeight: buttonHeight,
                  borderRadius: borderRadius,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> digits) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          Expanded(
            child: _PasswordDigitButton(
              digit: digits[i],
              letters: _letters[digits[i]] ?? '',
              enabled: enabled,
              onPressed: () => onDigitPressed(digits[i]),
              buttonHeight: buttonHeight,
              borderRadius: borderRadius,
              digitFontSize: digitFontSize,
              letterFontSize: letterFontSize,
            ),
          ),
          if (i != digits.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gate overlay
// ─────────────────────────────────────────────────────────────────────────────

class PasswordLockGateOverlay extends StatefulWidget {
  const PasswordLockGateOverlay({super.key, required this.controller});

  final PasswordLockService controller;

  @override
  State<PasswordLockGateOverlay> createState() =>
      _PasswordLockGateOverlayState();
}

class _PasswordLockGateOverlayState extends State<PasswordLockGateOverlay> {
  String? _feedback;
  bool _errorHighlight = false;
  LockGateState _lockState = LockGateState.idle;
  int _digitVersion = 0;

  PasswordLockService get _controller => widget.controller;

  @override
  void didUpdateWidget(covariant PasswordLockGateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.input.isEmpty &&
        !_controller.isLockedOut &&
        _errorHighlight) {
      _errorHighlight = false;
    }
    if (!_controller.shouldBlockApp) {
      _lockState = LockGateState.idle;
      _digitVersion = 0;
      _feedback = null;
      _errorHighlight = false;
      return;
    }
    if (!_controller.isLockedOut && _lockState == LockGateState.lockout) {
      _lockState = LockGateState.idle;
      _feedback = null;
      _errorHighlight = false;
    }
  }

  Future<void> _handleDigitPressed(String digit) async {
    if (!_controller.shouldBlockApp || _controller.isLockedOut) return;
    await HapticFeedback.mediumImpact();
    setState(() {
      _lockState = LockGateState.digit;
      _digitVersion++;
    });
    final result = await _controller.appendDigit(digit);
    if (!mounted) return;
    switch (result) {
      case PasswordVerificationResult.incomplete:
        setState(() {
          _feedback = null;
          _errorHighlight = false;
        });
      case PasswordVerificationResult.success:
        setState(() {
          _feedback = null;
          _errorHighlight = false;
          _lockState = LockGateState.success;
        });
      case PasswordVerificationResult.failed:
        setState(() {
          _feedback = l10n(
            context,
          ).passwordLockWrongPin(_controller.remainingAttempts.toString());
          _errorHighlight = true;
          _lockState = LockGateState.error;
        });
      case PasswordVerificationResult.lockedOut:
        setState(() {
          _feedback = l10n(context).passwordLockLockedForMinutes;
          _errorHighlight = true;
          _lockState = LockGateState.lockout;
        });
    }
  }

  Future<void> _handleBackspacePressed() async {
    if (_controller.isLockedOut) return;
    await HapticFeedback.lightImpact();
    _controller.removeLastDigit();
    if (!mounted) return;
    setState(() {
      _feedback = null;
      _errorHighlight = false;
      _lockState = LockGateState.idle;
    });
  }

  Future<void> _handleBiometricPressed() async {
    await HapticFeedback.mediumImpact();
    final success = await _controller.authenticateWithBiometric();
    if (!mounted || success) return;
    setState(() {
      _feedback = l10n(context).passwordLockBiometricFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = controller.lockoutRemaining;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Positioned.fill(
      child: Material(
        color: colorScheme.surface,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: controller.shouldBlockApp
              ? SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = math.min(
                        constraints.maxWidth * 0.92,
                        420.0,
                      );
                      return Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                LockGateAnimationHeader(
                                  size: 148,
                                  state: controller.isLockedOut
                                      ? LockGateState.lockout
                                      : _lockState,
                                  digitVersion: _digitVersion,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n(context).passwordLockUnlockTitle,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  controller.isLockedOut
                                      ? l10n(context).passwordLockCountdown(
                                          '$minutes:$seconds',
                                        )
                                      : l10n(
                                          context,
                                        ).passwordLockUnlockSubtitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 26),
                                PasswordLockFilledBoxes(
                                  length: controller.input.length,
                                  highlightError: _errorHighlight,
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 20,
                                  child: Text(
                                    _feedback ?? '',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _errorHighlight
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                PasswordLockNumericKeypad(
                                  enabled:
                                      !controller.isLockedOut &&
                                      !controller.authenticatingBiometric,
                                  maxWidth: 372,
                                  buttonHeight: 76,
                                  spacing: 12,
                                  digitFontSize: 29,
                                  letterFontSize: 14,
                                  showBiometricButton:
                                      controller.showBiometricButton,
                                  onDigitPressed: (digit) {
                                    unawaited(_handleDigitPressed(digit));
                                  },
                                  onBackspacePressed: () {
                                    unawaited(_handleBackspacePressed());
                                  },
                                  onBiometricPressed: _handleBiometricPressed,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private button widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordDigitButton extends StatelessWidget {
  const _PasswordDigitButton({
    required this.digit,
    required this.letters,
    required this.enabled,
    required this.onPressed,
    required this.buttonHeight,
    required this.borderRadius,
    required this.digitFontSize,
    required this.letterFontSize,
  });

  final String digit;
  final String letters;
  final bool enabled;
  final VoidCallback onPressed;
  final double buttonHeight;
  final double borderRadius;
  final double digitFontSize;
  final double letterFontSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: enabled ? onPressed : null,
        child: Ink(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  digit,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: digitFontSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                if (letters.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    letters,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: letterFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordKeyButton extends StatelessWidget {
  const _PasswordKeyButton({
    required this.icon,
    required this.onPressed,
    required this.buttonHeight,
    required this.borderRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double buttonHeight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onPressed,
        child: Ink(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Center(
            child: Icon(icon, color: colorScheme.onSurfaceVariant, size: 28),
          ),
        ),
      ),
    );
  }
}
