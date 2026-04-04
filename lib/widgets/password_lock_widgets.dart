import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../l10n/l10n.dart';
import '../services/password_lock_service.dart';

const String passwordProtectedAnimationAsset =
    'assets/animations/password_protected.json';

class PasswordLockAnimationCache {
  PasswordLockAnimationCache._();

  static final AssetLottie _provider = AssetLottie(
    passwordProtectedAnimationAsset,
  );
  static LottieComposition? _composition;
  static Future<LottieComposition>? _loadFuture;

  static LottieComposition? get cachedComposition => _composition;

  static Future<LottieComposition> ensureLoaded({BuildContext? context}) {
    final composition = _composition;
    if (composition != null) {
      return Future<LottieComposition>.value(composition);
    }
    return _loadFuture ??= _provider.load(context: context).then((composition) {
      _composition = composition;
      return composition;
    });
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
    final cachedComposition = PasswordLockAnimationCache.cachedComposition;
    if (cachedComposition != null) {
      _composition = cachedComposition;
    }
    unawaited(_loadComposition());
  }

  Future<void> _loadComposition() async {
    final composition = await PasswordLockAnimationCache.ensureLoaded();
    if (!mounted) {
      return;
    }
    final startProgress = _progressForFrame(composition, _visibleStartFrame);
    final holdProgress = _progressForFrame(composition, _holdFrame);
    final animationSpan = math.max(holdProgress - startProgress, 0.0);
    final holdDuration = Duration(
      milliseconds: (composition.duration.inMilliseconds * animationSpan)
          .round(),
    );
    _controller.value = startProgress;
    setState(() {
      _composition = composition;
    });
    await _controller.animateTo(
      holdProgress,
      duration: holdDuration,
      curve: Curves.linear,
    );
  }

  double _progressForFrame(LottieComposition composition, double frame) {
    final targetFrame = math.max(
      composition.startFrame,
      math.min(frame, composition.endFrame - 1),
    );
    final durationFrames = composition.durationFrames;
    if (durationFrames <= 0) {
      return 1;
    }
    return (targetFrame - composition.startFrame) / durationFrames;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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

  PasswordLockService get _controller => widget.controller;

  @override
  void didUpdateWidget(covariant PasswordLockGateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.input.isEmpty &&
        !_controller.isLockedOut &&
        _errorHighlight) {
      _errorHighlight = false;
    }
  }

  Future<void> _handleDigitPressed(String digit) async {
    if (!_controller.shouldBlockApp || _controller.isLockedOut) {
      return;
    }
    await HapticFeedback.mediumImpact();
    final result = await _controller.appendDigit(digit);
    if (!mounted) {
      return;
    }
    switch (result) {
      case PasswordVerificationResult.incomplete:
        setState(() {
          _feedback = null;
          _errorHighlight = false;
        });
        break;
      case PasswordVerificationResult.success:
        setState(() {
          _feedback = null;
          _errorHighlight = false;
        });
        break;
      case PasswordVerificationResult.failed:
        setState(() {
          _feedback = l10n(
            context,
          ).passwordLockWrongPin(_controller.remainingAttempts.toString());
          _errorHighlight = true;
        });
        break;
      case PasswordVerificationResult.lockedOut:
        setState(() {
          _feedback = l10n(context).passwordLockLockedForMinutes;
          _errorHighlight = true;
        });
        break;
    }
  }

  Future<void> _handleBackspacePressed() async {
    if (_controller.isLockedOut) {
      return;
    }
    await HapticFeedback.lightImpact();
    _controller.removeLastDigit();
    if (!mounted) {
      return;
    }
    setState(() {
      _feedback = null;
      _errorHighlight = false;
    });
  }

  Future<void> _handleBiometricPressed() async {
    await HapticFeedback.mediumImpact();
    final success = await _controller.authenticateWithBiometric();
    if (!mounted || success) {
      return;
    }
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
                                Icon(
                                  Icons.lock_rounded,
                                  size: 44,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(height: 18),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xff242424)
        : colorScheme.surfaceContainerHigh;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : colorScheme.outlineVariant.withValues(alpha: 0.7);
    final digitColor = isDark ? Colors.white : colorScheme.onSurface;
    final lettersColor = isDark
        ? Colors.white.withValues(alpha: 0.48)
        : colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: enabled ? onPressed : null,
        child: Ink(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  digit,
                  style: TextStyle(
                    color: digitColor,
                    fontSize: digitFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (letters.isNotEmpty)
                Positioned(
                  right: 22,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      letters,
                      style: TextStyle(
                        color: lettersColor,
                        fontSize: letterFontSize,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xff242424)
        : colorScheme.surfaceContainerHigh;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : colorScheme.outlineVariant.withValues(alpha: 0.7);
    final iconColor = isDark ? Colors.white : colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onPressed,
        child: Ink(
          height: buttonHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 28)),
        ),
      ),
    );
  }
}
