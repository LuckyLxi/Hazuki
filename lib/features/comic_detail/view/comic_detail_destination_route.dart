import 'package:flutter/material.dart';
import 'package:hazuki/shared/navigation/snapshotting_page_route.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

Route<void> buildComicDetailDestinationRoute(
  BuildContext context,
  WidgetBuilder builder, {
  bool skipEntrance = false,
}) {
  return useWindowsComicDetailPanel &&
          Theme.of(context).platform == TargetPlatform.windows
      ? _WindowsDestinationRoute(
          skipEntrance: skipEntrance,
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
      : buildSnapshottingPageRoute<void>(
          builder: builder,
          skipEntrance: skipEntrance,
        );
}

class _WindowsDestinationRoute extends PageRouteBuilder<void> {
  _WindowsDestinationRoute({
    required this.skipEntrance,
    required super.pageBuilder,
    required super.transitionsBuilder,
    required super.transitionDuration,
    required super.reverseTransitionDuration,
  });

  final bool skipEntrance;

  @override
  AnimationController createAnimationController() {
    final controller = super.createAnimationController();
    if (skipEntrance) controller.value = 1;
    return controller;
  }
}
