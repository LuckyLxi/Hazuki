import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';

import '../support/search_shared.dart';

Future<void> showSearchSettingsDialog(
  BuildContext context, {
  required bool aggregateSearchEnabled,
  required ValueChanged<bool> onAggregateSearchChanged,
  required SearchComicLayout comicLayout,
  required ValueChanged<SearchComicLayout> onComicLayoutChanged,
}) {
  final strings = AppLocalizations.of(context)!;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.commonClose,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return InheritedTheme.captureAll(
        context,
        _SearchSettingsDialog(
          aggregateSearchEnabled: aggregateSearchEnabled,
          onAggregateSearchChanged: onAggregateSearchChanged,
          comicLayout: comicLayout,
          onComicLayoutChanged: onComicLayoutChanged,
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = Tween<double>(begin: 0.92, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        ),
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}

class _SearchSettingsDialog extends StatefulWidget {
  const _SearchSettingsDialog({
    required this.aggregateSearchEnabled,
    required this.onAggregateSearchChanged,
    required this.comicLayout,
    required this.onComicLayoutChanged,
  });

  final bool aggregateSearchEnabled;
  final ValueChanged<bool> onAggregateSearchChanged;
  final SearchComicLayout comicLayout;
  final ValueChanged<SearchComicLayout> onComicLayoutChanged;

  @override
  State<_SearchSettingsDialog> createState() => _SearchSettingsDialogState();
}

class _SearchSettingsDialogState extends State<_SearchSettingsDialog> {
  late bool _aggregateSearchEnabled = widget.aggregateSearchEnabled;
  late SearchComicLayout _comicLayout = widget.comicLayout;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(strings.searchSettingsTitle),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey('aggregate-search-switch'),
            value: _aggregateSearchEnabled,
            secondary: const Icon(Icons.hub_outlined),
            title: Text(strings.searchAggregateSearch),
            subtitle: Text(strings.searchAggregateSearchDescription),
            onChanged: (enabled) {
              setState(() {
                _aggregateSearchEnabled = enabled;
              });
              widget.onAggregateSearchChanged(enabled);
            },
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              strings.searchResultLayout,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 4),
          _buildLayoutTile(
            context,
            layout: SearchComicLayout.list,
            icon: Icons.view_list_rounded,
            label: strings.searchLayoutList,
          ),
          _buildLayoutTile(
            context,
            layout: SearchComicLayout.grid3,
            icon: Icons.apps_rounded,
            label: strings.searchLayoutGrid3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
          child: Text(strings.commonClose),
        ),
      ],
    );
  }

  Widget _buildLayoutTile(
    BuildContext context, {
    required SearchComicLayout layout,
    required IconData icon,
    required String label,
  }) {
    final selected = _comicLayout == layout;
    return ListTile(
      key: ValueKey('search-layout-${layout.name}'),
      leading: Icon(icon),
      title: Text(label),
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      selected: selected,
      onTap: () {
        if (selected) return;
        setState(() {
          _comicLayout = layout;
        });
        widget.onComicLayoutChanged(layout);
      },
    );
  }
}
