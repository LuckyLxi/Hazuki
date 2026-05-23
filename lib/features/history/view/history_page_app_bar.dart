import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/widgets/widgets.dart';

class HistoryPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HistoryPageAppBar({
    super.key,
    required this.hasHistory,
    required this.selectionMode,
    required this.onToggleSelectionMode,
    required this.onDeleteSelected,
    required this.onClearAll,
  });

  final bool hasHistory;
  final bool selectionMode;
  final VoidCallback onToggleSelectionMode;
  final Future<void> Function() onDeleteSelected;
  final Future<void> Function() onClearAll;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;

    return hazukiFrostedAppBar(
      context: context,
      title: Text(strings.historyTitle),
      actions: [
        if (hasHistory)
          IconButton(
            tooltip: selectionMode
                ? strings.historySelectionCancelTooltip
                : strings.historySelectionEnterTooltip,
            icon: Icon(selectionMode ? Icons.close : Icons.checklist),
            onPressed: onToggleSelectionMode,
          ),
        if (hasHistory)
          IconButton(
            tooltip: selectionMode
                ? strings.historyDeleteSelectedTooltip
                : strings.historyClearAllTooltip,
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                unawaited(selectionMode ? onDeleteSelected() : onClearAll()),
          ),
      ],
    );
  }
}
