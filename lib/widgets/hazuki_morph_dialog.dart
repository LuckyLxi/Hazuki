import 'dart:async';

import 'package:flutter/material.dart';

/// 以胶囊/卡片为起点展开的弹窗路由，路由真正销毁后才返回结果。
///
/// [builder] 通常返回一个内部使用 [HazukiMorphDialogShell] 的组件；
/// [onLanding] 在收起动画接近落点或路由销毁时触发一次，便于提前恢复起点组件。
Future<T?> showHazukiMorphDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext context, Animation<double> animation)
  builder,
  VoidCallback? onLanding,
}) async {
  final disposed = Completer<void>();
  final result = await showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _HazukiMorphDialogLifecycle(
        animation: animation,
        onLanding: onLanding,
        onDisposed: () {
          if (!disposed.isCompleted) {
            disposed.complete();
          }
        },
        child: builder(dialogContext, animation),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
  );
  // pop 时 future 已完成，但收起动画仍在播放，需等路由销毁后再交还给调用方。
  if (!disposed.isCompleted) {
    await disposed.future;
  }
  return result;
}

class _HazukiMorphDialogLifecycle extends StatefulWidget {
  const _HazukiMorphDialogLifecycle({
    required this.animation,
    this.onLanding,
    required this.onDisposed,
    required this.child,
  });

  final Animation<double> animation;
  final VoidCallback? onLanding;
  final VoidCallback onDisposed;
  final Widget child;

  @override
  State<_HazukiMorphDialogLifecycle> createState() =>
      _HazukiMorphDialogLifecycleState();
}

class _HazukiMorphDialogLifecycleState
    extends State<_HazukiMorphDialogLifecycle> {
  bool _landingReported = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleAnimation);
  }

  void _handleAnimation() {
    if (!_landingReported &&
        widget.animation.status == AnimationStatus.reverse &&
        widget.animation.value <= 0.08) {
      _reportLanding();
    }
  }

  void _reportLanding() {
    if (_landingReported) {
      return;
    }
    _landingReported = true;
    widget.onLanding?.call();
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimation);
    _reportLanding();
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 从 [startRect] 先平移到 [endRect] 中心、再展开到 [endRect] 尺寸的弹窗外壳。
///
/// 起点内容 [launcherOverlay] 随展开淡出，弹窗内容 [child] 随后淡入；
/// 外壳底色由 [launcherColor] 过渡到全局弹窗底色。
class HazukiMorphDialogShell extends StatelessWidget {
  const HazukiMorphDialogShell({
    super.key,
    required this.animation,
    required this.startRect,
    required this.endRect,
    required this.launcherColor,
    this.launcherBorderColor,
    required this.launcherOverlay,
    required this.child,
    required this.beginRadius,
    required this.radiusGrowth,
    required this.beginElevation,
    required this.elevationGrowth,
    this.contentAlignment,
    this.animationKey,
    this.shellKey,
  });

  final Animation<double> animation;
  final Rect startRect;
  final Rect endRect;
  final Color launcherColor;

  /// 起点描边颜色，展开时渐隐；为 null 时不描边。
  final Color? launcherBorderColor;
  final Widget launcherOverlay;
  final Widget child;
  final double beginRadius;
  final double radiusGrowth;
  final double beginElevation;
  final double elevationGrowth;

  /// 非 null 时内容固定按 [endRect] 尺寸布局并裁剪；为 null 时内容随外壳尺寸布局。
  final Alignment? contentAlignment;
  final Key? animationKey;
  final Key? shellKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;
        final moveProgress = const Interval(
          0,
          0.78,
          curve: Curves.easeOutCubic,
        ).transform(progress);
        final expandProgress = const Interval(
          0.08,
          1,
          curve: Curves.easeOutCubic,
        ).transform(progress);
        final movingRect = Rect.lerp(
          startRect,
          Rect.fromCenter(
            center: endRect.center,
            width: startRect.width,
            height: startRect.height,
          ),
          moveProgress,
        )!;
        final rect = Rect.fromCenter(
          center: movingRect.center,
          width:
              startRect.width +
              ((endRect.width - startRect.width) * expandProgress),
          height:
              startRect.height +
              ((endRect.height - startRect.height) * expandProgress),
        );
        final contentOpacity = const Interval(
          0.42,
          0.78,
          curve: Curves.easeOutCubic,
        ).transform(progress);
        final launcherOpacity =
            1 - const Interval(0.12, 0.42).transform(progress);
        // 展开后跟随全局弹窗底色，未配置时回退 M3 默认值。
        final shellColor = Color.lerp(
          launcherColor,
          DialogTheme.of(context).backgroundColor ??
              colorScheme.surfaceContainerHigh,
          expandProgress,
        )!;
        final borderColor = launcherBorderColor;
        final content = Opacity(opacity: contentOpacity, child: child);
        final alignment = contentAlignment;
        return Stack(
          key: animationKey,
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Material(
                key: shellKey,
                color: shellColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    beginRadius + (radiusGrowth * expandProgress),
                  ),
                  side: borderColor == null
                      ? BorderSide.none
                      : BorderSide(
                          color: Color.lerp(
                            borderColor,
                            Colors.transparent,
                            expandProgress,
                          )!,
                        ),
                ),
                clipBehavior: Clip.antiAlias,
                elevation: beginElevation + (elevationGrowth * expandProgress),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(opacity: launcherOpacity, child: launcherOverlay),
                    Positioned.fill(
                      child: alignment == null
                          ? content
                          : ClipRect(
                              child: OverflowBox(
                                alignment: alignment,
                                minWidth: endRect.width,
                                maxWidth: endRect.width,
                                minHeight: endRect.height,
                                maxHeight: endRect.height,
                                child: content,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 可展开为弹窗的胶囊按钮；弹窗打开时由调用方置 [visible] 为 false 隐藏，
/// 收回后递增 [landingVersion] 播放落地回弹。
class HazukiMorphCapsule extends StatefulWidget {
  const HazukiMorphCapsule({
    super.key,
    required this.visible,
    required this.landingVersion,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.decorationKey,
    this.inkWellKey,
    this.opacityKey,
    this.landingKey,
  });

  static const double height = 36;
  static const double cornerRadius = 12;

  final bool visible;
  final int landingVersion;
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  /// 挂在胶囊外层装饰上，调用方可借助 GlobalKey 测量起点位置。
  final Key? decorationKey;
  final Key? inkWellKey;
  final Key? opacityKey;
  final Key? landingKey;

  @override
  State<HazukiMorphCapsule> createState() => _HazukiMorphCapsuleState();
}

class _HazukiMorphCapsuleState extends State<HazukiMorphCapsule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _landingController;
  late final Animation<double> _landingOffset;
  late final Animation<double> _landingScale;

  @override
  void initState() {
    super.initState();
    _landingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1,
    );
    final landingCurve = CurvedAnimation(
      parent: _landingController,
      curve: Curves.easeOutCubic,
    );
    _landingOffset = Tween<double>(begin: -3, end: 0).animate(landingCurve);
    _landingScale = Tween<double>(begin: 0.995, end: 1).animate(landingCurve);
  }

  @override
  void didUpdateWidget(covariant HazukiMorphCapsule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && widget.landingVersion != oldWidget.landingVersion) {
      _landingController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _landingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(HazukiMorphCapsule.cornerRadius);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AnimatedBuilder(
          animation: _landingController,
          builder: (context, child) => Transform.translate(
            key: widget.landingKey,
            offset: Offset(0, _landingOffset.value),
            child: Transform.scale(scale: _landingScale.value, child: child),
          ),
          child: Opacity(
            key: widget.opacityKey,
            opacity: widget.visible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !widget.visible,
              child: DecoratedBox(
                key: widget.decorationKey,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: radius,
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: radius,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: widget.inkWellKey,
                    onTap: widget.onPressed,
                    child: SizedBox(
                      height: HazukiMorphCapsule.height,
                      child: HazukiMorphCapsuleContents(
                        icon: widget.icon,
                        label: widget.label,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 胶囊内的图标 + 文字，同时用作展开弹窗里淡出的起点内容。
class HazukiMorphCapsuleContents extends StatelessWidget {
  const HazukiMorphCapsuleContents({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.mainAxisSize = MainAxisSize.max,
  });

  final IconData icon;
  final String label;
  final Color color;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
