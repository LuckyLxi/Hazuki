part of '../../main.dart';

class _HazukiTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _HazukiTabBarDelegate(this.tabBar, this.surfaceColor);

  final TabBar tabBar;
  final Color surfaceColor;

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
    return ColoredBox(color: surfaceColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _HazukiTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar ||
        surfaceColor != oldDelegate.surfaceColor;
  }
}

class _SpringBottomSheetRoute<T> extends PageRoute<T> {
  _SpringBottomSheetRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final isReversing = animation.status == AnimationStatus.reverse;

    // 使用 easeOutBack 带来轻度弹性，摒弃之前用力过猛的自制曲线
    final slideIn = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: isReversing ? Curves.easeInCubic : Curves.easeOutBack,
          ),
        );

    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
        reverseCurve: Curves.easeInCubic,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: FadeTransition(
        opacity: fade,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // 防透传
            child: SlideTransition(position: slideIn, child: child),
          ),
        ),
      ),
    );
  }
}

class _ChaptersPanelSheet extends StatelessWidget {
  const _ChaptersPanelSheet({
    required this.details,
    required this.onChapterTap,
  });

  final ComicDetailsData details;
  final void Function(String epId, String chapterTitle, int index) onChapterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chapters = details.chapters;
    final screenH = MediaQuery.of(context).size.height;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 这一层用于在弹性回环（弹窗跳得比屏幕底部更高）时，遮挡住屏幕底部的空缺
        Positioned(
          left: 0,
          right: 0,
          bottom: -200,
          height: 200,
          child: ColoredBox(color: cs.surface),
        ),
        Container(
          constraints: BoxConstraints(maxHeight: screenH * 0.65),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text(
                      l10n(context).comicDetailChapters,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n(
                        context,
                      ).comicDetailChapterCount('${chapters.length}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final entry = chapters.entries.elementAt(index);
                    return _ChapterChip(
                      label: entry.value,
                      onTap: () => onChapterTap(entry.key, entry.value, index),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChapterChip extends StatelessWidget {
  const _ChapterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: cs.onSecondaryContainer,
      fontWeight: FontWeight.w500,
      fontSize: 12,
    );

    return Material(
      color: cs.secondaryContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
