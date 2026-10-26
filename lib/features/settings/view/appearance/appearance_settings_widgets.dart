import 'package:flutter/material.dart';
import 'package:hazuki/shared/appearance/appearance_settings.dart';

/// 显示设置页的分区标题，可在标题右侧附带图标（如主题扩散动画起点）。
class AppearanceSectionHeader extends StatelessWidget {
  const AppearanceSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// 明暗模式选项卡片：上方为对应模式的界面缩略图，下方为名称。
class AppearanceThemeModeCard extends StatelessWidget {
  const AppearanceThemeModeCard({
    super.key,
    required this.mode,
    required this.label,
    required this.selected,
    required this.lightScheme,
    required this.darkScheme,
    required this.pureBlack,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 220);

  final ThemeMode mode;
  final String label;
  final bool selected;
  final ColorScheme lightScheme;
  final ColorScheme darkScheme;
  final bool pureBlack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(18);
    final light = _ThemeThumbnail(scheme: lightScheme);
    final dark = _ThemeThumbnail(
      scheme: darkScheme,
      background: pureBlack ? Colors.black : null,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: borderRadius,
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            // 边框宽度会计入 AnimatedContainer 的布局内边距并随动画渐变，
            // 内边距需以相同时长与曲线同步渐变，保持两者之和恒定，避免卡片高度跳动。
            child: AnimatedPadding(
              duration: _duration,
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(selected ? 7 : 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 64,
                      width: double.infinity,
                      child: switch (mode) {
                        ThemeMode.light => light,
                        ThemeMode.dark => dark,
                        // 跟随系统：沿对角线拼接浅色与深色缩略图。
                        ThemeMode.system => Stack(
                          fit: StackFit.expand,
                          children: [
                            light,
                            ClipPath(
                              clipper: const _DiagonalClipper(),
                              child: dark,
                            ),
                          ],
                        ),
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeThumbnail extends StatelessWidget {
  const _ThemeThumbnail({required this.scheme, this.background});

  final ColorScheme scheme;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, Color color) {
      return FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    return ColoredBox(
      color: background ?? scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(0.6, scheme.primary),
            const SizedBox(height: 5),
            bar(0.85, scheme.outlineVariant),
            const SizedBox(height: 5),
            bar(0.7, scheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  const _DiagonalClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 主题色圆形色块，选中时外圈描边并显示对勾。
class AppearanceColorSwatch extends StatelessWidget {
  const AppearanceColorSwatch({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  static const _size = 44.0;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 为空时绘制描边空心圆，用于“壁纸取色”这类非固定色选项。
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fill = color;
    final checkColor = fill == null
        ? colorScheme.primary
        : ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: _size + 10,
                height: _size + 10,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill ?? colorScheme.surface,
                    border: fill == null
                        ? Border.all(color: colorScheme.outline)
                        : null,
                  ),
                  child: Center(
                    child: selected
                        ? Icon(Icons.check_rounded, size: 20, color: checkColor)
                        : icon == null
                        ? null
                        : Icon(
                            icon,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 排版设置行尾部的小示意图，直观展示当前排版。
class AppearanceLayoutGlyph extends StatelessWidget {
  const AppearanceLayoutGlyph.discover(
    DiscoverSectionLayout layout, {
    super.key,
  }) : _discover = layout,
       _favorite = null;

  const AppearanceLayoutGlyph.favorite(FavoriteLayout layout, {super.key})
    : _discover = null,
      _favorite = layout;

  final DiscoverSectionLayout? _discover;
  final FavoriteLayout? _favorite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strong = colorScheme.primary.withValues(alpha: 0.75);
    final weak = colorScheme.primary.withValues(alpha: 0.35);

    Widget cell(double w, double h, [Color? color]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color ?? strong,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    Widget grid(int columns, int rows, double w, double h) => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 3,
            children: [
              for (var c = 0; c < columns; c++)
                cell(w, h, r == 0 ? strong : weak),
            ],
          ),
      ],
    );

    Widget listRows(int count) => Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 3,
      children: [for (var i = 0; i < count; i++) cell(30, 5)],
    );

    final glyph = switch ((_discover, _favorite)) {
      (DiscoverSectionLayout.horizontal, _) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [cell(11, 22), cell(11, 22), cell(6, 22, weak)],
      ),
      (DiscoverSectionLayout.list, _) => listRows(3),
      (DiscoverSectionLayout.grid2, _) => grid(2, 2, 13, 9),
      (DiscoverSectionLayout.grid3, _) => grid(3, 2, 8, 9),
      (_, FavoriteLayout.list) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          for (var i = 0; i < 2; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [cell(7, 10), cell(20, 4, weak)],
            ),
        ],
      ),
      (_, FavoriteLayout.grid3) => grid(3, 2, 8, 9),
      (_, FavoriteLayout.grid2) => grid(2, 1, 13, 22),
      (_, FavoriteLayout.coverOnly) => grid(4, 2, 6, 9),
      _ => const SizedBox.shrink(),
    };

    return ExcludeSemantics(
      child: SizedBox(width: 34, height: 24, child: Center(child: glyph)),
    );
  }
}
