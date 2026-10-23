import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../services/translation/translation_glossary_store.dart';
import '../support/reader_translation_controller.dart';

enum ReaderTranslationAction { retranslate, glossary, clearGlossary }

class ReaderTranslationActionsSheet extends StatelessWidget {
  const ReaderTranslationActionsSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), strings = l10n(context);
    Widget action(String text, ReaderTranslationAction? value) => InkWell(
      onTap: () => Navigator.pop(context, value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
    Widget surface(Widget child) => ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: theme.colorScheme.surfaceContainerLow.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.68 : 0.76,
          ),
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
              surface(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    action(
                      strings.translationRetranslate,
                      ReaderTranslationAction.retranslate,
                    ),
                    const Divider(height: 1),
                    action(
                      strings.translationGlossary,
                      ReaderTranslationAction.glossary,
                    ),
                    const Divider(height: 1),
                    action(
                      strings.translationClearGlossary,
                      ReaderTranslationAction.clearGlossary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              surface(action(strings.commonCancel, null)),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderTranslationGlossarySheet extends StatefulWidget {
  const ReaderTranslationGlossarySheet({super.key, required this.controller});
  final ReaderTranslationController controller;
  @override
  State<ReaderTranslationGlossarySheet> createState() =>
      _ReaderTranslationGlossarySheetState();
}

class _ReaderTranslationGlossarySheetState
    extends State<ReaderTranslationGlossarySheet> {
  late Future<List<TranslationGlossaryEntry>> _entries = _load();
  Future<List<TranslationGlossaryEntry>> _load() => widget.controller.glossary
      .load(widget.controller.sourceKey, widget.controller.comicId);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: FutureBuilder<List<TranslationGlossaryEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n(context).translationUnknown));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return Center(child: Text(l10n(context).translationGlossaryEmpty));
          }
          return ListView(
            children: [
              for (final entry in snapshot.data!)
                ListTile(
                  title: Text('${entry.source} → ${entry.target}'),
                  trailing: IconButton(
                    tooltip: l10n(context).translationDeleteTerm,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      try {
                        await widget.controller.glossary.removeEntry(
                          widget.controller.sourceKey,
                          widget.controller.comicId,
                          entry.source,
                        );
                        if (mounted) {
                          setState(() {
                            _entries = _load();
                          });
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n(context).translationUnknown),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
