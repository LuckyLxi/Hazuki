import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/translation/manga_translation_settings_store.dart';
import '../../../../services/translation/translation_failure.dart';
import '../../../../shared/translation/manga_translation_dependencies.dart';
import '../../../../shared/translation/translation_failure_message.dart';
import '../settings_group.dart';

/// 服务商、接口、模型与思考强度配置；进入前设置须已加载。
class TranslationProviderPage extends StatefulWidget {
  const TranslationProviderPage({super.key, required this.dependencies});
  final MangaTranslationDependencies dependencies;

  @override
  State<TranslationProviderPage> createState() =>
      _TranslationProviderPageState();
}

class _TranslationProviderPageState extends State<TranslationProviderPage> {
  late final _settings = widget.dependencies.settings;
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _token = CancelToken();
  bool _busy = false, _obscure = true;
  TranslationProviderPreset? _fieldsPreset;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_syncFields);
    _syncFields();
  }

  void _syncFields() {
    if (!mounted || _fieldsPreset == _settings.providerPreset) return;
    _fieldsPreset = _settings.providerPreset;
    for (final pair in [
      (_baseUrl, _settings.baseUrl),
      (_apiKey, _settings.apiKey),
      (_model, _settings.model),
    ]) {
      if (pair.$1.text != pair.$2) pair.$1.text = pair.$2;
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save(Future<void> action) async {
    try {
      await action;
    } catch (_) {
      if (mounted) _message(l10n(context).translationSettingsFailed);
    }
  }

  Future<void> _request({required bool testConnection}) async {
    if (_baseUrl.text.trim().isEmpty ||
        _apiKey.text.trim().isEmpty ||
        testConnection && _model.text.trim().isEmpty) {
      _message(l10n(context).translationConfigure);
      return;
    }
    setState(() => _busy = true);
    try {
      await _settings.updateProvider(
        preset: _settings.providerPreset,
        baseUrl: _baseUrl.text,
        apiKey: _apiKey.text,
        model: _model.text,
      );
      final service = widget.dependencies.service;
      if (testConnection) {
        await service.testProviderConnection(cancelToken: _token);
        if (mounted) _message(l10n(context).translationConnectionOk);
        return;
      }
      final models = await service.listProviderModels(cancelToken: _token);
      if (mounted) {
        if (models.isEmpty) {
          _message(l10n(context).translationNoModels);
          return;
        }
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n(context).translationModel),
            children: [
              for (final model in models)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, model),
                  child: Text(model),
                ),
            ],
          ),
        );
        if (selected != null && mounted) {
          await _settings.updateProvider(
            preset: _settings.providerPreset,
            model: selected,
          );
          _model.text = selected;
        }
      }
    } catch (error) {
      final failure = TranslationFailure.from(error);
      if (mounted && failure.kind != TranslationFailureKind.cancelled) {
        _message(translationFailureMessage(l10n(context), failure.kind));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _token.cancel();
    _settings.removeListener(_syncFields);
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.translationProviderAndModel)),
      body: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          final preset = _settings.providerPreset;
          Widget field(
            TextEditingController controller,
            String label,
            ValueChanged<String> changed, {
            bool secret = false,
          }) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: controller,
              enabled: !_busy,
              obscureText: secret && _obscure,
              autocorrect: !secret,
              enableSuggestions: !secret,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixIcon: secret
                    ? IconButton(
                        tooltip: label,
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )
                    : null,
              ),
              onChanged: changed,
            ),
          );
          return HazukiSettingsPageBody(
            child: ListView(
              children: [
                SettingsGroup(
                  children: [
                    ListTile(
                      title: Text(strings.translationProvider),
                      subtitle: DropdownButton<TranslationProviderPreset>(
                        isExpanded: true,
                        value: preset,
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value != null) {
                                  unawaited(
                                    _save(_settings.setProviderPreset(value)),
                                  );
                                }
                              },
                        items: [
                          for (final value in TranslationProviderPreset.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(
                                translationProviderLabel(strings, value),
                              ),
                            ),
                        ],
                      ),
                    ),
                    field(
                      _baseUrl,
                      strings.translationBaseUrl,
                      (value) => unawaited(
                        _save(
                          _settings.updateProvider(
                            preset: preset,
                            baseUrl: value,
                          ),
                        ),
                      ),
                    ),
                    field(
                      _apiKey,
                      strings.translationApiKey,
                      (value) => unawaited(
                        _save(
                          _settings.updateProvider(
                            preset: preset,
                            apiKey: value,
                          ),
                        ),
                      ),
                      secret: true,
                    ),
                    field(
                      _model,
                      strings.translationModel,
                      (value) => unawaited(
                        _save(
                          _settings.updateProvider(
                            preset: preset,
                            model: value,
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      title: Text(strings.translationReasoningEffort),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButton<TranslationReasoningEffort>(
                            isExpanded: true,
                            value: _settings.reasoningEffort,
                            onChanged: _busy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      unawaited(
                                        _save(
                                          _settings.updateProvider(
                                            preset: preset,
                                            reasoningEffort: value,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            items: [
                              for (final value
                                  in TranslationReasoningEffort.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(switch (value) {
                                    TranslationReasoningEffort
                                        .providerDefault =>
                                      strings.translationReasoningDefault,
                                    TranslationReasoningEffort.off =>
                                      strings.translationReasoningOff,
                                    TranslationReasoningEffort.low =>
                                      strings.translationReasoningLow,
                                    TranslationReasoningEffort.medium =>
                                      strings.translationReasoningMedium,
                                    TranslationReasoningEffort.high =>
                                      strings.translationReasoningHigh,
                                  }),
                                ),
                            ],
                          ),
                          Text(strings.translationReasoningHint),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _request(testConnection: false),
                            child: Text(strings.translationFetchModels),
                          ),
                          FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _request(testConnection: true),
                            child: Text(strings.translationTestConnection),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String translationProviderLabel(
  AppLocalizations strings,
  TranslationProviderPreset preset,
) => switch (preset) {
  TranslationProviderPreset.openai => 'OpenAI',
  TranslationProviderPreset.gemini => 'Gemini',
  TranslationProviderPreset.claude => 'Claude',
  TranslationProviderPreset.custom => strings.translationCustom,
};
