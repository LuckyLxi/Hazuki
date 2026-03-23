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
            onTap: () {},
            child: SlideTransition(position: slideIn, child: child),
          ),
        ),
      ),
    );
  }
}

class _ChaptersPanelSheet extends StatefulWidget {
  const _ChaptersPanelSheet({
    required this.details,
    required this.onChapterTap,
    required this.onDownloadConfirm,
  });

  final ComicDetailsData details;
  final void Function(String epId, String chapterTitle, int index) onChapterTap;
  final ValueChanged<Set<String>> onDownloadConfirm;

  @override
  State<_ChaptersPanelSheet> createState() => _ChaptersPanelSheetState();
}

class _ChaptersPanelSheetState extends State<_ChaptersPanelSheet> {
  bool _showDownloadSelection = false;
  final Set<String> _selectedEpIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chapters = widget.details.chapters;
    final screenH = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: !_showDownloadSelection,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showDownloadSelection) {
          setState(() {
            _showDownloadSelection = false;
          });
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      key: ValueKey<bool>(_showDownloadSelection),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showDownloadSelection
                              ? IconButton(
                                  key: const ValueKey('download_back'),
                                  tooltip: l10n(context).commonClose,
                                  onPressed: () {
                                    setState(() {
                                      _showDownloadSelection = false;
                                    });
                                  },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                )
                              : const SizedBox(
                                  key: ValueKey('download_back_hidden'),
                                  width: 0,
                                  height: 0,
                                ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.18),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            _showDownloadSelection
                                ? l10n(context).downloadsDownloadChaptersTitle
                                : l10n(context).comicDetailChapters,
                            key: ValueKey<String>(
                              _showDownloadSelection ? 'download_title' : 'chapter_title',
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          child: Text(
                            _showDownloadSelection
                                ? '${_selectedEpIds.length}/${chapters.length}'
                                : l10n(
                                    context,
                                  ).comicDetailChapterCount('${chapters.length}'),
                            key: ValueKey<String>(
                              _showDownloadSelection
                                  ? 'download_count_${_selectedEpIds.length}'
                                  : 'chapter_count_${chapters.length}',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.9, end: 1).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: !_showDownloadSelection
                              ? IconButton(
                                  key: const ValueKey('download_enter'),
                                  tooltip: l10n(context).downloadsDownloadAction,
                                  onPressed: () {
                                    setState(() {
                                      _showDownloadSelection = true;
                                    });
                                  },
                                  icon: const Icon(Icons.download_outlined),
                                )
                              : const SizedBox(
                                  key: ValueKey('download_enter_hidden'),
                                  width: 0,
                                  height: 0,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.04, 0.02),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _showDownloadSelection
                        ? _buildDownloadSelection(context, chapters)
                        : _buildChapterGrid(chapters),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        sizeFactor: animation,
                        axisAlignment: -1,
                        child: child,
                      ),
                    );
                  },
                  child: _showDownloadSelection
                      ? Padding(
                          key: const ValueKey('download_footer_visible'),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            MediaQuery.of(context).padding.bottom + 12,
                          ),
                          child: FilledButton.icon(
                            onPressed: _selectedEpIds.isEmpty
                                ? null
                                : () => widget.onDownloadConfirm(
                                    Set<String>.from(_selectedEpIds),
                                  ),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(l10n(context).downloadsDownloadAction),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('download_footer_hidden'),
                          height: MediaQuery.of(context).padding.bottom + 8,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterGrid(Map<String, String> chapters) {
    return GridView.builder(
      key: const ValueKey('chapter-grid'),
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
          onTap: () => widget.onChapterTap(entry.key, entry.value, index),
        );
      },
    );
  }

  Widget _buildDownloadSelection(
    BuildContext context,
    Map<String, String> chapters,
  ) {
    final chapterEntries = chapters.entries.toList();
    return Column(
      key: const ValueKey('download-grid'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n(context).downloadsDownloadChaptersSubtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: chapterEntries.length,
            itemBuilder: (context, index) {
              final entry = chapterEntries[index];
              final selected = _selectedEpIds.contains(entry.key);
              return _SelectableChapterChip(
                label: entry.value,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedEpIds.remove(entry.key);
                    } else {
                      _selectedEpIds.add(entry.key);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SelectableChapterChip extends StatelessWidget {
  const _SelectableChapterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.secondaryContainer.withValues(alpha: 0.55),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected
                    ? cs.onPrimaryContainer
                    : cs.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
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
