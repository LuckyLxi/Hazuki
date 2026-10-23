import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';

import '../manga_translation_provider.dart';
import '../models/translation_models.dart';
import '../translation_failure.dart';

class AnthropicProvider extends HttpMangaTranslationProvider {
  AnthropicProvider({
    required super.dio,
    required super.baseUrl,
    required super.apiKey,
    required super.model,
  });

  @override
  Map<String, String> get headers => {
    'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
  };

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
        'messages',
        data: {
          'model': model,
          'max_tokens': 4096,
          'system': systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': 'image/jpeg',
                    'data': encoded,
                  },
                },
                {'type': 'text', 'text': userPrompt},
              ],
            },
          ],
        },
        cancelToken: cancelToken,
      );
      final text = (response['content'] as List)
          .cast<Map<String, dynamic>>()
          .where((block) => block['type'] == 'text')
          .map((block) => block['text'] as String)
          .join('\n');
      if (text.trim().isEmpty) {
        throw const TranslationFailure(TranslationFailureKind.badResponse);
      }
      final usage = response['usage'] as Map?;
      return ProviderRawResponse(
        text: text,
        usage: TranslationUsage(
          inputTokens: (usage?['input_tokens'] as num?)?.toInt() ?? 0,
          outputTokens: (usage?['output_tokens'] as num?)?.toInt() ?? 0,
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
