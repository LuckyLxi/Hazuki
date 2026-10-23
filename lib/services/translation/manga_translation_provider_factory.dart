import 'package:dio/dio.dart';

import '../network/hazuki_network_factory.dart';
import 'manga_translation_provider.dart';
import 'manga_translation_settings_store.dart';
import 'providers/anthropic_provider.dart';
import 'providers/open_ai_compatible_provider.dart';

class MangaTranslationProviderFactory {
  MangaTranslationProviderFactory({Dio? dio})
    : _dio =
          dio ??
          createHazukiDio(
            baseOptions: BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 90),
            ),
          );

  final Dio _dio;

  MangaTranslationProvider create(
    TranslationProviderPreset preset,
    TranslationProviderConfiguration configuration,
  ) => switch (preset) {
    TranslationProviderPreset.claude => AnthropicProvider(
      dio: _dio,
      baseUrl: configuration.baseUrl,
      apiKey: configuration.apiKey,
      model: configuration.model,
      reasoningEffort: configuration.reasoningEffort,
    ),
    _ => OpenAiCompatibleProvider(
      dio: _dio,
      baseUrl: configuration.baseUrl,
      apiKey: configuration.apiKey,
      model: configuration.model,
      reasoningEffort: configuration.reasoningEffort,
      jsonResponseFormat: preset != TranslationProviderPreset.custom,
    ),
  };

  void dispose() => _dio.close(force: true);
}
