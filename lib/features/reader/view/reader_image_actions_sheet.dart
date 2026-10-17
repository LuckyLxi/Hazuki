import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

enum ReaderImageAction { share, copy, save }

class ReaderImageActionsSheet extends StatelessWidget {
  const ReaderImageActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surfaceAlpha = theme.brightness == Brightness.dark ? 0.68 : 0.76;
    final strings = l10n(context);
    final actions = [
      if (defaultTargetPlatform != TargetPlatform.windows)
        (ReaderImageAction.share, strings.readerShareImage),
      (ReaderImageAction.copy, strings.readerCopyImage),
      (ReaderImageAction.save, strings.readerSaveImageTitle),
    ];

    Widget action(String label, ReaderImageAction? result) => InkWell(
      onTap: () => Navigator.of(context).pop(result),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );

    Widget frostedSurface({required Color color, required Widget child}) =>
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Material(
              color: color.withValues(alpha: surfaceAlpha),
              child: child,
            ),
          ),
        );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              frostedSurface(
                color: colors.surfaceContainerLow,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: colors.outlineVariant,
                        ),
                      action(actions[i].$2, actions[i].$1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              frostedSurface(
                color: colors.surfaceContainerHigh,
                child: action(strings.commonCancel, null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
