import 'package:flutter/material.dart';

import 'hazuki_frosted_menu.dart';
import 'source_plugin_interaction.dart';
export 'source_plugin_menu.dart' show SourcePluginMenuBinding;

class HazukiFrostedMenuButton<T> extends StatelessWidget {
  const HazukiFrostedMenuButton({
    super.key,
    required this.options,
    required this.onSelected,
    this.selected,
    this.tooltip,
    this.onOpened,
    this.child,
    this.icon = const Icon(Icons.more_vert),
    this.enabled = true,
    this.waitForDismissal = false,
    this.pluginMenu,
  });

  final List<HazukiFrostedMenuOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final VoidCallback? onOpened;
  final Widget? child;
  final Widget icon;
  final bool enabled;

  /// Wait for the closing animation before an action can present another route.
  final bool waitForDismissal;
  final SourcePluginMenuBinding<T>? pluginMenu;

  @override
  Widget build(BuildContext context) => SourcePluginInteraction<T>(
    binding: pluginMenu,
    options: options,
    selected: selected,
    onSelected: onSelected,
    label: tooltip,
    enabled: enabled,
    onOpened: onOpened,
    waitForDismissal: waitForDismissal,
    builder: (context, activate) {
      if (child == null) {
        return IconButton(tooltip: tooltip, onPressed: activate, icon: icon);
      }
      final button = InkWell(
        onTap: activate,
        borderRadius: BorderRadius.circular(20),
        child: child,
      );
      return tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button);
    },
  );
}

class HazukiFrostedDropdown<T> extends StatelessWidget {
  const HazukiFrostedDropdown({
    super.key,
    required this.options,
    required this.onSelected,
    this.selected,
    this.tooltip,
    this.pluginMenu,
  });

  final List<HazukiFrostedMenuOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final SourcePluginMenuBinding<T>? pluginMenu;

  @override
  Widget build(BuildContext context) {
    final label = _selectedLabel(options, selected) ?? '';
    return HazukiFrostedMenuButton<T>(
      options: options,
      selected: selected,
      onSelected: onSelected,
      tooltip: tooltip,
      pluginMenu: pluginMenu,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.5,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单选类设置行：左侧图标、标题与说明，右侧胶囊显示当前取值，点整行弹出毛玻璃菜单。
class HazukiMenuSettingTile<T> extends StatelessWidget {
  const HazukiMenuSettingTile({
    super.key,
    required this.title,
    required this.options,
    required this.onSelected,
    this.selected,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.pluginMenu,
  });

  final String title;
  final List<HazukiFrostedMenuOption<T>> options;
  final ValueChanged<T> onSelected;
  final T? selected;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;
  final SourcePluginMenuBinding<T>? pluginMenu;

  @override
  Widget build(BuildContext context) {
    final label = _selectedLabel(options, selected);
    return SourcePluginInteraction<T>(
      binding: pluginMenu,
      options: options,
      selected: selected,
      onSelected: onSelected,
      label: title,
      enabled: enabled,
      builder: (context, activate) => ListTile(
        enabled: enabled,
        leading: leading,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: label == null ? null : _MenuValuePill(label: label),
        onTap: activate,
      ),
    );
  }
}

class _MenuValuePill extends StatelessWidget {
  const _MenuValuePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      // 插件提供的文案长度不可控，限制宽度避免挤压标题。
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 在可能含子菜单的选项树中查找当前选中项的文案。
String? _selectedLabel<T>(
  List<HazukiFrostedMenuOption<T>> entries,
  T? selected,
) {
  for (final option in entries) {
    if (option.children.isEmpty) {
      if (option.value == selected) return option.label;
    } else {
      final label = _selectedLabel(option.children, selected);
      if (label != null) return label;
    }
  }
  return null;
}
