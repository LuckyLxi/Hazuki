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

  /// 执行一次术语写入并刷新列表，失败时提示。
  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) {
        setState(() {
          _entries = _load();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context).translationUnknown)),
        );
      }
    }
  }

  Future<void> _edit([TranslationGlossaryEntry? entry]) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _GlossaryTermDialog(entry: entry),
    );
    if (result == null) return;
    await _mutate(
      () => widget.controller.glossary.saveEntry(
        widget.controller.sourceKey,
        widget.controller.comicId,
        source: result.$1,
        target: result.$2,
        previousSource: entry?.source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.translationGlossary,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(strings.translationAddTerm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TranslationGlossaryEntry>>(
                future: _entries,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(strings.translationUnknown));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(strings.translationGlossaryEmpty),
                    );
                  }
                  return ListView(
                    children: [
                      for (final entry in snapshot.data!)
                        ListTile(
                          title: Text('${entry.source} → ${entry.target}'),
                          onTap: () => _edit(entry),
                          trailing: IconButton(
                            tooltip: strings.translationDeleteTerm,
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _mutate(
                              () => widget.controller.glossary.removeEntry(
                                widget.controller.sourceKey,
                                widget.controller.comicId,
                                entry.source,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新增或编辑一条术语；确认时返回去除首尾空白的（原文, 译文）。
class _GlossaryTermDialog extends StatefulWidget {
  const _GlossaryTermDialog({this.entry});
  final TranslationGlossaryEntry? entry;

  @override
  State<_GlossaryTermDialog> createState() => _GlossaryTermDialogState();
}

class _GlossaryTermDialogState extends State<_GlossaryTermDialog> {
  late final _source = TextEditingController(text: widget.entry?.source);
  late final _target = TextEditingController(text: widget.entry?.target);

  bool get _valid =>
      _source.text.trim().isNotEmpty && _target.text.trim().isNotEmpty;

  void _submit() {
    if (_valid) {
      Navigator.pop(context, (_source.text.trim(), _target.text.trim()));
    }
  }

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return AlertDialog(
      title: Text(
        widget.entry == null
            ? strings.translationAddTerm
            : strings.translationEditTerm,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('glossary-term-source'),
            controller: _source,
            autofocus: widget.entry == null,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: strings.translationTermSource,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('glossary-term-target'),
            controller: _target,
            autofocus: widget.entry != null,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: strings.translationTermTarget,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.commonCancel),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: Text(strings.commonSave),
        ),
      ],
    );
  }
}
