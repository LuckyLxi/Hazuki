import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';

import '../manga_translation_provider.dart';
import '../manga_translation_settings_store.dart';
import '../models/translation_models.dart';
import '../translation_failure.dart';

class OpenAiCompatibleProvider extends HttpMangaTranslationProvider {
  OpenAiCompatibleProvider({
    required super.dio,
    required super.baseUrl,
    required super.apiKey,
    required super.model,
    required this.jsonResponseFormat,
    this.reasoningEffort = TranslationReasoningEffort.providerDefault,
  });

  final bool jsonResponseFormat;
  final TranslationReasoningEffort reasoningEffort;

  @override
  Map<String, String> get headers => {'Authorization': 'Bearer $apiKey'};

  @override
  Future<ProviderRawResponse> translateImage(
    TranslationImagePayload image,
    String systemPrompt,
    String userPrompt, {
    CancelToken? cancelToken,
  }) async {
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw const TranslationFailure(TranslationFailureKind.cancelled);
      }
      final bytes = image.jpegBytes;
      final encoded = await Isolate.run(() => base64Encode(bytes));
      final response = await requestJson(
        'chat/completions',
        data: {
          'model': model,
          if (reasoningEffort != TranslationReasoningEffort.providerDefault)
            'reasoning_effort': reasoningEffort.name,
          if (jsonResponseFormat) 'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': userPrompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$encoded'},
                },
              ],
            },
          ],
        },
        cancelToken: cancelToken,
      );
      final choices = response['choices'] as List;
      if (choices.isEmpty) {
        throw const TranslationFailure(TranslationFailureKind.badResponse);
      }
      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>;
      final text = message['content'] as String;
      if (text.trim().isEmpty) {
        throw const TranslationFailure(TranslationFailureKind.badResponse);
      }
      final usage = response['usage'] as Map?;
      return ProviderRawResponse(
        text: text,
        usage: TranslationUsage(
          inputTokens: (usage?['prompt_tokens'] as num?)?.toInt() ?? 0,
          outputTokens: (usage?['completion_tokens'] as num?)?.toInt() ?? 0,
        ),
      );
    } catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        throw const TranslationFailure(TranslationFailureKind.cancelled);
      }
      throw TranslationFailure.from(error);
    }
  }
}
