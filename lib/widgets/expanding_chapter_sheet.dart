import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Expands an existing chapter sheet before handing off to the reader.
class ExpandingChapterSheet extends StatefulWidget {
  const ExpandingChapterSheet({
    super.key,
    required this.builder,
    required this.cornerRadius,
    this.safePadding = EdgeInsets.zero,
  });

  final WidgetBuilder builder;
  final double cornerRadius;
  final EdgeInsets safePadding;

  static Future<bool> expand(BuildContext context) =>
      context.findAncestorStateOfType<_ExpandingChapterSheetState>()!.expand();

  /// 从面板内的某个元素（如继续阅读卡片）以圆角容器放大到全屏，面板本身保持不动。
  static Future<bool> expandFrom(
    BuildContext context, {
    required BuildContext source,
    required Color color,
    required double radius,
  }) => context.findAncestorStateOfType<_ExpandingChapterSheetState>()!.expand(
    source: (source, color, radius),
  );

  @override
  State<ExpandingChapterSheet> createState() => _ExpandingChapterSheetState();
}

class _ExpandingChapterSheetState extends State<ExpandingChapterSheet>
    with SingleTickerProviderStateMixin {
  final _sheetKey = GlobalKey();
  final _contentKey = GlobalKey();
  late final _controller = AnimationController(vsync: this);
  Size? _initialSize;
  ({Rect rect, Color color, double radius})? _source;

  Future<bool> expand({(BuildContext, Color, double)? source}) async {
    if (_initialSize != null) return false;
    final route = ModalRoute.of(context)!;
    if (!route.isCurrent) return false;
    final box = _sheetKey.currentContext!.findRenderObject()! as RenderBox;
    final sourceBox = source?.$1.findRenderObject() as RenderBox?;
    setState(() {
      _initialSize = box.size;
      // 记录源元素相对面板的位置，构建时再换算到全屏坐标
      _source = sourceBox == null || !sourceBox.attached
          ? null
          : (
              rect:
                  sourceBox.localToGlobal(Offset.zero, ancestor: box) &
                  sourceBox.size,
              color: source!.$2,
              radius: source.$3,
            );
    });
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360);
    try {
      await _controller.forward().orCancel;
      return mounted && route.isCurrent;
    } on TickerCanceled {
      return false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safePadding = widget.safePadding;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final content = KeyedSubtree(
            key: _contentKey,
            child: Builder(builder: widget.builder),
          );
          final initialSize = _initialSize;
          if (initialSize == null) {
            final maxWidth =
                theme.bottomSheetTheme.constraints?.maxWidth ??
                (theme.useMaterial3 ? 640.0 : double.infinity);
            return SizedBox(
              key: _sheetKey,
              width: math.min(constraints.maxWidth, maxWidth),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight - safePadding.top,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: safePadding.left,
                    right: safePadding.right,
                  ),
                  child: content,
                ),
              ),
            );
          }
          final progress = Curves.easeInOutCubicEmphasized.transform(
            _controller.value,
          );
          final source = _source;
          if (source != null) {
            return _buildSourceExpansion(
              theme,
              constraints.biggest,
              initialSize,
              source,
              progress,
              content,
            );
          }
          final width =
              initialSize.width +
              (constraints.maxWidth - initialSize.width) * progress;
          final height =
              initialSize.height +
              (constraints.maxHeight - initialSize.height) * progress;
          return PopScope(
            canPop: false,
            child: AbsorbPointer(
              child: SizedBox(
                key: _sheetKey,
                width: width,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(widget.cornerRadius * (1 - progress)),
                  ),
                  child: ColoredBox(
                    color: theme.colorScheme.surface,
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 0,
                          left: (width - initialSize.width) / 2,
                          width: initialSize.width,
                          height: initialSize.height,
                          child: Opacity(
                            opacity:
                                1 - const Interval(0, 0.5).transform(progress),
                            child: ExcludeFocus(child: content),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSourceExpansion(
    ThemeData theme,
    Size full,
    Size initialSize,
    ({Rect rect, Color color, double radius}) source,
    double progress,
    Widget content,
  ) {
    final sheetOrigin = Offset(
      (full.width - initialSize.width) / 2,
      full.height - initialSize.height,
    );
    final rect = Rect.lerp(
      source.rect.shift(sheetOrigin),
      Offset.zero & full,
      progress,
    )!;
    return PopScope(
      canPop: false,
      child: AbsorbPointer(
        child: SizedBox.fromSize(
          size: full,
          child: Stack(
            children: [
              Positioned(
                left: sheetOrigin.dx,
                top: sheetOrigin.dy,
                width: initialSize.width,
                height: initialSize.height,
                child: ExcludeFocus(child: content),
              ),
              // 圆角容器全程保持圆角，从卡片尺寸放大到全屏
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      source.color,
                      theme.colorScheme.surface,
                      const Interval(0.15, 0.75).transform(progress),
                    ),
                    borderRadius: BorderRadius.circular(
                      source.radius +
                          (widget.cornerRadius - source.radius) * progress,
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
