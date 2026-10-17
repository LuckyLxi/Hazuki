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
    this.showBackToTop = false,
    this.onBackToTopPressed,
    this.backToTopLabel = '',
    this.layoutScale = 1,
  }) : assert(layoutScale > 0);

  static const double floatingBarHeight =
      HazukiLiquidGlass.navigationControlHeight;
  static const double floatingVerticalPadding = 6;
  static const double fallbackBarHeight = floatingBarHeight;
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
  final bool showBackToTop;
  final VoidCallback? onBackToTopPressed;
  final String backToTopLabel;
  final double layoutScale;

  @override
  State<HomeBottomNavigation> createState() => _HomeBottomNavigationState();
}

class _HomeBottomNavigationState extends State<HomeBottomNavigation>
    with TickerProviderStateMixin {
  static const int _itemCount = 2;
  final _barKey = GlobalKey();
  Color? _accentSeed;
  Brightness? _accentBrightness;
  late Color _accent;

  late final GlassMorphController _backToTopMorph;

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnims;
  late final List<Animation<double>> _labelAnims;
  late final List<Animation<Offset>> _labelSlideAnims;

  @override
  void initState() {
    super.initState();
    _backToTopMorph = GlassMorphController(
      vsync: this,
      speed: MorphSpeed.slow,
      preserveLegacyMotion: true,
    );
    if (widget.showBackToTop) {
      _backToTopMorph.open();
    }
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
    if (oldWidget.showBackToTop != widget.showBackToTop) {
      if (widget.showBackToTop) {
        _backToTopMorph.open();
      } else {
        _backToTopMorph.close();
      }
    }
    _schedulePromptAnchorSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final seed = theme.colorScheme.primary;
    if (_accentSeed != seed || _accentBrightness != theme.brightness) {
      _accentSeed = seed;
      _accentBrightness = theme.brightness;
      _accent = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: theme.brightness,
      ).primary;
    }
    _backToTopMorph.setDisableAnimations(
      MediaQuery.disableAnimationsOf(context),
    );
    _schedulePromptAnchorSync();
  }

  @override
  void dispose() {
    _backToTopMorph.dispose();
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
    final accent = _accent;
    final foreground = isDark ? Colors.white : Colors.black87;
    final shadows = [
      Shadow(color: isDark ? Colors.black54 : Colors.white54, blurRadius: 1.5),
    ];

    if (HazukiLiquidGlass.isAvailable) {
      return AnimatedBuilder(
        animation: _backToTopMorph,
        builder: (context, _) {
          final morphState = _backToTopMorph.computeState(
            finalDx: 91 * scale,
            finalDy: 0,
          );
          final buttonScale = morphState.sizeT.clamp(0.0, 1.0).toDouble();
          return Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: SizedBox(
              height:
                  (HomeBottomNavigation.floatingBarHeight +
                      HomeBottomNavigation.floatingVerticalPadding * 2) *
                  scale,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extraWidth =
                      (8 + HazukiLiquidGlass.navigationControlHeight) * scale;
                  final navigationWidth = _navigationWidth(
                    constraints.maxWidth,
                  );
                  final combinedWidth = navigationWidth + extraWidth;
                  // Keep the destinations centred where space allows, and
                  // reserve room for the merging action on narrow screens.
                  final navigationLeft =
                      ((constraints.maxWidth - navigationWidth) / 2).clamp(
                        0.0,
                        (constraints.maxWidth - combinedWidth - 12 * scale)
                            .clamp(0.0, double.infinity),
                      );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        key: const ValueKey(
                          'home-bottom-navigation-glass-anchor',
                        ),
                        left: navigationLeft,
                        width: navigationWidth,
                        top: 0,
                        bottom: 0,
                        child: const SizedBox.shrink(),
                      ),
                      Positioned(
                        left: navigationLeft,
                        width: combinedWidth,
                        top: 0,
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            platformBrightness: Theme.of(context).brightness,
                          ),
                          child: GlassTabBar.bottom(
                            key: const ValueKey(
                              'home-bottom-navigation-premium',
                            ),
                            tabs: [
                              GlassTab(
                                icon: Icon(
                                  Icons.explore_outlined,
                                  shadows: shadows,
                                ),
                                activeIcon: Icon(
                                  Icons.explore,
                                  shadows: shadows,
                                ),
                                label: widget.discoverLabel,
                                semanticLabel: widget.discoverLabel,
                              ),
                              GlassTab(
                                icon: Icon(
                                  Icons.favorite_border,
                                  shadows: shadows,
                                ),
                                activeIcon: Icon(
                                  Icons.favorite,
                                  shadows: shadows,
                                ),
                                label: widget.favoriteLabel,
                                semanticLabel: widget.favoriteLabel,
                              ),
                            ],
                            selectedIndex: widget.currentIndex,
                            onTabSelected: widget.onDestinationSelected,
                            extraButton: GlassTabBarExtraButton(
                              icon: Opacity(
                                opacity: buttonScale,
                                child: Icon(
                                  Icons.vertical_align_top_rounded,
                                  color: foreground,
                                  shadows: shadows,
                                ),
                              ),
                              onTap: widget.onBackToTopPressed ?? () {},
                              label: widget.backToTopLabel,
                              size:
                                  HazukiLiquidGlass.navigationControlHeight *
                                  scale,
                              transformOffset: Offset(
                                morphState.currentDx - 91 * scale,
                                0,
                              ),
                              transformScale: buttonScale,
                              ignorePointer:
                                  !widget.showBackToTop || buttonScale < 0.8,
                              glowOpacity: 0,
                            ),
                            spacing: 8 * scale,
                            blendAmount: 10 + morphState.blend,
                            quality: HazukiLiquidGlass.navigationQuality,
                            adaptiveBrightness: false,
                            magnification: 1.2,
                            indicatorSettings:
                                HazukiLiquidGlass.indicatorSettings,
                            horizontalPadding: 12 * scale,
                            verticalPadding:
                                HomeBottomNavigation.floatingVerticalPadding *
                                scale,
                            barHeight:
                                HomeBottomNavigation.floatingBarHeight * scale,
                            tabWidth: (navigationWidth - 24 * scale) / 2,
                            barBorderRadius: GlassDefaults.capsuleRadius,
                            tabPadding: EdgeInsets.symmetric(
                              horizontal: 4 * scale,
                            ),
                            iconLabelSpacing: 4 * scale,
                            iconSize: 24 * scale,
                            labelFontSize: 11 * scale,
                            indicatorBorderRadius: GlassDefaults.capsuleRadius,
                            indicatorExpansion: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                              vertical: 8 * scale,
                            ),
                            selectedIconColor: accent,
                            selectedLabelColor: accent,
                            unselectedIconColor: foreground,
                            unselectedLabelColor: foreground,
                            selectedLabelStyle: TextStyle(
                              decoration: TextDecoration.none,
                              shadows: shadows,
                            ),
                            unselectedLabelStyle: TextStyle(
                              decoration: TextDecoration.none,
                              shadows: shadows,
                            ),
                            interactionBehavior: GlassInteractionBehavior.full,
                            indicatorColor:
                                (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.1),
                            settings: HazukiLiquidGlass.navigationSettings(
                              context,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: HomeBottomNavigation.bottomSpacing * scale + bottomPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Center(
          heightFactor: 1.0,
          child: Transform.scale(
            key: const ValueKey('home-bottom-navigation-fallback-scale'),
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: UnconstrainedBox(
              child: SizedBox(
                // The glass layout reserves 12 pixels on each side of its pill.
                width: (_navigationWidth(constraints.maxWidth) / scale - 24)
                    .clamp(0.0, double.infinity),
                height: HomeBottomNavigation.fallbackBarHeight,
                child: _buildNavigationSurface(
                  colorScheme: colorScheme,
                  isDark: isDark,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        final box =
                            _barKey.currentContext!.findRenderObject()!
                                as RenderBox;
                        final localX = box
                            .globalToLocal(details.globalPosition)
                            .dx;
                        widget.onDestinationSelected(
                          localX < box.size.width / 2 ? 0 : 1,
                        );
                      },
                      child: Row(
                        key: _barKey,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: _buildItem(
                              index: 0,
                              icon: Icons.explore_outlined,
                              selectedIcon: Icons.explore,
                              label: widget.discoverLabel,
                              colorScheme: colorScheme,
                              labelOnRight: true,
                            ),
                          ),
                          Expanded(
                            child: _buildItem(
                              index: 1,
                              icon: Icons.favorite_border,
                              selectedIcon: Icons.favorite,
                              label: widget.favoriteLabel,
                              colorScheme: colorScheme,
                              labelOnRight: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _navigationWidth(double availableWidth) {
    final scale = widget.layoutScale;
    final extraWidth = (8 + HazukiLiquidGlass.navigationControlHeight) * scale;
    return (availableWidth - extraWidth - 24 * scale).clamp(0.0, 240 * scale);
  }

  Widget _buildNavigationSurface({
    required ColorScheme colorScheme,
    required bool isDark,
    required Widget child,
  }) {
    return ClipRRect(
      key: const ValueKey('home-bottom-navigation-fallback-surface'),
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
      alignment: AlignmentDirectional(labelOnRight ? -1.0 : 1.0, 0),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                decoration: TextDecoration.none,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: labelOnRight
                  ? [iconWidget, Flexible(child: labelWidget)]
                  : [Flexible(child: labelWidget), iconWidget],
            ),
          ),
        ],
      ),
    );
  }
}
