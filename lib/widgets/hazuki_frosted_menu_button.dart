import 'package:flutter/material.dart';

import 'hazuki_frosted_menu.dart';

class HazukiFrostedMenuButton<T> extends StatefulWidget {
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
  });

  final List<HazukiFrostedMenuOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final VoidCallback? onOpened;
  final Widget? child;
  final Widget icon;
  final bool enabled;

  @override
  State<HazukiFrostedMenuButton<T>> createState() =>
      _HazukiFrostedMenuButtonState<T>();
}

class _HazukiFrostedMenuButtonState<T>
    extends State<HazukiFrostedMenuButton<T>> {
  final _anchorKey = GlobalKey();
  bool _open = false;

  Future<void> _showMenu() async {
    if (_open || !widget.enabled || widget.options.isEmpty) return;
    _open = true;
    try {
      widget.onOpened?.call();
      final value = await showHazukiFrostedMenu<T>(
        context: context,
        anchorKey: _anchorKey,
        options: widget.options,
        selected: widget.selected,
        label: widget.tooltip,
      );
      if (mounted && widget.enabled && value != null) widget.onSelected(value);
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.enabled && widget.options.isNotEmpty
        ? _showMenu
        : null;
    if (widget.child == null) {
      return IconButton(
        key: _anchorKey,
        tooltip: widget.tooltip,
        onPressed: onTap,
        icon: widget.icon,
      );
    }
    final button = InkWell(
      key: _anchorKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: widget.child,
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}

class HazukiFrostedDropdown<T> extends StatelessWidget {
  const HazukiFrostedDropdown({
    super.key,
    required this.options,
    required this.onSelected,
    this.selected,
    this.tooltip,
  });

  final List<HazukiFrostedMenuOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label =
        options
            .where((option) => option.value == selected)
            .firstOrNull
            ?.label ??
        '';
    return HazukiFrostedMenuButton<T>(
      options: options,
      selected: selected,
      onSelected: onSelected,
      tooltip: tooltip,
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
