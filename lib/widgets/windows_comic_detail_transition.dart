import 'package:flutter/material.dart';

import '../shared/windows/windows_comic_detail.dart';

/// Presents navigation changes without owning the detail history or routes.
class WindowsComicDetailTransition extends StatelessWidget {
  const WindowsComicDetailTransition({
    super.key,
    required this.entry,
    required this.shouldAnimatePanelReveal,
    required this.child,
  });

  final WindowsComicDetailEntry entry;
  final bool shouldAnimatePanelReveal;
  final Widget child;

  Widget _slide(Widget child, Animation<double> animation, Offset begin) {
    return SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        final current = currentChild == null ? <Widget>[] : [currentChild];
        return Stack(
          fit: StackFit.expand,
          children: entry.navigation == WindowsComicDetailNavigation.pop
              ? [...current, ...previousChildren]
              : [...previousChildren, ...current],
        );
      },
      transitionBuilder: (child, animation) {
        if (shouldAnimatePanelReveal) {
          final isActiveEntry = child.key == ValueKey<int>(entry.revision);
          final shouldSlide = switch (entry.navigation) {
            WindowsComicDetailNavigation.pop => !isActiveEntry,
            WindowsComicDetailNavigation.push => isActiveEntry,
            WindowsComicDetailNavigation.open ||
            WindowsComicDetailNavigation.replace ||
            WindowsComicDetailNavigation.resume => false,
          };
          return shouldSlide
              ? _slide(child, animation, const Offset(0, 1))
              : child;
        }
        return FadeTransition(
          opacity: animation,
          child: _slide(child, animation, const Offset(0.08, 0)),
        );
      },
      child: child,
    );
  }
}
