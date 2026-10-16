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

  @override
  State<ExpandingChapterSheet> createState() => _ExpandingChapterSheetState();
}

class _ExpandingChapterSheetState extends State<ExpandingChapterSheet>
    with SingleTickerProviderStateMixin {
  final _sheetKey = GlobalKey();
  final _contentKey = GlobalKey();
  late final _controller = AnimationController(vsync: this);
  Size? _initialSize;

  Future<bool> expand() async {
    if (_initialSize != null) return false;
    final route = ModalRoute.of(context)!;
    if (!route.isCurrent) return false;
    final box = _sheetKey.currentContext!.findRenderObject()! as RenderBox;
    setState(() => _initialSize = box.size);
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
}
