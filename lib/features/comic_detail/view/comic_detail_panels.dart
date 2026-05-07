import 'package:flutter/material.dart';

export 'package:hazuki/widgets/chapters_panel_sheet.dart';

class HazukiTabBarDelegate extends SliverPersistentHeaderDelegate {
  const HazukiTabBarDelegate(
    this.tabBar,
    this.surfaceColor, {
    required this.detailsReady,
    required this.shouldAnimateInitialDetailReveal,
  });

  final TabBar tabBar;
  final Color surfaceColor;
  final bool detailsReady;
  final bool shouldAnimateInitialDetailReveal;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final tabBarHeight = tabBar.preferredSize.height;
    final targetOffsetY = shouldAnimateInitialDetailReveal && !detailsReady
        ? -(tabBarHeight * 0.12)
        : 0.0;

    return RepaintBoundary(
      child: ColoredBox(
        color: surfaceColor,
        child: SizedBox(
          height: tabBarHeight,
          child: ClipRect(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: targetOffsetY, end: targetOffsetY),
              duration: shouldAnimateInitialDetailReveal
                  ? const Duration(milliseconds: 320)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              child: tabBar,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: child,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant HazukiTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        surfaceColor != oldDelegate.surfaceColor ||
        detailsReady != oldDelegate.detailsReady ||
        shouldAnimateInitialDetailReveal !=
            oldDelegate.shouldAnimateInitialDetailReveal;
  }
}
