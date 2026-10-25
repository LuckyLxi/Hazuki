import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/services/password_lock_service.dart';

part 'password_lock_animation.dart';
part 'password_lock_keypad.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gate overlay
// ─────────────────────────────────────────────────────────────────────────────

/// 解锁遮罩的宿主：服务解除阻挡后先保留遮罩播放解锁动画，
/// 再以锁为圆心向外揭开露出应用，结束后才真正移除。
class PasswordLockGateHost extends StatefulWidget {
  const PasswordLockGateHost({super.key, required this.controller});

  final PasswordLockService controller;

  @override
  State<PasswordLockGateHost> createState() => _PasswordLockGateHostState();
}

class _PasswordLockGateHostState extends State<PasswordLockGateHost>
    with SingleTickerProviderStateMixin {
  // 解锁动画（锁梁弹开 + 对勾）保留时长，之后开始揭开
  static const Duration _unlockHold = Duration(milliseconds: 560);
  // 锁梁弹开的瞬间触发震动
  static const Duration _unlockHapticDelay = Duration(milliseconds: 120);

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  final GlobalKey _lockKey = GlobalKey();
  final List<Timer> _timers = [];
  // 只在收到通知时更新：服务解锁时会先改状态、写完偏好才通知，
  // 若构建时直接读取 shouldBlockApp，中间插入的一帧会让遮罩消失而闪出底层页面
  late bool _wasBlocking = widget.controller.shouldBlockApp;
  bool _unlocking = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PasswordLockGateHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _wasBlocking = widget.controller.shouldBlockApp;
    }
  }

  void _handleControllerChanged() {
    final blocking = widget.controller.shouldBlockApp;
    if (_wasBlocking && !blocking) {
      _startUnlock();
    } else if (blocking && _unlocking) {
      // 退场途中被重新上锁：立即恢复为完整遮罩
      _cancelUnlock();
    }
    _wasBlocking = blocking;
    setState(() {});
  }

  void _startUnlock() {
    _cancelTimers();
    _unlocking = true;
    _reveal.value = 0;
    _timers
      ..add(Timer(_unlockHapticDelay, () => HapticFeedback.heavyImpact()))
      ..add(
        Timer(_unlockHold, () {
          if (!mounted) return;
          _reveal.forward(from: 0).whenCompleteOrCancel(() {
            if (!mounted || !_unlocking) return;
            setState(() => _unlocking = false);
            _reveal.value = 0;
          });
        }),
      );
  }

  void _cancelUnlock() {
    _cancelTimers();
    _reveal.stop();
    _reveal.value = 0;
    _unlocking = false;
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _cancelTimers();
    widget.controller.removeListener(_handleControllerChanged);
    _reveal.dispose();
    super.dispose();
  }

  Offset? _lockCenterIn(RenderBox host) {
    final lockBox = _lockKey.currentContext?.findRenderObject();
    if (lockBox is! RenderBox || !lockBox.attached || !lockBox.hasSize) {
      return null;
    }
    return host.globalToLocal(
      lockBox.localToGlobal(lockBox.size.center(Offset.zero)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_wasBlocking && !_unlocking) {
      return const SizedBox.shrink();
    }
    final overlay = Stack(
      fit: StackFit.expand,
      children: [
        PasswordLockGateOverlay(
          controller: widget.controller,
          // 尚未收到解锁通知但服务已不再阻挡时，同样按解锁中处理，保持内容不变
          unlocking: _unlocking || !widget.controller.shouldBlockApp,
          lockKey: _lockKey,
        ),
      ],
    );
    // ClipPath 始终保留：揭开开始时若再插入裁剪层，会重建整棵遮罩并改变图层结构，
    // 在带 BackdropFilter 的磨砂顶栏页面上会闪出一帧底层内容
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _reveal,
        child: overlay,
        builder: (context, child) {
          final t = Curves.easeInOutCubic.transform(_reveal.value);
          return ClipPath(
            clipper: _RevealHoleClipper(
              progress: t,
              centerOf: (size) {
                final host = context.findRenderObject();
                final center = host is RenderBox && host.hasSize
                    ? _lockCenterIn(host)
                    : null;
                return center ?? size.center(Offset.zero);
              },
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// 在遮罩上挖出一个逐渐扩大的圆洞，露出下方的应用。
class _RevealHoleClipper extends CustomClipper<Path> {
  const _RevealHoleClipper({required this.progress, required this.centerOf});

  final double progress;
  final Offset Function(Size size) centerOf;

  @override
  Path getClip(Size size) {
    if (progress <= 0) return Path()..addRect(Offset.zero & size);
    final center = centerOf(size);
    // 半径取圆心到最远角的距离，保证结束时完全揭开
    final maxRadius = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - center).distance).reduce(math.max);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: maxRadius * progress));
  }

  @override
  bool shouldReclip(_RevealHoleClipper oldClipper) =>
      oldClipper.progress != progress;
}

class PasswordLockGateOverlay extends StatefulWidget {
  const PasswordLockGateOverlay({
    super.key,
    required this.controller,
    this.unlocking = false,
    this.lockKey,
  });

  final PasswordLockService controller;

  /// 挂在锁动画上的 key，供退场动画定位圆形揭开的圆心。
  final GlobalKey? lockKey;

  /// 已解锁、正在播放解锁与退场动画；此时服务端已不再阻挡，但遮罩仍需保留内容。
  final bool unlocking;

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
        unawaited(_playErrorHaptics());
        setState(() {
          _feedback = l10n(
            context,
          ).passwordLockWrongPin(_controller.remainingAttempts.toString());
          _errorHighlight = true;
          _lockState = LockGateState.error;
        });
      case PasswordVerificationResult.lockedOut:
        unawaited(_playErrorHaptics());
        setState(() {
          _feedback = l10n(context).passwordLockLockedForMinutes;
          _errorHighlight = true;
          _lockState = LockGateState.lockout;
        });
    }
  }

  /// 密码错误：一长一短两次震动，与锁的左右摆动同步。
  Future<void> _playErrorHaptics() async {
    await HapticFeedback.vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    await HapticFeedback.heavyImpact();
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
          child: controller.shouldBlockApp || widget.unlocking
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
                                  key: widget.lockKey,
                                  size: 148,
                                  state: widget.unlocking
                                      ? LockGateState.success
                                      : controller.isLockedOut
                                      ? LockGateState.lockout
                                      : _lockState,
                                  digitVersion: _digitVersion,
                                  filledCount: controller.input.length,
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
                                      !widget.unlocking &&
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
