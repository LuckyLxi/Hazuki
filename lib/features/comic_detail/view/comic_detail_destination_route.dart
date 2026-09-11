import 'package:flutter/material.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

Route<void> buildComicDetailDestinationRoute(WidgetBuilder builder) {
  return useWindowsComicDetailPanel
      ? PageRouteBuilder<void>(
          transitionDuration: windowsComicDetailPanelAnimationDuration,
          reverseTransitionDuration: const Duration(milliseconds: 280),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final position =
                Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                );
            return SlideTransition(position: position, child: child);
          },
        )
      : MaterialPageRoute<void>(builder: builder);
}
