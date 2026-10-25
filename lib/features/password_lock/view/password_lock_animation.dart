part of 'password_lock_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 锁动画（设置密码页与解锁遮罩共用）
//
// MD3 Expressive 插画风格：九瓣饼干形底板 + 纯色锁身/锁梁 + 四段刻度。
// 画布按边长 S 归一化：锁身 x∈[0.215, 0.785]、y∈[0.455, 0.875]，
// 锁梁两腿中线位于 cx ± 0.155S，下端藏在锁身之后。
// ─────────────────────────────────────────────────────────────────────────────

enum _LockAnimationMode {
  /// 设置密码：入场后弹开等待输入，输满后扣合。
  setup,

  /// 解锁遮罩：保持扣合，验证成功后弹开。
  gate,
}

const Duration _lockEnterDuration = Duration(milliseconds: 1100);
const Duration _lockErrorDuration = Duration(milliseconds: 860);
const Duration _lockDoneDuration = Duration(milliseconds: 1100);
const double _lockUnlockAtMs = 520;

class PasswordLockAnimationHeader extends StatelessWidget {
  const PasswordLockAnimationHeader({
    super.key,
    this.size = 228,
    this.filledCount = 0,
    this.errorVersion = 0,
    this.completed = false,
  });

  final double size;
  final int filledCount;

  /// 每次递增触发一次出错动画。
  final int errorVersion;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return _HazukiLockAnimation(
      mode: _LockAnimationMode.setup,
      size: size,
      filledCount: filledCount,
      tapVersion: 0,
      errorVersion: errorVersion,
      completed: completed,
      persistentError: false,
    );
  }
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
    this.filledCount = 0,
  });

  final double size;
  final LockGateState state;
  final int digitVersion;
  final int filledCount;

  @override
  State<LockGateAnimationHeader> createState() =>
      _LockGateAnimationHeaderState();
}

class _LockGateAnimationHeaderState extends State<LockGateAnimationHeader> {
  int _errorVersion = 0;

  static bool _isErrorState(LockGateState state) =>
      state == LockGateState.error || state == LockGateState.lockout;

  @override
  void didUpdateWidget(covariant LockGateAnimationHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 进入出错或锁定状态时播放一次出错动画；遮罩打开时已处于锁定则只保持错误配色
    if (_isErrorState(widget.state) && !_isErrorState(oldWidget.state)) {
      _errorVersion++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HazukiLockAnimation(
      mode: _LockAnimationMode.gate,
      size: widget.size,
      filledCount: widget.filledCount,
      tapVersion: widget.digitVersion,
      errorVersion: _errorVersion,
      completed: widget.state == LockGateState.success,
      persistentError: widget.state == LockGateState.lockout,
    );
  }
}

class _HazukiLockAnimation extends StatefulWidget {
  const _HazukiLockAnimation({
    required this.mode,
    required this.size,
    required this.filledCount,
    required this.tapVersion,
    required this.errorVersion,
    required this.completed,
    required this.persistentError,
  });

  final _LockAnimationMode mode;
  final double size;
  final int filledCount;
  final int tapVersion;
  final int errorVersion;
  final bool completed;
  final bool persistentError;

  @override
  State<_HazukiLockAnimation> createState() => _HazukiLockAnimationState();
}

class _HazukiLockAnimationState extends State<_HazukiLockAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: _lockEnterDuration,
  );
  // 待机：底板自转与星点闪烁共用一个循环
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  late final AnimationController _tap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final AnimationController _error = AnimationController(
    vsync: this,
    duration: _lockErrorDuration,
  );
  late final AnimationController _done = AnimationController(
    vsync: this,
    duration: _lockDoneDuration,
  );
  // 刻度填充量，取值 0–4，整数部分为已亮段数
  late final AnimationController _fill = AnimationController(
    vsync: this,
    upperBound: 4,
    duration: const Duration(milliseconds: 220),
    value: widget.filledCount.clamp(0, 4).toDouble(),
  );
  late final Listenable _ticker = Listenable.merge([
    _enter,
    _idle,
    _tap,
    _error,
    _done,
    _fill,
  ]);

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.completed) _done.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce == _reduceMotion && _enter.status != AnimationStatus.dismissed) {
      return;
    }
    _reduceMotion = reduce;
    if (reduce) {
      _enter.value = 1;
      _idle.stop();
    } else {
      if (_enter.status == AnimationStatus.dismissed) _enter.forward();
      if (!_idle.isAnimating) _idle.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _HazukiLockAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filled = widget.filledCount.clamp(0, 4);
    if (filled != oldWidget.filledCount.clamp(0, 4)) {
      _fill.animateTo(filled.toDouble(), curve: Curves.easeOutCubic);
    }
    final tapped =
        widget.tapVersion != oldWidget.tapVersion ||
        widget.filledCount > oldWidget.filledCount;
    if (tapped) {
      // 出错动画进行中继续输入时直接让位给新输入
      if (_error.isAnimating) _error.value = 0;
      _tap.forward(from: 0);
    }
    if (widget.errorVersion != oldWidget.errorVersion) {
      _error.forward(from: 0);
    }
    if (widget.completed != oldWidget.completed) {
      if (widget.completed) {
        _done.forward(from: 0);
      } else {
        _done.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _idle.dispose();
    _tap.dispose();
    _error.dispose();
    _done.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _ticker,
          builder: (context, _) => CustomPaint(
            painter: _HazukiLockPainter(
              mode: widget.mode,
              colors: colorScheme,
              enterMs: _enter.value * _lockEnterDuration.inMilliseconds,
              idle: _idle.value,
              tap: _tap.isAnimating ? _tap.value : -1,
              errorMs: _error.isAnimating
                  ? _error.value * _lockErrorDuration.inMilliseconds
                  : -1,
              doneMs: widget.completed
                  ? _done.value * _lockDoneDuration.inMilliseconds
                  : -1,
              fill: _fill.value,
              persistentError: widget.persistentError,
            ),
          ),
        ),
      ),
    );
  }
}

double _clamp01(double x) => x.clamp(0.0, 1.0);
double _easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _easeOutBack(double x, [double s = 1.70158]) =>
    1 + (s + 1) * math.pow(x - 1, 3) + s * math.pow(x - 1, 2);

class _HazukiLockPainter extends CustomPainter {
  const _HazukiLockPainter({
    required this.mode,
    required this.colors,
    required this.enterMs,
    required this.idle,
    required this.tap,
    required this.errorMs,
    required this.doneMs,
    required this.fill,
    required this.persistentError,
  });

  final _LockAnimationMode mode;
  final ColorScheme colors;
  final double enterMs;

  /// 待机循环进度 0–1。
  final double idle;

  /// 按键回弹进度 0–1，未播放时为 -1。
  final double tap;

  /// 出错动画已播放毫秒数，未播放时为 -1。
  final double errorMs;

  /// 完成动画已播放毫秒数，未完成时为 -1。
  final double doneMs;
  final double fill;
  final bool persistentError;

  bool get _isSetup => mode == _LockAnimationMode.setup;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final cx = size.width / 2;
    final inErr = errorMs >= 0;

    // 错误色强度：快速染红，保持，再淡回；锁定期间常亮
    var errAmt = 0.0;
    if (inErr) {
      errAmt = errorMs < 90
          ? errorMs / 90
          : errorMs < 520
          ? 1.0
          : 1 - _easeOutCubic(_clamp01((errorMs - 520) / 340));
    }
    if (persistentError) errAmt = 1;

    final shapeColor = Color.lerp(
      colors.primaryContainer,
      colors.errorContainer,
      errAmt,
    )!;
    final bodyColor = Color.lerp(colors.primary, colors.error, errAmt)!;
    final onBody = Color.lerp(colors.onPrimary, colors.onError, errAmt)!;
    final shackleColor = Color.lerp(
      colors.onPrimaryContainer,
      colors.onErrorContainer,
      errAmt,
    )!;

    const bodyTopK = 0.455, bodyBotK = 0.875;
    final bodyTop = s * bodyTopK, bodyBot = s * bodyBotK;
    final bodyL = cx - s * 0.285, bodyR = cx + s * 0.285;
    final bodyCy = (bodyTop + bodyBot) / 2;
    final shapeCy = s * 0.55;

    // ── 底形：饼干形，弹出 + 缓慢自转 ──
    final shapeIn = _easeOutBack(_clamp01(enterMs / 520), 1.4);
    var shapePulse = 0.0;
    if (doneMs >= 230 && doneMs < 830) {
      shapePulse = math.sin((doneMs - 230) / 600 * math.pi) * 0.07;
    }
    if (inErr) shapePulse -= 0.05 * math.sin(_clamp01(errorMs / 700) * math.pi);
    final spinIn = (1 - _easeOutCubic(_clamp01(enterMs / 700))) * -1.0;
    final spinDone = doneMs >= 0
        ? _easeOutCubic(_clamp01((doneMs - 200) / 700)) * (math.pi * 2 / 9)
        : 0.0;
    final rot = idle * math.pi * 2 + spinIn + spinDone;
    final lobeAmp =
        s *
        (0.022 +
            (inErr ? 0.012 * math.sin(_clamp01(errorMs / 700) * math.pi) : 0));
    canvas.drawPath(
      _cookiePath(
        Offset(cx, shapeCy),
        s * 0.4 * shapeIn * (1 + shapePulse),
        lobeAmp * shapeIn,
        rot,
      ),
      Paint()..color = shapeColor,
    );

    // ── 待机点缀 ──
    final twinkleBase = idle * math.pi * 2 * 10;
    final deco = <(double, double, double, Color)>[
      (0.13, 0.2, 0.042, colors.tertiary),
      (0.87, 0.3, 0.028, colors.primary),
      (0.85, 0.86, 0.022, colors.tertiary),
    ];
    for (var i = 0; i < deco.length; i++) {
      final (x, y, r, col) = deco[i];
      final pin = _easeOutBack(_clamp01((enterMs - 760 - i * 90) / 340), 2.2);
      final tw = 0.85 + 0.15 * math.sin(twinkleBase + i * 2);
      _drawSparkle(
        canvas,
        Offset(x * s, y * s),
        r * s * pin * tw,
        math.pi / 4 * (1 - pin),
        Color.lerp(col, colors.error, errAmt)!,
      );
    }

    // ── 完成：同形描边波纹 + 向上飞散的星点 ──
    final impact = doneMs - 230;
    if (doneMs >= 0 && impact >= 0 && impact < 700) {
      final k = impact / 700;
      canvas.drawPath(
        _cookiePath(
          Offset(cx, shapeCy),
          s * (0.42 + 0.1 * _easeOutCubic(k)),
          s * 0.022,
          rot,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012 * (1 - k) + 1
          ..color = colors.primary.withValues(alpha: 0.5 * (1 - k)),
      );
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + (i - 2.5) * 0.5;
        final d = s * (0.3 + 0.2 * _easeOutCubic(k));
        final r = s * 0.03 * math.sin(math.min(1.0, k * 1.4) * math.pi);
        _drawSparkle(
          canvas,
          Offset(cx + math.cos(a) * d, bodyCy - s * 0.05 + math.sin(a) * d),
          r,
          k * 1.5,
          i.isOdd ? colors.tertiary : colors.primary,
        );
      }
    }

    // ── 整体浮现 + 出错摆动（以锁身底部中点为支点）──
    final riseT = _clamp01((enterMs - 120) / 440);
    final lockAlpha = _clamp01((enterMs - 120) / 240);
    final lockScale = 0.86 + 0.14 * _easeOutBack(riseT, 1.2);
    final lockDy = (1 - _easeOutCubic(riseT)) * s * 0.08;
    var tilt = 0.0;
    if (inErr && errorMs > 60) {
      final k = _clamp01((errorMs - 60) / 560);
      tilt =
          math.sin(k * math.pi * 5) * math.pow(1 - k, 2) * (7 * math.pi / 180);
    }

    // ── 锁梁抬起量与锁身挤压 ──
    // bumpMs 为锁身受力后的毫秒数；bumpSign 为正表示被压扁，为负表示被向上拉长
    final liftOpen = s * 0.105;
    var lift = 0.0;
    var bumpMs = -1.0;
    var bumpSign = 1.0;
    var bumpAmp = 0.035;
    if (doneMs >= 0) {
      final t = _clamp01(doneMs / 300);
      if (_isSetup) {
        lift = liftOpen * (1 - _easeOutBack(t, 2.6));
        bumpMs = doneMs - 230;
      } else {
        lift = liftOpen * _easeOutBack(t, 2.2);
        bumpMs = doneMs;
        bumpSign = -1;
      }
      bumpAmp = 0.07;
    } else {
      if (_isSetup) {
        // 入场：扣着出现，随后"咔"地弹开
        lift =
            liftOpen *
            _easeOutBack(_clamp01((enterMs - _lockUnlockAtMs) / 340), 2.2);
        if (enterMs >= _lockUnlockAtMs && enterMs < _lockUnlockAtMs + 580) {
          bumpMs = enterMs - _lockUnlockAtMs;
          bumpSign = -1;
        }
      }
      if (tap >= 0) lift += math.sin(tap * math.pi) * s * 0.022;
      if (inErr) {
        // 设置页：往下扣被挡回；解锁页：往上拔被卡住落回
        final dir = _isSetup ? -1.0 : 1.0;
        final travel = liftOpen * (_isSetup ? 0.62 : 0.4);
        if (errorMs < 150) {
          lift += dir * travel * _easeOutCubic(errorMs / 150);
        } else if (errorMs < 420) {
          lift += dir * travel * (1 - _easeOutBack((errorMs - 150) / 270, 2.4));
        }
        if (errorMs >= 150 && errorMs < 600) {
          bumpMs = errorMs - 150;
          bumpSign = _isSetup ? -1 : 1;
          bumpAmp = 0.05;
        }
      }
    }
    var sq = 0.0;
    if (bumpMs >= 0 && bumpMs < 480) {
      final k = bumpMs / 480;
      sq = math.sin(k * math.pi * 2.5) * math.exp(-k * 4) * bumpAmp * bumpSign;
    }

    if (lockAlpha <= 0) return;
    if (lockAlpha < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, lockAlpha),
      );
    } else {
      canvas.save();
    }
    canvas
      ..translate(cx, bodyBot + lockDy)
      ..rotate(tilt)
      ..scale(lockScale * (1 + sq), lockScale * (1 - sq))
      ..translate(-cx, -bodyBot);

    // 锁梁：纯色粗描边，先画以便两腿下端被锁身盖住
    final shW = s * 0.074;
    final shL = cx - s * 0.155, shR = cx + s * 0.155;
    final shR0 = (shR - shL) / 2;
    final arcCy = s * 0.30 - lift;
    final shacklePath = Path()
      ..moveTo(shL, math.min(arcCy + s * 0.11, bodyTop + s * 0.05))
      ..lineTo(shL, arcCy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, arcCy), radius: shR0),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(shR, bodyTop + s * 0.05);
    canvas.drawPath(
      shacklePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = shackleColor,
    );

    // 锁身
    canvas.drawRRect(
      RRect.fromLTRBR(
        bodyL,
        bodyTop,
        bodyR,
        bodyBot,
        Radius.circular(s * 0.11),
      ),
      Paint()..color = bodyColor,
    );

    // ── 四段刻度 ──
    final bh = bodyBot - bodyTop;
    final keyCenter = Offset(cx, bodyTop + bh * 0.52);
    final keyRect = Rect.fromCircle(center: keyCenter, radius: s * 0.11);
    final trackIn = _easeOutCubic(_clamp01((enterMs - 640) / 460));
    final gapClose = doneMs >= 0
        ? _easeOutCubic(_clamp01((doneMs - 220) / 380))
        : 0.0;
    final gap = 0.4 * (1 - gapClose);
    final segPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.026
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a0 = -math.pi / 2 + i * math.pi / 2 + gap / 2;
      final full = math.pi / 2 - gap;
      final span = full * _clamp01(trackIn * 4 - i);
      if (span <= 0.001) continue;
      canvas.drawArc(
        keyRect,
        a0,
        span,
        false,
        segPaint..color = onBody.withValues(alpha: 0.3),
      );
      var lit = persistentError ? 0.0 : _clamp01(fill - i);
      if (inErr) {
        // 出错时四段先全亮，再从第 4 段起倒序清空
        final start = 380 + (3 - i) * 80;
        lit = 1 - _easeOutCubic(_clamp01((errorMs - start) / 160));
      }
      if (lit > 0.002) {
        canvas.drawArc(
          keyRect,
          a0,
          full * lit,
          false,
          segPaint..color = onBody,
        );
      }
    }
    if (gapClose > 0) {
      canvas.drawCircle(
        keyCenter,
        s * 0.11,
        segPaint
          ..strokeCap = StrokeCap.butt
          ..color = onBody.withValues(alpha: gapClose),
      );
    }

    // ── 钥匙孔 → 对勾 ──
    final morph = doneMs >= 0
        ? _easeOutCubic(_clamp01((doneMs - 260) / 360))
        : 0.0;
    if (morph < 1) {
      final pop = enterMs < _lockUnlockAtMs
          ? 1.0
          : 1 +
                math.sin(
                      _clamp01((enterMs - _lockUnlockAtMs) / 260) * math.pi,
                    ) *
                    0.14;
      final ks = (1 - morph) * pop;
      final keyPaint = Paint()..color = onBody;
      canvas
        ..save()
        ..translate(keyCenter.dx, keyCenter.dy)
        ..scale(ks)
        ..drawCircle(Offset(0, -s * 0.018), s * 0.032, keyPaint)
        ..drawRRect(
          RRect.fromLTRBR(
            -s * 0.016,
            -s * 0.02,
            s * 0.016,
            s * 0.048,
            Radius.circular(s * 0.016),
          ),
          keyPaint,
        )
        ..restore();
    }
    if (morph > 0) {
      final check = Path()
        ..moveTo(keyCenter.dx - s * 0.046, keyCenter.dy + s * 0.002)
        ..lineTo(keyCenter.dx - s * 0.013, keyCenter.dy + s * 0.034)
        ..lineTo(keyCenter.dx + s * 0.048, keyCenter.dy - s * 0.03);
      final metric = check.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * morph),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.03
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = onBody,
      );
    }
    canvas.restore();
  }

  /// MD3 Expressive 的"饼干"形：极坐标下半径按余弦起伏。
  static Path _cookiePath(Offset c, double r, double amp, double rot) {
    const n = 144;
    const lobes = 9;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final t = i / n * math.pi * 2;
      final rr = r + amp * math.cos(lobes * (t - rot));
      final p = Offset(c.dx + math.cos(t) * rr, c.dy + math.sin(t) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// 四角星点缀。
  static void _drawSparkle(
    Canvas canvas,
    Offset c,
    double r,
    double rot,
    Color color,
  ) {
    if (r <= 0.1) return;
    final path = Path();
    for (var i = 0; i <= 4; i++) {
      final a = rot + i * math.pi / 2;
      final p = Offset(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      i == 0
          ? path.moveTo(p.dx, p.dy)
          : path.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HazukiLockPainter old) =>
      old.mode != mode ||
      old.colors != colors ||
      old.enterMs != enterMs ||
      old.idle != idle ||
      old.tap != tap ||
      old.errorMs != errorMs ||
      old.doneMs != doneMs ||
      old.fill != fill ||
      old.persistentError != persistentError;
}
