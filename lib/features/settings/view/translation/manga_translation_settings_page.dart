import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../shared/translation/manga_translation_dependencies.dart';
import '../../../../l10n/l10n.dart';
import '../../../../services/translation/manga_translation_provider.dart';
import '../../../../services/translation/manga_translation_settings_store.dart';
import '../../../../services/translation/translation_failure.dart';
import '../../../../services/translation/translation_prompt.dart';
import '../../../../shared/translation/translation_failure_message.dart';
import '../../../../shared/translation/translation_confirmation_dialog.dart';
import '../settings_group.dart';
import 'translation_detector_group.dart';
import 'translation_usage_group.dart';

class MangaTranslationSettingsPage extends StatefulWidget {
  const MangaTranslationSettingsPage({super.key, required this.dependencies});
  final MangaTranslationDependencies dependencies;

  @override
  State<MangaTranslationSettingsPage> createState() =>
      _MangaTranslationSettingsPageState();
}

class _MangaTranslationSettingsPageState
    extends State<MangaTranslationSettingsPage> {
  late final _settings = widget.dependencies.settings;
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _systemPrompt = TextEditingController();
  final _token = CancelToken();
  bool _ready = false, _busy = false, _obscure = true;
  int _cacheBytes = 0;
  TranslationProviderPreset? _fieldsPreset;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_syncFields);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _settings.load();
      await widget.dependencies.models.load();
      final bytes = await widget.dependencies.cache.sizeBytes();
      if (!mounted) return;
      _syncFields();
      _systemPrompt.text = _settings.customSystemPrompt;
      setState(() {
        _ready = true;
        _cacheBytes = bytes;
      });
    } catch (_) {
      if (mounted) _message(l10n(context).translationSettingsFailed);
    }
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
      final provider = widget.dependencies.providers.create(
        _settings.providerPreset,
        _settings.configuration,
      );
      final models = await provider.listModels(cancelToken: _token);
      if (testConnection) {
        final image = await Isolate.run(() {
          final image = img.Image(width: 120, height: 48);
          img.fill(image, color: img.ColorRgb8(255, 255, 255));
          img.drawString(
            image,
            'Hello',
            font: img.arial24,
            x: 12,
            y: 10,
            color: img.ColorRgb8(0, 0, 0),
          );
          return TranslationImagePayload(
            jpegBytes: img.encodeJpg(image, quality: 85),
            width: image.width,
            height: image.height,
          );
        });
        final raw = await provider.translateImage(
          image,
          buildTranslationSystemPrompt(
            targetLanguage: _settings.targetLanguage,
            translateSfx: _settings.translateSfx,
            customInstructions: _settings.customSystemPrompt,
          ),
          buildTranslationUserPrompt(),
          cancelToken: _token,
        );
        widget.dependencies.parser.parse(
          raw.text,
          translateSfx: _settings.translateSfx,
        );
        if (mounted) _message(l10n(context).translationConnectionOk);
      } else if (mounted) {
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

  Future<void> _clearCache() async {
    if (!await confirmTranslationClear(context)) return;
    await _save(widget.dependencies.cache.clear());
    final bytes = await widget.dependencies.cache.sizeBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  @override
  void dispose() {
    _token.cancel();
    _settings.removeListener(_syncFields);
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _systemPrompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.translationTitle)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _settings,
              builder: (context, _) {
                final preset = _settings.providerPreset;
                Widget field(
                  TextEditingController controller,
                  String label,
                  ValueChanged<String> changed, {
                  bool secret = false,
                }) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
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
                          SwitchListTile(
                            title: Text(strings.translationEnable),
                            subtitle: Text(strings.translationPrivacy),
                            value: _settings.enabled,
                            onChanged: (value) =>
                                _save(_settings.setEnabled(value)),
                          ),
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
                                          _save(
                                            _settings.setProviderPreset(value),
                                          ),
                                        );
                                      }
                                    },
                              items: [
                                for (final value
                                    in TranslationProviderPreset.values)
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(switch (value) {
                                      TranslationProviderPreset.openai =>
                                        'OpenAI',
                                      TranslationProviderPreset.gemini =>
                                        'Gemini',
                                      TranslationProviderPreset.claude =>
                                        'Claude',
                                      TranslationProviderPreset.custom =>
                                        strings.translationCustom,
                                    }),
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
                                  child: Text(
                                    strings.translationTestConnection,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      TranslationDetectorGroup(
                        settings: _settings,
                        models: widget.dependencies.models,
                      ),
                      SettingsGroup(
                        children: [
                          ListTile(
                            title: Text(strings.translationSystemPrompt),
                            subtitle: Text(strings.translationSystemPromptHint),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              key: const ValueKey('translation-system-prompt'),
                              controller: _systemPrompt,
                              enabled: !_busy,
                              minLines: 4,
                              maxLines: 8,
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
                                  onPressed: _busy
                                      ? null
                                      : () => _save(
                                          _settings.setCustomSystemPrompt(
                                            _systemPrompt.text,
                                          ),
                                        ),
                                  child: Text(strings.commonSave),
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          _systemPrompt.clear();
                                          unawaited(
                                            _save(
                                              _settings.setCustomSystemPrompt(
                                                '',
                                              ),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    strings.translationResetSystemPrompt,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SettingsGroup(
                        children: [
                          ListTile(
                            title: Text(strings.translationTargetLanguage),
                            subtitle: DropdownButton<TranslationTargetLanguage>(
                              isExpanded: true,
                              value: _settings.targetLanguage,
                              onChanged: (value) {
                                if (value != null) {
                                  unawaited(
                                    _save(_settings.setTargetLanguage(value)),
                                  );
                                }
                              },
                              items: [
                                for (final value
                                    in TranslationTargetLanguage.values)
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      [
                                        strings.translationLanguageZhHans,
                                        strings.translationLanguageZhHant,
                                        strings.translationLanguageEn,
                                        strings.translationLanguageJa,
                                        strings.translationLanguageKo,
                                        strings.translationLanguageEs,
                                        strings.translationLanguageFr,
                                        strings.translationLanguageDe,
                                        strings.translationLanguageRu,
                                        strings.translationLanguagePt,
                                      ][value.index],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ListTile(
                            title: Text(strings.translationPrefetch),
                            subtitle: _settings.prefetchAhead == 0
                                ? Text(strings.translationCurrentOnly)
                                : null,
                            trailing: Text('${_settings.prefetchAhead}'),
                          ),
                          Slider(
                            value: _settings.prefetchAhead.toDouble(),
                            min: 0,
                            max: 5,
                            divisions: 5,
                            label: '${_settings.prefetchAhead}',
                            onChanged: (value) => unawaited(
                              _save(_settings.setPrefetchAhead(value.round())),
                            ),
                          ),
                          ListTile(
                            title: Text(strings.translationBubbleStyle),
                            subtitle: DropdownButton<TranslationBubbleStyle>(
                              isExpanded: true,
                              value: _settings.bubbleStyle,
                              onChanged: (value) {
                                if (value != null) {
                                  unawaited(
                                    _save(_settings.setBubbleStyle(value)),
                                  );
                                }
                              },
                              items: [
                                DropdownMenuItem(
                                  value: TranslationBubbleStyle.sampled,
                                  child: Text(strings.translationSampled),
                                ),
                                DropdownMenuItem(
                                  value: TranslationBubbleStyle.white,
                                  child: Text(strings.translationWhite),
                                ),
                              ],
                            ),
                          ),
                          SwitchListTile(
                            title: Text(strings.translationSfx),
                            value: _settings.translateSfx,
                            onChanged: (value) =>
                                _save(_settings.setTranslateSfx(value)),
                          ),
                        ],
                      ),
                      SettingsGroup(
                        children: [
                          ListTile(
                            title: Text(strings.translationCache),
                            subtitle: Text(
                              '${(_cacheBytes / 1024 / 1024).toStringAsFixed(2)} MB',
                            ),
                            trailing: TextButton(
                              onPressed: _clearCache,
                              child: Text(strings.translationClear),
                            ),
                          ),
                        ],
                      ),
                      TranslationUsageGroup(store: widget.dependencies.usage),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
