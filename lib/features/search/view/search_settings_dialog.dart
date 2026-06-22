import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/l10n/app_localizations.dart';

Future<void> showSearchSettingsDialog(
  BuildContext context, {
  required bool aggregateSearchEnabled,
  required ValueChanged<bool> onAggregateSearchChanged,
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
  });

  final bool aggregateSearchEnabled;
  final ValueChanged<bool> onAggregateSearchChanged;

  @override
  State<_SearchSettingsDialog> createState() => _SearchSettingsDialogState();
}

class _SearchSettingsDialogState extends State<_SearchSettingsDialog> {
  late bool _aggregateSearchEnabled = widget.aggregateSearchEnabled;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.searchSettingsTitle),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      content: SwitchListTile(
        key: const ValueKey('aggregate-search-switch'),
        value: _aggregateSearchEnabled,
        secondary: const Icon(Icons.hub_outlined),
        title: Text(strings.searchAggregateSearch),
        onChanged: (enabled) {
          setState(() {
            _aggregateSearchEnabled = enabled;
          });
          widget.onAggregateSearchChanged(enabled);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(Navigator.of(context).maybePop()),
          child: Text(strings.commonClose),
        ),
      ],
    );
  }
}
