import 'dart:ui';

import 'package:flutter/material.dart';

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
  double? titleSpacing,
  bool enableBlur = true,
}) {
  final surface = Theme.of(context).colorScheme.surface;
  return AppBar(
    title: title,
    actions: actions,
    leading: leading,
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
    flexibleSpace: enableBlur
        ? ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: const SizedBox.expand(),
            ),
          )
        : null,
  );
}
