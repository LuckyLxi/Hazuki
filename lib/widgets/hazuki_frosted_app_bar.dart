import 'package:flutter/material.dart';

import 'package:hazuki/shared/windows/windows_app_bar_drag_area.dart';

PreferredSizeWidget hazukiFrostedAppBar({
  required BuildContext context,
  Widget? title,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double? toolbarHeight,
  PreferredSizeWidget? bottom,
  double elevation = 0,
  bool centerTitle = false,
  double backgroundAlpha = 0.72,
  double? leadingWidth,
  double? titleSpacing,
}) {
  final surface = Theme.of(context).colorScheme.surface;
  return AppBar(
    title: title,
    actions: [...?actions, const HazukiWindowsCaptionButtonSpacer()],
    leading: leading,
    leadingWidth: leadingWidth,
    automaticallyImplyLeading: automaticallyImplyLeading,
    toolbarHeight: toolbarHeight,
    titleSpacing: titleSpacing,
    bottom: bottom,
    elevation: elevation,
    centerTitle: centerTitle,
    backgroundColor: surface.withValues(alpha: backgroundAlpha),
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    clipBehavior: Clip.antiAlias,
    // 顶栏刻意不做背景模糊：BackdropFilter 在上层遮罩（如密码锁解锁揭开动画）
    // 改变裁剪时会闪出一帧底层内容，且每帧模糊开销较大。请勿重新加回。
    flexibleSpace: const HazukiWindowsAppBarDragArea(child: SizedBox.expand()),
  );
}
