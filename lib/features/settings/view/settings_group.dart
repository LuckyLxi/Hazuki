import 'package:flutter/material.dart';
import 'package:hazuki/widgets/widgets.dart';

class HazukiSettingsPageBody extends StatelessWidget {
  const HazukiSettingsPageBody({
    super.key,
    required this.child,
    this.maxWidth = 1080,
    this.padding = const EdgeInsets.symmetric(horizontal: 28),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return HazukiDesktopPageContainer(
      maxWidth: maxWidth,
      padding: padding,
      child: child,
    );
  }
}

/// 设置分区标题：主题色加粗小标题，与设置首页分区一致。
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 设置条目前导图标：圆形色块底，与设置首页入口一致。
class SettingsLeadingIcon extends StatelessWidget {
  const SettingsLeadingIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: colorScheme.onSecondaryContainer),
    );
  }
}

/// 与图标对齐的缩进分隔线。
Widget settingsDivider(BuildContext context) => Divider(
  height: 1,
  indent: 72,
  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
);

/// 条目之间插入与图标对齐的缩进分隔线。
List<Widget> withSettingsDividers(BuildContext context, List<Widget> tiles) {
  final divider = settingsDivider(context);
  return [
    for (var i = 0; i < tiles.length; i++) ...[if (i > 0) divider, tiles[i]],
  ];
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(20);
    return Padding(
      padding: margin,
      child: Material(
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
