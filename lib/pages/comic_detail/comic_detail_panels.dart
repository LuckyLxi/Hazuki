part of '../../main.dart';

class _HazukiTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _HazukiTabBarDelegate(this.tabBar);

  final TabBar tabBar;

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
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _HazukiTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
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
  String? get barrierLabel => 'Dismiss';

  @override
  bool get maintainState => true;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 480);

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
    final slideIn = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: isReversing ? Curves.easeInCubic : const _SpringCurve(),
            reverseCurve: Curves.easeInCubic,
          ),
        );

    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        reverseCurve: const Interval(0.5, 1.0, curve: Curves.easeIn),
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
            onTap: () {},
            child: SlideTransition(position: slideIn, child: child),
          ),
        ),
      ),
    );
  }
}

class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.55) {
      return Curves.easeOut.transform(t / 0.55) * 1.06;
    } else if (t < 0.78) {
      final p = (t - 0.55) / (0.78 - 0.55);
      return 1.06 - p * 0.09;
    } else {
      final p = (t - 0.78) / (1.0 - 0.78);
      return 0.97 + p * 0.03;
    }
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

    return Container(
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
                  '章节',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '共 ${chapters.length} 话',
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
