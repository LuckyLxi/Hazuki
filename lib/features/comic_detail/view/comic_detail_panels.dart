import 'package:flutter/material.dart';
import 'package:hazuki/shared/comments/comments_sort_scope.dart';

class HazukiTabBarDelegate extends SliverPersistentHeaderDelegate {
  const HazukiTabBarDelegate(
    this.tabBar,
    this.surfaceColor, {
    required this.detailsReady,
    required this.shouldAnimateInitialDetailReveal,
    this.trailing,
  });

  final TabBar tabBar;
  final Color surfaceColor;
  final bool detailsReady;
  final bool shouldAnimateInitialDetailReveal;
  final Widget? trailing;

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
              child: trailing == null
                  ? tabBar
                  : Row(
                      children: [
                        Expanded(child: tabBar),
                        trailing!,
                      ],
                    ),
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
        trailing != oldDelegate.trailing ||
        surfaceColor != oldDelegate.surfaceColor ||
        detailsReady != oldDelegate.detailsReady ||
        shouldAnimateInitialDetailReveal !=
            oldDelegate.shouldAnimateInitialDetailReveal;
  }
}

class ComicDetailCommentsSortAction extends StatelessWidget {
  const ComicDetailCommentsSortAction({
    super.key,
    required this.tabController,
    required this.tabIndex,
  });

  final TabController tabController;
  final int tabIndex;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: tabController.animation ?? tabController,
    builder: (context, _) {
      final position =
          tabController.animation?.value ?? tabController.index.toDouble();
      final involvesComments =
          !tabController.indexIsChanging ||
          tabController.index == tabIndex ||
          tabController.previousIndex == tabIndex;
      final visible = involvesComments && (position - tabIndex).abs() < 0.5;
      return IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
            child: visible
                ? const Padding(
                    key: ValueKey('comic-detail-comments-sort'),
                    padding: EdgeInsets.only(right: 12),
                    child: CommentsSortButton(),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    },
  );
}
