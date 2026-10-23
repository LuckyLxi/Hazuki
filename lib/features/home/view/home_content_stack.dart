import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 首页发现/收藏切页的切口过渡。
///
/// 一道弧形斜切口横扫过整个屏幕，新页带投影压过旧页并视差滑入。
/// 内容区与应用栏共享同一个实例，切口几何按屏幕坐标计算，因此两者连成一刀。
class HomeTabCutTransition {
  HomeTabCutTransition({
    required TickerProvider vsync,
    required int initialIndex,
    this.onTransitionChanged,
  }) : _target = initialIndex,
       _incoming = initialIndex,
       _controller = AnimationController(vsync: vsync, duration: duration) {
    _controller.addStatusListener(_handleStatusChanged);
    _progress = CurvedAnimation(parent: _controller, curve: Easing.standard);
  }

  static const Duration duration = Duration(milliseconds: 480);

  final AnimationController _controller;
  late final CurvedAnimation _progress;

  /// 切页开始时上报 true，过渡结束（含中途折返）后上报 false。
  ValueChanged<bool>? onTransitionChanged;

  int _target;
  int _incoming;
  bool _transitionReported = false;

  Animation<double> get animation => _progress;
  bool get isAnimating => _controller.isAnimating;
  double get progress => _progress.value;

  /// 本次过渡的进入页；中途折返时保持不变，进度沿原路收回。
  int get incoming => _incoming;
  int get outgoing => 1 - _incoming;

  // 进入收藏时切口自左向右扫（几何镜像），进入发现时自右向左扫。
  int get direction => _incoming == 1 ? -1 : 1;

  /// 视差位移占屏幕宽度的比例：进入页从 10% 处滑回原位，退出页反向轻推 6%。
  double parallaxFor(int index) {
    if (!isAnimating) {
      return 0;
    }
    return index == _incoming
        ? direction * 0.1 * (1 - progress)
        : -direction * 0.06 * progress;
  }

  void select(int index) {
    if (index == _target) {
      return;
    }
    _target = index;
    onTransitionChanged?.call(true);
    if (_controller.isAnimating) {
      // 动画中途切回时沿原路收回，避免画面跳变。
      if (index == _incoming) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    } else {
      _incoming = index;
      _controller.forward(from: 0);
    }
    _transitionReported = true;
  }

  /// 不播放过渡直接停在 [index]；切口过渡关闭时用于保持选中页同步。
  void jumpTo(int index) {
    _target = index;
    _incoming = index;
    if (_controller.value != 0 || _controller.isAnimating) {
      _controller.value = 0;
    }
    if (_transitionReported) {
      _transitionReported = false;
      onTransitionChanged?.call(false);
    }
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (!_transitionReported || status.isAnimating) {
      return;
    }
    _transitionReported = false;
    onTransitionChanged?.call(false);
  }

  void dispose() {
    _progress.dispose();
    _controller.dispose();
  }
}

/// 首页发现/收藏切换容器；两个子页常驻，切换不会重建页面状态。
class HomeContentStack extends StatefulWidget {
  const HomeContentStack({
    super.key,
    required this.currentIndex,
    required this.discoverChild,
    required this.favoriteChild,
    this.transition,
    this.onTransitionChanged,
    this.cutTransition = true,
  });

  final int currentIndex;
  final Widget discoverChild;
  final Widget favoriteChild;

  /// 与应用栏共享的过渡；为空时内部自建，此时由 [onTransitionChanged] 上报状态。
  final HomeTabCutTransition? transition;

  /// 内部自建切口过渡或使用淡入滑动过渡时上报状态；
  /// 外部传入切口过渡时由其所有者负责上报。
  final ValueChanged<bool>? onTransitionChanged;

  /// 为 false 时使用淡入滑动过渡，不播放切口过渡。
  final bool cutTransition;

  @override
  State<HomeContentStack> createState() => _HomeContentStackState();
}

class _HomeContentStackState extends State<HomeContentStack>
    with SingleTickerProviderStateMixin {
  HomeTabCutTransition? _ownTransition;

  HomeTabCutTransition get _transition =>
      widget.transition ??
      (_ownTransition ??= HomeTabCutTransition(
        vsync: this,
        initialIndex: widget.currentIndex,
        onTransitionChanged: widget.onTransitionChanged,
      ));

  @override
  void didUpdateWidget(HomeContentStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ownTransition?.onTransitionChanged = widget.onTransitionChanged;
    if (!widget.cutTransition) {
      _transition.jumpTo(widget.currentIndex);
      if (oldWidget.currentIndex != widget.currentIndex) {
        widget.onTransitionChanged?.call(true);
      }
      return;
    }
    // 外部过渡通常已由所有者先行切换，这里重复调用是空操作。
    _transition.select(widget.currentIndex);
  }

  @override
  void dispose() {
    _ownTransition?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.cutTransition) {
      return _buildSlideFade();
    }
    final transition = _transition;
    final shadowColor = Theme.of(context).colorScheme.shadow;
    final screenSize = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: transition.animation,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: _buildPage(
                transition,
                screenSize,
                index: 0,
                child: RepaintBoundary(
                  key: const ValueKey('home-discover-repaint-boundary'),
                  child: widget.discoverChild,
                ),
              ),
            ),
            Positioned.fill(
              child: _buildPage(
                transition,
                screenSize,
                index: 1,
                child: RepaintBoundary(
                  key: const ValueKey('home-favorite-repaint-boundary'),
                  child: widget.favoriteChild,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _PanelCutShadow(
                    active: transition.isAnimating,
                    progress: transition.progress,
                    direction: transition.direction,
                    screenSize: screenSize,
                    color: shadowColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 淡入滑动过渡：退出页淡出并向反方向轻移，进入页淡入归位。
  Widget _buildSlideFade() {
    final currentIndex = widget.currentIndex;
    return Stack(
      children: [
        Positioned.fill(
          child: HeroMode(
            enabled: currentIndex == 0,
            child: IgnorePointer(
              ignoring: currentIndex != 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                offset: currentIndex == 0
                    ? Offset.zero
                    : const Offset(-0.04, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: currentIndex == 0 ? 1 : 0,
                  child: RepaintBoundary(
                    key: const ValueKey('home-discover-repaint-boundary'),
                    child: widget.discoverChild,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: HeroMode(
            enabled: currentIndex == 1,
            child: IgnorePointer(
              ignoring: currentIndex != 1,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                // 两页的滑动同时结束且晚于淡入淡出，在此统一上报一次结束。
                onEnd: () => widget.onTransitionChanged?.call(false),
                offset: currentIndex == 1 ? Offset.zero : const Offset(0.04, 0),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: currentIndex == 1 ? 1 : 0,
                  child: RepaintBoundary(
                    key: const ValueKey('home-favorite-repaint-boundary'),
                    child: widget.favoriteChild,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(
    HomeTabCutTransition transition,
    Size screenSize, {
    required int index,
    required Widget child,
  }) {
    final currentIndex = widget.currentIndex;
    final animating = transition.isAnimating;
    // 两页本身透明（底色由外层提供），因此按切口互补裁剪：
    // 进入页只画已扫过的一侧，退出页只画尚未扫过的一侧，避免内容叠在一起。
    return HeroMode(
      enabled: currentIndex == index,
      child: IgnorePointer(
        ignoring: currentIndex != index,
        child: _PanelCutClip(
          active: animating,
          progress: transition.progress,
          direction: transition.direction,
          swept: index == transition.incoming,
          screenSize: screenSize,
          child: Transform.translate(
            offset: Offset(transition.parallaxFor(index) * screenSize.width, 0),
            child: Opacity(
              opacity: animating || currentIndex == index ? 1 : 0,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 让任意属于某一页的组件（如应用栏的搜索框、收藏操作按钮）跟随切口裁剪与视差。
class HomeTabCutClip extends StatelessWidget {
  const HomeTabCutClip({
    super.key,
    required this.transition,
    required this.index,
    required this.child,
  });

  final HomeTabCutTransition transition;

  /// 该组件所属的页：0 为发现，1 为收藏。
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: transition.animation,
      child: child,
      builder: (context, child) => _PanelCutClip(
        active: transition.isAnimating,
        progress: transition.progress,
        direction: transition.direction,
        swept: index == transition.incoming,
        screenSize: screenSize,
        child: Transform.translate(
          offset: Offset(transition.parallaxFor(index) * screenSize.width, 0),
          child: child,
        ),
      ),
    );
  }
}

/// 切口几何：以屏幕为坐标系，在未镜像坐标系下切口自右向左扫过，呈 `/` 走向
/// （底端比顶端偏左 [slant] 倍宽度），并在横扫中段向前弯出弧度、首尾回直。
abstract final class _PanelCutGeometry {
  static const double slant = 0.42;

  /// 中段弧度：二次贝塞尔控制点的横向偏移占宽度比例（实际弧高约为一半）。
  static const double bow = 0.16;

  /// 起止时切口额外移出屏幕的距离，保证投影在首尾帧完全不可见。
  static const double overscan = 28;

  /// [swept] 为 true 取已扫过的区域（进入页），否则取尚未扫过的区域（退出页）。
  static Path region(
    Size size,
    double progress,
    int direction, {
    required bool swept,
  }) {
    final w = size.width;
    final h = size.height;
    final run = w * slant;
    final far = w + run + overscan;
    final topX = lerpDouble(w + run + overscan, -overscan, progress)!;
    final top = Offset(topX, 0);
    final bottomX = topX - run;
    final control = Offset(
      topX - run / 2 - w * bow * math.sin(math.pi * progress),
      h / 2,
    );
    final path = Path()..moveTo(top.dx, top.dy);
    if (swept) {
      path
        ..lineTo(far, 0)
        ..lineTo(far, h)
        ..lineTo(bottomX, h)
        ..quadraticBezierTo(control.dx, control.dy, top.dx, top.dy);
    } else {
      path
        ..quadraticBezierTo(control.dx, control.dy, bottomX, h)
        ..lineTo(-far, h)
        ..lineTo(-far, 0);
    }
    path.close();
    if (direction > 0) {
      return path;
    }
    // 进入收藏页时水平镜像。
    return path.transform(
      Float64List.fromList([-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, w, 0, 0, 1]),
    );
  }
}

/// 按屏幕坐标裁剪子树：绘制时取自身的全局位置，把屏幕空间的切口换算到本地。
class _PanelCutClip extends SingleChildRenderObjectWidget {
  const _PanelCutClip({
    required this.active,
    required this.progress,
    required this.direction,
    required this.swept,
    required this.screenSize,
    super.child,
  });

  final bool active;
  final double progress;
  final int direction;
  final bool swept;
  final Size screenSize;

  @override
  _RenderPanelCutClip createRenderObject(BuildContext context) =>
      _RenderPanelCutClip(
        active: active,
        progress: progress,
        direction: direction,
        swept: swept,
        screenSize: screenSize,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPanelCutClip renderObject,
  ) {
    renderObject
      ..active = active
      ..progress = progress
      ..direction = direction
      ..swept = swept
      ..screenSize = screenSize;
  }
}

class _RenderPanelCutClip extends RenderProxyBox {
  _RenderPanelCutClip({
    required bool active,
    required double progress,
    required int direction,
    required bool swept,
    required Size screenSize,
  }) : _active = active,
       _progress = progress,
       _direction = direction,
       _swept = swept,
       _screenSize = screenSize;

  final _clipLayer = LayerHandle<ClipPathLayer>();

  bool _active;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsPaint();
  }

  double _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    if (_active) markNeedsPaint();
  }

  int _direction;
  set direction(int value) {
    if (_direction == value) return;
    _direction = value;
    if (_active) markNeedsPaint();
  }

  bool _swept;
  set swept(bool value) {
    if (_swept == value) return;
    _swept = value;
    if (_active) markNeedsPaint();
  }

  Size _screenSize;
  set screenSize(Size value) {
    if (_screenSize == value) return;
    _screenSize = value;
    if (_active) markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      _clipLayer.layer = null;
      return;
    }
    if (!_active || _screenSize.isEmpty || size.isEmpty) {
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final origin = localToGlobal(Offset.zero);
    final clip = _PanelCutGeometry.region(
      _screenSize,
      _progress,
      _direction,
      swept: _swept,
    ).shift(-origin);
    _clipLayer.layer = context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      clip,
      super.paint,
      oldLayer: _clipLayer.layer,
    );
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }
}

/// 进入页像一张纸压在旧页上，沿切口向旧页一侧投下淡影（按屏幕坐标绘制）。
class _PanelCutShadow extends LeafRenderObjectWidget {
  const _PanelCutShadow({
    required this.active,
    required this.progress,
    required this.direction,
    required this.screenSize,
    required this.color,
  });

  final bool active;
  final double progress;
  final int direction;
  final Size screenSize;
  final Color color;

  @override
  _RenderPanelCutShadow createRenderObject(BuildContext context) =>
      _RenderPanelCutShadow()
        ..active = active
        ..progress = progress
        ..direction = direction
        ..screenSize = screenSize
        ..color = color;

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPanelCutShadow renderObject,
  ) {
    renderObject
      ..active = active
      ..progress = progress
      ..direction = direction
      ..screenSize = screenSize
      ..color = color;
  }
}

class _RenderPanelCutShadow extends RenderBox {
  static const int _layers = 8;
  static const double _layerStep = 3;

  bool _active = false;
  set active(bool value) {
    if (_active == value) return;
    _active = value;
    markNeedsPaint();
  }

  double _progress = 0;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    if (_active) markNeedsPaint();
  }

  int _direction = 1;
  set direction(int value) {
    if (_direction == value) return;
    _direction = value;
    if (_active) markNeedsPaint();
  }

  Size _screenSize = Size.zero;
  set screenSize(Size value) {
    if (_screenSize == value) return;
    _screenSize = value;
    if (_active) markNeedsPaint();
  }

  Color _color = const Color(0xFF000000);
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    if (_active) markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_active ||
        _progress <= 0 ||
        _progress >= 1 ||
        _screenSize.isEmpty ||
        size.isEmpty) {
      return;
    }
    final origin = localToGlobal(Offset.zero);
    // 中段最浓、首尾收淡，避免切口出现和离场时突兀。
    final alpha =
        0.22 * math.sin(math.pi * math.min(1.0, _progress * 1.15)) + 0.06;
    final swept = _PanelCutGeometry.region(
      _screenSize,
      _progress,
      _direction,
      swept: true,
    );
    // 把进入页形状逐层错向旧页一侧叠加淡色填充，越靠近切口叠得越多，
    // 形成贴合弧线的渐隐阴影，且无需逐帧模糊。
    final paint = Paint()..color = _color.withValues(alpha: alpha / _layers);
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx - origin.dx, offset.dy - origin.dy)
      ..clipRect(origin & size)
      ..clipPath(
        _PanelCutGeometry.region(
          _screenSize,
          _progress,
          _direction,
          swept: false,
        ),
      );
    for (var i = 1; i <= _layers; i++) {
      canvas.drawPath(
        swept.shift(Offset(-_direction * i * _layerStep, 0)),
        paint,
      );
    }
    canvas.restore();
  }
}
