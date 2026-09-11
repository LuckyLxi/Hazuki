import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';

Future<void> showReaderWindowsShortcutsDialog(
  BuildContext context, {
  ThemeData? theme,
}) {
  final dialogTheme = theme ?? Theme.of(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => Theme(
      data: dialogTheme,
      child: const SafeArea(child: _ReaderWindowsShortcutsDialog()),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final movement = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final scale = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        key: const ValueKey('reader-windows-shortcuts-fade'),
        opacity: movement,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(movement),
          child: ScaleTransition(
            key: const ValueKey('reader-windows-shortcuts-scale'),
            scale: Tween<double>(begin: 0.92, end: 1).animate(scale),
            child: child,
          ),
        ),
      );
    },
  );
}

class _ReaderWindowsShortcutsDialog extends StatelessWidget {
  const _ReaderWindowsShortcutsDialog();

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height - 48,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.keyboard_alt_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.readerWindowsShortcutsTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.readerWindowsShortcutsIntro,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ShortcutRow(
                        keys: const ['Alt', '↕'],
                        description: strings.readerWindowsShortcutsZoom,
                      ),
                      _ShortcutRow(
                        keys: const ['↑', '↓'],
                        description:
                            strings.readerWindowsShortcutsVerticalPaging,
                      ),
                      _ShortcutRow(
                        keys: const ['←', '→'],
                        description:
                            strings.readerWindowsShortcutsHorizontalPaging,
                      ),
                      _ShortcutRow(
                        keys: const ['Ctrl', '← / →'],
                        description:
                            strings.readerWindowsShortcutsChapterPaging,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          strings.readerWindowsShortcutsReopenHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => unawaited(Navigator.of(context).maybePop()),
                  child: Text(strings.commonClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.description});

  final List<String> keys;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final key in keys) _KeyCap(label: key)],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(description, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
