import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/widgets/hazuki_prompt.dart';

class HomeBottomNavigation extends StatefulWidget {
  const HomeBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.discoverLabel,
    required this.favoriteLabel,
    this.layoutScale = 1,
  }) : assert(layoutScale > 0);

  static const double floatingBarHeight = 58;
  static const double floatingVerticalPadding = 6;
  static const double fallbackBarHeight = 48;
  static const double bottomSpacing = 10;
  static const double promptGap = 10;
  static const double promptBottomPadding =
      floatingBarHeight + floatingVerticalPadding * 2 + promptGap;
  static const double fallbackPromptBottomPadding =
      fallbackBarHeight + bottomSpacing + promptGap;

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String discoverLabel;
  final String favoriteLabel;
  final double layoutScale;

  @override
  State<HomeBottomNavigation> createState() => _HomeBottomNavigationState();
}

class _HomeBottomNavigationState extends State<HomeBottomNavigation>
    with TickerProviderStateMixin {
  static const int _itemCount = 2;
  final _barKey = GlobalKey();

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnims;
  late final List<Animation<double>> _labelAnims;
  late final List<Animation<Offset>> _labelSlideAnims;

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

    // Label fade/size: easeOutCubic in, easeIn out
    _labelAnims = _controllers
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeIn,
          ),
        )
        .toList();

    // Label slide: Discover (index 0) label is to the right of icon, so it
    // springs in from the left (near-icon side). Favorites (index 1) label is
    // to the left of icon, so it springs in from the right (near-icon side).
    // easeOutBack gives the horizontal bounce/spring feel.
    _labelSlideAnims = List.generate(_itemCount, (i) {
      return Tween<Offset>(
        begin: Offset(i == 0 ? -0.5 : 0.5, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controllers[i],
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        ),
      );
    });
    _schedulePromptAnchorSync();
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
    _schedulePromptAnchorSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePromptAnchorSync();
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
    final scale = widget.layoutScale;
    final bottomPadding = MediaQuery.of(context).padding.bottom * scale;

    if (HazukiLiquidGlass.isAvailable) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Center(
          heightFactor: 1,
          child: SizedBox(
            width: 240 * scale,
            child: GlassTabBar.bottom(
              key: const ValueKey('home-bottom-navigation-premium'),
              tabs: [
                GlassTab(
                  icon: const Icon(Icons.explore_outlined),
                  activeIcon: const Icon(Icons.explore),
                  label: widget.discoverLabel,
                  semanticLabel: widget.discoverLabel,
                ),
                GlassTab(
                  icon: const Icon(Icons.favorite_border),
                  activeIcon: const Icon(Icons.favorite),
                  label: widget.favoriteLabel,
                  semanticLabel: widget.favoriteLabel,
                ),
              ],
              selectedIndex: widget.currentIndex,
              onTabSelected: widget.onDestinationSelected,
              quality: HazukiLiquidGlass.navigationQuality,
              horizontalPadding: 12 * scale,
              verticalPadding:
                  HomeBottomNavigation.floatingVerticalPadding * scale,
              barHeight: HomeBottomNavigation.floatingBarHeight * scale,
              tabWidth: 108 * scale,
              barBorderRadius: 32 * scale,
              tabPadding: EdgeInsets.symmetric(horizontal: 4 * scale),
              iconLabelSpacing: 4 * scale,
              iconSize: 24 * scale,
              labelFontSize: 11 * scale,
              indicatorBorderRadius: 40 * scale,
              indicatorExpansion: EdgeInsets.symmetric(
                horizontal: 12 * scale,
                vertical: 8 * scale,
              ),
              selectedIconColor: colorScheme.primary,
              selectedLabelColor: colorScheme.primary,
              unselectedIconColor: colorScheme.onSurfaceVariant,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              selectedLabelStyle: const TextStyle(
                decoration: TextDecoration.none,
              ),
              unselectedLabelStyle: const TextStyle(
                decoration: TextDecoration.none,
              ),
              interactionBehavior: GlassInteractionBehavior.scaleOnly,
              settings: LiquidGlassSettings(
                thickness: 30,
                blur: 3,
                chromaticAberration: 0.3,
                lightIntensity: 0.6,
                refractiveIndex: 1.59,
                saturation: 0.7,
                ambientStrength: 1,
                glassColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x3DFFFFFF),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: HomeBottomNavigation.bottomSpacing * scale + bottomPadding,
      ),
      child: Center(
        heightFactor: 1.0,
        child: Transform.scale(
          key: const ValueKey('home-bottom-navigation-fallback-scale'),
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: UnconstrainedBox(
            child: _buildNavigationSurface(
              colorScheme: colorScheme,
              isDark: isDark,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final box =
                        _barKey.currentContext!.findRenderObject()!
                            as RenderBox;
                    final localX = box.globalToLocal(details.globalPosition).dx;
                    widget.onDestinationSelected(
                      localX < box.size.width / 2 ? 0 : 1,
                    );
                  },
                  child: Row(
                    key: _barKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildItem(
                        index: 0,
                        icon: Icons.explore_outlined,
                        selectedIcon: Icons.explore,
                        label: widget.discoverLabel,
                        colorScheme: colorScheme,
                        labelOnRight: true,
                      ),
                      const SizedBox(width: 44),
                      _buildItem(
                        index: 1,
                        icon: Icons.favorite_border,
                        selectedIcon: Icons.favorite,
                        label: widget.favoriteLabel,
                        colorScheme: colorScheme,
                        labelOnRight: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationSurface({
    required ColorScheme colorScheme,
    required bool isDark,
    required Widget child,
  }) {
    return ClipRRect(
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
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  void _schedulePromptAnchorSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      hazukiPromptPlacementController.updateHomeAnchor(
        tabIndex: widget.currentIndex,
        elevatedBottomPadding: HazukiLiquidGlass.isAvailable
            ? HomeBottomNavigation.promptBottomPadding
            : HomeBottomNavigation.fallbackPromptBottomPadding,
      );
    });
  }

  Widget _buildItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required ColorScheme colorScheme,
    required bool labelOnRight,
  }) {
    final isSelected = widget.currentIndex == index;

    final iconWidget = ScaleTransition(
      scale: _scaleAnims[index],
      child: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        size: 22,
      ),
    );

    final labelWidget = SizeTransition(
      sizeFactor: _labelAnims[index],
      axis: Axis.horizontal,
      alignment: AlignmentDirectional(labelOnRight ? -1.0 : 1.0, -1.0),
      child: SlideTransition(
        position: _labelSlideAnims[index],
        child: FadeTransition(
          opacity: _labelAnims[index],
          child: Padding(
            padding: labelOnRight
                ? const EdgeInsets.only(left: 5)
                : const EdgeInsets.only(right: 5),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: labelOnRight
                  ? [iconWidget, labelWidget]
                  : [labelWidget, iconWidget],
            ),
          ),
        ],
      ),
    );
  }
}
