import 'dart:ui';

import 'package:flutter/material.dart';

class HomeBottomNavigation extends StatefulWidget {
  const HomeBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.discoverLabel,
    required this.favoriteLabel,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String discoverLabel;
  final String favoriteLabel;

  @override
  State<HomeBottomNavigation> createState() => _HomeBottomNavigationState();
}

class _HomeBottomNavigationState extends State<HomeBottomNavigation>
    with TickerProviderStateMixin {
  static const int _itemCount = 2;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _itemCount,
      (i) => AnimationController(
        vsync: this,
        // Forward: bouncy spring feel
        duration: const Duration(milliseconds: 360),
        // Reverse: snappy and instant
        reverseDuration: const Duration(milliseconds: 140),
        value: i == widget.currentIndex ? 1.0 : 0.0,
      ),
    );
    _scaleAnims = _controllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(
              parent: c,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            ),
          ),
        )
        .toList();
  }

  @override
  void didUpdateWidget(covariant HomeBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      // Snap back the old item instantly
      _controllers[oldWidget.currentIndex].reverse();
      // Animate in the new item with spring
      _controllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: 10 + bottomPadding),
      // heightFactor: 1.0 — Center only takes the height of its child,
      // preventing it from expanding to fill the full Scaffold bottomNav area.
      child: Center(
        heightFactor: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface.withValues(alpha: 0.75)
                    : colorScheme.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.20 : 0.08,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildItem(
                    index: 0,
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore,
                    label: widget.discoverLabel,
                    colorScheme: colorScheme,
                  ),
                  // Wider gap between the two items
                  const SizedBox(width: 20),
                  _buildItem(
                    index: 1,
                    icon: Icons.favorite_border,
                    selectedIcon: Icons.favorite,
                    label: widget.favoriteLabel,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    final isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => widget.onDestinationSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.88)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnims[index],
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
