import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

@immutable
class HazukiFrostedMenuOption<T> {
  const HazukiFrostedMenuOption({
    required this.value,
    required this.label,
    this.key,
  }) : children = const [];

  const HazukiFrostedMenuOption.submenu({
    required this.label,
    required this.children,
    this.key,
  }) : value = null;

  final T? value;
  final String label;
  final Key? key;
  final List<HazukiFrostedMenuOption<T>> children;

  bool containsValue(T? selected) => children.isEmpty
      ? value == selected
      : selected != null && children.any((e) => e.containsValue(selected));
}

/// 形变菜单的入口锚点：挂上菜单定位用的 [anchorKey]，并把 [child] 的外观
/// 交给菜单形变外框复用。菜单打开期间由外框里的副本代替入口显示，入口本身隐藏，
/// 菜单完全收起后再显示。
///
/// 无论菜单是否打开都保持同一结构，菜单路由持有锚点的 RenderBox，换树会让锚点失效。
class HazukiMenuMorphAnchor extends StatelessWidget {
  const HazukiMenuMorphAnchor({
    super.key,
    required this.anchorKey,
    required this.transition,
    required this.child,
  });

  final GlobalKey anchorKey;

  /// 当前菜单路由的动画；没有菜单时为 null。
  final Animation<double>? transition;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final transition = this.transition ?? kAlwaysDismissedAnimation;
    return KeyedSubtree(
      key: anchorKey,
      child: AnimatedBuilder(
        animation: transition,
        child: child,
        // 收起动画结束的同一帧恢复入口，与外框里副本的消失无缝衔接。
        builder: (context, child) => Opacity(
          opacity: transition.status == AnimationStatus.dismissed ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}

Future<T?> showHazukiFrostedMenuCore<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<HazukiFrostedMenuOption<T>> options,
  T? selected,
  String? label,
  String keyPrefix = 'hazuki-frosted-menu',
  Listenable? dismissOn,
  bool waitForDismissal = false,
  bool morphFromAnchor = false,
  ValueChanged<Animation<double>?>? onTransitionChanged,
}) async {
  if (options.isEmpty || anchorKey.currentContext == null) return null;
  final anchor = anchorKey.currentContext!.findRenderObject() as RenderBox?;
  if (anchor == null || !anchor.attached) return null;
  // 入口用 HazukiMenuMorphAnchor 包裹时，把它的外观复制进形变外框，
  // 让菜单看起来是由入口本身长出来的。
  final anchorGhost = morphFromAnchor
      ? anchorKey.currentContext!
            .findAncestorWidgetOfExactType<HazukiMenuMorphAnchor>()
            ?.child
      : null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final strings = MaterialLocalizations.of(context);
  final route = _HazukiFrostedMenuRoute<T>(
    anchor: anchor,
    options: options,
    selected: selected,
    label: label ?? strings.popupMenuLabel,
    keyPrefix: keyPrefix,
    closeLabel: strings.modalBarrierDismissLabel,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    morphFromAnchor: morphFromAnchor,
    anchorGhost: anchorGhost,
  );
  void dismiss() {
    WidgetsBinding.instance.addPostFrameCallback((_) => route.dismiss());
  }

  dismissOn?.addListener(dismiss);
  try {
    final pushed = navigator.push<T>(route);
    if (onTransitionChanged != null) {
      onTransitionChanged(route.animation);
      // 无论正常收起还是被直接移除，路由销毁时都会完成，借此让入口恢复显示。
      unawaited(route.completed.whenComplete(() => onTransitionChanged(null)));
    }
    final result = await pushed;
    if (waitForDismissal) await route.completed;
    return result;
  } finally {
    dismissOn?.removeListener(dismiss);
  }
}

class _HazukiFrostedMenuRoute<T> extends PopupRoute<T> {
  _HazukiFrostedMenuRoute({
    required this.anchor,
    required this.selected,
    required this.options,
    required this.label,
    required this.keyPrefix,
    required String closeLabel,
    required this.themes,
    this.header,
    this.morphFromAnchor = false,
    this.anchorGhost,
  }) : barrierLabel = closeLabel;

  final RenderBox anchor;
  final T? selected;
  final List<HazukiFrostedMenuOption<T>> options;
  final String label;
  final String keyPrefix;
  final CapturedThemes themes;
  final String? header;

  /// 一级菜单是否由入口按钮原位形变展开，收起时缩回按钮。
  final bool morphFromAnchor;

  /// 入口外观的副本，形变初期显示在外框内，随后淡出让位给菜单内容。
  final Widget? anchorGhost;
  CurvedAnimation? _progress;
  CurvedAnimation? _morphGeometry;
  CurvedAnimation? _depthProgress;
  bool _openingSubmenu = false;
  _HazukiFrostedMenuRoute<T>? _submenu;

  void dismiss() {
    _submenu?.dismiss();
    if (isActive) navigator?.removeRoute(this);
  }

  Future<void> _select(HazukiFrostedMenuOption<T> option, GlobalKey key) async {
    if (!isCurrent ||
        _openingSubmenu ||
        animation!.status == AnimationStatus.reverse) {
      return;
    }
    if (option.children.isEmpty) {
      navigator!.pop(option.value);
      return;
    }
    final submenuAnchor = key.currentContext?.findRenderObject() as RenderBox?;
    if (submenuAnchor == null || !submenuAnchor.attached) return;
    _openingSubmenu = true;
    final routeNavigator = navigator!;
    final submenu = _submenu = _HazukiFrostedMenuRoute<T>(
      anchor: submenuAnchor,
      selected: selected,
      options: option.children,
      label: option.label,
      header: option.label,
      keyPrefix: '$keyPrefix-submenu',
      closeLabel: barrierLabel,
      themes: themes,
    );
    final value = await routeNavigator.push<T>(submenu);
    // Keep the parent dimmed until the child has finished closing.
    await submenu.completed;
    _submenu = null;
    _openingSubmenu = false;
    if (value != null && isCurrent) routeNavigator.pop(value);
  }

  @override
  void dispose() {
    _progress?.dispose();
    _morphGeometry?.dispose();
    _depthProgress?.dispose();
    super.dispose();
  }

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: _buttonMorph ? 360 : 280);

  bool get _buttonMorph => morphFromAnchor && header == null;

  /// 按钮形变的外框尺寸曲线：展开时略微越过终点再回弹，收起时平滑缩回。
  static const _morphOpenCurve = Cubic(0.2, 1.25, 0.35, 1);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final progressAnimation = _progress ??= CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final geometryAnimation = _morphGeometry ??= CurvedAnimation(
      parent: animation,
      curve: _morphOpenCurve,
      reverseCurve: Curves.easeInOutCubic,
    );
    final depthAnimation = _depthProgress ??= CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return themes.wrap(
      LayoutBuilder(
        builder: (context, constraints) {
          final overlay =
              navigator?.overlay?.context.findRenderObject() as RenderBox?;
          if (!anchor.attached || overlay == null) {
            return const SizedBox.shrink();
          }
          final anchorRect =
              anchor.localToGlobal(Offset.zero, ancestor: overlay) &
              anchor.size;
          final media = MediaQuery.of(context);
          final bounds = Rect.fromLTRB(
            media.padding.left + 12,
            media.padding.top + 12,
            constraints.maxWidth - media.padding.right - 12,
            constraints.maxHeight -
                math.max(media.padding.bottom, media.viewInsets.bottom) -
                12,
          );
          final below =
              bounds.bottom - anchorRect.bottom >= anchorRect.top - bounds.top;
          final isSubmenu = header != null;
          final morphs = isSubmenu || morphFromAnchor;
          final surface = IntrinsicWidth(
            child: _FrostedMenuSurface<T>(
              animation: progressAnimation,
              dimAnimation: depthAnimation,
              selected: selected,
              options: options,
              label: label,
              header: header,
              morphAnchor: morphs ? anchor : null,
              geometry: geometryAnimation,
              // 副本按入口当前尺寸布局，起点处与入口逐像素重合。
              anchorGhost: anchorGhost == null
                  ? null
                  : SizedBox.fromSize(
                      size: anchorRect.size,
                      child: anchorGhost,
                    ),
              keyPrefix: keyPrefix,
              onSelected: _select,
              onBack: () {
                if (isCurrent && animation.status != AnimationStatus.reverse) {
                  navigator!.pop();
                }
              },
            ),
          );
          return CustomSingleChildLayout(
            delegate: _FrostedMenuLayout(
              anchorRect: anchorRect,
              bounds: bounds,
              submenu: isSubmenu,
            ),
            child: AnimatedBuilder(
              animation: progressAnimation,
              child: surface,
              builder: (context, child) {
                final progress = progressAnimation.value;
                final ignoring = animation.status == AnimationStatus.reverse;
                // 形变菜单的展开/收起由自身外框完成，不再叠加整体缩放位移。
                if (morphs) {
                  return IgnorePointer(ignoring: ignoring, child: child);
                }
                return IgnorePointer(
                  ignoring: ignoring,
                  child: FractionalTranslation(
                    translation: Offset(
                      0,
                      (below ? -0.06 : 0.06) * (1 - progress),
                    ),
                    child: Transform.scale(
                      key: ValueKey('$keyPrefix-scale'),
                      alignment: below
                          ? Alignment.topRight
                          : Alignment.bottomRight,
                      scale: ui.lerpDouble(0.86, 1, progress),
                      child: child,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FrostedMenuLayout extends SingleChildLayoutDelegate {
  const _FrostedMenuLayout({
    required this.anchorRect,
    required this.bounds,
    this.submenu = false,
  });

  final Rect anchorRect;
  final Rect bounds;

  /// 子菜单锚定在被点击的行上：比父菜单更宽，优先向左下方展开，左侧放不下时
  /// 向右下方展开。
  final bool submenu;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = math.max(0.0, bounds.width);
    if (submenu) {
      final minWidth = math.min(anchorRect.width + 48, available);
      return BoxConstraints(
        minWidth: minWidth,
        maxWidth: math.min(math.max(280.0, minWidth), available),
        maxHeight: math.max(0, bounds.height),
      );
    }
    return BoxConstraints(
      maxWidth: math.min(240.0, available),
      maxHeight: math.max(0, bounds.height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // 子菜单右缘与父菜单右缘对齐、标题行与被点击的行重合（扣除面板 8px
    // 内边距），因此向左下方展开；左侧放不下时改为左缘对齐、向右下方展开。
    var left = anchorRect.right - childSize.width;
    if (submenu) {
      left = anchorRect.right + 8 - childSize.width;
      if (left < bounds.left) left = anchorRect.left - 8;
    }
    final top = submenu ? anchorRect.top - 8 : anchorRect.top;
    return Offset(
      left.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      top.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_FrostedMenuLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect ||
      bounds != oldDelegate.bounds ||
      submenu != oldDelegate.submenu;
}

class _FrostedMenuSurface<T> extends StatelessWidget {
  const _FrostedMenuSurface({
    required this.animation,
    required this.dimAnimation,
    required this.selected,
    required this.options,
    required this.label,
    required this.keyPrefix,
    required this.onSelected,
    required this.onBack,
    required this.geometry,
    this.header,
    this.morphAnchor,
    this.anchorGhost,
  });

  final T? selected;
  final List<HazukiFrostedMenuOption<T>> options;
  final String label;
  final String? header;
  final String keyPrefix;
  final Animation<double> animation;
  final Animation<double> dimAnimation;
  final void Function(HazukiFrostedMenuOption<T>, GlobalKey) onSelected;
  final VoidCallback onBack;

  /// 非空时外框从锚点原位形变展开、收起时再缩回：子菜单锚定被点的那一行，
  /// 一级菜单锚定入口按钮。
  final RenderBox? morphAnchor;

  /// 按钮形变的外框尺寸进度，带轻微回弹，可能略大于 1。
  final Animation<double> geometry;
  final Widget? anchorGhost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 深色下 surfaceContainerHigh 与页面反差过大，改用更暗的 Low 与弹窗保持一致。
    final fillBase = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerHigh;
    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        fillBase.withValues(alpha: 0.82),
        fillBase.withValues(alpha: 0.66),
      ],
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.45);
    final content = _MenuDepthDim(
      animation: dimAnimation,
      keyPrefix: keyPrefix,
      child: _buildContent(context, scheme),
    );
    if (morphAnchor case final anchor?) {
      final fromButton = header == null;
      if (!fromButton) {
        return _FrostedMenuMorph(
          key: ValueKey('$keyPrefix-surface'),
          animation: animation,
          anchor: anchor,
          fill: fill,
          borderColor: borderColor,
          child: content,
        );
      }
      // 入口外观先占满外框，菜单内容随外框一起放大并逐渐显现。
      final items = AnimatedBuilder(
        animation: animation,
        child: content,
        builder: (context, child) => Opacity(
          key: ValueKey('$keyPrefix-items-fade'),
          opacity: _buttonContentInterval.transform(animation.value),
          child: child,
        ),
      );
      final ghost = anchorGhost;
      // 与非形变面板一致：被子菜单覆盖时淡化底色，让子菜单的模糊采样到页面。
      return AnimatedBuilder(
        animation: Listenable.merge([dimAnimation, animation]),
        builder: (context, _) => _FrostedButtonMorph(
          key: ValueKey('$keyPrefix-surface'),
          progress: animation,
          geometry: geometry,
          anchor: anchor,
          fill: fill.scale(1 - 0.85 * dimAnimation.value),
          borderColor: borderColor,
          children: [
            items,
            // 副本完全淡出后移出树，避免与菜单内容重复参与查找和语义。
            if (ghost != null &&
                animation.value < _RenderFrostedButtonMorph.ghostFadeEnd)
              Material(
                key: ValueKey('$keyPrefix-anchor-ghost'),
                type: MaterialType.transparency,
                child: IgnorePointer(child: ExcludeSemantics(child: ghost)),
              ),
          ],
        ),
      );
    }
    return _AnimatedMenuGlass(
      animation: animation,
      keyPrefix: keyPrefix,
      // 被子菜单覆盖时淡化父菜单底色，让子菜单的模糊能采样到页面颜色，
      // 否则只会模糊一块深色底板而失去毛玻璃质感。
      child: AnimatedBuilder(
        animation: dimAnimation,
        child: content,
        builder: (context, child) => DecoratedBox(
          key: ValueKey('$keyPrefix-fill'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: fill.scale(1 - 0.85 * dimAnimation.value),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }

  static const _buttonContentInterval = Interval(0.2, 0.75);

  Widget _buildContent(BuildContext context, ColorScheme scheme) {
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: label,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                InkWell(
                  key: ValueKey('$keyPrefix-back'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: onBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            header!,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.expand_less_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 16, indent: 16, endIndent: 16),
              ],
              for (final option in options)
                _FrostedMenuItemAnchor<T>(
                  builder: (anchorKey) => Semantics(
                    selected: option.containsValue(selected),
                    expanded: option.children.isEmpty ? null : false,
                    child: InkWell(
                      key:
                          option.key ??
                          (option.children.isEmpty
                              ? ValueKey((keyPrefix, option.value as T))
                              : ValueKey((keyPrefix, option.label))),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onSelected(option, anchorKey),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: option.containsValue(selected)
                              ? scheme.primaryContainer.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    option.label,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: option.containsValue(selected)
                                              ? scheme.primary
                                              : scheme.onSurface,
                                          fontWeight:
                                              option.containsValue(selected)
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 20,
                                  child: option.children.isNotEmpty
                                      ? const Icon(
                                          Icons.expand_more_rounded,
                                          size: 20,
                                        )
                                      : option.containsValue(selected)
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 20,
                                          color: scheme.primary,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _FrostedMenuItemAnchor<T> extends StatefulWidget {
  const _FrostedMenuItemAnchor({required this.builder});
  final Widget Function(GlobalKey) builder;

  @override
  State<_FrostedMenuItemAnchor<T>> createState() =>
      _FrostedMenuItemAnchorState<T>();
}

class _FrostedMenuItemAnchorState<T> extends State<_FrostedMenuItemAnchor<T>> {
  final _key = GlobalKey();
  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.builder(_key));
}

/// 被子菜单覆盖时只压暗并淡化父菜单内容，不再缩放父菜单。
class _MenuDepthDim extends StatelessWidget {
  const _MenuDepthDim({
    required this.animation,
    required this.keyPrefix,
    required this.child,
  });

  final Animation<double> animation;
  final String keyPrefix;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => DecoratedBox(
      key: ValueKey('$keyPrefix-dim'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.12 * animation.value),
      ),
      child: Opacity(
        key: ValueKey('$keyPrefix-content-fade'),
        opacity: 1 - 0.5 * animation.value,
        child: child,
      ),
    ),
  );
}

/// 子菜单外框：按动画进度在锚点行与完整面板之间插值。
///
/// 展开时描边先出现、填充随后；收起时描边先淡出，填充与内容在缩回原行的
/// 最后阶段才淡出，使其与父菜单中的那一行无缝重合。
class _FrostedMenuMorph extends SingleChildRenderObjectWidget {
  const _FrostedMenuMorph({
    super.key,
    required this.animation,
    required this.anchor,
    required this.fill,
    required this.borderColor,
    required super.child,
  });

  final Animation<double> animation;
  final RenderBox anchor;
  final Gradient fill;
  final Color borderColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFrostedMenuMorph(
        animation: animation,
        anchor: anchor,
        fill: fill,
        borderColor: borderColor,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFrostedMenuMorph renderObject,
  ) {
    renderObject
      ..animation = animation
      ..anchor = anchor
      ..fill = fill
      ..borderColor = borderColor;
  }
}

class _RenderFrostedMenuMorph extends RenderProxyBox {
  _RenderFrostedMenuMorph({
    required Animation<double> animation,
    required RenderBox anchor,
    required Gradient fill,
    required Color borderColor,
  }) : _animation = animation,
       _anchor = anchor,
       _fill = fill,
       _borderColor = borderColor;

  static const _fadeInterval = Interval(0, 0.35);
  static const _borderInterval = Interval(0.3, 1);

  final _clipLayer = LayerHandle<ClipRRectLayer>();
  final _blurLayer = LayerHandle<BackdropFilterLayer>();
  final _opacityLayer = LayerHandle<OpacityLayer>();

  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(value, _animation)) return;
    if (attached) {
      _animation.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _animation = value;
    markNeedsPaint();
  }

  RenderBox _anchor;
  set anchor(RenderBox value) {
    if (identical(value, _anchor)) return;
    _anchor = value;
    markNeedsPaint();
  }

  Gradient _fill;
  set fill(Gradient value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  Color _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _blurLayer.layer = null;
    _opacityLayer.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  /// 当前帧外框，以及让标题行对齐锚点行所需的内容偏移（面板内边距 8px）。
  ({RRect frame, Offset shift}) _geometry() {
    final t = _animation.value;
    final full = Offset.zero & size;
    final from = _anchor.attached
        ? MatrixUtils.transformRect(
            _anchor.getTransformTo(this),
            Offset.zero & _anchor.size,
          )
        : full;
    return (
      frame: RRect.fromRectAndRadius(
        Rect.lerp(from, full, t)!,
        Radius.circular(ui.lerpDouble(20, 28, t)!),
      ),
      shift: (from.topLeft - const Offset(8, 8)) * (1 - t),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final t = _animation.value;
    final fade = _fadeInterval.transform(t);
    if (fade == 0) {
      _clipLayer.layer = null;
      _blurLayer.layer = null;
      _opacityLayer.layer = null;
      return;
    }
    final (:frame, :shift) = _geometry();
    final shadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.16 * fade),
      blurRadius: 28,
      offset: const Offset(0, 10),
    );
    context.canvas.drawRRect(
      frame.shift(offset + shadow.offset),
      shadow.toPaint(),
    );
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      frame,
      (context, offset) {
        // 模糊层保持在透明度层之外，确保每一帧都能采样到页面内容。
        final blur = _blurLayer.layer ??= BackdropFilterLayer();
        blur.filter = ui.ImageFilter.blur(sigmaX: 24 * fade, sigmaY: 24 * fade);
        context.pushLayer(blur, (context, offset) {
          _opacityLayer.layer = context.pushOpacity(
            offset,
            (fade * 255).round(),
            (context, offset) {
              final rect = frame.shift(offset);
              context.canvas.drawRRect(
                rect,
                Paint()..shader = _fill.createShader(rect.outerRect),
              );
              context.paintChild(child, offset + shift);
            },
            oldLayer: _opacityLayer.layer,
          );
        }, offset);
      },
      oldLayer: _clipLayer.layer,
    );
    final edge = _borderInterval.transform(t);
    if (edge > 0) {
      context.canvas.drawRRect(
        frame.shift(offset).deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _borderColor.withValues(alpha: _borderColor.a * edge),
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final (:frame, :shift) = _geometry();
    if (!frame.contains(position)) return false;
    return result.addWithPaintOffset(
      offset: shift,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  bool hitTestSelf(Offset position) => _geometry().frame.contains(position);

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final shift = _geometry().shift;
    transform.translateByDouble(shift.dx, shift.dy, 0, 1);
  }
}

/// 一级菜单由入口按钮形变而成：外框从按钮矩形带回弹地长成完整面板。
///
/// 子节点依次为菜单内容与可选的入口外观副本。形变初期副本占满外框、与真实
/// 入口完全重合，随后淡出；菜单内容锚定外框右上角，按外框宽度同比缩放，
/// 跟随外框一起长大而不是被外框裁出来。收起时按相反顺序缩回入口。
class _FrostedButtonMorph extends MultiChildRenderObjectWidget {
  const _FrostedButtonMorph({
    super.key,
    required this.progress,
    required this.geometry,
    required this.anchor,
    required this.fill,
    required this.borderColor,
    required super.children,
  });

  final Animation<double> progress;
  final Animation<double> geometry;
  final RenderBox anchor;
  final Gradient fill;
  final Color borderColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFrostedButtonMorph(
        progress: progress,
        geometry: geometry,
        anchor: anchor,
        fill: fill,
        borderColor: borderColor,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFrostedButtonMorph renderObject,
  ) {
    renderObject
      ..progress = progress
      ..geometry = geometry
      ..anchor = anchor
      ..fill = fill
      ..borderColor = borderColor;
  }
}

class _MorphParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFrostedButtonMorph extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MorphParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MorphParentData> {
  _RenderFrostedButtonMorph({
    required Animation<double> progress,
    required Animation<double> geometry,
    required RenderBox anchor,
    required Gradient fill,
    required Color borderColor,
  }) : _progress = progress,
       _geometryAnimation = geometry,
       _anchor = anchor,
       _fill = fill,
       _borderColor = borderColor;

  /// 玻璃底色在形变初期就铺满，入口副本盖在其上，看起来是入口本身在变大。
  static const _fillInterval = Interval(0, 0.2);
  static const ghostFadeEnd = 0.3;
  static const _ghostFadeInterval = Interval(0, ghostFadeEnd);
  static const _borderInterval = Interval(0.4, 1);

  final _clipLayer = LayerHandle<ClipRRectLayer>();
  final _blurLayer = LayerHandle<BackdropFilterLayer>();
  final _fillLayer = LayerHandle<OpacityLayer>();
  final _contentLayer = LayerHandle<TransformLayer>();
  final _ghostLayer = LayerHandle<OpacityLayer>();

  Animation<double> _progress;
  set progress(Animation<double> value) {
    if (identical(value, _progress)) return;
    if (attached) {
      _progress.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _progress = value;
    markNeedsPaint();
  }

  Animation<double> _geometryAnimation;
  set geometry(Animation<double> value) {
    if (identical(value, _geometryAnimation)) return;
    if (attached) {
      _geometryAnimation.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _geometryAnimation = value;
    markNeedsPaint();
  }

  RenderBox _anchor;
  set anchor(RenderBox value) {
    if (identical(value, _anchor)) return;
    _anchor = value;
    markNeedsPaint();
  }

  Gradient _fill;
  set fill(Gradient value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  Color _borderColor;
  set borderColor(Color value) {
    if (value == _borderColor) return;
    _borderColor = value;
    markNeedsPaint();
  }

  RenderBox? get _content => firstChild;
  RenderBox? get _ghost => firstChild == null ? null : childAfter(firstChild!);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MorphParentData) {
      child.parentData = _MorphParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
    _geometryAnimation.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    _geometryAnimation.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _blurLayer.layer = null;
    _fillLayer.layer = null;
    _contentLayer.layer = null;
    _ghostLayer.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _content?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _content?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _content?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _content?.getMaxIntrinsicHeight(width) ?? 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _content?.getDryLayout(constraints) ?? constraints.smallest;

  @override
  void performLayout() {
    final content = _content;
    if (content == null) {
      size = constraints.smallest;
      return;
    }
    content.layout(constraints, parentUsesSize: true);
    size = content.size;
    _ghost?.layout(const BoxConstraints(), parentUsesSize: true);
  }

  Rect get _anchorRect => _anchor.attached
      ? MatrixUtils.transformRect(
          _anchor.getTransformTo(this),
          Offset.zero & _anchor.size,
        )
      : Offset.zero & size;

  RRect _frame() {
    final from = _anchorRect;
    final t = _geometryAnimation.value;
    return RRect.fromRectAndRadius(
      Rect.lerp(from, Offset.zero & size, t)!,
      // 起点用半短边作圆角，贴合按钮或胶囊的轮廓。
      Radius.circular(ui.lerpDouble(from.shortestSide / 2, 28, t.clamp(0, 1))!),
    );
  }

  /// 菜单内容锚定外框右上角、按外框宽度同比缩放。
  Matrix4 _contentTransform(RRect frame) {
    final scale = size.width == 0 ? 1.0 : frame.width / size.width;
    return Matrix4.translationValues(frame.right, frame.top, 0)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-size.width, 0, 0, 1);
  }

  /// 入口副本贴着外框右上角，起点处与真实入口完全重合。
  Offset _ghostOffset(RRect frame, RenderBox ghost) =>
      Offset(frame.right - ghost.size.width, frame.top);

  @override
  void paint(PaintingContext context, Offset offset) {
    final content = _content;
    if (content == null) return;
    final p = _progress.value;
    final fill = _fillInterval.transform(p);
    final ghost = _ghost;
    final ghostAlpha = ghost == null
        ? 0.0
        : 1 - _ghostFadeInterval.transform(p);
    if (fill == 0 && ghostAlpha == 0) {
      _clipLayer.layer = null;
      _blurLayer.layer = null;
      _fillLayer.layer = null;
      _contentLayer.layer = null;
      _ghostLayer.layer = null;
      return;
    }
    final frame = _frame();
    if (fill > 0) {
      final shadow = BoxShadow(
        color: Colors.black.withValues(alpha: 0.16 * fill),
        blurRadius: 28,
        offset: const Offset(0, 10),
      );
      context.canvas.drawRRect(
        frame.shift(offset + shadow.offset),
        shadow.toPaint(),
      );
    }
    _clipLayer.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      frame,
      (context, offset) {
        if (fill > 0) {
          // 模糊层保持在透明度层之外，确保每一帧都能采样到页面内容。
          final blur = _blurLayer.layer ??= BackdropFilterLayer();
          blur.filter = ui.ImageFilter.blur(
            sigmaX: 24 * fill,
            sigmaY: 24 * fill,
          );
          context.pushLayer(blur, (context, offset) {
            _fillLayer.layer = context.pushOpacity(
              offset,
              (fill * 255).round(),
              (context, offset) {
                final rect = frame.shift(offset);
                context.canvas.drawRRect(
                  rect,
                  Paint()..shader = _fill.createShader(rect.outerRect),
                );
              },
              oldLayer: _fillLayer.layer,
            );
          }, offset);
        } else {
          _blurLayer.layer = null;
          _fillLayer.layer = null;
        }
        _contentLayer.layer = context.pushTransform(
          needsCompositing,
          offset,
          _contentTransform(frame),
          (context, offset) => context.paintChild(content, offset),
          oldLayer: _contentLayer.layer,
        );
        if (ghost != null && ghostAlpha > 0) {
          _ghostLayer.layer = context.pushOpacity(
            offset,
            (ghostAlpha * 255).round(),
            (context, offset) =>
                context.paintChild(ghost, offset + _ghostOffset(frame, ghost)),
            oldLayer: _ghostLayer.layer,
          );
        } else {
          _ghostLayer.layer = null;
        }
      },
      oldLayer: _clipLayer.layer,
    );
    final edge = _borderInterval.transform(p);
    if (edge > 0) {
      context.canvas.drawRRect(
        frame.shift(offset).deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = _borderColor.withValues(alpha: _borderColor.a * edge),
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final content = _content;
    if (content == null) return false;
    final frame = _frame();
    if (!frame.contains(position)) return false;
    return result.addWithPaintTransform(
      transform: _contentTransform(frame),
      position: position,
      hitTest: (result, transformed) =>
          content.hitTest(result, position: transformed),
    );
  }

  @override
  bool hitTestSelf(Offset position) => _frame().contains(position);

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final frame = _frame();
    if (identical(child, _content)) {
      transform.multiply(_contentTransform(frame));
    } else {
      final ghostOffset = _ghostOffset(frame, child);
      transform.translateByDouble(ghostOffset.dx, ghostOffset.dy, 0, 1);
    }
  }
}

class _AnimatedMenuGlass extends StatelessWidget {
  const _AnimatedMenuGlass({
    required this.animation,
    required this.child,
    required this.keyPrefix,
  });

  final String keyPrefix;

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, foreground) {
        final progress = animation.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16 * progress),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            key: ValueKey('$keyPrefix-surface'),
            borderRadius: radius,
            child: BackdropFilter(
              // Keep the backdrop outside Opacity's offscreen buffer so it can
              // sample the page during every opening and closing frame.
              filter: ui.ImageFilter.blur(
                sigmaX: 24 * progress,
                sigmaY: 24 * progress,
              ),
              child: Opacity(
                key: ValueKey('$keyPrefix-opacity'),
                opacity: progress,
                child: foreground,
              ),
            ),
          ),
        );
      },
    );
  }
}
