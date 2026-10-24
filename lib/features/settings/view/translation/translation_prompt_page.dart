import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../../services/translation/manga_translation_settings_store.dart';
import '../settings_group.dart';

/// 自定义系统提示词；保存后才写入设置。
class TranslationPromptPage extends StatefulWidget {
  const TranslationPromptPage({super.key, required this.settings});
  final MangaTranslationSettingsStore settings;

  @override
  State<TranslationPromptPage> createState() => _TranslationPromptPageState();
}

class _TranslationPromptPageState extends State<TranslationPromptPage> {
  late final _systemPrompt = TextEditingController(
    text: widget.settings.customSystemPrompt,
  );

  Future<void> _save(Future<void> action) async {
    try {
      await action;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n(context).translationSettingsFailed)),
        );
      }
    }
  }

  @override
  void dispose() {
    _systemPrompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.translationSystemPrompt)),
      body: HazukiSettingsPageBody(
        child: ListView(
          children: [
            SettingsGroup(
              children: [
                ListTile(subtitle: Text(strings.translationSystemPromptHint)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const ValueKey('translation-system-prompt'),
                    controller: _systemPrompt,
                    minLines: 6,
                    maxLines: 12,
                    decoration: InputDecoration(
                      labelText: strings.translationSystemPrompt,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => _save(
                          widget.settings.setCustomSystemPrompt(
                            _systemPrompt.text,
                          ),
                        ),
                        child: Text(strings.commonSave),
                      ),
                      TextButton(
                        onPressed: () {
                          _systemPrompt.clear();
                          unawaited(
                            _save(widget.settings.setCustomSystemPrompt('')),
                          );
                        },
                        child: Text(strings.translationResetSystemPrompt),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
