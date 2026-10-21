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
    String? selectedLabel(List<HazukiFrostedMenuOption<T>> entries) {
      for (final option in entries) {
        if (option.children.isEmpty) {
          if (option.value == selected) return option.label;
        } else {
          final label = selectedLabel(option.children);
          if (label != null) return label;
        }
      }
      return null;
    }

    final label = selectedLabel(options) ?? '';
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
